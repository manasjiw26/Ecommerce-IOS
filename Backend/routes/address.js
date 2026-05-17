const express = require('express');
const router = express.Router();
const { supabase } = require('../supabaseClient');

// GET /users/address?device_id=...
router.get('/address', async (req, res) => {
    try {
        const device_id = String(req.query.device_id || '').trim();
        if (!device_id) {
            return res.status(400).json({ error: 'device_id required' });
        }

        const addressKey = `address:${device_id}`;
        const { data, error } = await supabase
            .from('user_style_profiles')
            .select('*')
            .eq('device_id', addressKey)
            .maybeSingle();

        if (error) throw error;

        if (!data) {
            return res.json({ address: null });
        }

        try {
            const address = JSON.parse(data.style_description);
            return res.json({ address });
        } catch (parseErr) {
            return res.json({ address: null });
        }
    } catch (e) {
        console.error('[GET /users/address]:', e.message);
        return res.status(500).json({ error: e.message });
    }
});

// POST /users/address
router.post('/address', async (req, res) => {
    try {
        const { device_id, address } = req.body || {};
        if (!device_id) {
            return res.status(400).json({ error: 'device_id required' });
        }
        if (!address) {
            return res.status(400).json({ error: 'address required' });
        }

        const addressKey = `address:${device_id}`;
        const upsertPayload = {
            device_id: addressKey,
            style_name: 'user_address',
            style_description: JSON.stringify(address),
            price_tier: 'mid',
            generated_at: new Date().toISOString()
        };

        const { data, error } = await supabase
            .from('user_style_profiles')
            .upsert([upsertPayload], { onConflict: 'device_id' })
            .select()
            .single();

        if (error) throw error;

        return res.json({ success: true, data });
    } catch (e) {
        console.error('[POST /users/address]:', e.message);
        return res.status(500).json({ error: e.message });
    }
});

module.exports = router;
