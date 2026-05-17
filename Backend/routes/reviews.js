const express = require('express');
const router = express.Router();
const { supabase } = require('../supabaseClient');

// GET reviews (filter by product_id)
router.get('/', async (req, res) => {
    const { product_id } = req.query;
    if (!product_id) {
        return res.status(400).json({ error: 'product_id query parameter is required' });
    }
    
    const { data, error } = await supabase
        .from('reviews')
        .select('*')
        .eq('product_id', parseInt(product_id))
        .order('created_at', { ascending: false });
        
    if (error) {
        return res.status(500).json({ error: error.message });
    }
    
    res.json(data || []);
});

// POST a new review
router.post('/', async (req, res) => {
    const { product_id, user_id, rating, body } = req.body;
    
    if (!product_id || !user_id || rating === undefined) {
        return res.status(400).json({ error: 'Missing required fields: product_id, user_id, rating' });
    }
    
    const parsedRating = parseInt(rating);
    if (isNaN(parsedRating) || parsedRating < 1 || parsedRating > 5) {
        return res.status(400).json({ error: 'Rating must be an integer between 1 and 5' });
    }
    
    // Server-side sanitization of username/ID (trim, lowercase, space to underscore replacement)
    const sanitizedUserId = user_id.trim().replace(/\s+/g, '_').toLowerCase();
    
    try {
        // Enforce maximum one review per user per product to prevent spamming
        const { data: existing, error: checkError } = await supabase
            .from('reviews')
            .select('id')
            .eq('product_id', parseInt(product_id))
            .eq('user_id', sanitizedUserId);
            
        if (checkError) {
            return res.status(500).json({ error: checkError.message });
        }
        
        if (existing && existing.length > 0) {
            return res.status(400).json({ error: 'You have already submitted a review for this product.' });
        }
        
        // Sanitize review body text and limit length to 1000 characters
        let sanitizedBody = null;
        if (body) {
            sanitizedBody = body.trim();
            if (sanitizedBody.length > 1000) {
                sanitizedBody = sanitizedBody.substring(0, 1000);
            }
        }
        
        const { data, error } = await supabase
            .from('reviews')
            .insert([
                {
                    product_id: parseInt(product_id),
                    user_id: sanitizedUserId,
                    rating: parsedRating,
                    body: sanitizedBody,
                    created_at: new Date().toISOString()
                }
            ])
            .select()
            .single();
            
        if (error) {
            return res.status(500).json({ error: error.message });
        }
        
        res.status(201).json(data);
    } catch (err) {
        res.status(500).json({ error: err.message });
    }
});

// GET average rating & total reviews count for a product
router.get('/average/:productId', async (req, res) => {
    const { productId } = req.params;
    
    const { data, error } = await supabase
        .from('reviews')
        .select('rating')
        .eq('product_id', parseInt(productId));
        
    if (error) {
        return res.status(500).json({ error: error.message });
    }
    
    if (!data || data.length === 0) {
        return res.json({ averageRating: 0, totalReviews: 0 });
    }
    
    const sum = data.reduce((acc, curr) => acc + (curr.rating || 0), 0);
    const average = sum / data.length;
    
    res.json({
        averageRating: parseFloat(average.toFixed(1)),
        totalReviews: data.length
    });
});

// DELETE a review by id
router.delete('/:id', async (req, res) => {
    const { id } = req.params;
    const { error } = await supabase
        .from('reviews')
        .delete()
        .eq('id', id);
        
    if (error) {
        return res.status(500).json({ error: error.message });
    }
    
    res.json({ success: true, message: 'Review successfully deleted' });
});

module.exports = router;
