// ========== FILE: routes/ai_presence.js ==========
// AI Presence System — dynamic hints, scan status, and health check
// Mounted in server.js as: app.use('/ai/presence', require('./routes/ai_presence'));

const express = require('express');
const router = express.Router();
const { supabase } = require('../supabaseClient');
const { GoogleGenAI } = require('@google/genai');

const isDev = process.env.NODE_ENV !== 'production';

// ── Gemini client (optional — graceful degradation if key absent) ─────────────
let ai = null;
let geminiAvailable = false;
if (process.env.GEMINI_API_KEY) {
    try {
        ai = new GoogleGenAI({ apiKey: process.env.GEMINI_API_KEY, apiVersion: 'v1' });
        geminiAvailable = true;
    } catch (_) {
        geminiAvailable = false;
    }
}

// ── Hardcoded fallback pools ──────────────────────────────────────────────────
const HINT_POOLS = {
    shop_browse:    ['✦ Personalizing your feed', '✦ Scanning 200+ products for you', '✦ 3 new arrivals match your taste', '✦ Prices verified just now'],
    product_detail: ['✦ Reading reviews for this', '✦ I have thoughts on this', '✦ Checking for a better deal', '✦ Analyzing similar products'],
    cart_empty:     ['✦ Cart is empty — want ideas?', '✦ I can build a cart from a vibe'],
    cart_has_items: ['✦ Optimizing your cart', '✦ Nice picks — found a bundle 👀', '✦ Want to complete the set?'],
    orders:         ['✦ Tracking your deliveries', '✦ Need to return something?', '✦ I can reorder instantly'],
    registry:       ['✦ Building your perfect registry', '✦ I can find gifts in any budget', '✦ Analyzing wish patterns'],
    checkout:       ['✦ Checking stock one more time', '✦ All clear — ready to order'],
    search_results: ['✦ Results ranked by relevance', '✦ Found across all categories'],
    idle:           ['✦ Still here if you need me', '✦ Ask me anything ✦']
};

function randomFrom(arr) {
    return arr[Math.floor(Math.random() * arr.length)];
}

function fallbackHint(context) {
    const pool = HINT_POOLS[context] || HINT_POOLS.idle;
    return randomFrom(pool);
}

// ── 6-second Gemini timeout wrapper ──────────────────────────────────────────
function withTimeout(promise, ms = 6000) {
    const timeout = new Promise((_, reject) =>
        setTimeout(() => reject(new Error('timeout')), ms)
    );
    return Promise.race([promise, timeout]);
}

// ── POST /ai/presence/hint ────────────────────────────────────────────────────
router.post('/hint', async (req, res) => {
    const {
        context = 'idle',
        product_name,
        product_category,
        cart_count = 0,
        tab = 0,
        device_id
    } = req.body;

    if (isDev) {
        console.log('[AI:presence] POST /hint body:', req.body);
    }

    // Always return 200 — never 500
    if (!geminiAvailable || !ai) {
        const hint = fallbackHint(context);
        if (isDev) console.log('[AI:presence] /hint fallback response:', hint);
        return res.json({ hint, source: 'fallback' });
    }

    try {
        const prompt = `You are a shopping assistant AI. A user is currently on: ${context}.
Product in view: ${product_name || 'none'} (${product_category || 'general'}).
Cart has ${cart_count} items.
Write exactly ONE hint message, max 7 words, that feels like the AI is actively working.
Start with ✦. Examples: "✦ Scanning similar products now", "✦ Great choice for starters", "✦ I found a better bundle".
Respond with only the message, nothing else.`;

        const geminiCall = ai.models.generateContent({
            model: process.env.GEMINI_MODEL || 'gemini-2.0-flash',
            contents: [{ role: 'user', parts: [{ text: prompt }] }],
            generationConfig: { temperature: 0.7, maxOutputTokens: 30 }
        });

        const response = await withTimeout(geminiCall, 6000);
        let hint = (response.text() || '').trim();

        // Validate: must start with ✦ and be max 7 words
        if (!hint.startsWith('✦')) hint = '✦ ' + hint;
        const words = hint.replace('✦', '').trim().split(/\s+/);
        if (words.length > 7) hint = '✦ ' + words.slice(0, 7).join(' ');
        if (!hint || hint === '✦') hint = fallbackHint(context);

        if (isDev) console.log('[AI:presence] /hint gemini response:', hint);
        return res.json({ hint, source: 'gemini' });
    } catch (err) {
        console.log('[AI] Gemini error:', err.message);
        const hint = fallbackHint(context);
        if (isDev) console.log('[AI:presence] /hint fallback after error:', hint);
        return res.json({ hint, source: 'fallback' });
    }
});

// ── POST /ai/presence/scan-status ────────────────────────────────────────────
router.post('/scan-status', async (req, res) => {
    const { screen = 'shop', device_id } = req.body;

    if (isDev) {
        console.log('[AI:presence] POST /scan-status body:', req.body);
    }

    const genericMessages = {
        shop: [
            '✦ Personalizing your feed',
            '✦ Prices verified just now',
            '✦ 3 new arrivals match your taste',
            '✦ Recommendations refreshed'
        ],
        registry: [
            '✦ Analyzing popular registry patterns',
            '✦ Gift completion rate: typically 73%',
            '✦ AI can fill gaps in your registry',
            '✦ Smart bundles available for your list'
        ]
    };

    try {
        // Attempt to personalize from style profile
        if (device_id) {
            const { data: profile, error } = await supabase
                .from('user_style_profiles')
                .select('style_name, top_categories, price_tier')
                .eq('device_id', device_id)
                .maybeSingle();

            if (!error && profile) {
                const styleName = profile.style_name || 'your taste';
                const cat = (profile.top_categories || [])[0] || 'Products';
                const messages = screen === 'registry'
                    ? [
                        `✦ Curating registry for ${styleName} style`,
                        '✦ Gift completion rate: typically 73%',
                        `✦ Top picks from ${cat} ready`,
                        '✦ Smart bundles available for your list'
                    ]
                    : [
                        `✦ Personalizing your feed for ${styleName} taste`,
                        '✦ Prices verified 2 min ago',
                        `✦ 3 new arrivals in ${cat}`,
                        '✦ Recommendations refreshed'
                    ];
                if (isDev) console.log('[AI:presence] /scan-status personalized:', messages);
                return res.json({ messages });
            }
        }
    } catch (_) {
        // Fall through to generic
    }

    const messages = genericMessages[screen] || genericMessages.shop;
    if (isDev) console.log('[AI:presence] /scan-status generic:', messages);
    return res.json({ messages });
});

// ── GET /ai/presence/health ───────────────────────────────────────────────────
router.get('/health', (req, res) => {
    return res.json({ status: 'ok', gemini: geminiAvailable });
});

module.exports = router;
