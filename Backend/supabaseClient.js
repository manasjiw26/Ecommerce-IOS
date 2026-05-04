const { createClient } = require('@supabase/supabase-js');

const supabaseUrl = process.env.SUPABASE_URL;
const supabaseServiceKey = process.env.SUPABASE_SERVICE_ROLE_KEY;
const supabaseAnonKey = process.env.SUPABASE_ANON_KEY;

if (!supabaseUrl || (!supabaseServiceKey && !supabaseAnonKey)) {
    console.warn('Missing SUPABASE_URL or key environment variables');
}

// Use service role key on the backend to bypass RLS safely
// NEVER expose this key to client-side apps
const key = supabaseServiceKey && supabaseServiceKey !== 'your_service_role_key_here'
    ? supabaseServiceKey
    : supabaseAnonKey;

if (key === supabaseAnonKey) {
    console.warn('⚠️  Using anon key — RLS will block reads. Add SUPABASE_SERVICE_ROLE_KEY to .env');
} else {
    console.log('✅  Using service role key — RLS bypassed for backend operations');
}

const supabase = createClient(supabaseUrl, key);

module.exports = { supabase };
