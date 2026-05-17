// ========== FILE: routes/registry.js ==========
const express = require('express');
const router = express.Router();
const { supabase } = require('../supabaseClient');

const fixImg = (p) => {
    return p;
};

function daysUntil(dateStr) {
    if (!dateStr) return null;
    const d = new Date(dateStr);
    const now = new Date();
    return Math.ceil((d - now) / 86400000);
}

async function buildDashboard(registryId) {
    const { data: registry, error: regErr } = await supabase
        .from('registries')
        .select('id, event_type, event_date, budget, share_token, theme')
        .eq('id', registryId)
        .single();
    if (regErr) throw regErr;

    const { data: itemsRaw, error: itemsErr } = await supabase
        .from('registry_items')
        .select('*, products (*)')
        .eq('registry_id', registryId)
        .order('created_at', { ascending: false });
    if (itemsErr) throw itemsErr;

    const itemIds = (itemsRaw || []).map((i) => i.id);
    let contributions = [];
    if (itemIds.length) {
        const { data: contribData, error: contribErr } = await supabase
            .from('registry_contributions')
            .select('*')
            .in('registry_item_id', itemIds)
            .order('created_at', { ascending: false });
        if (contribErr) throw contribErr;
        contributions = contribData || [];
    }

    const contribByItem = new Map();
    for (const c of contributions) {
        const arr = contribByItem.get(c.registry_item_id) || [];
        arr.push(c);
        contribByItem.set(c.registry_item_id, arr);
    }

    const items = (itemsRaw || []).map((item) => {
        const product = item.products ? fixImg(item.products) : null;
        const itemContribs = contribByItem.get(item.id) || [];
        const totalContributed = itemContribs.reduce((sum, x) => sum + Number(x.amount || 0), 0);
        const targetAmount = Number(item.price_snapshot || 0) * Number(item.quantity_requested || 0);
        const isFullyFunded = targetAmount > 0 ? totalContributed >= targetAmount : false;

        const out = { ...item };
        delete out.products;
        return {
            ...out,
            product,
            contributions: itemContribs,
            total_contributed: totalContributed,
            is_fully_funded: isFullyFunded
        };
    });

    const totalItems = items.length;
    const purchasedItems = items.filter((i) => Number(i.quantity_received || 0) > 0).length;
    const pendingItems = Math.max(0, totalItems - purchasedItems);
    const budgetUsed = items.reduce(
        (sum, i) => sum + (Number(i.price_snapshot || 0) * Number(i.quantity_received || 0)),
        0
    );
    const budgetTotal = Number(registry.budget || 0);
    const budgetRemaining = budgetTotal - budgetUsed;
    const completionPct = totalItems ? Math.round((purchasedItems / totalItems) * 100) : 0;

    return {
        registry,
        stats: {
            total_items: totalItems,
            purchased_items: purchasedItems,
            pending_items: pendingItems,
            budget_total: budgetTotal,
            budget_used: budgetUsed,
            budget_remaining: budgetRemaining,
            completion_pct: completionPct,
            days_until_event: daysUntil(registry.event_date)
        },
        items
    };
}

// GET registries for a user
router.get('/user/:userId', async (req, res) => {
    try {
        const { userId } = req.params;
        const { data, error } = await supabase.from('registries').select('*').eq('user_id', userId);
        if (error) return res.status(500).json({ error: error.message, code: 500 });
        return res.json(data || []);
    } catch (e) {
        console.error('[GET /registry/user/:userId]:', e.message);
        return res.status(500).json({ error: e.message, code: 500 });
    }
});

// GET public registry by share token (guest access)
router.get('/public/:shareToken', async (req, res) => {
    try {
        const { shareToken } = req.params;
        const { data: registry, error } = await supabase
            .from('registries')
            .select('id')
            .eq('share_token', shareToken)
            .single();
        if (error) return res.status(500).json({ error: error.message, code: 500 });
        const dashboard = await buildDashboard(registry.id);
        return res.json(dashboard);
    } catch (e) {
        console.error('[GET /registry/public/:shareToken]:', e.message);
        return res.status(500).json({ error: e.message, code: 500 });
    }
});

// GET single registry
router.get('/:id', async (req, res) => {
    try {
        const { id } = req.params;
        const { data, error } = await supabase.from('registries').select('*').eq('id', id).single();
        if (error) return res.status(500).json({ error: error.message, code: 500 });
        return res.json(data);
    } catch (e) {
        console.error('[GET /registry/:id]:', e.message);
        return res.status(500).json({ error: e.message, code: 500 });
    }
});

