const express = require('express');
const router = express.Router();
const { supabase } = require('../supabaseClient');
const { GoogleGenAI } = require('@google/genai');

const ai = new GoogleGenAI({
    apiKey: process.env.GEMINI_API_KEY,
    apiVersion: 'v1'
});

// Load transformers locally
let pipeline;
(async () => {
    const transformers = await import('@xenova/transformers');
    pipeline = transformers.pipeline;
})();

async function getLocalEmbedding(text) {
    if (!pipeline) throw new Error("Embedder not loaded yet");
    const embedder = await pipeline('feature-extraction', 'Xenova/all-MiniLM-L6-v2');
    const output = await embedder(text, { pooling: 'mean', normalize: true });
    return Array.from(output.data);
}

router.post('/events', async (req, res) => {
    const { device_id, product_id, event_type } = req.body;
    if (!device_id || !product_id || !event_type) return res.status(400).json({ error: 'Missing required fields' });

    try {
        await supabase.from('user_events').insert([{ device_id, product_id, event_type }]);
        res.json({ success: true });
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

router.post('/search', async (req, res) => {
    const { query } = req.body;
    if (!query) return res.status(400).json({ error: 'Missing query' });

    try {
        // Run Local Embedding Generation
        const queryEmbedding = await getLocalEmbedding(query);
        
        // Complex RRF Hybrid Search with Weights
        const { data, error } = await supabase.rpc('hybrid_search', {
            query_text: query,
            query_embedding: queryEmbedding,
            match_count: 20,
            fts_weight: 1.0,        // Complexity: Adjustable weights for keyword matching
            semantic_weight: 1.5    // Complexity: Prioritize AI meaning slightly more
        });

        if (error) throw error;
        res.json(data);
    } catch (error) {
        console.error('Complex Search Failed. Falling back to Native Postgres ILIKE:', error.message);
        
        const fallbackQuery = `%${query}%`;
        const { data: fallbackData, error: fallbackError } = await supabase
            .from('products')
            .select('*')
            .or(`name.ilike.${fallbackQuery},description.ilike.${fallbackQuery},category.ilike.${fallbackQuery}`)
            .order('stock', { ascending: false })
            .limit(20);

        if (fallbackError) {
             return res.status(500).json({ error: fallbackError.message });
        }
        res.json(fallbackData || []);
    }
});

router.post('/recommend', async (req, res) => {
    const { device_id } = req.body;
    if (!device_id) return res.status(400).json({ error: 'Missing device_id' });

    try {
        const { data: events } = await supabase.from('user_events')
            .select('product_id, event_type')
            .eq('device_id', device_id)
            .order('timestamp', { ascending: false })
            .limit(10);

        let candidates = [];
        let recentHistoryText = "";

        if (!events || events.length === 0) {
            const { data: popular } = await supabase.from('products').select('*').order('stock', { ascending: false }).limit(20);
            candidates = popular || [];
        } else {
            const productIds = events.map(e => e.product_id);
            const { data: historyProducts } = await supabase.from('products').select('id, name, category').in('id', productIds);
            
            recentHistoryText = events.map(e => {
                const p = historyProducts.find(prod => prod.id === e.product_id);
                return p ? `${e.event_type}: ${p.name} (${p.category})` : null;
            }).filter(Boolean).join('\n');

            try {
                const response = await ai.models.generateContent({
                    model: "gemini-1.5-flash-8b",
                    contents: [{ role: 'user', parts: [{ text: `User history:\n${recentHistoryText}\nBased on this, what 3-5 words describe what they might want to buy next? Return ONLY the search string.` }] }]
                });
                const searchIntent = response.text().trim();

                // Generate vector locally to match Supabase pgvector!
                const queryEmbedding = await getLocalEmbedding(searchIntent);

                const { data: searchResults } = await supabase.rpc('hybrid_search', {
                    query_text: searchIntent,
                    query_embedding: queryEmbedding,
                    match_count: 5
                });
                candidates = searchResults || [];
            } catch (aiError) {
                console.error("AI Intent Generation Failed. Falling back to history categories.", aiError.message);
                const categories = [...new Set(historyProducts.map(p => p.category))];
                const { data: fallbackCandidates } = await supabase.from('products').select('*').in('category', categories).limit(5);
                candidates = fallbackCandidates || [];
            }
        }

        if (candidates.length === 0) return res.json([]);

        let recommendedItems = [];
        try {
            const finalPrompt = `You are an expert e-commerce assistant. Here are the Top 5 absolute best-matching products for the user based on our internal search engine:\n${JSON.stringify(candidates.map(c => ({id: c.id, name: c.name, category: c.category, tags: c.tags})))}\n\nYour ONLY job is to write a short 1-sentence reasoning pitch for why they would love each product. Do NOT filter or remove any products. Return ONLY a valid JSON array of objects with "id" (number) and "reasoning" (string).`;
            const response = await ai.models.generateContent({
                model: "gemini-1.5-flash-8b",
                contents: [{ role: 'user', parts: [{ text: finalPrompt }] }],
                generationConfig: { temperature: 0.1, responseMimeType: "application/json" }
            });
            recommendedItems = JSON.parse(response.text());
        } catch(e) {
            console.error("Gemini Re-ranking Failed. Falling back to pure data.", e.message);
            recommendedItems = candidates.slice(0, 5).map(c => ({
                id: c.id
            }));
        }

        const fullRecommendations = recommendedItems.map(item => {
            const productDetails = candidates.find(p => p.id === item.id);
            if (!productDetails) return null;
            return { ...productDetails, ai_reasoning: item.reasoning };
        }).filter(Boolean);

        res.json(fullRecommendations);

    } catch (error) {
        console.error('Critical Error in /ai/recommend:', error);
        res.status(500).json({ error: error.message });
    }
});

// A convenient utility route to regenerate embeddings for ALL products in the database
// You can just visit this URL in your browser after uploading a new CSV!
router.get('/regenerate_embeddings', async (req, res) => {
    try {
        // 1. Fetch all products from Supabase
        const { data: products, error: fetchError } = await supabase
            .from('products')
            .select('*');
        
        if (fetchError) throw fetchError;

        let successCount = 0;
        let errors = [];

        // 2. Loop through every product and generate a fresh vector embedding
        for (const p of products) {
            try {
                const textToEmbed = `${p.name} ${p.category} ${p.description || ''} ${(p.tags || []).join(' ')}`;
                const embedding = await getLocalEmbedding(textToEmbed);

                // 3. Save the new vector back to the product_embeddings table
                const { error: upsertError } = await supabase
                    .from('product_embeddings')
                    .upsert({ 
                        product_id: p.id, 
                        embedding: embedding 
                    }, { onConflict: 'product_id' });
                
                if (upsertError) throw upsertError;
                successCount++;
            } catch (err) {
                console.error(`Failed to generate embedding for ${p.name}:`, err.message);
                errors.push({ id: p.id, error: err.message });
            }
        }

        res.json({
            message: "Embeddings regeneration complete!",
            total_processed: products.length,
            success_count: successCount,
            errors: errors
        });
    } catch (error) {
        console.error('Critical Error in /regenerate_embeddings:', error);
        res.status(500).json({ error: error.message });
    }
});

module.exports = router;
