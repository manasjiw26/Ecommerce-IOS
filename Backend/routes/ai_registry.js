// ========== FILE: routes/ai_registry.js ==========
const express = require('express');
const router = express.Router();
const { supabase } = require('../supabaseClient');
const { GoogleGenAI } = require('@google/genai');

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

function withJsonGuard(prompt) {
    const suffix = 'Return ONLY valid JSON. No markdown, no explanation, no backticks.';
    return prompt.trim().endsWith(suffix) ? prompt.trim() : `${prompt.trim()}\n${suffix}`;
}

function defaultPriority(i) {
    if (i === 0 || i === 1) return 'essential';
    if (i === 2 || i === 3 || i === 4) return 'recommended';
    return 'nice-to-have';
}

function computeRegistryStats(items) {
    const totalItems = items.length;
    const purchasedItems = items.filter((i) => Number(i.quantity_received || 0) > 0).length;
    const completionPct = totalItems ? Math.round((purchasedItems / totalItems) * 100) : 0;
    const budgetUsed = items.reduce((sum, i) => sum + (Number(i.price_snapshot || 0) * Number(i.quantity_received || 0)), 0);
    return { total_items: totalItems, purchased_items: purchasedItems, completion_pct: completionPct, budget_used: budgetUsed };
}

// POST /ai/registry/suggest
router.post('/suggest', async (req, res) => {
    try {
        const { event_type, budget, existing_categories } = req.body || {};
        if (!event_type) return res.status(400).json({ error: 'event_type required', code: 400 });

        const { data: products, error } = await supabase.from('products').select('id, category, price').limit(5000);
        if (error) throw error;

        const catMap = new Map();
        for (const p of products || []) {
            const c = p.category || 'Other';
            const row = catMap.get(c) || { category: c, count: 0, min: null, max: null };
            row.count += 1;
            const price = Number(p.price || 0);
            row.min = row.min == null ? price : Math.min(row.min, price);
            row.max = row.max == null ? price : Math.max(row.max, price);
            catMap.set(c, row);
        }
        const categories = Array.from(catMap.values())
            .sort((a, b) => b.count - a.count)
            .slice(0, 50)
            .map((c) => `${c.category} (count ${c.count}, $${Math.round(c.min || 0)}-$${Math.round(c.max || 0)})`);

        const prompt = withJsonGuard(`
You are a Williams Sonoma registry specialist. A customer is creating a registry for: ${event_type}.
Their budget is: $${budget || 'not specified'}.
They already have items in: ${Array.isArray(existing_categories) ? existing_categories.join(', ') : existing_categories || 'nothing yet'}.
Available product categories in our store: ${categories.join('; ')}.
Suggest 8 registry categories they should add. For each, explain why it matters for this event.
Return ONLY valid JSON array:
[{"category":"Cookware","reason":"Essential for..","budget_pct":20,"priority":"essential","example_items":["Cast iron skillet","Dutch oven"]}]
Priority must be one of: essential, recommended, nice-to-have.
`);

        let suggestions = await askGemini(prompt);
        if (!Array.isArray(suggestions)) {
            const topCats = Array.from(catMap.values()).sort((a, b) => b.count - a.count).slice(0, 8).map((x, idx) => ({
                category: x.category,
                reason: `Popular category for ${event_type} registries and everyday use.`,
                budget_pct: Math.max(5, Math.round(100 / 8)),
                priority: defaultPriority(idx),
                example_items: []
            }));
            suggestions = topCats;
        }

        const productsByCategory = {};
        for (const s of suggestions) {
            const cat = s?.category;
            if (!cat) continue;
            const { data: catProducts, error: catErr } = await supabase
                .from('products')
                .select('*')
                .eq('category', cat)
                .order('stock', { ascending: false })
                .limit(4);
            if (catErr) continue;
            productsByCategory[cat] = (catProducts || []).map(fixImg);
        }

        return res.json({ event_type, suggestions, products_by_category: productsByCategory });
    } catch (e) {
        console.error('[POST /ai/registry/suggest]:', e.message);
        return res.status(500).json({ error: e.message, code: 500 });
    }
});