// POST create registry
router.post('/', async (req, res) => {
    try {
        const { user_id, event_type, event_date, event_location, is_public, address_pre_event, address_post_event } =
            req.body;

        const { data, error } = await supabase
            .from('registries')
            .insert([
                {
                    user_id,
                    event_type,
                    event_date,
                    event_location,
                    is_public,
                    address_pre_event,
                    address_post_event
                }
            ])
            .select()
            .single();

        if (error) return res.status(500).json({ error: error.message, code: 500 });
        return res.json(data);
    } catch (e) {
        console.error('[POST /registry]:', e.message);
        return res.status(500).json({ error: e.message, code: 500 });
    }
});

// POST /registry/:id/budget
router.post('/:id/budget', async (req, res) => {
    try {
        const { id } = req.params;
        const { budget } = req.body;
        const { data, error } = await supabase
            .from('registries')
            .update({ budget: Number(budget || 0) })
            .eq('id', id)
            .select()
            .single();
        if (error) return res.status(500).json({ error: error.message, code: 500 });
        return res.json(data);
    } catch (e) {
        console.error('[POST /registry/:id/budget]:', e.message);
        return res.status(500).json({ error: e.message, code: 500 });
    }
});

// GET /registry/:id/dashboard
router.get('/:id/dashboard', async (req, res) => {
    try {
        const { id } = req.params;
        const dashboard = await buildDashboard(id);
        return res.json(dashboard);
    } catch (e) {
        console.error('[GET /registry/:id/dashboard]:', e.message);
        return res.status(500).json({ error: e.message, code: 500 });
    }
});

// POST /registry/:id/contribute
router.post('/:id/contribute', async (req, res) => {
    try {
        const { registry_item_id, contributor_name, amount, message } = req.body;
        if (!registry_item_id || !contributor_name || amount == null) {
            return res.status(400).json({ error: 'registry_item_id, contributor_name, amount required', code: 400 });
        }

        const { data: contribution, error: insErr } = await supabase
            .from('registry_contributions')
            .insert([
                {
                    registry_item_id,
                    contributor_name,
                    amount: Number(amount),
                    message: message || null
                }
            ])
            .select()
            .single();
        if (insErr) return res.status(500).json({ error: insErr.message, code: 500 });

        const { data: item, error: itemErr } = await supabase
            .from('registry_items')
            .select('id, price_snapshot, quantity_requested')
            .eq('id', registry_item_id)
            .single();
        if (itemErr) return res.status(500).json({ error: itemErr.message, code: 500 });

        const { data: allContrib, error: sumErr } = await supabase
            .from('registry_contributions')
            .select('amount')
            .eq('registry_item_id', registry_item_id);
        if (sumErr) return res.status(500).json({ error: sumErr.message, code: 500 });

        const totalContributed = (allContrib || []).reduce((sum, x) => sum + Number(x.amount || 0), 0);
        const targetAmount = Number(item.price_snapshot || 0) * Number(item.quantity_requested || 0);
        const isFullyFunded = targetAmount > 0 ? totalContributed >= targetAmount : false;

        return res.json({
            contribution,
            total_contributed: totalContributed,
            target_amount: targetAmount,
            is_fully_funded: isFullyFunded
        });
    } catch (e) {
        console.error('[POST /registry/:id/contribute]:', e.message);
        return res.status(500).json({ error: e.message, code: 500 });
    }
});

// GET /registry/:id/contributions
router.get('/:id/contributions', async (req, res) => {
    try {
        const { id } = req.params;
        const { data: items, error: itemErr } = await supabase.from('registry_items').select('id').eq('registry_id', id);
        if (itemErr) return res.status(500).json({ error: itemErr.message, code: 500 });

        const itemIds = (items || []).map((x) => x.id);
        if (!itemIds.length) return res.json([]);

        const { data: contribs, error: cErr } = await supabase
            .from('registry_contributions')
            .select('*')
            .in('registry_item_id', itemIds)
            .order('created_at', { ascending: false });
        if (cErr) return res.status(500).json({ error: cErr.message, code: 500 });

        const grouped = new Map();
        for (const c of contribs || []) {
            const g = grouped.get(c.registry_item_id) || { registry_item_id: c.registry_item_id, total_contributed: 0, contributors: [] };
            g.total_contributed += Number(c.amount || 0);
            g.contributors.push(c);
            grouped.set(c.registry_item_id, g);
        }

        return res.json(Array.from(grouped.values()));
    } catch (e) {
        console.error('[GET /registry/:id/contributions]:', e.message);
        return res.status(500).json({ error: e.message, code: 500 });
    }
});

