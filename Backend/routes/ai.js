/**
 * ai.js — Thin router for all AI endpoints.
 *
 * Search is delegated to the modular search pipeline.
 * Recommend + Events remain unchanged from original implementation.
 */

const express = require('express');
const router = express.Router();
const { supabase } = require('../supabaseClient');
const { GoogleGenAI } = require('@google/genai');

// ── Search Pipeline ───────────────────────────────────────────────────────────
const searchOrchestrator = require('../services/search/searchOrchestrator');
const autocompleteService = require('../services/search/autocompleteService');
const { getEmbedding } = require('../services/search/semanticSearchService');
const analyticsService = require('../services/search/analyticsService');
const trendingService = require('../services/search/trendingService');

// ── Gemini AI (for recommendations — unchanged) ──────────────────────────────
const ai = new GoogleGenAI({
    apiKey: process.env.GEMINI_API_KEY
});

// ══════════════════════════════════════════════════════════════════════════════
//  SEARCH — Delegated to modular pipeline
// ══════════════════════════════════════════════════════════════════════════════

router.post('/search', async (req, res) => {
    const { query, device_id, page, category, max_price, tags } = req.body;
    if (!query) return res.status(400).json({ error: 'Missing query' });

    try {
        // Log to recent_searches
        if (device_id) {
            supabase.from('recent_searches').insert([{
                query: query.trim(),
                device_id: device_id
            }]).then(({error}) => { if(error) console.error("Recent search log failed", error.message); })
            .catch(() => {});
        }

        const results = await searchOrchestrator.execute(query, device_id, {
            limit: 20,
            page: page || 1,
            category: category,
            maxPrice: max_price,
            tags: tags
        });
        res.json(results);
    } catch (error) {
        console.error('Search pipeline error:', error.message);
        res.status(500).json({ error: error.message });
    }
});

// ══════════════════════════════════════════════════════════════════════════════
//  AUTOCOMPLETE — New endpoint
// ══════════════════════════════════════════════════════════════════════════════

router.get('/autocomplete', async (req, res) => {
    const { q, device_id } = req.query;
    // We allow empty q to return trending/recent
    try {
        const suggestions = await autocompleteService.suggest(q || "", device_id, 5);
        res.json(suggestions);
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

// ══════════════════════════════════════════════════════════════════════════════
//  SEARCH ANALYTICS — Click/Conversion tracking + Metrics
// ══════════════════════════════════════════════════════════════════════════════

router.post('/search/analytics', async (req, res) => {
    const { type, search_query, product_id, position, device_id, conversion_type } = req.body;

    if (!type) return res.status(400).json({ error: 'Missing type (click|conversion)' });

    try {
        if (type === 'click') {
            analyticsService.logClick({
                searchQuery: search_query,
                productId: product_id,
                position: position,
                deviceId: device_id,
            });
        } else if (type === 'conversion') {
            analyticsService.logConversion({
                searchQuery: search_query,
                productId: product_id,
                deviceId: device_id,
                conversionType: conversion_type || 'purchase',
            });
        }

        res.json({ success: true });
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

router.get('/search/metrics', async (req, res) => {
    try {
        const hours = parseInt(req.query.hours) || 24;
        const metrics = await analyticsService.getMetrics(hours);
        res.json(metrics);
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

// ══════════════════════════════════════════════════════════════════════════════
//  TRENDING SEARCHES
// ══════════════════════════════════════════════════════════════════════════════

router.get('/trending-searches', async (req, res) => {
    try {
        const limit = parseInt(req.query.limit) || 10;
        const trending = await trendingService.getTrendingQueries(limit);
        res.json(trending);
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

// ══════════════════════════════════════════════════════════════════════════════
//  RECENT SEARCHES — Per device
// ══════════════════════════════════════════════════════════════════════════════

router.get('/recent-searches', async (req, res) => {
    const { device_id } = req.query;
    if (!device_id) return res.status(400).json({ error: 'Missing device_id' });

    try {
        const { data, error } = await supabase
            .from('recent_searches')
            .select('query, created_at')
            .eq('device_id', device_id)
            .order('created_at', { ascending: false })
            .limit(20);

        if (error) throw error;

        // Deduplicate
        const unique = [];
        const seen = new Set();
        for (const row of (data || [])) {
            const q = row.query.toLowerCase().trim();
            if (!seen.has(q)) {
                seen.add(q);
                unique.push({ query: row.query, created_at: row.created_at });
            }
        }

        res.json(unique.slice(0, 10));
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

// ══════════════════════════════════════════════════════════════════════════════
//  EVENTS — Unchanged from original
// ══════════════════════════════════════════════════════════════════════════════

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

// ══════════════════════════════════════════════════════════════════════════════
//  RECOMMEND — Unchanged from original (uses Gemini + hybrid_search)
// ══════════════════════════════════════════════════════════════════════════════

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
                const searchIntent = queryResponse.text.trim();

                // Generate vector via shared semantic service (with caching!)
                const queryEmbedding = await getEmbedding(searchIntent);

                const { data: searchResults, error } = await supabase.rpc('hybrid_search', {
                    query_text: searchIntent,
                    query_embedding: queryEmbedding,
                    match_count: 20
                });
                if (error) throw new Error("hybrid_search failed: " + error.message);
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
