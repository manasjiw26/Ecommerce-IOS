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
        .select('id, event_type, event_date, budget, share_token, theme, event_location, is_public, user_id')
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

// GET /registry/starter-bundles
router.get('/starter-bundles', async (req, res) => {
    try {
        const { event_type } = req.query;
        // Fetch real products from catalog to construct bundles dynamically!
        const { data: products, error } = await supabase.from('products').select('*');
        if (error) return res.status(500).json({ error: error.message });
        const catalog = products || [];

        const withFallback = (primary) => {
            if (primary.length) return primary;
            return catalog.slice(0, 3);
        };

        // Let's group products dynamically into gorgeous starter bundles
        // depending on the event type!
        const type = (event_type || '').toLowerCase();
        let bundles = [];

        if (type.includes('sangeet') || type.includes('diwali')) {
            const platterProducts = withFallback(catalog.filter(p => {
                const name = p.name.toLowerCase();
                return name.includes('platter') || name.includes('spoon') || name.includes('bowl') || name.includes('serve') || name.includes('brass');
            }).slice(0, 3));

            const diningProducts = withFallback(catalog.filter(p => {
                const name = p.name.toLowerCase();
                return name.includes('plate') || name.includes('glass') || name.includes('cup') || name.includes('dining');
            }).slice(0, 3));

            bundles = [
                {
                    title: "Festive Host Starter",
                    subtitle: platterProducts.length > 0 ? `Premium traditional platters including ${platterProducts[0].name}` : "Premium traditional platters & servers",
                    imageUrl: platterProducts[0]?.image_url || "https://images.unsplash.com/photo-1544025162-d76694265947?auto=format&fit=crop&w=300&q=80",
                    bundleType: "Festive Host",
                    productIds: platterProducts.map(p => p.id)
                },
                {
                    title: "Royal Dining Essentials",
                    subtitle: diningProducts.length > 0 ? `Elegant dinnerware featuring ${diningProducts[0].name}` : "Elegant brass & copper serving styles",
                    imageUrl: diningProducts[0]?.image_url || "https://images.unsplash.com/photo-1510812431401-41d2bd2722f3?auto=format&fit=crop&w=300&q=80",
                    bundleType: "Royal Dining",
                    productIds: diningProducts.map(p => p.id)
                }
            ];
        } else if (type.includes('wedding') || type.includes('engagement') || type.includes('gala')) {
            const cookwareProducts = withFallback(catalog.filter(p => {
                const name = p.name.toLowerCase();
                const cat = (p.category || '').toLowerCase();
                return name.includes('pan') || name.includes('pot') || name.includes('oven') || cat.includes('cook') || name.includes('staub');
            }).slice(0, 3));

            const glassProducts = withFallback(catalog.filter(p => {
                const name = p.name.toLowerCase();
                return name.includes('glass') || name.includes('wine') || name.includes('champagne') || name.includes('dorset');
            }).slice(0, 3));

            bundles = [
                {
                    title: "Grand Kitchen Starter",
                    subtitle: cookwareProducts.length > 0 ? `Luxury cookware featuring ${cookwareProducts[0].name}` : "Luxury enameled cast iron & appliances",
                    imageUrl: cookwareProducts[0]?.image_url || "https://images.unsplash.com/photo-1584269600464-37b1b58a9fe7?auto=format&fit=crop&w=300&q=80",
                    bundleType: "Grand Kitchen",
                    productIds: cookwareProducts.map(p => p.id)
                },
                {
                    title: "Crystal Tabletop",
                    subtitle: glassProducts.length > 0 ? `Schott Zwiesel glass sets with ${glassProducts[0].name}` : "Premium Schott Zwiesel glassware & wine styles",
                    imageUrl: glassProducts[0]?.image_url || "https://images.unsplash.com/photo-1510812431401-41d2bd2722f3?auto=format&fit=crop&w=300&q=80",
                    bundleType: "Crystal Tabletop",
                    productIds: glassProducts.map(p => p.id)
                }
            ];
        } else if (type.includes('housewarming')) {
            const nestProducts = withFallback(catalog.filter(p => {
                const name = p.name.toLowerCase();
                return name.includes('mug') || name.includes('linen') || name.includes('wood') || name.includes('candle') || name.includes('apilco');
            }).slice(0, 3));

            const barProducts = withFallback(catalog.filter(p => {
                const name = p.name.toLowerCase();
                return name.includes('bar') || name.includes('shaker') || name.includes('cocktail') || name.includes('corkscrew') || name.includes('martini');
            }).slice(0, 3));

            bundles = [
                {
                    title: "New Nest Essentials",
                    subtitle: nestProducts.length > 0 ? `Cozy home items featuring ${nestProducts[0].name}` : "Cozy mugs, organic linens & woodware",
                    imageUrl: nestProducts[0]?.image_url || "https://images.unsplash.com/photo-1513694203232-719a280e022f?auto=format&fit=crop&w=300&q=80",
                    bundleType: "New Nest",
                    productIds: nestProducts.map(p => p.id)
                },
                {
                    title: "Premium Barware",
                    subtitle: barProducts.length > 0 ? `Elegant tools with ${barProducts[0].name}` : "Cocktail tools & marble serving boards",
                    imageUrl: barProducts[0]?.image_url || "https://images.unsplash.com/photo-1544025162-d76694265947?auto=format&fit=crop&w=300&q=80",
                    bundleType: "Premium Barware",
                    productIds: barProducts.map(p => p.id)
                }
            ];
        } else {
            // Default Fallback Bundles
            const defaultProducts1 = withFallback(catalog.filter(p => {
                const name = p.name.toLowerCase();
                return name.includes('martini') || name.includes('glass') || name.includes('shaker');
            }).slice(0, 3));
            
            const defaultProducts2 = withFallback(catalog.filter(p => {
                const name = p.name.toLowerCase();
                return name.includes('spoon') || name.includes('dutch') || name.includes('pan');
            }).slice(0, 3));

            bundles = [
                {
                    title: "Professional Mixology",
                    subtitle: defaultProducts1.length > 0 ? `Luxury setup including ${defaultProducts1[0].name}` : "Barware tools, strainers & luxury glassware",
                    imageUrl: defaultProducts1[0]?.image_url || "https://images.unsplash.com/photo-1510812431401-41d2bd2722f3?auto=format&fit=crop&w=300&q=80",
                    bundleType: "Professional Mixology",
                    productIds: defaultProducts1.map(p => p.id)
                },
                {
                    title: "Gourmet Entertaining",
                    subtitle: defaultProducts2.length > 0 ? `Premium boards with ${defaultProducts2[0].name}` : "Cheeseboards, marble platters & markers",
                    imageUrl: defaultProducts2[0]?.image_url || "https://images.unsplash.com/photo-1544025162-d76694265947?auto=format&fit=crop&w=300&q=80",
                    bundleType: "Gourmet Entertaining",
                    productIds: defaultProducts2.map(p => p.id)
                }
            ];
        }

        return res.json(bundles);
    } catch (e) {
        console.error('[GET /registry/starter-bundles]:', e.message);
        return res.status(500).json({ error: e.message });
    }
});