// POST /registry/:id/collaborators
router.post('/:id/collaborators', async (req, res) => {
    try {
        const { id } = req.params;
        const { email, role } = req.body;
        if (!email) return res.status(400).json({ error: 'email required', code: 400 });

        const { data: existing, error: exErr } = await supabase
            .from('registry_collaborators')
            .select('*')
            .eq('registry_id', id)
            .eq('email', email)
            .maybeSingle();
        if (exErr) return res.status(500).json({ error: exErr.message, code: 500 });
        if (existing) return res.json({ collaborator: existing, already_existed: true });

        const { data: collaborator, error } = await supabase
            .from('registry_collaborators')
            .insert([{ registry_id: id, email, role: role || 'viewer' }])
            .select()
            .single();
        if (error) return res.status(500).json({ error: error.message, code: 500 });
        return res.json({ collaborator, already_existed: false });
    } catch (e) {
        console.error('[POST /registry/:id/collaborators]:', e.message);
        return res.status(500).json({ error: e.message, code: 500 });
    }
});

// GET /registry/:id/collaborators
router.get('/:id/collaborators', async (req, res) => {
    try {
        const { id } = req.params;
        const { data, error } = await supabase
            .from('registry_collaborators')
            .select('*')
            .eq('registry_id', id)
            .order('invited_at', { ascending: false });
        if (error) return res.status(500).json({ error: error.message, code: 500 });
        return res.json(data || []);
    } catch (e) {
        console.error('[GET /registry/:id/collaborators]:', e.message);
        return res.status(500).json({ error: e.message, code: 500 });
    }
});

// GET /registry/:id/share-link
router.get('/:id/share-link', async (req, res) => {
    try {
        const { id } = req.params;
        const { data, error } = await supabase.from('registries').select('share_token').eq('id', id).single();
        if (error) return res.status(500).json({ error: error.message, code: 500 });
        const shareToken = data?.share_token;
        return res.json({
            share_token: shareToken,
            share_url: `https://smartregistry.williamsonoma.app/r/${shareToken}`
        });
    } catch (e) {
        console.error('[GET /registry/:id/share-link]:', e.message);
        return res.status(500).json({ error: e.message, code: 500 });
    }
});

// GET registry items
router.get('/:id/items', async (req, res) => {
    try {
        const { id } = req.params;
        const { data, error } = await supabase
            .from('registry_items')
            .select(`
                *,
                products (*)
            `)
            .eq('registry_id', id);

        if (error) return res.status(500).json({ error: error.message, code: 500 });

        const items = (data || []).map((item) => {
            if (item.products) fixImg(item.products);
            return item;
        });

        return res.json(items);
    } catch (e) {
        console.error('[GET /registry/:id/items]:', e.message);
        return res.status(500).json({ error: e.message, code: 500 });
    }
});

// POST add item to registry (extended to store price_snapshot + ai_reason)
router.post('/:id/items', async (req, res) => {
    try {
        const { id } = req.params;
        const { product_id, quantity_requested, is_most_wanted, ai_reason } = req.body;

        const { data: product, error: prodErr } = await supabase
            .from('products')
            .select('id, price')
            .eq('id', product_id)
            .single();
        if (prodErr) return res.status(500).json({ error: prodErr.message, code: 500 });

        const { data, error } = await supabase
            .from('registry_items')
            .insert([
                {
                    registry_id: id,
                    product_id,
                    quantity_requested,
                    is_most_wanted,
                    price_snapshot: Number(product?.price || 0),
                    ai_reason: ai_reason || null
                }
            ])
            .select()
            .single();

        if (error) return res.status(500).json({ error: error.message, code: 500 });
        return res.json(data);
    } catch (e) {
        console.error('[POST /registry/:id/items]:', e.message);
        return res.status(500).json({ error: e.message, code: 500 });
    }
});

// PUT update item (e.g. quantity received, or most wanted)
router.put('/:id/items/:itemId', async (req, res) => {
    try {
        const { itemId } = req.params;
        const updates = req.body;

        const { data, error } = await supabase.from('registry_items').update(updates).eq('id', itemId).select().single();

        if (error) return res.status(500).json({ error: error.message, code: 500 });
        return res.json(data);
    } catch (e) {
        console.error('[PUT /registry/:id/items/:itemId]:', e.message);
        return res.status(500).json({ error: e.message, code: 500 });
    }
});

// DELETE item from registry
router.delete('/:id/items/:itemId', async (req, res) => {
    try {
        const { itemId } = req.params;

        const { error } = await supabase.from('registry_items').delete().eq('id', itemId);
        if (error) return res.status(500).json({ error: error.message, code: 500 });
        return res.json({ success: true });
    } catch (e) {
        console.error('[DELETE /registry/:id/items/:itemId]:', e.message);
        return res.status(500).json({ error: e.message, code: 500 });
    }
});

module.exports = router;