// POST /ai/registry/budget-plan
router.post('/budget-plan', async (req, res) => {
    try {
        const { event_type, total_budget } = req.body || {};
        if (!event_type || total_budget == null) return res.status(400).json({ error: 'event_type and total_budget required', code: 400 });

        const prompt = withJsonGuard(`
You are a Williams Sonoma financial planner for registries.
For a ${event_type} registry with total budget $${total_budget}:
Allocate the budget smartly across categories.
Return ONLY valid JSON:
{"allocations":[{"category":"Cookware","amount":450,"pct":22,"priority":"essential","rationale":"..."}],"tips":["..."],"total_check":true}
Make sure amounts sum to total_budget. Rationale is one sentence each.
`);

        let plan = await askGemini(prompt);
        if (!plan || !Array.isArray(plan.allocations)) {
            const b = Number(total_budget || 0);
            plan = {
                allocations: [
                    { category: 'Cookware', amount: Math.round(b * 0.28), pct: 28, priority: 'essential', rationale: 'Core cooking foundation.' },
                    { category: 'Dinnerware', amount: Math.round(b * 0.18), pct: 18, priority: 'essential', rationale: 'Everyday dining and hosting.' },
                    { category: 'Appliances', amount: Math.round(b * 0.18), pct: 18, priority: 'recommended', rationale: 'Time-saving kitchen upgrades.' },
                    { category: 'Bakeware', amount: Math.round(b * 0.12), pct: 12, priority: 'recommended', rationale: 'Completes cooking with baking.' },
                    { category: 'Serveware', amount: Math.round(b * 0.12), pct: 12, priority: 'recommended', rationale: 'Makes entertaining effortless.' },
                    { category: 'Kitchen Tools', amount: Math.round(b * 0.07), pct: 7, priority: 'essential', rationale: 'Small tools make daily cooking easier.' },
                    { category: 'Linens', amount: b - (Math.round(b * 0.28) + Math.round(b * 0.18) + Math.round(b * 0.18) + Math.round(b * 0.12) + Math.round(b * 0.12) + Math.round(b * 0.07)), pct: 5, priority: 'nice-to-have', rationale: 'Finishing touches for the home.' }
                ],
                tips: ['Start with essentials, then add upgrades as gifts arrive.'],
                total_check: true
            };
        }

        return res.json(plan);
    } catch (e) {
        console.error('[POST /ai/registry/budget-plan]:', e.message);
        return res.status(500).json({ error: e.message, code: 500 });
    }
});

// POST /ai/registry/completeness
router.post('/completeness', async (req, res) => {
    try {
        const { registry_id, event_type } = req.body || {};
        if (!registry_id || !event_type) return res.status(400).json({ error: 'registry_id and event_type required', code: 400 });

        const { data: items, error } = await supabase
            .from('registry_items')
            .select('id, quantity_received, price_snapshot, products (id, name, category)')
            .eq('registry_id', registry_id);
        if (error) throw error;

        const stats = computeRegistryStats(items || []);
        const itemList = (items || []).map((i) => `${i.products?.name} (${i.products?.category})`).filter(Boolean);

        const prompt = withJsonGuard(`
You are a Williams Sonoma registry expert.
Event type: ${event_type}
Items currently in registry: ${itemList.join(', ')}
Budget used: $${stats.budget_used}
Score this registry 0-100 for completeness. Be specific about what's missing.
Return ONLY valid JSON:
{"score":67,"label":"Well started","grade":"B","missing_categories":["Linens","Bar tools"],"surplus_warning":"You have 4 similar frying pans - consider diversifying","message":"Great start! Your kitchen is covered but you're missing bedroom and dining essentials.","next_3_to_add":["Bed sheets","Wine glasses","Serving platter"]}
`);

        let result = await askGemini(prompt);
        if (!result || typeof result.score !== 'number') {
            const covered = new Set((items || []).map((i) => i.products?.category).filter(Boolean));
            const missing = ['Serveware', 'Dinnerware', 'Kitchen Tools', 'Linens'].filter((c) => !covered.has(c)).slice(0, 3);
            result = {
                score: Math.min(95, Math.round((covered.size / 8) * 100)),
                label: covered.size >= 4 ? 'Well started' : 'Just beginning',
                grade: covered.size >= 5 ? 'B' : 'C',
                missing_categories: missing,
                surplus_warning: '',
                message: 'Add a few key categories to round out the registry.',
                next_3_to_add: missing.length ? missing : ['Serveware', 'Dinnerware', 'Kitchen Tools']
            };
        }

        return res.json(result);
    } catch (e) {
        console.error('[POST /ai/registry/completeness]:', e.message);
        return res.status(500).json({ error: e.message, code: 500 });
    }
});

