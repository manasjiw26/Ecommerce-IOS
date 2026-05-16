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

// POST /ai/events
// Logs a user event (view, add_to_cart, purchase)
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

// POST /ai/search
router.post('/search', async (req, res) => {
    const { query } = req.body;
    if (!query) return res.status(400).json({ error: 'Missing query' });

    try {
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

// POST /ai/recommend
// Cart-aware AI recommendation engine.
// PRIMARY signal: current cart contents (cart_items).
// SECONDARY signal: historical user_events.
router.post('/recommend', async (req, res) => {
    const { device_id, cart_items } = req.body;
    if (!device_id) return res.status(400).json({ error: 'Missing device_id' });

    try {
        // ── 1. Fetch historical events (secondary context) ──────────────
        const { data: events } = await supabase.from('user_events')
            .select('product_id, event_type')
            .eq('device_id', device_id)
            .order('timestamp', { ascending: false })
            .limit(10);

        let recentHistoryText = "";
        if (events && events.length > 0) {
            const productIds = events.map(e => e.product_id);
            const { data: historyProducts } = await supabase.from('products')
                .select('id, name, category, item_tag')
                .in('id', productIds);
            
            recentHistoryText = events.map(e => {
                const p = historyProducts?.find(prod => prod.id === e.product_id);
                return p ? `${e.event_type}: ${p.name} (${p.category || 'General'})${p.item_tag ? ' [' + p.item_tag + ']' : ''}` : null;
            }).filter(Boolean).join('\n');
        }

        // ── 2. Determine recommendation mode ────────────────────────────
        const hasCart = Array.isArray(cart_items) && cart_items.length > 0;
        const cartCount = hasCart ? cart_items.length : 0;
        const cartProductIds = hasCart ? cart_items.map(c => c.id) : [];

        let candidates = [];
        let searchIntent = "";

        if (hasCart) {
            // ═══════════════════════════════════════════════════════════
            // CART-AWARE MODE — cart is the PRIMARY recommendation signal
            // ═══════════════════════════════════════════════════════════

            // Build rich cart description including tags
            const cartDescription = cart_items.map(item => {
                let desc = `${item.name} (${item.category || 'General'})`;
                if (item.item_tag) desc += ` [tags: ${item.item_tag}]`;
                return desc;
            }).join('\n');

            // Determine intelligence level label for the prompt
            let levelHint = "";
            if (cartCount === 1) {
                levelHint = "The user has only 1 item. Suggest simple complementary accessories and pairings.";
            } else if (cartCount <= 3) {
                levelHint = "The user has 2-3 items. Try to detect a shopping context (e.g., baking setup, coffee corner, hosting prep) and suggest items that complete that setup.";
            } else {
                levelHint = "The user has 4+ items. Infer a broader lifestyle/intent (e.g., hosting dinner, modern kitchen overhaul, outdoor entertaining) and suggest premium, diverse products that elevate the experience.";
            }

            // Intent generation prompt — cart-first, history-secondary
            let intentPrompt = `You are an expert e-commerce shopping assistant for a premium home & kitchen store.\n\n`;
            intentPrompt += `CURRENT CART (${cartCount} items):\n${cartDescription}\n\n`;
            if (recentHistoryText) {
                intentPrompt += `RECENT BROWSING HISTORY (secondary context):\n${recentHistoryText}\n\n`;
            }
            intentPrompt += `${levelHint}\n\n`;
            intentPrompt += `Based primarily on the CURRENT CART contents (and secondarily on history), what 3-5 word search phrase describes what complementary products this user would want next? Return ONLY the search string, no quotes.`;

            try {
                const queryResponse = await ai.models.generateContent({
                    model: 'gemini-1.5-flash',
                    contents: intentPrompt
                });
                searchIntent = queryResponse.text.trim();
            } catch (aiErr) {
                console.error("Cart intent generation failed:", aiErr.message);
                // Fallback: use cart categories as search
                const categories = [...new Set(cart_items.map(c => c.category).filter(Boolean))];
                searchIntent = categories.join(' ') || 'popular kitchen items';
            }

            // Vector search using the generated intent
            try {
                const queryEmbedding = await getLocalEmbedding(searchIntent);
                const { data: searchResults } = await supabase.rpc('hybrid_search', {
                    query_text: searchIntent,
                    query_embedding: queryEmbedding,
                    match_count: 25
                });
                candidates = searchResults || [];
            } catch (vecErr) {
                console.error("Vector search failed, falling back to category match:", vecErr.message);
                const categories = [...new Set(cart_items.map(c => c.category).filter(Boolean))];
                if (categories.length > 0) {
                    const { data: catProducts } = await supabase.from('products').select('*').in('category', categories).limit(25);
                    candidates = catProducts || [];
                }
            }

            // Remove cart items from candidates
            candidates = candidates.filter(c => !cartProductIds.includes(c.id));

        } else if (events && events.length > 0) {
            // ═══════════════════════════════════════════════════════════
            // HISTORY-ONLY MODE — no cart, use browsing history
            // ═══════════════════════════════════════════════════════════
            try {
                const queryResponse = await ai.models.generateContent({
                    model: 'gemini-1.5-flash',
                    contents: `User history:\n${recentHistoryText}\nBased on this, what 3-5 words describe what they might want to buy next? Return ONLY the search string.`
                });
                searchIntent = queryResponse.text.trim();

                const queryEmbedding = await getLocalEmbedding(searchIntent);
                const { data: searchResults } = await supabase.rpc('hybrid_search', {
                    query_text: searchIntent,
                    query_embedding: queryEmbedding,
                    match_count: 20
                });
                candidates = searchResults || [];
            } catch (aiError) {
                console.error("History intent generation failed:", aiError.message);
                const { data: popular } = await supabase.from('products').select('*').order('stock', { ascending: false }).limit(20);
                candidates = popular || [];
            }
        } else {
            // ═══════════════════════════════════════════════════════════
            // EMPTY MODE — no cart, no history → trending/popular
            // ═══════════════════════════════════════════════════════════
            const { data: popular } = await supabase.from('products').select('*').order('stock', { ascending: false }).limit(20);
            candidates = popular || [];
        }

        if (candidates.length === 0) {
            return res.json({ ai_context: "Handpicked for you", recommendations: [] });
        }

        // ── 3. Gemini re-ranking + context generation ───────────────────
        let recommendedItems = [];
        let aiContext = "Handpicked for you";

        try {
            // Build the re-ranking prompt
            let rerankPrompt = `You are an expert e-commerce assistant for a premium home & kitchen store.\n\n`;

            if (hasCart) {
                const cartSummary = cart_items.map(item => {
                    let desc = `${item.name} (${item.category || 'General'})`;
                    if (item.item_tag) desc += ` [${item.item_tag}]`;
                    return desc;
                }).join(', ');
                rerankPrompt += `The user's CURRENT CART contains: ${cartSummary}\n\n`;
            }

            rerankPrompt += `From this candidate list, pick 5 diverse products that best complement the user's cart:\n`;
            rerankPrompt += JSON.stringify(candidates.slice(0, 15).map(c => ({
                id: c.id, name: c.name, category: c.category, item_tag: c.item_tag
            })));
            rerankPrompt += `\n\nReturn ONLY a valid JSON object with:\n`;
            rerankPrompt += `- "context": a single sentence describing the shopping intent you detect (e.g., "Looks like you're building a baking setup", "Curated for your hosting experience", "Popular pairings for your selection"). This will be shown as a subheading.\n`;
            rerankPrompt += `- "recommendations": an array of objects with "id" (number) and "reasoning" (1-sentence personalized pitch)\n`;
            rerankPrompt += `\nExample: { "context": "...", "recommendations": [{ "id": 5, "reasoning": "..." }] }`;

            const response = await ai.models.generateContent({
                model: 'gemini-1.5-flash',
                contents: rerankPrompt,
                config: { temperature: 0.2, responseMimeType: "application/json" }
            });

            const parsed = JSON.parse(response.text);
            
            if (parsed.context) {
                aiContext = parsed.context;
            }
            if (Array.isArray(parsed.recommendations)) {
                recommendedItems = parsed.recommendations;
            } else if (Array.isArray(parsed)) {
                // Fallback: Gemini returned flat array instead of object
                recommendedItems = parsed;
            }
        } catch(e) {
            console.error("Gemini re-ranking failed. Falling back to raw candidates.", e.message);
            recommendedItems = candidates.slice(0, 5).map(c => ({
                id: c.id,
                reasoning: "Recommended for you based on our catalog."
            }));
            
            if (hasCart) {
                aiContext = "Popular pairings for your selection";
            } else {
                aiContext = "Trending in our collection";
            }
        }

        // ── 4. Hydrate with full product details ────────────────────────
        const fullRecommendations = recommendedItems.map(item => {
            const productDetails = candidates.find(p => p.id === item.id);
            if (!productDetails) return null;
            return { ...productDetails, ai_reasoning: item.reasoning };
        }).filter(Boolean);

        // ── 5. Return wrapped response ──────────────────────────────────
        res.json({
            ai_context: aiContext,
            recommendations: fullRecommendations
        });

    } catch (error) {
        console.error('Critical Error in /ai/recommend:', error);
        res.status(500).json({ error: error.message });
    }
});

module.exports = router;
