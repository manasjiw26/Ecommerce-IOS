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
    apiKey: process.env.GEMINI_API_KEY,
    apiVersion: 'v1'
});

// ── Gemini JSON helpers (backend-at-night merge) ──────────────────────────────
function stripJsonCodeFences(text) {
    const t = String(text || '').trim();
    return t.replace(/^```json\s*/i, '').replace(/^```\s*/i, '').replace(/\s*```$/i, '').trim();
}

async function askGeminiJSON(prompt, { model } = {}) {
    // Default to a model name that is available on the GenAI API v1 for generateContent.
    const chosenModel = model || process.env.GEMINI_MODEL_JSON || process.env.GEMINI_MODEL || 'gemini-2.0-flash';
    try {
        const response = await ai.models.generateContent({
            model: chosenModel,
            contents: [{ role: 'user', parts: [{ text: String(prompt || '') }] }],
            generationConfig: { responseMimeType: 'application/json', temperature: 0.2 }
        });
        const raw = stripJsonCodeFences(response.text());
        return JSON.parse(raw);
    } catch (e) {
        console.error('Gemini JSON parse error:', e.message);
        return null;
    }
}

function missingTable(err) {
    const msg = (err && err.message ? String(err.message) : '').toLowerCase();
    return msg.includes('relation') && msg.includes('does not exist');
}

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

/*
 * LEGACY SEARCH (kept for reference; DO NOT ENABLE)
 *
 * Krish branch introduced a modular search pipeline which is now the canonical
 * `/ai/search` implementation. We keep the older hybrid_search-based handler
 * here, commented, so none of the previous logic is lost.
 *
 * If you ever need to compare results, consider re-enabling it under a new
 * route like `/ai/search-legacy` instead of defining `/ai/search` twice.
 */
// router.post('/search', async (req, res) => {
//     const { query } = req.body;
//     if (!query) return res.status(400).json({ error: 'Missing query' });
//
//     try {
//         // Run Local Embedding Generation
//         const queryEmbedding = await getLocalEmbedding(query);
//
//         // Complex RRF Hybrid Search with Weights
//         const { data, error } = await supabase.rpc('hybrid_search', {
//             query_text: query,
//             query_embedding: queryEmbedding,
//             match_count: 20,
//             fts_weight: 1.0,        // Complexity: Adjustable weights for keyword matching
//             semantic_weight: 1.5    // Complexity: Prioritize AI meaning slightly more
//         });
//
//         if (error) throw error;
//         res.json(data);
//     } catch (error) {
//         console.error('Complex Search Failed. Falling back to Native Postgres ILIKE:', error.message);
//
//         // Sanitize query into keywords
//         const stopwords = ['can','you','find','me','some','show','looking','for','i','want','to','buy','do','have','the','a','an','is','are','of','in','on','with'];
//         const keywords = query.toLowerCase().replace(/[^a-z0-9 ]/g, '').split(' ').filter(w => w.length > 2 && !stopwords.includes(w));
//
//         // If no keywords found, fallback to original query
//         const searchTerms = keywords.length > 0 ? keywords : [query];
//         const orConditions = searchTerms.map(kw => `name.ilike.%${kw}%,description.ilike.%${kw}%,category.ilike.%${kw}%`).join(',');
//
//         const { data: fallbackData, error: fallbackError } = await supabase
//             .from('products')
//             .select('*')
//             .or(orConditions)
//             .order('stock', { ascending: false })
//             .limit(20);
//
//         if (fallbackError) {
//              return res.status(500).json({ error: fallbackError.message });
//         }
//         res.json(fallbackData || []);
//     }
// });

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
                const GEMINI_MODEL = process.env.GEMINI_MODEL || "gemini-2.0-flash";
                const response = await ai.models.generateContent({
                    model: GEMINI_MODEL,
                    contents: [{ role: 'user', parts: [{ text: `User history:\n${recentHistoryText}\nBased on this, what 3-5 words describe what they might want to buy next? Return ONLY the search string.` }] }]
                });
                const searchIntent = response.text().trim();

                const queryEmbedding = await getLocalEmbedding(searchIntent);

                const { data: searchResults } = await supabase.rpc('hybrid_search', {
                    query_text: searchIntent,
                    query_embedding: queryEmbedding,
                    match_count: 5
                });
                candidates = searchResults || [];
            } catch (aiError) {
                console.error("AI Intent Generation Failed:", aiError.message);
                const categories = [...new Set(historyProducts.map(p => p.category))];
                const { data: fallbackCandidates } = await supabase.from('products').select('*').in('category', categories).limit(5);
                candidates = fallbackCandidates || [];
            }
        }

        if (candidates.length === 0) return res.json([]);

        let recommendedItems = [];
        try {
            const finalPrompt = `You are an expert e-commerce assistant. Here are the Top 5 absolute best-matching products for the user based on our internal search engine:\n${JSON.stringify(candidates.map(c => ({id: c.id, name: c.name, category: c.category, tags: c.tags})))}\n\nYour ONLY job is to write a short 1-sentence reasoning pitch for why they would love each product. Do NOT filter or remove any products. Return ONLY a valid JSON array of objects with "id" (number) and "reasoning" (string).`;
            const GEMINI_MODEL = process.env.GEMINI_MODEL || "gemini-2.0-flash";
            const response = await ai.models.generateContent({
                model: GEMINI_MODEL,
                contents: [{ role: 'user', parts: [{ text: finalPrompt }] }],
                generationConfig: { temperature: 0.15, responseMimeType: "application/json" }
            });
            recommendedItems = JSON.parse(response.text());
        } catch(e) {
            console.error("Gemini Re-ranking Failed:", e.message);
            recommendedItems = candidates.slice(0, 5).map(c => ({ id: c.id }));
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

// ─────────────────────────────────────────────
// backend-at-night: Extra AI utility endpoints
// ─────────────────────────────────────────────

async function pipelineSearch(query, device_id, limit = 20) {
    const results = await searchOrchestrator.execute(query, device_id, { limit, page: 1 });
    return (results || []).map(fixImageUrl);
}

async function upsertStyleProfile(device_id) {
    const { data: events, error: eErr } = await supabase
        .from('user_events')
        // user_events historically used `timestamp`; newer tables sometimes use `created_at`.
        // We standardize on `timestamp` here to match the existing prod schema.
        .select('product_id, timestamp')
        .eq('device_id', device_id)
        .order('timestamp', { ascending: false })
        .limit(30);
    if (eErr) throw eErr;

    const productIds = [...new Set((events || []).map(x => x.product_id).filter(Boolean))];
    let products = [];
    if (productIds.length) {
        const { data: pData, error: pErr } = await supabase
            .from('products')
            .select('id, category, price, tags')
            .in('id', productIds);
        if (pErr) throw pErr;
        products = pData || [];
    }

    const { data: searches, error: sErr } = await supabase
        .from('recent_searches')
        .select('query')
        .eq('device_id', device_id)
        .order('created_at', { ascending: false })
        .limit(20);
    if (sErr) throw sErr;

    const categories = [...new Set(products.map(p => p.category).filter(Boolean))];
    const avg = products.length ? (products.reduce((a, p) => a + Number(p.price || 0), 0) / products.length) : 0;
    const recentQueries = (searches || []).map(s => s.query).filter(Boolean).slice(0, 10);

    const prompt = `
You are a premium home & kitchen e-commerce personalization engine.
Given user signals, generate a style profile. Return ONLY valid JSON.
Signals:
- Recent categories: ${JSON.stringify(categories.slice(0, 5))}
- Avg viewed price: ${avg.toFixed(2)}
- Recent searches: ${JSON.stringify(recentQueries)}

Return JSON shape:
{"style_name":"Modern Home Chef","style_description":"...","top_categories":["Cookware"],"price_tier":"mid","personality_traits":["..."],"tagline":"...","recommended_collections":["..."]}
`;

    let profile = await askGeminiJSON(prompt);
    if (!profile || !profile.style_name) {
        profile = {
            style_name: 'Classic Home Entertainer',
            style_description: 'You enjoy making home feel welcoming, with reliable essentials that look great on the table.',
            top_categories: categories.slice(0, 3),
            price_tier: avg >= 150 ? 'premium' : avg >= 60 ? 'mid' : 'budget',
            personality_traits: ['welcoming', 'practical', 'quality-focused'],
            tagline: 'Warm home, great meals.',
            recommended_collections: ['Everyday Essentials', 'Entertaining Classics', 'Premium Cookware']
        };
    }

    const upsertPayload = {
        device_id,
        style_name: profile.style_name,
        style_description: profile.style_description,
        top_categories: profile.top_categories || [],
        price_tier: profile.price_tier || null,
        generated_at: new Date().toISOString()
    };

    const { data: saved, error: uErr } = await supabase
        .from('user_style_profiles')
        .upsert([upsertPayload], { onConflict: 'device_id' })
        .select()
        .single();
    if (uErr) throw uErr;
    return saved;
}

router.post('/style-detect', async (req, res) => {
    try {
        const { device_id } = req.body || {};
        if (!device_id) return res.status(400).json({ error: 'device_id required' });
        const profile = await upsertStyleProfile(device_id);
        return res.json(profile);
    } catch (e) {
        if (missingTable(e)) return res.status(501).json({ error: 'Missing DB tables for style profiles. Run Backend/migrations/new_features_schema.sql.' });
        return res.status(500).json({ error: e.message });
    }
});

router.get('/style-profile', async (req, res) => {
    try {
        const device_id = String(req.query.device_id || '').trim();
        if (!device_id) return res.status(400).json({ error: 'device_id required' });

        const { data, error } = await supabase
            .from('user_style_profiles')
            .select('*')
            .eq('device_id', device_id)
            .maybeSingle();
        if (error) throw error;

        if (!data) return res.json(await upsertStyleProfile(device_id));

        const ageMs = Date.now() - new Date(data.generated_at || data.updated_at || data.created_at || Date.now()).getTime();
        if (ageMs > 24 * 3600000) return res.json(await upsertStyleProfile(device_id));
        return res.json(data);
    } catch (e) {
        if (missingTable(e)) return res.status(501).json({ error: 'Missing DB tables for style profiles. Run Backend/migrations/new_features_schema.sql.' });
        return res.status(500).json({ error: e.message });
    }
});

router.post('/cart-coach', async (req, res) => {
    try {
        const { cart_items } = req.body || {};
        if (!Array.isArray(cart_items)) return res.status(400).json({ error: 'cart_items array required' });

        const prompt = `
You are a premium home & kitchen shopping coach analyzing a customer's cart.
Cart contents: ${JSON.stringify(cart_items)}
Analyze the cart and give smart feedback. Look for: missing items that complete a set, duplicate categories, imbalanced spending, great add-ons.
Return ONLY valid JSON:
{"score":72,"headline":"Great start, but you're missing a few essentials","insights":[{"type":"missing","message":"..."}],"top_suggestion":"..."}
`;
        let analysis = await askGeminiJSON(prompt);
        if (!analysis || typeof analysis.score !== 'number') {
            analysis = {
                score: 70,
                headline: 'Good start — consider a few add-ons',
                insights: [{ type: 'missing', message: 'Consider adding one versatile utensil or serving piece to complete the set.' }],
                top_suggestion: 'Add a best-selling utensil set to round out your cart.'
            };
        }
        return res.json(analysis);
    } catch (e) {
        return res.status(500).json({ error: e.message });
    }
});

router.post('/aesthetic-match', async (req, res) => {
    try {
        const { materials, finish_keywords, mood_keywords, categories, desired_items, budget, device_id } = req.body || {};

        const mats = Array.isArray(materials) ? materials.filter(Boolean).slice(0, 10) : [];
        const finishes = Array.isArray(finish_keywords) ? finish_keywords.filter(Boolean).slice(0, 10) : [];
        const moods = Array.isArray(mood_keywords) ? mood_keywords.filter(Boolean).slice(0, 10) : [];
        const cats = Array.isArray(categories) ? categories.filter(Boolean).slice(0, 10) : [];

        const desired = Array.isArray(desired_items) ? desired_items.join(' ') : (desired_items || 'cutlery flatware dinnerware');
        const queryParts = [...mats, ...finishes, ...moods].map(x => String(x).trim()).filter(Boolean);
        const baseQueries = [
            `${queryParts.slice(0, 4).join(' ')} ${desired}`.trim(),
            `${queryParts.slice(0, 4).join(' ')} serveware`.trim(),
            `${queryParts.slice(0, 4).join(' ')} glassware`.trim()
        ].filter(q => q.length > 2);

        let picked = [];
        for (const q of baseQueries.slice(0, 3)) {
            const hits = await pipelineSearch(q, device_id, 12);
            picked.push(...(hits || []));
        }

        if (picked.length < 12) {
            let catQuery = supabase.from('products').select('*').order('stock', { ascending: false }).limit(60);
            if (cats.length) catQuery = catQuery.in('category', cats);
            const tagTokens = [...mats, ...finishes, ...moods].map(x => String(x).trim().toLowerCase()).filter(Boolean).slice(0, 20);
            if (tagTokens.length) catQuery = catQuery.overlaps('tags', tagTokens);
            const { data: more } = await catQuery;
            picked.push(...(more || []).map(fixImageUrl));
        }

        const seen = new Set();
        let unique = [];
        for (const p of picked) {
            if (!p?.id || seen.has(p.id)) continue;
            seen.add(p.id);
            unique.push(p);
        }

        const b = budget != null ? Number(budget) : null;
        if (b && Number.isFinite(b) && b > 0) unique = unique.filter(p => Number(p.price || 0) <= b * 1.25);

        unique = unique.slice(0, 24);

        return res.json({
            profile: {
                style_label: 'aesthetic_match',
                materials: mats,
                finish_keywords: finishes,
                mood_keywords: moods,
                categories: cats
            },
            suggestions: unique,
            suggested_next_searches: baseQueries.slice(0, 3)
        });
    } catch (e) {
        return res.status(500).json({ error: e.message });
    }
});

router.post('/gift-message', async (req, res) => {
    try {
        const { contributor_name, recipient_name, event_type, product_name, amount } = req.body || {};
        const prompt = `
Write a warm gift message for a registry contribution.
From: ${contributor_name}
To: ${recipient_name}
Event: ${event_type}
Gift: ${product_name} (contributed $${amount})
Write 3 options: heartfelt, funny, elegant. Under 40 words each.
Return ONLY valid JSON: {"messages":[{"tone":"heartfelt","text":"..."},{"tone":"funny","text":"..."},{"tone":"elegant","text":"..."}]}
`;
        let result = await askGeminiJSON(prompt);
        if (!result || !Array.isArray(result.messages)) {
            result = {
                messages: [
                    { tone: 'heartfelt', text: `So happy for you — can’t wait to see the joy this brings to your home.` },
                    { tone: 'funny', text: `May this help you cook, host, and impress… or at least order takeout in style.` },
                    { tone: 'elegant', text: `Wishing you a lifetime of warmth, celebration, and beautiful moments at home.` }
                ]
            };
        }
        return res.json(result);
    } catch (e) {
        return res.status(500).json({ error: e.message });
    }
});

router.post('/thank-you-note', async (req, res) => {
    try {
        const { registry_owner_name, contributor_name, product_name, event_type } = req.body || {};
        const prompt = `
Write a thank-you note for receiving a registry gift.
From: ${registry_owner_name}
To: ${contributor_name}
Gift: ${product_name}
Occasion: ${event_type}
Return ONLY valid JSON: {"notes":[{"style":"casual","text":"..."},{"style":"formal","text":"..."}]}
`;
        let result = await askGeminiJSON(prompt);
        if (!result || !Array.isArray(result.notes)) {
            result = {
                notes: [
                    { style: 'casual', text: `Thank you so much for the ${product_name}! We’re so excited to use it — it means a lot that you celebrated with us.` },
                    { style: 'formal', text: `Thank you for your thoughtful gift of the ${product_name}. We truly appreciate your kindness and support as we celebrate our ${event_type}.` }
                ]
            };
        }
        return res.json(result);
    } catch (e) {
        return res.status(500).json({ error: e.message });
    }
});

router.post('/product-story', async (req, res) => {
    try {
        const { product_id } = req.body || {};
        if (!product_id) return res.status(400).json({ error: 'product_id required' });
        const { data: product, error } = await supabase.from('products').select('*').eq('id', product_id).single();
        if (error) throw error;
        fixImageUrl(product);
        const prompt = `
Write a vivid, aspirational 2-sentence story for this product:
${JSON.stringify({ name: product.name, category: product.category, description: product.description })}
Return ONLY valid JSON: {"story":"...","mood":"warm","occasion_tags":["..."]}
`;
        let result = await askGeminiJSON(prompt);
        if (!result || !result.story) {
            result = {
                story: `Imagine an easy Sunday where ${product.name} turns a simple meal into a moment worth sharing. It’s the kind of piece that quietly becomes part of your best memories at home.`,
                mood: 'warm',
                occasion_tags: ['Everyday cooking', 'Entertaining']
            };
        }
        return res.json({ product, ...result });
    } catch (e) {
        return res.status(500).json({ error: e.message });
    }
});

router.post('/smart-search', async (req, res) => {
    try {
        const { query, device_id } = req.body || {};
        if (!query) return res.status(400).json({ error: 'query required' });
        const prompt = `
A customer searched for: "${query}" in a premium home goods store.
Return ONLY valid JSON:
{"intent":"...","expanded_queries":["..."],"categories":["..."],"mood":"...","budget_signal":"...","tags":["..."]}
`;
        let intentAnalysis = await askGeminiJSON(prompt);
        if (!intentAnalysis || !Array.isArray(intentAnalysis.expanded_queries)) {
            intentAnalysis = { intent: `searching for ${query}`, expanded_queries: [query], categories: [], mood: 'neutral', budget_signal: 'unknown', tags: [] };
        }
        const bestQuery = intentAnalysis.expanded_queries[0] || query;
        const products = await pipelineSearch(bestQuery, device_id, 20);
        if (device_id) {
            await supabase.from('recent_searches').insert([{ query, device_id }]);
        }
        return res.json({ intent_analysis: intentAnalysis, products });
    } catch (e) {
        return res.status(500).json({ error: e.message });
    }
});

router.post('/price-insight', async (req, res) => {
    try {
        const { product_id } = req.body || {};
        if (!product_id) return res.status(400).json({ error: 'product_id required' });
        const { data: product, error } = await supabase.from('products').select('*').eq('id', product_id).single();
        if (error) throw error;
        fixImageUrl(product);

        const { data: similar, error: sErr } = await supabase
            .from('products')
            .select('id, name, price, category')
            .eq('category', product.category)
            .limit(10);
        if (sErr) throw sErr;

        const prices = (similar || []).map(p => Number(p.price || 0));
        const min = prices.length ? Math.min(...prices) : Number(product.price || 0);
        const max = prices.length ? Math.max(...prices) : Number(product.price || 0);
        const avg = prices.length ? Math.round((prices.reduce((a, b) => a + b, 0) / prices.length) * 100) / 100 : Number(product.price || 0);

        const prompt = `
You are a pricing expert.
Product: ${product.name} at $${product.price}
Similar range: $${min}-$${max}, avg $${avg}.
Return ONLY valid JSON: {"verdict":"...","score":82,"percentile":"...","one_liner":"...","compared_to_avg":"...","buy_now_reason":"..."}
`;
        let result = await askGeminiJSON(prompt);
        if (!result || !result.verdict) {
            const delta = Number(product.price || 0) - avg;
            result = {
                verdict: delta <= 0 ? 'Good value' : 'Premium pick',
                score: delta <= 0 ? 78 : 70,
                percentile: delta <= 0 ? 'priced at or below average' : 'above average',
                one_liner: `A solid ${product.category} choice for the right kitchen.`,
                compared_to_avg: `${Math.round(delta * 100) / 100} vs avg`,
                buy_now_reason: 'Great fit if you value quality and design.'
            };
        }
        return res.json({ product, similar, ...result });
    } catch (e) {
        return res.status(500).json({ error: e.message });
    }
});

module.exports = router;