// POST /ai/registry/theme
router.post('/theme', async (req, res) => {
    try {
        const { event_type, style_hints } = req.body || {};
        if (!event_type) return res.status(400).json({ error: 'event_type required', code: 400 });

        const prompt = withJsonGuard(`
You are a Williams Sonoma interior and lifestyle consultant.
Suggest 3 registry themes for a ${event_type} with style: ${style_hints || 'classic'}.
Return ONLY valid JSON:
{"themes":[{"name":"Coastal Farmhouse","description":"...","color_palette":["#F5F0E8","#A8C5B5"],"key_categories":["..."],"vibe":"..."}]}
`);

        let result = await askGemini(prompt);
        if (!result || !Array.isArray(result.themes)) {
            result = {
                themes: [
                    { name: 'Classic Warmth', description: 'Timeless neutrals and reliable essentials for daily living.', color_palette: ['#F6F1E8', '#C8B8A6'], key_categories: ['Cookware', 'Dinnerware', 'Linens'], vibe: 'comfortable' },
                    { name: 'Modern Minimal', description: 'Clean lines, premium materials, clutter-free hosting pieces.', color_palette: ['#FFFFFF', '#111827'], key_categories: ['Cookware', 'Kitchen Tools', 'Serveware'], vibe: 'sleek' },
                    { name: 'Coastal Calm', description: 'Light tones and effortless entertaining inspired by the coast.', color_palette: ['#F5F0E8', '#A8C5B5'], key_categories: ['Serveware', 'Glassware', 'Linens'], vibe: 'airy' }
                ]
            };
        }

        return res.json(result);
    } catch (e) {
        console.error('[POST /ai/registry/theme]:', e.message);
        return res.status(500).json({ error: e.message, code: 500 });
    }
});

// POST /ai/registry/timeline
router.post('/timeline', async (req, res) => {
    try {
        const { event_type, event_date, registry_id } = req.body || {};
        if (!event_type || !event_date || !registry_id) return res.status(400).json({ error: 'event_type, event_date, registry_id required', code: 400 });

        const daysUntil = Math.ceil((new Date(event_date) - new Date()) / 86400000);

        const { data: items, error } = await supabase.from('registry_items').select('id, quantity_received, price_snapshot').eq('registry_id', registry_id);
        if (error) throw error;
        const stats = computeRegistryStats(items || []);

        const prompt = withJsonGuard(`
A ${event_type} is in ${daysUntil} days.
Their registry currently has ${stats.total_items} items and is ${stats.completion_pct}% complete.
Create a prioritized action plan — what should they focus on adding NOW vs LATER?
Return ONLY valid JSON:
{"urgency":"high","phases":[{"phase":"This week","action":"Add these essentials first","categories":["..."],"reason":"..."},{"phase":"This month","action":"...","categories":["..."],"reason":"..."},{"phase":"Final stretch","action":"...","categories":["..."],"reason":"..."}],"warning":"You only have ${daysUntil} days — focus on essentials first"}
`);

        let result = await askGemini(prompt);
        if (!result || !Array.isArray(result.phases)) {
            const urgency = daysUntil <= 21 ? 'high' : daysUntil <= 60 ? 'medium' : 'low';
            result = {
                urgency,
                phases: [
                    { phase: 'This week', action: 'Add core essentials', categories: ['Cookware', 'Dinnerware', 'Kitchen Tools'], reason: 'Essentials get purchased first and set your foundation.' },
                    { phase: 'This month', action: 'Add entertaining + upgrades', categories: ['Serveware', 'Glassware', 'Appliances'], reason: 'Round out hosting and add aspirational gifts.' },
                    { phase: 'Final stretch', action: 'Add finishing touches', categories: ['Linens', 'Decor', 'Storage'], reason: 'Complete the home with smaller add-ons.' }
                ],
                warning: `You only have ${daysUntil} days — focus on essentials first`
            };
        }

        return res.json(result);
    } catch (e) {
        console.error('[POST /ai/registry/timeline]:', e.message);
        return res.status(500).json({ error: e.message, code: 500 });
    }
});

