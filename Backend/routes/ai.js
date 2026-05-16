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

// ─────────────────────────────────────────────
// VISUAL SEARCH ROUTES
// ─────────────────────────────────────────────

const STORAGE_BASE = 'https://czahuzfliuuhhegynsjr.supabase.co/storage/v1/object/public/Product%20Images';

function fixImageUrl(product) {
    if (product.image_url && !product.image_url.startsWith('http')) {
        product.image_url = `${STORAGE_BASE}/${encodeURIComponent(product.image_url)}`;
    }
    return product;
}

// POST /ai/visual-search
// Body: { device_id, vision_labels: [{label, confidence}], top_label, base64_image? }
router.post('/visual-search', async (req, res) => {
    const { device_id, vision_labels, top_label, base64_image } = req.body;
    if (!device_id || !Array.isArray(vision_labels) || vision_labels.length === 0) {
        return res.status(400).json({ error: 'Missing required fields' });
    }

    try {
        const labelStrings = vision_labels.map(v => (v.label || v).toLowerCase()).filter(Boolean);
        const top5 = labelStrings.slice(0, 5);

        // ── Step 1: Build text query string from Vision labels ────────────────
        const queryString = vision_labels
            .sort((a, b) => (b.confidence || 0) - (a.confidence || 0))
            .slice(0, 10)
            .map(v => (v.label || v).replace(/_/g, ' ').replace(/\.n\.\d+/g, '').trim())
            .filter(Boolean)
            .join(' ');

        // ── Step 2: Run all queries in parallel ───────────────────────────────
        const [imageSearchResult, textSearchResult, tagMatchResult, ...ilikeResults] =
            await Promise.allSettled([

            // A) CLIP image similarity search (best — true visual match)
            (async () => {
                if (!base64_image) throw new Error('No image provided');
                const { RawImage, pipeline: p } = await import('@xenova/transformers');
                const extractor = await p('image-feature-extraction', 'Xenova/clip-vit-base-patch32');
                const imageBuffer = Buffer.from(base64_image, 'base64');
                const blob = new Blob([imageBuffer], { type: 'image/jpeg' });
                const image = await RawImage.fromBlob(blob);
                const output = await extractor(image, { pooling: 'mean', normalize: true });
                const embedding = Array.from(output.data);
                const { data, error } = await supabase.rpc('image_similarity_search', {
                    query_embedding: embedding,
                    match_count: 20
                });
                if (error) throw error;
                return { results: data || [], type: 'image' };
            })(),

            // B) Text hybrid search (fallback when no image)
            (async () => {
                const embedding = await getLocalEmbedding(queryString);
                const { data, error } = await supabase.rpc('hybrid_search', {
                    query_text: queryString,
                    query_embedding: embedding,
                    match_count: 20
                });
                if (error) throw error;
                return { results: data || [], type: 'text' };
            })(),

            // C) Tag overlap
            supabase
                .from('products')
                .select('id, name, price, image_url, category, tags, description, stock')
                .overlaps('tags', labelStrings)
                .gt('stock', 0),

            // D) ILIKE text search for top 5 labels
            ...top5.map(label =>
                supabase
                    .from('products')
                    .select('id, name, price, image_url, category, tags, description, stock')
                    .or(`name.ilike.%${label}%,category.ilike.%${label}%,description.ilike.%${label}%`)
                    .gt('stock', 0)
            )
        ]);

        // ── Step 3: Merge & deduplicate ───────────────────────────────────────
        const seen = new Set();
        const merged = [];
        const hasImageSearch = imageSearchResult.status === 'fulfilled';

        // PRIMARY: CLIP image similarity (when base64_image was provided)
        // Position score: rank 1 = 1.0, rank 20 = ~0.05
        if (hasImageSearch) {
            const list = imageSearchResult.value.results;
            const total = list.length || 1;
            list.forEach((p, i) => {
                if (!seen.has(p.id)) {
                    seen.add(p.id);
                    merged.push({ ...p, _image_score: 1 - (i / total), _hybrid_score: 0 });
                }
            });
        }

        // SECONDARY: text hybrid search (used when no image, or to fill gaps)
        if (textSearchResult.status === 'fulfilled') {
            const list = textSearchResult.value.results.filter(p => (p.stock ?? 1) > 0);
            const total = list.length || 1;
            list.forEach((p, i) => {
                if (!seen.has(p.id)) {
                    seen.add(p.id);
                    merged.push({ ...p, _image_score: 0, _hybrid_score: 1 - (i / total) });
                } else {
                    // Already in from image search — add hybrid score too
                    const existing = merged.find(m => m.id === p.id);
                    if (existing) existing._hybrid_score = 1 - (i / total);
                }
            });
        }

        // Tag overlap — flag for bonus
        const tagMatchIds = new Set();
        if (tagMatchResult.status === 'fulfilled') {
            for (const p of (tagMatchResult.value.data || [])) {
                tagMatchIds.add(p.id);
                if (!seen.has(p.id)) {
                    seen.add(p.id);
                    merged.push({ ...p, _image_score: 0, _hybrid_score: 0 });
                }
            }
        }

        // ILIKE results
        for (const r of ilikeResults) {
            if (r.status === 'fulfilled') {
                for (const p of (r.value.data || [])) {
                    if (!seen.has(p.id)) {
                        seen.add(p.id);
                        merged.push({ ...p, _image_score: 0, _hybrid_score: 0 });
                    }
                }
            }
        }


        // ── Step 4: Score ─────────────────────────────────────────────────────
        // Top 3 Vision labels (highest confidence) — these define what the image IS
        const topVisionLabels = [...vision_labels]
            .sort((a, b) => (b.confidence || 0) - (a.confidence || 0))
            .slice(0, 3)
            .map(vl => (vl.label || vl).replace(/_/g, ' ').replace(/\.n\.\d+/g, '').toLowerCase().trim())
            .filter(Boolean);

        const scored = merged.map(product => {
            const name        = (product.name || '').toLowerCase();
            const category    = (product.category || '').toLowerCase();
            const tags        = (product.tags || []).map(t => t.toLowerCase());
            const description = (product.description || '').toLowerCase();
            const haystack    = [name, category, tags.join(' '), description].join(' ');

            // ① PRIMARY MATCH — does product contain any top Vision label?
            //   Tag match > name/category match > description match
            //   Top label (rank 1) weighs more than rank 2, rank 3
            let primaryScore = 0;
            topVisionLabels.forEach((lbl, i) => {
                const weight = 1 - (i * 0.2); // rank1=1.0, rank2=0.8, rank3=0.6
                if (tags.some(t => t.includes(lbl) || lbl.includes(t))) {
                    primaryScore = Math.max(primaryScore, weight);           // strongest
                } else if (name.includes(lbl) || category.includes(lbl)) {
                    primaryScore = Math.max(primaryScore, weight * 0.85);    // strong
                } else if (description.includes(lbl)) {
                    primaryScore = Math.max(primaryScore, weight * 0.5);     // weak
                }
            });

            // ② FULL LABEL COVERAGE — how many total Vision labels match?
            let labelScore = 0;
            for (const vl of vision_labels) {
                const lbl  = (vl.label || vl).replace(/_/g, ' ').replace(/\.n\.\d+/g, '').toLowerCase().trim();
                const conf = typeof vl.confidence === 'number' ? vl.confidence : 0.5;
                if (lbl && haystack.includes(lbl)) labelScore += conf;
            }
            const normLabel = Math.min(labelScore / 3, 1);

            // ③ TAG OVERLAP BONUS
            const tagBonus = tagMatchIds.has(product.id) ? 0.2 : 0;

            let combined;
            if (hasImageSearch) {
                // CLIP image search ran → image similarity is king
                // 65% image similarity | 15% label match | 10% tag bonus | 10% text hybrid
                combined = (product._image_score  * 0.65)
                         + (normLabel             * 0.15)
                         + (tagBonus              * 0.10)
                         + (product._hybrid_score * 0.10);
            } else {
                // No image sent → fall back to label-first text ranking
                // 55% primary label | 20% label coverage | 15% text hybrid | 10% tag bonus
                combined = (primaryScore           * 0.55)
                         + (normLabel              * 0.20)
                         + (product._hybrid_score  * 0.15)
                         + (tagBonus               * 0.10);
            }

            return { ...product, _score: combined };
        });

        // Sort descending; tiebreak by tag match
        scored.sort((a, b) => {
            if (Math.abs(b._score - a._score) > 0.02) return b._score - a._score;
            return (tagMatchIds.has(b.id) ? 1 : 0) - (tagMatchIds.has(a.id) ? 1 : 0);
        });
        let final = scored.slice(0, 8);


        // ── Step 5: Fallback — always return 8 products ───────────────────────
        if (final.length < 8) {
            const existingIds = new Set(final.map(p => p.id));
            const { data: recent } = await supabase
                .from('products')
                .select('id, name, price, image_url, category, tags, description, stock')
                .gt('stock', 0)
                .order('created_at', { ascending: false })
                .limit(20);

            for (const p of (recent || [])) {
                if (!existingIds.has(p.id)) {
                    final.push({ ...p, _score: 0 });
                    existingIds.add(p.id);
                    if (final.length >= 8) break;
                }
            }
        }

        final = final.map(fixImageUrl);
        const resultIds = final.map(p => p.id);

        // ── Step 6: Log ───────────────────────────────────────────────────────
        const { data: logRow } = await supabase
            .from('visual_search_logs')
            .insert([{
                device_id,
                vision_labels: vision_labels,
                matched_product_ids: resultIds,
                top_label: top_label || labelStrings[0] || ''
            }])
            .select('id')
            .single();

        if (resultIds.length > 0) {
            await supabase.from('user_events').insert([{
                device_id,
                product_id: resultIds[0],
                event_type: 'visual_search'
            }]);
        }

        res.json({

            products: final,
            search_log_id: logRow?.id || null,
            labels_used: labelStrings
        });

    } catch (error) {
        console.error('Visual search error:', error);
        res.status(500).json({ error: error.message });
    }
});

// POST /ai/visual-search/feedback
// Body: { device_id, search_log_id, product_id, was_relevant }
router.post('/visual-search/feedback', async (req, res) => {
    const { device_id, search_log_id, product_id, was_relevant } = req.body;
    if (!device_id || product_id == null || was_relevant == null) {
        return res.status(400).json({ error: 'Missing required fields' });
    }

    try {
        await supabase.from('visual_search_feedback').insert([{
            device_id,
            search_log_id: search_log_id || null,
            product_id,
            was_relevant
        }]);
        res.json({ success: true });
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

module.exports = router;

