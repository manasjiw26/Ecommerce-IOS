const express = require('express');
const router = express.Router();
const { supabase } = require('../supabaseClient');

// POST /auth/signup
router.post('/signup', async (req, res) => {
    const { name, email, password } = req.body;

    if (!name || !email || !password) {
        return res.status(400).json({ error: 'Name, email and password are required.' });
    }

    const { data, error } = await supabase.auth.signUp({
        email,
        password,
        options: { data: { full_name: name } }
    });

    if (error) {
        if (error.message?.toLowerCase().includes('rate limit') || error.status === 429) {
            return res.status(429).json({ error: 'Too many sign-up attempts. Please go to Supabase Dashboard → Auth → Email Provider → disable "Confirm email", then try again.' });
        }
        return res.status(400).json({ error: error.message });
    }

    // If email confirmation is disabled, session is returned immediately
    if (data.session?.access_token) {
        return res.json({
            user: {
                id: data.user?.id,
                email: data.user?.email,
                name: data.user?.user_metadata?.full_name
            },
            access_token: data.session.access_token
        });
    }

    // Email confirmation required — attempt immediate login anyway
    const { data: loginData, error: loginError } = await supabase.auth.signInWithPassword({ email, password });

    if (!loginError && loginData.session) {
        return res.json({
            user: {
                id: loginData.user?.id,
                email: loginData.user?.email,
                name: loginData.user?.user_metadata?.full_name
            },
            access_token: loginData.session.access_token
        });
    }

    // Account created but confirmation needed
    return res.json({
        user: {
            id: data.user?.id,
            email: data.user?.email,
            name: data.user?.user_metadata?.full_name
        },
        access_token: null,
        message: 'Account created. Please disable email confirmation in Supabase dashboard to log in immediately.'
    });
});

// POST /auth/login
router.post('/login', async (req, res) => {
    const { email, password } = req.body;

    if (!email || !password) {
        return res.status(400).json({ error: 'Email and password are required.' });
    }

    const { data, error } = await supabase.auth.signInWithPassword({ email, password });

    if (error) return res.status(401).json({ error: error.message });

    return res.json({
        user: {
            id: data.user?.id,
            email: data.user?.email,
            name: data.user?.user_metadata?.full_name
        },
        access_token: data.session?.access_token
    });
});

// POST /auth/logout
router.post('/logout', async (req, res) => {
    const { error } = await supabase.auth.signOut();
    if (error) return res.status(500).json({ error: error.message });
    return res.json({ message: 'Logged out successfully.' });
});

module.exports = router;
