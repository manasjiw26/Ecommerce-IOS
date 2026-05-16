// ========== FILE: routes/ai.js ==========
const express = require('express');
const router = express.Router();
const { supabase } = require('../supabaseClient');
const { GoogleGenAI } = require('@google/genai');
const { searchOrchestrator } = require('../searchOrchestrator');

const ai = new GoogleGenAI({ apiKey: process.env.GEMINI_API_KEY, apiVersion: 'v1' });

const STORAGE = 'https://czahuzfliuuhhegynsjr.supabase.co/storage/v1/object/public/Product%20Images';
const fixImg = (p) => {
    if (p?.image_url && !p.image_url.startsWith('http')) p.image_url = `${STORAGE}/${encodeURIComponent(p.image_url)}`;
    return p;
};

async function askGemini(prompt) {
    try {
        const response = await ai.models.generateContent({ model: 'gemini-2.0-flash', contents: prompt });
        const raw = response.text.trim().replace(/^```json\n?/, '').replace(/\n?```$/, '').trim();
        return JSON.parse(raw);
    } catch (e) {
        console.error('Gemini parse error:', e.message);
        return null;
    }
}

const JSON_SUFFIX = 'Return ONLY valid JSON. No markdown, no explanation, no backticks.';
function jsonPrompt(p) {
    const t = String(p || '').trim();
    return t.endsWith(JSON_SUFFIX) ? t : `${t}\n${JSON_SUFFIX}`;
}

async function askGeminiParts(parts) {
    try {
        const response = await ai.models.generateContent({ model: 'gemini-2.0-flash', contents: [{ role: 'user', parts }] });
        const raw = response.text.trim().replace(/^```json\n?/, '').replace(/\n?```$/, '').trim();
        return JSON.parse(raw);
    } catch (e) {
        console.error('Gemini parse error:', e.message);
        return null;
    }
}