// GET /ai/registry/gift-picker?registry_id=xxx&budget=100
router.get('/gift-picker', async (req, res) => {
    try {
        const registry_id = req.query.registry_id;
        const budget = Number(req.query.budget || 0);
        if (!registry_id || !budget) return res.status(400).json({ error: 'registry_id and budget required', code: 400 });

        const { data: registry, error: regErr } = await supabase.from('registries').select('event_type').eq('id', registry_id).single();
        if (regErr) throw regErr;

        const { data: items, error } = await supabase
            .from('registry_items')
            .select('id, registry_id, product_id, quantity_requested, quantity_received, price_snapshot, is_most_wanted, products (id, name, category)')
            .eq('registry_id', registry_id);
        if (error) throw error;

        const pending = (items || []).filter((i) => Number(i.quantity_received || 0) < Number(i.quantity_requested || 0));
        const filtered = pending.filter((i) => Number(i.price_snapshot || 0) <= budget * 1.2);

        const itemNames = filtered.map((i) => `${i.products?.name} ($${Number(i.price_snapshot || 0)})`).filter(Boolean);
        const prompt = withJsonGuard(`
A gift-giver has $${budget} to spend on a registry for a ${registry?.event_type || 'registry'}.
These items are still needed: ${itemNames.join(', ')}.
Recommend the 3 best gift options. Consider: completing sets, picking most-wanted items, staying in budget.
Return ONLY valid JSON:
{"recommendations":[{"product_name":"...","registry_item_id":"uuid","price":89,"reason":"...","wow_factor":"This is their most-wanted item!"}]}
`);

        let rec = await askGemini(prompt);
        if (!rec || !Array.isArray(rec.recommendations)) {
            const sorted = filtered
                .slice()
                .sort((a, b) => Number(b.is_most_wanted) - Number(a.is_most_wanted) || Number(a.price_snapshot || 0) - Number(b.price_snapshot || 0))
                .slice(0, 3);
            rec = {
                recommendations: sorted.map((i) => ({
                    product_name: i.products?.name || 'Gift',
                    registry_item_id: i.id,
                    price: Number(i.price_snapshot || 0),
                    reason: i.is_most_wanted ? 'Marked as most wanted by the recipient.' : 'A great fit within budget for what they still need.',
                    wow_factor: i.is_most_wanted ? 'Most-wanted pick!' : 'Perfect registry essential.'
                }))
            };
        }

        return res.json({ budget, recommendations: rec.recommendations, registry_event_type: registry?.event_type || null });
    } catch (e) {
        console.error('[GET /ai/registry/gift-picker]:', e.message);
        return res.status(500).json({ error: e.message, code: 500 });
    }
});

// POST /ai/registry/trending-occasion
router.post('/trending-occasion', async (req, res) => {
    try {
        const { event_type } = req.body || {};
        if (!event_type) return res.status(400).json({ error: 'event_type required', code: 400 });

        const since = new Date(Date.now() - 30 * 86400000).toISOString();
        const { data, error } = await supabase
            .from('registry_items')
            .select('product_id, registries!inner(event_type, created_at), products (id, name, category, price, image_url)')
            .eq('registries.event_type', event_type)
            .gte('registries.created_at', since);
        if (error) throw error;

        const counts = new Map();
        for (const row of data || []) {
            const pid = row.product_id;
            counts.set(pid, (counts.get(pid) || 0) + 1);
        }
        const top = Array.from(counts.entries())
            .sort((a, b) => b[1] - a[1])
            .slice(0, 10)
            .map(([pid]) => (data || []).find((r) => r.product_id === pid))
            .filter(Boolean);

        const trendingProducts = top.map((r) => fixImg(r.products));
        const names = trendingProducts.map((p) => `${p.name} (${p.category})`).filter(Boolean);

        const prompt = withJsonGuard(`
You are a Williams Sonoma trend analyst.
These products are most popular in ${event_type} registries right now: ${names.join(', ')}.
Write 3 trend insights — what this tells us about what people want for their ${event_type}.
Return ONLY valid JSON:
{"trend_title":"What's Hot for ${event_type}s Right Now","insights":[{"headline":"...","detail":"...","category":"..."}],"hot_categories":["..."],"data_summary":"Based on recent registry activity"}
`);

        let insights = await askGemini(prompt);
        if (!insights || !Array.isArray(insights.insights)) {
            const hotCats = [...new Set(trendingProducts.map((p) => p.category).filter(Boolean))].slice(0, 5);
            insights = {
                trend_title: `What's Hot for ${event_type}s Right Now`,
                insights: hotCats.slice(0, 3).map((c) => ({ headline: `More focus on ${c}`, detail: `Shoppers are prioritizing quality pieces in ${c} for long-term use.`, category: c })),
                hot_categories: hotCats,
                data_summary: 'Based on recent registry activity'
            };
        }

        return res.json({ insights, trending_products: trendingProducts, event_type });
    } catch (e) {
        console.error('[POST /ai/registry/trending-occasion]:', e.message);
        return res.status(500).json({ error: e.message, code: 500 });
    }
});

module.exports = router;

