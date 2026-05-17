const { createClient } = require('@supabase/supabase-js');

const supabaseUrl = process.env.SUPABASE_URL;
const supabaseAnonKey = process.env.SUPABASE_ANON_KEY;
const supabaseServiceKey = process.env.SUPABASE_SERVICE_ROLE_KEY;

// Create a global client using service role key to perform verification
const globalSupabase = createClient(supabaseUrl, supabaseServiceKey);

async function authenticateToken(req, res, next) {
    const authHeader = req.headers['authorization'];
    const token = authHeader && authHeader.split(' ')[1];

    if (!token) {
        // Fallback for public/guest routes: use anon client
        req.supabase = createClient(supabaseUrl, supabaseAnonKey);
        req.user = null;
        return next();
    }

    try {
        const { data: { user }, error } = await globalSupabase.auth.getUser(token);
        
        if (error || !user) {
            return res.status(401).json({ error: 'Unauthorized: Invalid token', code: 401 });
        }

        req.user = user;
        // Instantiate a client scoped to this user
        req.supabase = createClient(supabaseUrl, supabaseAnonKey, {
            global: {
                headers: {
                    Authorization: `Bearer ${token}`
                }
            }
        });
        next();
    } catch (e) {
        console.error('Auth middleware error:', e.message);
        return res.status(500).json({ error: 'Internal server error during auth verification', code: 500 });
    }
}

// Strict version for routes that MUST be authenticated
async function requireAuth(req, res, next) {
    authenticateToken(req, res, () => {
        if (!req.user) {
            return res.status(401).json({ error: 'Unauthorized: Authentication required', code: 401 });
        }
        next();
    });
}

module.exports = {
    authenticateToken,
    requireAuth
};