async function upsertStyleProfile(device_id) {
    const { data: events, error: eErr } = await supabase
        .from('user_events')
        .select('product_id, created_at')
        .eq('device_id', device_id)
        .order('created_at', { ascending: false })
        .limit(30);
    if (eErr) throw eErr;

    const productIds = [...new Set((events || []).map((x) => x.product_id).filter(Boolean))];
    let products = [];
    if (productIds.length) {
        const { data: pData, error: pErr } = await supabase.from('products').select('id, category, price, tags').in('id', productIds);
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

    const catFreq = {};
    const tagFreq = {};
    const prices = [];
    for (const p of products) {
        if (p.category) catFreq[p.category] = (catFreq[p.category] || 0) + 1;
        const tags = Array.isArray(p.tags) ? p.tags : [];
        for (const tag of tags) tagFreq[tag] = (tagFreq[tag] || 0) + 1;
        if (p.price != null) prices.push(Number(p.price));
    }

    const categories = Object.entries(catFreq).sort((a, b) => b[1] - a[1]).map(([k]) => k);
    const tags = Object.entries(tagFreq).sort((a, b) => b[1] - a[1]).slice(0, 20).map(([k]) => k);
    const min = prices.length ? Math.min(...prices) : 0;
    const max = prices.length ? Math.max(...prices) : 0;
    const avg = prices.length ? Math.round((prices.reduce((a, b) => a + b, 0) / prices.length) * 100) / 100 : 0;
    const searchTerms = (searches || []).map((x) => x.query).filter(Boolean);

    const prompt = jsonPrompt(`
You are a Williams Sonoma personal stylist analyzing a customer's browsing behavior.
They have been looking at products in these categories (most to least): ${categories.join(', ') || 'unknown'}.
Common tags in their browsing: ${tags.join(', ') || 'unknown'}.
Their price range: $${min} - $${max} avg $${avg}.
Recent searches: ${searchTerms.join(', ') || 'none'}.
Identify their style persona and preferences.
Return ONLY valid JSON:
{"style_name":"Modern Home Chef","style_description":"You love clean lines, quality cookware, and creating memorable meals for people you love.","top_categories":["Cookware","Bakeware","Kitchen Tools"],"price_tier":"mid","personality_traits":["detail-oriented","quality-focused","entertainer"],"tagline":"Built for the kitchen, designed for life.","recommended_collections":["All-Clad Essentials","Staub Cast Iron","Le Creuset Collection"]}
`);

    let profile = await askGemini(prompt);
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

// POST /ai/events
router.post('/events', async (req, res) => {
    try {
        const { device_id, product_id, event_type } = req.body || {};
        if (!device_id || !product_id || !event_type) return res.status(400).json({ error: 'Missing required fields', code: 400 });
        const { error } = await supabase.from('user_events').insert([{ device_id, product_id, event_type }]);
        if (error) throw error;
        return res.json({ success: true });
    } catch (e) {
        console.error('[POST /ai/events]:', e.message);
        return res.status(500).json({ error: e.message, code: 500 });
    }
});

// POST /ai/search
router.post('/search', async (req, res) => {
    try {
        const { query, device_id } = req.body || {};
        if (!query) return res.status(400).json({ error: 'Missing query', code: 400 });

        const results = (await searchOrchestrator(query, 20)).map(fixImg);
        if (device_id) {
            await supabase.from('recent_searches').insert([{ query, device_id }]);
        }
        return res.json(results);
    } catch (e) {
        console.error('[POST /ai/search]:', e.message);
        return res.status(500).json({ error: e.message, code: 500 });
    }
});

// GET /ai/autocomplete?q=...
router.get('/autocomplete', async (req, res) => {
    try {
        const q = String(req.query.q || '').trim();
        if (!q) return res.json({ suggestions: [] });

        const like = `%${q}%`;
        const { data, error } = await supabase
            .from('products')
            .select('name, category')
            .or(`name.ilike.${like},category.ilike.${like}`)
            .limit(15);
        if (error) throw error;

        const suggestions = [...new Set((data || []).map((x) => x.name).filter(Boolean))].slice(0, 10);
        return res.json({ suggestions });
    } catch (e) {
        console.error('[GET /ai/autocomplete]:', e.message);
        return res.status(500).json({ error: e.message, code: 500 });
    }
});

// POST /ai/search/analytics
router.post('/search/analytics', async (req, res) => {
    try {
        const { query, device_id } = req.body || {};
        if (!query || !device_id) return res.status(400).json({ error: 'query and device_id required', code: 400 });
        const { error } = await supabase.from('recent_searches').insert([{ query, device_id }]);
        if (error) throw error;
        return res.json({ success: true });
    } catch (e) {
        console.error('[POST /ai/search/analytics]:', e.message);
        return res.status(500).json({ error: e.message, code: 500 });
    }
});

// GET /ai/trending-searches
router.get('/trending-searches', async (_req, res) => {
    try {
        const since = new Date(Date.now() - 7 * 86400000).toISOString();
        const { data, error } = await supabase.from('recent_searches').select('query, created_at').gte('created_at', since).limit(2000);
        if (error) throw error;

        const counts = new Map();
        for (const r of data || []) {
            const q = (r.query || '').trim().toLowerCase();
            if (!q) continue;
            counts.set(q, (counts.get(q) || 0) + 1);
        }
        const trending = Array.from(counts.entries())
            .sort((a, b) => b[1] - a[1])
            .slice(0, 15)
            .map(([query, count]) => ({ query, count }));

        return res.json({ trending });
    } catch (e) {
        console.error('[GET /ai/trending-searches]:', e.message);
        return res.status(500).json({ error: e.message, code: 500 });
    }
});

// GET /ai/recent-searches?device_id=...
router.get('/recent-searches', async (req, res) => {
    try {
        const device_id = String(req.query.device_id || '').trim();
        if (!device_id) return res.status(400).json({ error: 'device_id required', code: 400 });

        const { data, error } = await supabase
            .from('recent_searches')
            .select('*')
            .eq('device_id', device_id)
            .order('created_at', { ascending: false })
            .limit(20);
        if (error) throw error;
        return res.json({ recent: data || [] });
    } catch (e) {
        console.error('[GET /ai/recent-searches]:', e.message);
        return res.status(500).json({ error: e.message, code: 500 });
    }
});

// POST /ai/visual-search
router.post('/visual-search', async (req, res) => {
    try {
        const { image_url, image_base64, device_id } = req.body || {};
        if (!image_url && !image_base64) return res.status(400).json({ error: 'image_url or image_base64 required', code: 400 });

        const prompt = jsonPrompt(`
You are a product discovery assistant for a premium home goods store (Williams Sonoma).
Given an image, describe it and turn it into a concise product search query (3-7 words).
Return ONLY valid JSON:
{"query":"cast iron skillet","category_hint":"Cookware","tags":["cast iron","skillet"],"reason":"Looks like a heavy cast iron pan for searing."}
`);

        const contents = image_url
            ? [{ role: 'user', parts: [{ text: prompt }, { fileData: { mimeType: 'image/jpeg', fileUri: image_url } }] }]
            : [{ role: 'user', parts: [{ text: prompt }, { inlineData: { mimeType: 'image/jpeg', data: String(image_base64).replace(/^data:image\/\w+;base64,/, '') } }] }];

        let analysis = null;
        try {
            const response = await ai.models.generateContent({ model: 'gemini-2.0-flash', contents });
            const raw = response.text.trim().replace(/^```json\n?/, '').replace(/\n?```$/, '').trim();
            analysis = JSON.parse(raw);
        } catch (err) {
            console.error('[POST /ai/visual-search] Gemini parse:', err.message);
        }

        const q = analysis?.query || analysis?.category_hint || 'kitchen';
        const products = (await searchOrchestrator(q, 20)).map(fixImg);

        if (device_id && products[0]?.id) {
            await supabase.from('user_events').insert([{ device_id, product_id: products[0].id, event_type: 'visual_search' }]);
        }

        return res.json({ intent: analysis || { query: q }, products });
    } catch (e) {
        console.error('[POST /ai/visual-search]:', e.message);
        return res.status(500).json({ error: e.message, code: 500 });
    }
});

// POST /ai/aesthetic-suggest
// Image-driven aesthetic matching: analyze a kitchen photo and suggest matching cutlery/tabletop items.
router.post('/aesthetic-suggest', async (req, res) => {
    try {
        const { image_url, image_base64, budget, room_type, desired_items, use_ai } = req.body || {};
        const aiEnabled = (use_ai !== false) && !!process.env.GEMINI_API_KEY;
        if (!aiEnabled) {
            return res.status(400).json({
                error: 'Gemini disabled/unavailable. Use POST /ai/aesthetic-match with an extracted aesthetic profile from iOS (VisionKit/CoreImage) instead.',
                code: 400
            });
        }
        if (!image_url && !image_base64) return res.status(400).json({ error: 'image_url or image_base64 required', code: 400 });

        const prompt = jsonPrompt(`
You are a Williams Sonoma design stylist.
Analyze the provided kitchen photo and extract an aesthetic profile, then propose shopping searches and categories that match the photo.
Constraints:
- Focus on aesthetic-matching items like cutlery/flatware, dinnerware, serveware, glassware, linens, countertop accessories.
- Keep suggestions realistic for a premium home goods store.
User context:
- Room type: ${room_type || 'kitchen'}
- Desired items: ${Array.isArray(desired_items) ? desired_items.join(', ') : desired_items || 'cutlery / tabletop'}
- Budget: $${budget || 'not specified'}
Return ONLY valid JSON:
{
  "style_label":"Modern Minimal",
  "dominant_colors":["#111827","#F5F0E8"],
  "accent_colors":["#C8B8A6"],
  "materials":["stainless steel","oak","matte ceramic"],
  "finish_keywords":["matte","brushed","satin"],
  "mood_keywords":["warm","minimal","coastal"],
  "categories":["Kitchen Tools","Dinnerware","Serveware"],
  "search_queries":["brushed stainless flatware set","matte black cutlery","neutral stoneware dinnerware"],
  "notes":"One short sentence on what you see and why these match."
}
`);

        const parts = image_url
            ? [{ text: prompt }, { fileData: { mimeType: 'image/jpeg', fileUri: image_url } }]
            : [{ text: prompt }, { inlineData: { mimeType: 'image/jpeg', data: String(image_base64).replace(/^data:image\/\\w+;base64,/, '') } }];

        let profile = await askGeminiParts(parts);
        if (!profile || !Array.isArray(profile.search_queries)) {
            profile = {
                style_label: 'Classic Modern',
                dominant_colors: ['#111827', '#F5F0E8'],
                accent_colors: ['#C8B8A6'],
                materials: ['stainless steel', 'ceramic'],
                finish_keywords: ['matte', 'brushed'],
                mood_keywords: ['clean', 'warm', 'timeless'],
                categories: ['Kitchen Tools', 'Dinnerware', 'Serveware'],
                search_queries: ['stainless steel flatware set', 'neutral stoneware dinnerware', 'minimal serveware'],
                notes: 'Fallback profile used because AI analysis failed.'
            };
        }

        const queries = profile.search_queries.slice(0, 4).filter(Boolean);
        const categories = Array.isArray(profile.categories) ? profile.categories.slice(0, 6).filter(Boolean) : [];
        const keywords = [
            ...(Array.isArray(profile.materials) ? profile.materials : []),
            ...(Array.isArray(profile.finish_keywords) ? profile.finish_keywords : []),
            ...(Array.isArray(profile.mood_keywords) ? profile.mood_keywords : [])
        ]
            .map((x) => String(x).trim().toLowerCase())
            .filter(Boolean)
            .slice(0, 20);

        // 1) AI-driven search (best results)
        let picked = [];
        for (const q of queries) {
            const hits = await searchOrchestrator(q, 12);
            picked.push(...(hits || []));
        }

        // 2) Category/tag fallback
        if (picked.length < 12) {
            let catQuery = supabase.from('products').select('*').order('stock', { ascending: false }).limit(40);
            if (categories.length) catQuery = catQuery.in('category', categories);
            if (keywords.length) catQuery = catQuery.overlaps('tags', keywords);
            const { data: more, error } = await catQuery;
            if (!error) picked.push(...(more || []));
        }

        // De-dupe and (soft) budget-filter
        const seen = new Set();
        let unique = [];
        for (const p of picked) {
            if (!p?.id || seen.has(p.id)) continue;
            seen.add(p.id);
            unique.push(p);
        }
        const b = budget != null ? Number(budget) : null;
        if (b && Number.isFinite(b) && b > 0) {
            unique = unique.filter((p) => Number(p.price || 0) <= b * 1.25);
        }

        unique = unique.slice(0, 24).map(fixImg);

        return res.json({
            profile,
            suggestions: unique,
            suggested_next_searches: queries
        });
    } catch (e) {
        console.error('[POST /ai/aesthetic-suggest]:', e.message);
        return res.status(500).json({ error: e.message, code: 500 });
    }
});

// POST /ai/aesthetic-match
// No-Gemini matching: client sends palette/keywords (e.g., extracted on-device via VisionKit/CoreImage).
router.post('/aesthetic-match', async (req, res) => {
    try {
        const { palette_hex, materials, finish_keywords, mood_keywords, categories, desired_items, budget } = req.body || {};

        const palette = Array.isArray(palette_hex) ? palette_hex.filter(Boolean).slice(0, 6) : [];
        const mats = Array.isArray(materials) ? materials.filter(Boolean).slice(0, 10) : [];
        const finishes = Array.isArray(finish_keywords) ? finish_keywords.filter(Boolean).slice(0, 10) : [];
        const moods = Array.isArray(mood_keywords) ? mood_keywords.filter(Boolean).slice(0, 10) : [];
        const cats = Array.isArray(categories) ? categories.filter(Boolean).slice(0, 10) : [];

        // For now, we don’t parse the image server-side (no extra deps); we match by tags/category + search queries.
        // Build queries the same way iOS can show as “chips”.
        const desired = Array.isArray(desired_items) ? desired_items.join(' ') : desired_items || 'cutlery flatware dinnerware';
        const queryParts = [...mats, ...finishes, ...moods].map((x) => String(x).trim()).filter(Boolean);
        const baseQueries = [
            `${queryParts.slice(0, 4).join(' ')} ${desired}`.trim(),
            `${queryParts.slice(0, 4).join(' ')} serveware`.trim(),
            `${queryParts.slice(0, 4).join(' ')} glassware`.trim()
        ].filter((q) => q.length > 2);

        let picked = [];
        for (const q of baseQueries.slice(0, 3)) {
            const hits = await searchOrchestrator(q, 12);
            picked.push(...(hits || []));
        }

        if (picked.length < 12) {
            let catQuery = supabase.from('products').select('*').order('stock', { ascending: false }).limit(60);
            if (cats.length) catQuery = catQuery.in('category', cats);
            // If tags column exists, overlap by keyword tokens (best-effort)
            const tagTokens = [...mats, ...finishes, ...moods]
                .map((x) => String(x).trim().toLowerCase())
                .filter(Boolean)
                .slice(0, 20);
            if (tagTokens.length) catQuery = catQuery.overlaps('tags', tagTokens);
            const { data: more } = await catQuery;
            picked.push(...(more || []));
        }

        const seen = new Set();
        let unique = [];
        for (const p of picked) {
            if (!p?.id || seen.has(p.id)) continue;
            seen.add(p.id);
            unique.push(p);
        }

        const b = budget != null ? Number(budget) : null;
        if (b && Number.isFinite(b) && b > 0) unique = unique.filter((p) => Number(p.price || 0) <= b * 1.25);

        unique = unique.slice(0, 24).map(fixImg);

        return res.json({
            profile: {
                style_label: 'client_extracted',
                dominant_colors: palette,
                materials: mats,
                finish_keywords: finishes,
                mood_keywords: moods,
                categories: cats
            },
            suggestions: unique,
            suggested_next_searches: baseQueries.slice(0, 3)
        });
    } catch (e) {
        console.error('[POST /ai/aesthetic-match]:', e.message);
        return res.status(500).json({ error: e.message, code: 500 });
    }
});

// POST /ai/visual-search/feedback
router.post('/visual-search/feedback', async (req, res) => {
    try {
        const { device_id, product_id, feedback } = req.body || {};
        if (!device_id || !product_id) return res.status(400).json({ error: 'device_id and product_id required', code: 400 });
        const { error } = await supabase.from('user_events').insert([{ device_id, product_id, event_type: `visual_feedback:${feedback || 'unknown'}` }]);
        if (error) throw error;
        return res.json({ success: true });
    } catch (e) {
        console.error('[POST /ai/visual-search/feedback]:', e.message);
        return res.status(500).json({ error: e.message, code: 500 });
    }
});

// POST /ai/recommend
router.post('/recommend', async (req, res) => {
    try {
        const { device_id } = req.body || {};
        if (!device_id) return res.status(400).json({ error: 'Missing device_id', code: 400 });

        const { data: events, error: eErr } = await supabase
            .from('user_events')
            .select('product_id, event_type, created_at')
            .eq('device_id', device_id)
            .order('created_at', { ascending: false })
            .limit(10);
        if (eErr) throw eErr;

        let candidates = [];
        if (!events || events.length === 0) {
            const { data: popular, error } = await supabase.from('products').select('*').order('stock', { ascending: false }).limit(20);
            if (error) throw error;
            candidates = popular || [];
        } else {
            const productIds = events.map((e) => e.product_id);
            const { data: historyProducts, error: hErr } = await supabase.from('products').select('id, name, category').in('id', productIds);
            if (hErr) throw hErr;

            const recentHistoryText = (events || [])
                .map((e) => {
                    const p = (historyProducts || []).find((prod) => prod.id === e.product_id);
                    return p ? `${e.event_type}: ${p.name} (${p.category})` : null;
                })
                .filter(Boolean)
                .join('\n');

            const intentPrompt = jsonPrompt(`
User history:
${recentHistoryText}
Based on this, infer what they might want to buy next.
Return ONLY valid JSON:
{"search_intent":"cast iron cookware","categories":["Cookware"],"tags":["cast iron"],"why":"One sentence."}
`);

            const intent = await askGemini(intentPrompt);
            const searchIntent = intent?.search_intent || (historyProducts?.[0]?.category ? `${historyProducts[0].category}` : 'kitchen essentials');

            candidates = await searchOrchestrator(searchIntent, 20);
            if (!candidates.length) {
                const categories = [...new Set((historyProducts || []).map((p) => p.category).filter(Boolean))];
                const { data: fallbackCandidates } = await supabase.from('products').select('*').in('category', categories).limit(20);
                candidates = fallbackCandidates || [];
            }
        }

        candidates = (candidates || []).map(fixImg);
        if (!candidates.length) return res.json([]);

        const rerankPrompt = jsonPrompt(`
You are an expert e-commerce assistant. Pick 5 diverse products from this list:
${JSON.stringify((candidates || []).map((c) => ({ id: c.id, name: c.name, category: c.category })))}
Return ONLY valid JSON array of objects with "id" (number) and "reasoning" (1-sentence pitch).
`);

        let recommendedItems = await askGemini(rerankPrompt);
        if (!Array.isArray(recommendedItems)) recommendedItems = candidates.slice(0, 5).map((c) => ({ id: c.id, reasoning: 'Popular pick.' }));

        const fullRecommendations = recommendedItems
            .map((item) => {
                const productDetails = candidates.find((p) => p.id === item.id);
                if (!productDetails) return null;
                return { ...productDetails, ai_reasoning: item.reasoning || '' };
            })
            .filter(Boolean);

        return res.json(fullRecommendations);
    } catch (e) {
        console.error('[POST /ai/recommend]:', e.message);
        return res.status(500).json({ error: e.message, code: 500 });
    }
});

// POST /ai/cart-coach
router.post('/cart-coach', async (req, res) => {
    try {
        const { cart_items } = req.body || {};
        if (!Array.isArray(cart_items)) return res.status(400).json({ error: 'cart_items array required', code: 400 });

        const prompt = jsonPrompt(`
You are a Williams Sonoma shopping coach analyzing a customer's cart.
Cart contents: ${JSON.stringify(cart_items)}
Analyze the cart and give smart feedback. Look for: missing items that complete a set, duplicate categories, imbalanced spending, great add-ons.
Return ONLY valid JSON:
{"score":72,"headline":"Great start, but you're missing a few essentials","insights":[{"type":"missing","message":"You have 2 frying pans but no spatula or tongs"},{"type":"bundle","message":"Add a lid set to complete your cookware bundle"},{"type":"value","message":"Your cart qualifies for the cookware bundle discount"}],"top_suggestion":"Add silicone utensils to complete your kitchen setup"}
`);

        let analysis = await askGemini(prompt);
        if (!analysis || typeof analysis.score !== 'number') {
            analysis = {
                score: 70,
                headline: 'Good start — consider a few add-ons',
                insights: [{ type: 'missing', message: 'Add one versatile utensil set to round out your cart.' }],
                top_suggestion: 'Add a utensil set or kitchen tongs'
            };
        }

        return res.json(analysis);
    } catch (e) {
        console.error('[POST /ai/cart-coach]:', e.message);
        return res.status(500).json({ error: e.message, code: 500 });
    }
});

// POST /ai/occasion-detect
router.post('/occasion-detect', async (req, res) => {
    try {
        const { cart_items } = req.body || {};
        if (!Array.isArray(cart_items)) return res.status(400).json({ error: 'cart_items array required', code: 400 });

        const prompt = jsonPrompt(`
You are a Williams Sonoma shopping analyst.
A customer has these items in their cart: ${JSON.stringify(cart_items)}.
What shopping occasion does this suggest? Be specific and creative.
Return ONLY valid JSON:
{"occasion":"Wedding Registry Shopping","confidence":0.87,"icon":"🎊","sub_occasions":["Couples cooking together","Entertaining guests"],"personalized_message":"Looks like you're setting up a kitchen for two! Here are some must-haves for newlyweds.","suggested_categories":["Cookware sets","Dinnerware","Serveware"]}
`);

        let result = await askGemini(prompt);
        if (!result || !result.occasion) {
            result = {
                occasion: 'Home Setup Shopping',
                confidence: 0.6,
                icon: '🏠',
                sub_occasions: ['Upgrading essentials'],
                personalized_message: 'Looks like you are building out the home basics — want help planning the essentials?',
                suggested_categories: ['Cookware', 'Dinnerware', 'Kitchen Tools']
            };
        }

        return res.json(result);
    } catch (e) {
        console.error('[POST /ai/occasion-detect]:', e.message);
        return res.status(500).json({ error: e.message, code: 500 });
    }
});

// GET /ai/resurface?device_id=xxx
router.get('/resurface', async (req, res) => {
    try {
        const device_id = String(req.query.device_id || '').trim();
        if (!device_id) return res.status(400).json({ error: 'device_id required', code: 400 });

        const { data: saved, error: sErr } = await supabase
            .from('save_for_later')
            .select('id, saved_at, product_id, products (*)')
            .eq('device_id', device_id)
            .order('saved_at', { ascending: false });
        if (sErr) throw sErr;

        const allSaved = (saved || []).map((x) => ({ ...x, products: x.products ? fixImg(x.products) : null }));

        const since = new Date(Date.now() - 7 * 86400000).toISOString();
        const { data: ev, error: eErr } = await supabase.from('user_events').select('product_id, created_at').gte('created_at', since).limit(5000);
        if (eErr) throw eErr;

        const counts = new Map();
        for (const r of ev || []) counts.set(r.product_id, (counts.get(r.product_id) || 0) + 1);
        const trendingIds = Array.from(counts.entries()).sort((a, b) => b[1] - a[1]).slice(0, 25).map(([pid]) => pid);
        const trendingSaved = allSaved.filter((x) => trendingIds.includes(x.product_id)).slice(0, 3);

        const prompt = jsonPrompt(`
A customer saved these items for later: ${allSaved.map((x) => x.products?.name).filter(Boolean).join(', ')}.
Of these, these are currently trending on our platform: ${trendingSaved.map((x) => x.products?.name).filter(Boolean).join(', ')}.
Write a compelling, personalized reason for each item why they should move it back to cart now. Max 3 items.
Return ONLY valid JSON:
[{"product_id":5,"product_name":"...","reason":"This is one of our most popular wedding gifts right now — only 3 left in stock!","urgency":"high"}]
`);

        let resurface = await askGemini(prompt);
        if (!Array.isArray(resurface)) {
            resurface = trendingSaved.slice(0, 3).map((x) => ({
                product_id: x.product_id,
                product_name: x.products?.name || 'Saved item',
                reason: 'This saved item is trending — now is a great time to grab it.',
                urgency: 'medium'
            }));
        }

        return res.json({ resurface, all_saved: allSaved.map((x) => ({ id: x.id, saved_at: x.saved_at, product: x.products })) });
    } catch (e) {
        console.error('[GET /ai/resurface]:', e.message);
        return res.status(500).json({ error: e.message, code: 500 });
    }
});

// POST /ai/style-detect
router.post('/style-detect', async (req, res) => {
    try {
        const { device_id } = req.body || {};
        if (!device_id) return res.status(400).json({ error: 'device_id required', code: 400 });
        const profile = await upsertStyleProfile(device_id);
        return res.json(profile);
    } catch (e) {
        console.error('[POST /ai/style-detect]:', e.message);
        return res.status(500).json({ error: e.message, code: 500 });
    }
});

// GET /ai/style-profile?device_id=xxx
router.get('/style-profile', async (req, res) => {
    try {
        const device_id = String(req.query.device_id || '').trim();
        if (!device_id) return res.status(400).json({ error: 'device_id required', code: 400 });

        const { data, error } = await supabase.from('user_style_profiles').select('*').eq('device_id', device_id).maybeSingle();
        if (error) throw error;

        if (!data) {
            const fresh = await upsertStyleProfile(device_id);
            return res.json(fresh);
        }

        const ageMs = Date.now() - new Date(data.generated_at || data.updated_at || data.created_at || Date.now()).getTime();
        if (ageMs > 24 * 3600000) {
            const fresh = await upsertStyleProfile(device_id);
            return res.json(fresh);
        }

        return res.json(data);
    } catch (e) {
        console.error('[GET /ai/style-profile]:', e.message);
        return res.status(500).json({ error: e.message, code: 500 });
    }
});

// POST /ai/gift-message
router.post('/gift-message', async (req, res) => {
    try {
        const { contributor_name, recipient_name, event_type, product_name, amount } = req.body || {};
        const prompt = jsonPrompt(`
Write a warm, heartfelt gift message for a registry contribution.
From: ${contributor_name}
To: ${recipient_name}
Event: ${event_type}
Gift: ${product_name} (contributed $${amount})
Write 3 message options: one heartfelt, one funny, one elegant.
Return ONLY valid JSON:
{"messages":[{"tone":"heartfelt","text":"..."},{"tone":"funny","text":"..."},{"tone":"elegant","text":"..."}]}
Keep each message under 40 words.
`);

        let result = await askGemini(prompt);
        if (!result || !Array.isArray(result.messages)) {
            result = {
                messages: [
                    { tone: 'heartfelt', text: `So happy for you both — can’t wait to see the joy this brings to your home.` },
                    { tone: 'funny', text: `May this gift help you cook, host, and impress… or at least order takeout in style.` },
                    { tone: 'elegant', text: `Wishing you a lifetime of warmth, celebration, and beautiful moments at home.` }
                ]
            };
        }
        return res.json(result);
    } catch (e) {
        console.error('[POST /ai/gift-message]:', e.message);
        return res.status(500).json({ error: e.message, code: 500 });
    }
});

// POST /ai/thank-you-note
router.post('/thank-you-note', async (req, res) => {
    try {
        const { registry_owner_name, contributor_name, product_name, event_type } = req.body || {};
        const prompt = jsonPrompt(`
Write a thank-you note for receiving a registry gift.
From: ${registry_owner_name}
To: ${contributor_name}
Gift received: ${product_name}
Occasion: ${event_type}
Write 2 options: casual and formal. Under 60 words each.
Return ONLY valid JSON:
{"notes":[{"style":"casual","text":"..."},{"style":"formal","text":"..."}]}
`);

        let result = await askGemini(prompt);
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
        console.error('[POST /ai/thank-you-note]:', e.message);
        return res.status(500).json({ error: e.message, code: 500 });
    }
});

// POST /ai/product-story
router.post('/product-story', async (req, res) => {
    try {
        const { product_id } = req.body || {};
        if (!product_id) return res.status(400).json({ error: 'product_id required', code: 400 });

        const { data: product, error } = await supabase.from('products').select('*').eq('id', product_id).single();
        if (error) throw error;
        fixImg(product);

        const prompt = jsonPrompt(`
You are a Williams Sonoma lifestyle copywriter.
Product: ${product.name}
Category: ${product.category}
Description: ${product.description}
Write a vivid, aspirational 2-sentence story about using this product in real life. Make the customer feel emotion — not features, but the experience.
Return ONLY valid JSON:
{"story":"Imagine Sunday morning... {vivid scene}. {emotional close}.","mood":"warm","occasion_tags":["Sunday brunch","Holiday cooking","Entertaining"]}
`);

        let result = await askGemini(prompt);
        if (!result || !result.story) {
            result = {
                story: `Imagine an easy Sunday where ${product.name} turns a simple meal into a moment worth sharing. It’s the kind of piece that quietly becomes part of your best memories at home.`,
                mood: 'warm',
                occasion_tags: ['Everyday cooking', 'Entertaining']
            };
        }

        return res.json({ product, ...result });
    } catch (e) {
        console.error('[POST /ai/product-story]:', e.message);
        return res.status(500).json({ error: e.message, code: 500 });
    }
});

// POST /ai/compare-products
router.post('/compare-products', async (req, res) => {
    try {
        const { product_ids } = req.body || {};
        if (!Array.isArray(product_ids) || product_ids.length < 2) return res.status(400).json({ error: 'product_ids (2-3) required', code: 400 });

        const { data: products, error } = await supabase.from('products').select('*').in('id', product_ids.slice(0, 3));
        if (error) throw error;
        (products || []).forEach(fixImg);

        const prompt = jsonPrompt(`
You are a Williams Sonoma product expert.
Compare these products for a customer trying to decide:
${JSON.stringify((products || []).map((p) => ({ id: p.id, name: p.name, price: p.price, category: p.category, description: p.description, tags: p.tags })))}
Give an honest, helpful comparison. Be specific about differences.
Return ONLY valid JSON:
{"winner_id":2,"winner_reason":"Best value for most home cooks","comparison_table":[{"aspect":"Price","values":{"1":"$X","2":"$Y"}}],"product_summaries":[{"id":1,"pros":["..."],"cons":["..."],"best_for":"..."}],"recommendation":"Go with {name} if you... Go with {other name} if you..."}
`);

        let result = await askGemini(prompt);
        if (!result || !result.winner_id) {
            const winner = (products || []).slice().sort((a, b) => Number(a.price || 0) - Number(b.price || 0))[0];
            result = {
                winner_id: winner?.id,
                winner_reason: 'Best value based on price.',
                comparison_table: [],
                product_summaries: (products || []).map((p) => ({ id: p.id, pros: ['Quality build'], cons: ['Depends on preference'], best_for: 'Everyday use' })),
                recommendation: 'Pick the one that matches your cooking style and budget.'
            };
        }

        return res.json({ products, ...result });
    } catch (e) {
        console.error('[POST /ai/compare-products]:', e.message);
        return res.status(500).json({ error: e.message, code: 500 });
    }
});

// POST /ai/bundle-build
router.post('/bundle-build', async (req, res) => {
    try {
        const { theme, budget, exclude_product_ids } = req.body || {};
        if (!theme || budget == null) return res.status(400).json({ error: 'theme and budget required', code: 400 });

        const { data: products, error } = await supabase
            .from('products')
            .select('id, name, price, category, stock, image_url, description, tags')
            .gt('stock', 0)
            .order('stock', { ascending: false })
            .limit(250);
        if (error) throw error;

        const excluded = new Set(Array.isArray(exclude_product_ids) ? exclude_product_ids : []);
        const candidates = (products || []).filter((p) => !excluded.has(p.id)).map((p) => ({ id: p.id, name: p.name, price: p.price, category: p.category }));

        const prompt = jsonPrompt(`
You are a Williams Sonoma buyer building a curated bundle.
Theme: "${theme}"
Budget: $${budget}
Available products (id, name, price, category): ${JSON.stringify(candidates)}
Build the perfect bundle. Stay within budget. Pick complementary items that tell a story together.
Return ONLY valid JSON:
{"bundle_name":"The Perfect Starter Kitchen","bundle_story":"Everything you need to cook your first real meal together.","total_price":347,"products":[{"id":5,"reason":"The foundation of every kitchen"}],"under_budget_by":53}
`);

        let bundle = await askGemini(prompt);
        if (!bundle || !Array.isArray(bundle.products)) {
            const sorted = candidates.slice().sort((a, b) => Number(a.price || 0) - Number(b.price || 0));
            const chosen = [];
            let total = 0;
            for (const p of sorted) {
                const price = Number(p.price || 0);
                if (total + price > Number(budget)) continue;
                chosen.push({ id: p.id, reason: 'Great foundational pick within budget.' });
                total += price;
                if (chosen.length >= 5) break;
            }
            bundle = {
                bundle_name: `${theme} bundle`,
                bundle_story: 'A curated set of complementary essentials.',
                total_price: total,
                products: chosen,
                under_budget_by: Math.max(0, Number(budget) - total)
            };
        }

        const ids = bundle.products.map((x) => x.id).filter(Boolean);
        const { data: full, error: fErr } = await supabase.from('products').select('*').in('id', ids);
        if (fErr) throw fErr;
        (full || []).forEach(fixImg);

        return res.json({
            bundle_name: bundle.bundle_name,
            bundle_story: bundle.bundle_story,
            total_price: bundle.total_price,
            under_budget_by: bundle.under_budget_by,
            products: (bundle.products || []).map((bp) => ({ ...full.find((p) => p.id === bp.id), ai_reason: bp.reason })).filter(Boolean)
        });
    } catch (e) {
        console.error('[POST /ai/bundle-build]:', e.message);
        return res.status(500).json({ error: e.message, code: 500 });
    }
});

// POST /ai/chat-session
router.post('/chat-session', async (req, res) => {
    try {
        const { device_id, session_id, message } = req.body || {};
        if (!device_id || !session_id || !message) return res.status(400).json({ error: 'device_id, session_id, message required', code: 400 });

        const { data: history, error: hErr } = await supabase
            .from('ai_conversation_history')
            .select('role, content, created_at')
            .eq('device_id', device_id)
            .eq('session_id', session_id)
            .order('created_at', { ascending: false })
            .limit(10);
        if (hErr) throw hErr;

        const { data: style } = await supabase.from('user_style_profiles').select('style_name, style_description').eq('device_id', device_id).maybeSingle();

        const historyLines = (history || []).slice().reverse().map((m) => `${m.role}: ${m.content}`).join('\n');
        const prompt = jsonPrompt(`
You are a Williams Sonoma AI shopping assistant. You are helpful, warm, and knowledgeable about home goods, cookware, and lifestyle products.
The customer's style profile: ${style?.style_name || 'Unknown'} — ${style?.style_description || 'No profile'}
Conversation so far:
${historyLines || '(none)'}
Customer says: ${message}
Help them with shopping, registry planning, product questions, gift ideas. When you recommend specific products, say exactly what category to search for.
If they ask to add something to cart or registry, respond with a structured action.
Return ONLY valid JSON:
{"reply":"Your conversational response here...","actions":[{"type":"search","query":"cast iron skillet"},{"type":"add_to_registry","category":"Cookware"}],"suggested_products_query":"cast iron cookware","follow_up_questions":["Would you like me to compare Dutch ovens?","What's your budget for cookware?"]}
`);

        let result = await askGemini(prompt);
        if (!result || !result.reply) {
            result = {
                reply: "Got it — tell me what you're shopping for (cookware, dinnerware, entertaining, or a registry) and your budget, and I’ll guide you.",
                actions: [{ type: 'search', query: 'kitchen essentials' }],
                suggested_products_query: 'kitchen essentials',
                follow_up_questions: ['What’s your budget?', 'Is this for a registry or everyday shopping?']
            };
        }

        await supabase.from('ai_conversation_history').insert([
            { device_id, session_id, role: 'user', content: message },
            { device_id, session_id, role: 'assistant', content: result.reply }
        ]);

        return res.json({
            reply: result.reply,
            actions: result.actions || [],
            suggested_products_query: result.suggested_products_query || null,
            follow_up_questions: result.follow_up_questions || [],
            session_id
        });
    } catch (e) {
        console.error('[POST /ai/chat-session]:', e.message);
        return res.status(500).json({ error: e.message, code: 500 });
    }
});

// GET /ai/chat-history?device_id=xxx&session_id=xxx
router.get('/chat-history', async (req, res) => {
    try {
        const device_id = String(req.query.device_id || '').trim();
        const session_id = String(req.query.session_id || '').trim();
        if (!device_id || !session_id) return res.status(400).json({ error: 'device_id and session_id required', code: 400 });

        const { data, error } = await supabase
            .from('ai_conversation_history')
            .select('role, content, created_at')
            .eq('device_id', device_id)
            .eq('session_id', session_id)
            .order('created_at', { ascending: false })
            .limit(20);
        if (error) throw error;
        return res.json({ messages: (data || []).slice().reverse() });
    } catch (e) {
        console.error('[GET /ai/chat-history]:', e.message);
        return res.status(500).json({ error: e.message, code: 500 });
    }
});

// DELETE /ai/chat-history
router.delete('/chat-history', async (req, res) => {
    try {
        const { device_id, session_id } = req.body || {};
        if (!device_id || !session_id) return res.status(400).json({ error: 'device_id and session_id required', code: 400 });

        const { error } = await supabase.from('ai_conversation_history').delete().eq('device_id', device_id).eq('session_id', session_id);
        if (error) throw error;
        return res.json({ success: true });
    } catch (e) {
        console.error('[DELETE /ai/chat-history]:', e.message);
        return res.status(500).json({ error: e.message, code: 500 });
    }
});

// POST /ai/smart-search
router.post('/smart-search', async (req, res) => {
    try {
        const { query, device_id } = req.body || {};
        if (!query) return res.status(400).json({ error: 'query required', code: 400 });

        const prompt = jsonPrompt(`
A customer searched for: "${query}" on a premium home goods store (Williams Sonoma).
Understand their intent and expand the search.
Return ONLY valid JSON:
{"intent":"looking for cookware for entertaining","expanded_queries":["cast iron skillet","dutch oven","cookware set"],"categories":["Cookware"],"mood":"entertaining","budget_signal":"premium","tags":["cooking","entertaining"]}
`);

        let intentAnalysis = await askGemini(prompt);
        if (!intentAnalysis || !Array.isArray(intentAnalysis.expanded_queries)) {
            intentAnalysis = {
                intent: `searching for ${query}`,
                expanded_queries: [query],
                categories: [],
                mood: 'neutral',
                budget_signal: 'unknown',
                tags: []
            };
        }

        const bestQuery = intentAnalysis.expanded_queries[0] || query;
        const products = (await searchOrchestrator(bestQuery, 20)).map(fixImg);

        if (device_id) await supabase.from('recent_searches').insert([{ query, device_id }]);

        return res.json({ intent_analysis: intentAnalysis, products });
    } catch (e) {
        console.error('[POST /ai/smart-search]:', e.message);
        return res.status(500).json({ error: e.message, code: 500 });
    }
});

// POST /ai/price-insight
router.post('/price-insight', async (req, res) => {
    try {
        const { product_id } = req.body || {};
        if (!product_id) return res.status(400).json({ error: 'product_id required', code: 400 });

        const { data: product, error } = await supabase.from('products').select('*').eq('id', product_id).single();
        if (error) throw error;
        fixImg(product);

        const { data: similar, error: sErr } = await supabase
            .from('products')
            .select('id, name, price, category')
            .eq('category', product.category)
            .limit(10);
        if (sErr) throw sErr;

        const prices = (similar || []).map((p) => Number(p.price || 0));
        const min = prices.length ? Math.min(...prices) : Number(product.price || 0);
        const max = prices.length ? Math.max(...prices) : Number(product.price || 0);
        const avg = prices.length ? Math.round((prices.reduce((a, b) => a + b, 0) / prices.length) * 100) / 100 : Number(product.price || 0);

        const prompt = jsonPrompt(`
You are a Williams Sonoma pricing expert.
Product: ${product.name} at $${product.price}
Similar products in this category range from $${min} to $${max}, average $${avg}.
Is this a good price? What makes it worth it or not?
Return ONLY valid JSON:
{"verdict":"Great value","score":82,"percentile":"cheaper than 78% of similar items","one_liner":"This is one of the best-priced ${product.category} items in our store.","compared_to_avg":"$X below average","buy_now_reason":"Price is at a 3-month low based on catalog data"}
`);

        let result = await askGemini(prompt);
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
        console.error('[POST /ai/price-insight]:', e.message);
        return res.status(500).json({ error: e.message, code: 500 });
    }
});

module.exports = router;
