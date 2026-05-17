// ========== FILE: routes/cart.js ==========
const express = require('express');
const router = express.Router();
const { supabase } = require('../supabaseClient');

const fixImg = (p) => {
    return p;
};

// POST Add item to cart
router.post('/', async (req, res) => {
    try {
        const { user_id, product_id, quantity } = req.body;

        const { data: existingItem, error: fetchError } = await supabase
            .from('cart_items')
            .select('*')
            .eq('user_id', user_id)
            .eq('product_id', product_id)
            .single();

        if (fetchError && fetchError.code !== 'PGRST116') {
            return res.status(500).json({ error: fetchError.message || String(fetchError), code: 500 });
        }

        let result;
        if (existingItem) {
            result = await supabase
                .from('cart_items')
                .update({ quantity: Number(existingItem.quantity || 0) + Number(quantity || 0) })
                .eq('id', existingItem.id)
                .select();
        } else {
            result = await supabase.from('cart_items').insert([{ user_id, product_id, quantity }]).select();
        }

        if (result.error) return res.status(500).json({ error: result.error.message || String(result.error), code: 500 });
        return res.json(result.data || []);
    } catch (e) {
        console.error('[POST /cart]:', e.message);
        return res.status(500).json({ error: e.message, code: 500 });
    }
});

// POST /cart/save-for-later
router.post('/save-for-later', async (req, res) => {
    try {
        const { device_id, product_id } = req.body;
        if (!device_id || !product_id) return res.status(400).json({ error: 'device_id and product_id required', code: 400 });

        const { data, error } = await supabase
            .from('save_for_later')
            .upsert([{ device_id, product_id }], { onConflict: 'device_id,product_id' })
            .select()
            .single();
        if (error) return res.status(500).json({ error: error.message, code: 500 });
        return res.json(data);
    } catch (e) {
        console.error('[POST /cart/save-for-later]:', e.message);
        return res.status(500).json({ error: e.message, code: 500 });
    }
});

// DELETE /cart/save-for-later
router.delete('/save-for-later', async (req, res) => {
    try {
        const { device_id, product_id } = req.body;
        if (!device_id || !product_id) return res.status(400).json({ error: 'device_id and product_id required', code: 400 });

        const { error } = await supabase.from('save_for_later').delete().eq('device_id', device_id).eq('product_id', product_id);
        if (error) return res.status(500).json({ error: error.message, code: 500 });
        return res.json({ success: true });
    } catch (e) {
        console.error('[DELETE /cart/save-for-later]:', e.message);
        return res.status(500).json({ error: e.message, code: 500 });
    }
});

// GET /cart/saved/:deviceId
router.get('/saved/:deviceId', async (req, res) => {
    try {
        const { deviceId } = req.params;
        const { data, error } = await supabase
            .from('save_for_later')
            .select('id, saved_at, products (*)')
            .eq('device_id', deviceId)
            .order('saved_at', { ascending: false });

        if (error) return res.status(500).json({ error: error.message, code: 500 });
        const out = (data || []).map((row) => ({
            id: row.id,
            saved_at: row.saved_at,
            product: row.products ? fixImg(row.products) : null
        }));
        return res.json(out);
    } catch (e) {
        console.error('[GET /cart/saved/:deviceId]:', e.message);
        return res.status(500).json({ error: e.message, code: 500 });
    }
});

// POST /cart/move-to-registry
router.post('/move-to-registry', async (req, res) => {
    try {
        const { device_id, product_id, registry_id, quantity_requested, ai_reason } = req.body;
        if (!device_id || !product_id || !registry_id) {
            return res.status(400).json({ error: 'device_id, product_id, registry_id required', code: 400 });
        }

        const { data: product, error: pErr } = await supabase.from('products').select('id, price').eq('id', product_id).single();
        if (pErr) return res.status(500).json({ error: pErr.message, code: 500 });

        // registry_items has a uniqueness constraint on (registry_id, product_id).
        // Make this endpoint idempotent: if the item already exists, increment quantity_requested.
        const { data: existing, error: exErr } = await supabase
            .from('registry_items')
            .select('id, quantity_requested')
            .eq('registry_id', registry_id)
            .eq('product_id', product_id)
            .maybeSingle();
        if (exErr) return res.status(500).json({ error: exErr.message, code: 500 });

        const deltaQty = Number(quantity_requested ?? 1);
        const nextQty = Number(existing?.quantity_requested || 0) + deltaQty;

        // Use upsert so we never 500 on uniqueness conflicts. If the row exists, we "update" it to nextQty.
        const { data: registryItem, error: upsertErr } = await supabase
            .from('registry_items')
            .upsert(
                [
                    {
                        id: existing?.id,
                        registry_id,
                        product_id,
                        quantity_requested: nextQty,
                        price_snapshot: Number(product?.price || 0),
                        ai_reason: ai_reason || null
                    }
                ],
                { onConflict: 'registry_id,product_id' }
            )
            .select()
            .single();
        if (upsertErr) return res.status(500).json({ error: upsertErr.message, code: 500 });

        await supabase.from('save_for_later').delete().eq('device_id', device_id).eq('product_id', product_id);

        return res.json({ success: true, registry_item: registryItem, already_existed: Boolean(existing?.id) });
    } catch (e) {
        console.error('[POST /cart/move-to-registry]:', e.message);
        return res.status(500).json({ error: e.message, code: 500 });
    }
});

// GET Get user's cart
router.get('/:userId', async (req, res) => {
    try {
        const { userId } = req.params;

        const { data, error } = await supabase
            .from('cart_items')
            .select(`
                id,
                quantity,
                products (*)
            `)
            .eq('user_id', userId);

        if (error) return res.status(500).json({ error: error.message, code: 500 });
        const out = (data || []).map((row) => {
            if (row.products) fixImg(row.products);
            return row;
        });
        return res.json(out);
    } catch (e) {
        console.error('[GET /cart/:userId]:', e.message);
        return res.status(500).json({ error: e.message, code: 500 });
    }
});

// DELETE Remove from cart
router.delete('/:itemId', async (req, res) => {
    try {
        const { itemId } = req.params;

        const { error } = await supabase.from('cart_items').delete().eq('id', itemId);
        if (error) return res.status(500).json({ error: error.message, code: 500 });
        return res.json({ message: 'Item removed from cart' });
    } catch (e) {
        console.error('[DELETE /cart/:itemId]:', e.message);
        return res.status(500).json({ error: e.message, code: 500 });
    }
});

module.exports = router;
