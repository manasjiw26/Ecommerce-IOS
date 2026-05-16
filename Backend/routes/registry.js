const express = require('express');
const router = express.Router();
const { supabase } = require('../supabaseClient');

const SUPABASE_STORAGE_URL = 'https://czahuzfliuuhhegynsjr.supabase.co/storage/v1/object/public/Product%20Images';

// GET registries for a user
router.get('/user/:userId', async (req, res) => {
    const { userId } = req.params;
    const { data, error } = await supabase
        .from('registries')
        .select('*')
        .eq('user_id', userId);

    if (error) return res.status(500).json({ error: error.message });
    res.json(data);
});

// GET single registry
router.get('/:id', async (req, res) => {
    const { id } = req.params;
    const { data, error } = await supabase
        .from('registries')
        .select('*')
        .eq('id', id)
        .single();

    if (error) return res.status(500).json({ error: error.message });
    res.json(data);
});

// POST create registry
router.post('/', async (req, res) => {
    const { user_id, event_type, event_date, event_location, is_public, address_pre_event, address_post_event } = req.body;
    
    const { data, error } = await supabase
        .from('registries')
        .insert([{
            user_id, event_type, event_date, event_location, is_public, address_pre_event, address_post_event
        }])
        .select()
        .single();

    if (error) return res.status(500).json({ error: error.message });
    res.json(data);
});

// GET registry items
router.get('/:id/items', async (req, res) => {
    const { id } = req.params;
    const { data, error } = await supabase
        .from('registry_items')
        .select(`
            *,
            products (*)
        `)
        .eq('registry_id', id);

    if (error) return res.status(500).json({ error: error.message });
    
    // Fix image URLs
    const items = data.map(item => {
        if (item.products && item.products.image_url && !item.products.image_url.startsWith('http')) {
            item.products.image_url = `${SUPABASE_STORAGE_URL}/${encodeURIComponent(item.products.image_url)}`;
        }
        return item;
    });

    res.json(items);
});

// POST add item to registry
router.post('/:id/items', async (req, res) => {
    const { id } = req.params;
    const { product_id, quantity_requested, is_most_wanted } = req.body;

    const { data, error } = await supabase
        .from('registry_items')
        .insert([{
            registry_id: id,
            product_id,
            quantity_requested,
            is_most_wanted
        }])
        .select()
        .single();

    if (error) return res.status(500).json({ error: error.message });
    res.json(data);
});

// PUT update item (e.g. quantity received, or most wanted)
router.put('/:id/items/:itemId', async (req, res) => {
    const { itemId } = req.params;
    const updates = req.body;

    const { data, error } = await supabase
        .from('registry_items')
        .update(updates)
        .eq('id', itemId)
        .select()
        .single();

    if (error) return res.status(500).json({ error: error.message });
    res.json(data);
});

// DELETE item from registry
router.delete('/:id/items/:itemId', async (req, res) => {
    const { itemId } = req.params;

    const { error } = await supabase
        .from('registry_items')
        .delete()
        .eq('id', itemId);

    if (error) return res.status(500).json({ error: error.message });
    res.json({ success: true });
});

module.exports = router;