// GET /registry/search?name=Emma
// NOTE: keep this before router.get('/:id', ...) so Express doesn't treat "search" as an id.
router.get('/search', async (req, res) => {
    try {
        const { name } = req.query;
        const q = (name || '').trim();
        if (!q || q.length < 2) {
            return res.status(400).json({ error: 'name query must be at least 2 characters', code: 400 });
        }

        const { data, error } = await supabase
            .from('registries')
            .select('id, user_id, event_type, event_date, event_location, theme, share_token, is_public, budget, created_at')
            .eq('is_public', true)
            .ilike('theme', `%${q}%`)
            .order('created_at', { ascending: false })
            .limit(20);

        if (error) return res.status(500).json({ error: error.message, code: 500 });
        return res.json(data || []);
    } catch (e) {
        console.error('[GET /registry/search]:', e.message);
        return res.status(500).json({ error: e.message, code: 500 });
    }
});

// GET registries for a user
router.get('/user/:userId', async (req, res) => {
    try {
        const { userId } = req.params;
               // 1. Fetch registries where the user is the owner
        const { data: owned, error: ownedErr } = await supabase
            .from('registries')
            .select('*')
            .eq('user_id', userId);
        if (ownedErr) return res.status(500).json({ error: ownedErr.message, code: 500 });

        // 2. Fetch registries where the user is a collaborator (queried by their registered email)
        let collabRegistries = [];
        const { data: userRec, error: userErr } = await supabase
            .from('users')
            .select('email')
            .eq('id', userId)
            .maybeSingle();

        if (!userErr && userRec && userRec.email) {
            const { data: collabs, error: collabErr } = await supabase
                .from('registry_collaborators')
                .select('registry_id')
                .eq('email', userRec.email);
            
            if (!collabErr && collabs && collabs.length > 0) {
                const collabIds = collabs.map(c => c.registry_id);
                const { data: shared, error: sharedErr } = await supabase
                    .from('registries')
                    .select('*')
                    .in('id', collabIds);
                if (!sharedErr && shared) {
                    collabRegistries = shared;
                }
            }
        }

        // 3. Combine both lists (removing duplicates if any)
        const combined = [...(owned || [])];
        const ownedIds = new Set(combined.map(r => r.id));
        for (const r of collabRegistries) {
            if (!ownedIds.has(r.id)) {
                combined.push(r);
            }
        }

        return res.json(combined);
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
            .maybeSingle();
        if (error) return res.status(500).json({ error: error.message, code: 500 });
        if (!registry) return res.status(404).json({ error: 'registry not found', code: 404 });
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
        const { user_id, event_type, event_date, event_location, is_public, address_pre_event, address_post_event, theme, budget } =
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
                    address_post_event,
                    theme,
                    budget: budget || 0
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
        const productId = Number(product_id);
        const quantity = Math.max(0, Number(quantity_requested ?? 1));

        if (!Number.isInteger(productId) || productId <= 0) {
            return res.status(400).json({ error: 'valid product_id is required', code: 400 });
        }

        const { data: product, error: prodErr } = await supabase
            .from('products')
            .select('id, price')
            .eq('id', productId)
            .maybeSingle();
        if (prodErr) return res.status(500).json({ error: prodErr.message, code: 500 });
        if (!product) return res.status(404).json({ error: `product ${productId} not found`, code: 404 });

        // Safe Check: If item already exists, update the quantity requested instead of crashing on unique constraint
        const { data: existing, error: exErr } = await supabase
            .from('registry_items')
            .select('*')
            .eq('registry_id', id)
            .eq('product_id', productId)
            .limit(1)
            .maybeSingle();
        if (exErr) return res.status(500).json({ error: exErr.message, code: 500 });

        if (existing) {
            const newQty = Number(existing.quantity_requested || 0) + quantity;
            const { data: updated, error: updErr } = await supabase
                .from('registry_items')
                .update({
                    quantity_requested: newQty,
                    ai_reason: ai_reason || existing.ai_reason
                })
                .eq('id', existing.id)
                .select()
                .single();
            if (updErr) return res.status(500).json({ error: updErr.message, code: 500 });
            return res.json(updated);
        }

        const { data, error } = await supabase
            .from('registry_items')
            .insert([
                {
                    registry_id: id,
                    product_id: productId,
                    quantity_requested: quantity,
                    is_most_wanted: is_most_wanted || false,
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
        const { id, itemId } = req.params;
        const updates = req.body;

        if (updates.is_most_wanted === true) {
            // Enforce only ONE most wanted item in this registry
            await supabase
                .from('registry_items')
                .update({ is_most_wanted: false })
                .eq('registry_id', id)
                .neq('id', itemId);
        }

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

// PUT update registry
router.put('/:id', async (req, res) => {
    try {
        const { id } = req.params;
        const updates = req.body;
        const { data, error } = await supabase
            .from('registries')
            .update(updates)
            .eq('id', id)
            .select()
            .single();
        if (error) return res.status(500).json({ error: error.message, code: 500 });
        return res.json(data);
    } catch (e) {
        console.error('[PUT /registry/:id]:', e.message);
        return res.status(500).json({ error: e.message, code: 500 });
    }
});

// DELETE registry
router.delete('/:id', async (req, res) => {
    try {
        const { id } = req.params;
        // Delete children first to avoid FK constraint failures when DB doesn't have ON DELETE CASCADE.
        const { data: items, error: itemsErr } = await supabase
            .from('registry_items')
            .select('id')
            .eq('registry_id', id);
        if (itemsErr) return res.status(500).json({ error: itemsErr.message, code: 500 });

        const itemIds = (items || []).map((x) => x.id);
        if (itemIds.length) {
            const { error: contribErr } = await supabase.from('registry_contributions').delete().in('registry_item_id', itemIds);
            if (contribErr) return res.status(500).json({ error: contribErr.message, code: 500 });
        }

        const { error: collabErr } = await supabase.from('registry_collaborators').delete().eq('registry_id', id);
        if (collabErr) return res.status(500).json({ error: collabErr.message, code: 500 });

        const { error: itemsDelErr } = await supabase.from('registry_items').delete().eq('registry_id', id);
        if (itemsDelErr) return res.status(500).json({ error: itemsDelErr.message, code: 500 });

        const { error } = await supabase.from('registries').delete().eq('id', id);
        if (error) return res.status(500).json({ error: error.message, code: 500 });
        return res.json({ success: true });
    } catch (e) {
        console.error('[DELETE /registry/:id]:', e.message);
        return res.status(500).json({ error: e.message, code: 500 });
    }
});

module.exports = router;
