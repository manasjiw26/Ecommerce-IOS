const express = require('express');
const router = express.Router();
const { supabase } = require('../supabaseClient');
const { GoogleGenAI } = require('@google/genai');

const ai = new GoogleGenAI({
    apiKey: process.env.GEMINI_API_KEY
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
        
        const { data, error } = await supabase.rpc('hybrid_search', {
            query_text: query,
            query_embedding: queryEmbedding,
            match_count: 20
        });

        if (error) throw error;
        res.json(data);
    } catch (error) {
        console.error('Local Search Failed. Falling back to Native Postgres ILIKE:', error.message);
        
        // Sanitize query into keywords
        const stopwords = ['can','you','find','me','some','show','looking','for','i','want','to','buy','do','have','the','a','an','is','are','of','in','on','with'];
        const keywords = query.toLowerCase().replace(/[^a-z0-9 ]/g, '').split(' ').filter(w => w.length > 2 && !stopwords.includes(w));
        
        // If no keywords found, fallback to original query
        const searchTerms = keywords.length > 0 ? keywords : [query];
        const orConditions = searchTerms.map(kw => `name.ilike.%${kw}%,description.ilike.%${kw}%,category.ilike.%${kw}%`).join(',');

        const { data: fallbackData, error: fallbackError } = await supabase
            .from('products')
            .select('*')
            .or(orConditions)
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
                // We still use Gemini 1.5 Flash for the actual generation, as it works perfectly!
                const queryResponse = await ai.models.generateContent({
                    model: 'gemini-2.5-flash',
                    contents: `User history:\n${recentHistoryText}\nBased on this, what 3-5 words describe what they might want to buy next? Return ONLY the search string.`
                });
                console.log('✅ Intent generated using Gemini (gemini-2.5-flash)');
                const searchIntent = queryResponse.text.trim();

                // Generate vector locally to match Supabase pgvector!
                const queryEmbedding = await getLocalEmbedding(searchIntent);

                const { data: searchResults } = await supabase.rpc('hybrid_search', {
                    query_text: searchIntent,
                    query_embedding: queryEmbedding,
                    match_count: 20
                });
                candidates = searchResults || [];
            } catch (aiError) {
                console.error("AI Intent Generation Failed. Falling back to history categories.", aiError.message);
                const categories = [...new Set(historyProducts.map(p => p.category))];
                const { data: fallbackCandidates } = await supabase.from('products').select('*').in('category', categories).limit(20);
                candidates = fallbackCandidates || [];
            }
        }

        if (candidates.length === 0) return res.json([]);

        let recommendedItems = [];
        try {
            const finalPrompt = `You are an expert e-commerce assistant. Pick 5 diverse products from this list:\n${JSON.stringify(candidates.map(c => ({id: c.id, name: c.name, category: c.category})))}\n\nReturn ONLY a valid JSON array of objects with "id" (number) and "reasoning" (1-sentence pitch).`;
            const response = await ai.models.generateContent({
                model: 'gemini-2.5-flash',
                contents: finalPrompt,
                config: { temperature: 0.2, responseMimeType: "application/json" }
            });
            console.log('✅ Re-ranking completed using Gemini (gemini-2.5-flash)');
            recommendedItems = JSON.parse(response.text);
        } catch(e) {
            console.error("Gemini Re-ranking Failed. Falling back to pure data.", e.message);
            recommendedItems = candidates.slice(0, 5).map(c => ({
                id: c.id,
                reasoning: "Highly recommended for you based on our catalog."
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

module.exports = router;
