const express = require('express');
const router = express.Router();
const { supabase } = require('../supabaseClient');
const { GoogleGenAI } = require('@google/genai');

// Initialize Gemini API
const ai = new GoogleGenAI({
    apiKey: process.env.GEMINI_API_KEY
});

// POST /ai/events
// Logs a user event (view, add_to_cart, purchase)
router.post('/events', async (req, res) => {
    const { device_id, product_id, event_type } = req.body;

    if (!device_id || !product_id || !event_type) {
        return res.status(400).json({ error: 'Missing required fields' });
    }

    try {
        const { error } = await supabase
            .from('user_events')
            .insert([{ device_id, product_id, event_type }]);

        if (error) throw error;

        res.json({ success: true });
    } catch (error) {
        console.error('Error logging event:', error);
        res.status(500).json({ error: error.message });
    }
});

// POST /ai/recommend
// Generates personalized recommendations using Gemini
router.post('/recommend', async (req, res) => {
    const { device_id } = req.body;

    if (!device_id) {
        return res.status(400).json({ error: 'Missing device_id' });
    }

    try {
        // 1. Fetch user's recent events
        const { data: events, error: eventsError } = await supabase
            .from('user_events')
            .select('product_id, event_type')
            .eq('device_id', device_id)
            .order('timestamp', { ascending: false })
            .limit(20);

        if (eventsError) throw eventsError;

        // 2. Fetch active product catalog
        const { data: catalog, error: catalogError } = await supabase
            .from('products')
            .select('id, name, price, category, description');

        if (catalogError) throw catalogError;

        // Map event product IDs to actual product details for context
        const recentHistory = events.map(e => {
            const product = catalog.find(p => p.id === e.product_id);
            return product ? `${e.event_type} - ${product.name} (${product.category})` : null;
        }).filter(Boolean);

        // 3. Construct Gemini Prompt
        let promptText = "";
        
        if (recentHistory.length === 0) {
            promptText = `You are an expert e-commerce shopping assistant for Williams Sonoma. The user has no history yet. 
Here is our catalog:
${JSON.stringify(catalog)}

Pick 5 diverse, popular products from the catalog to recommend.
Return ONLY a valid JSON array of objects, with each object containing "id" (number) and "reasoning" (a short string, e.g., "A great starting piece for your kitchen."). No other text or formatting.`;
        } else {
            promptText = `You are an expert e-commerce shopping assistant for Williams Sonoma. 
The user recently did the following actions:
${recentHistory.join('\n')}

Based on this behavior, look at our catalog and recommend 5 products they might want to buy next:
${JSON.stringify(catalog)}

Return ONLY a valid JSON array of objects, with each object containing "id" (number) and "reasoning" (a short, personalized 1-sentence explanation of why you recommend this based on their history, e.g., "Since you were looking at Cast Iron pans, this lid is a perfect match."). No other text or markdown formatting.`;
        }

        // 4. Call Gemini
        const response = await ai.models.generateContent({
            model: 'gemini-1.5-flash',
            contents: promptText,
            config: {
                temperature: 0.2,
                responseMimeType: "application/json"
            }
        });

        const textResponse = response.text;
        
        let recommendedItems = [];
        try {
            recommendedItems = JSON.parse(textResponse);
        } catch(e) {
            console.error("Failed to parse Gemini response:", textResponse);
            return res.status(500).json({ error: "Failed to generate recommendations" });
        }

        // 5. Hydrate recommendations with full product details
        const fullRecommendations = recommendedItems.map(item => {
            const productDetails = catalog.find(p => p.id === item.id);
            if (!productDetails) return null;
            return {
                ...productDetails,
                ai_reasoning: item.reasoning
            };
        }).filter(Boolean);

        res.json(fullRecommendations);

    } catch (error) {
        console.error('Error in /ai/recommend:', error);
        res.status(500).json({ error: error.message });
    }
});

module.exports = router;
