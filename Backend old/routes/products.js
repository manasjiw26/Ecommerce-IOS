const express = require('express');
const router = express.Router();
const { supabase } = require('../supabaseClient');

const SUPABASE_STORAGE_URL = 'https://czahuzfliuuhhegynsjr.supabase.co/storage/v1/object/public/Product%20Images';

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
    
    const productsWithUrls = data.map(product => {
        if (product.image_url && !product.image_url.startsWith('http')) {
            product.image_url = `${SUPABASE_STORAGE_URL}/${encodeURIComponent(product.image_url)}`;
        }
        return product;
    });
    
    res.json(productsWithUrls);
});

// GET single product by id
router.get('/:id', async (req, res) => {
    const { id } = req.params;
    const { data, error } = await supabase.from('products').select('*').eq('id', id).single();
    
    if (error) {
        return res.status(500).json({ error });
    }

    if (data && data.image_url && !data.image_url.startsWith('http')) {
        data.image_url = `${SUPABASE_STORAGE_URL}/${encodeURIComponent(data.image_url)}`;
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

module.exports = router;
