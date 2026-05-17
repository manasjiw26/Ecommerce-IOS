const express = require('express');
const router = express.Router();
const { supabase } = require('../supabaseClient');

// GET all products
router.get('/', async (req, res) => {
    const { category } = req.query;
    let query = supabase.from('products').select('*');
    
    if (category) {
        query = query.eq('category', category);
    }
    
    const { data, error } = await query;
    
    if (error) {
        return res.status(500).json({ error });
    }
    
    res.json(data || []);
});

// GET single product by id
router.get('/:id', async (req, res) => {
    const { id } = req.params;
    const { data, error } = await supabase.from('products').select('*').eq('id', id).single();
    
    if (error) {
        return res.status(500).json({ error });
    }

    res.json(data);
});

// GET /products/:id/stock — Get current stock for a product
router.get('/:id/stock', async (req, res) => {
    const { id } = req.params;
    const { data, error } = await supabase
        .from('products')
        .select('id, stock')
        .eq('id', id)
        .single();

    if (error) return res.status(500).json({ error: error.message });
    res.json({ id: data.id, stock: data.stock ?? 0 });
});

// GET /products/:id/reviews — Get all reviews for a specific product
router.get('/:id/reviews', async (req, res) => {
    const { id } = req.params;
    const { data, error } = await supabase
        .from('reviews')
        .select('*')
        .eq('product_id', parseInt(id))
        .order('created_at', { ascending: false });

    if (error) {
        return res.status(500).json({ error: error.message });
    }

    res.json(data || []);
});

module.exports = router;
