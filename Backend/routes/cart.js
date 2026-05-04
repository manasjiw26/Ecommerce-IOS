const express = require('express');
const router = express.Router();
const { supabase } = require('../supabaseClient');

// POST Add item to cart
router.post('/', async (req, res) => {
    const { user_id, product_id, quantity } = req.body;
    
    // First check if item already exists in cart
    const { data: existingItem, error: fetchError } = await supabase
        .from('cart_items')
        .select('*')
        .eq('user_id', user_id)
        .eq('product_id', product_id)
        .single();
        
    if (fetchError && fetchError.code !== 'PGRST116') { // PGRST116 is not found
        return res.status(500).json({ error: fetchError });
    }
    
    let result;
    if (existingItem) {
        // Update quantity
        result = await supabase
            .from('cart_items')
            .update({ quantity: existingItem.quantity + quantity })
            .eq('id', existingItem.id)
            .select();
    } else {
        // Insert new item
        result = await supabase
            .from('cart_items')
            .insert([{ user_id, product_id, quantity }])
            .select();
    }
    
    if (result.error) {
        return res.status(500).json({ error: result.error });
    }
    
    res.json(result.data);
});

// GET Get user's cart
router.get('/:userId', async (req, res) => {
    const { userId } = req.params;
    
    const { data, error } = await supabase
        .from('cart_items')
        .select(`
            id,
            quantity,
            products (*)
        `)
        .eq('user_id', userId);
        
    if (error) {
        return res.status(500).json({ error });
    }
    res.json(data);
});

// DELETE Remove from cart
router.delete('/:itemId', async (req, res) => {
    const { itemId } = req.params;
    
    const { data, error } = await supabase
        .from('cart_items')
        .delete()
        .eq('id', itemId);
        
    if (error) {
        return res.status(500).json({ error });
    }
    res.json({ message: 'Item removed from cart' });
});

module.exports = router;
