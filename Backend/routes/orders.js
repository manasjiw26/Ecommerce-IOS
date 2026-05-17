const express = require('express');
const router = express.Router();
const { supabase } = require('../supabaseClient');

// POST /orders — Verify stock, place order, deduct stock
router.post('/', async (req, res) => {
    const { user_id, total, items_summary, image_url, payment_id, cart_items } = req.body;

    if (!user_id || !total) {
        return res.status(400).json({ error: 'user_id and total are required.' });
    }

    // 1. Verify stock for each cart item
    if (cart_items && cart_items.length > 0) {
        for (const item of cart_items) {
            const { data: product, error } = await supabase
                .from('products')
                .select('id, name, stock')
                .eq('id', item.product_id)
                .single();

            if (error || !product) {
                return res.status(404).json({ error: `Product ${item.product_id} not found.` });
            }

            if ((product.stock ?? 0) < item.quantity) {
                return res.status(400).json({
                    error: `"${product.name}" is out of stock. Only ${product.stock} left.`,
                    product_id: item.product_id
                });
            }
        }

        // 2. Deduct stock for each item
        for (const item of cart_items) {
            const { data: product } = await supabase
                .from('products')
                .select('stock')
                .eq('id', item.product_id)
                .single();

            await supabase
                .from('products')
                .update({ stock: (product?.stock ?? 0) - item.quantity })
                .eq('id', item.product_id);
        }
    }

    // 3. Insert order
    const { data: orderData, error: orderError } = await supabase
        .from('orders')
        .insert([{
            user_id,
            total,
            status: 'Processing',
            items_summary: items_summary || '',
            image_url: image_url || '',
            payment_id: payment_id || ''
        }])
        .select()
        .single();

    if (orderError) {
        return res.status(500).json({ error: orderError.message });
    }

    // 4. Clear user's backend cart (best-effort) so cart UI reflects checkout completion
    try {
        await supabase.from('cart_items').delete().eq('user_id', user_id);
    } catch (_) {}

    res.json({ message: 'Order placed successfully', order: orderData });
});

// GET /orders/:userId — Fetch user's order history
router.get('/:userId', async (req, res) => {
    const { userId } = req.params;

    const { data, error } = await supabase
        .from('orders')
        .select('*')
        .eq('user_id', userId)
        .order('created_at', { ascending: false });

    if (error) {
        return res.status(500).json({ error: error.message });
    }

    res.json(data);
});

module.exports = router;
