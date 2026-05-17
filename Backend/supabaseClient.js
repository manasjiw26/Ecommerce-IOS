const { createClient } = require('@supabase/supabase-js');

const supabaseUrl        = process.env.SUPABASE_URL;
const supabaseServiceKey = process.env.SUPABASE_SERVICE_ROLE_KEY;
const supabaseAnonKey    = process.env.SUPABASE_ANON_KEY;

if (!supabaseUrl) {
    throw new Error('❌  SUPABASE_URL is missing from environment variables.');
}

const isServiceKeyValid =
    supabaseServiceKey &&
    supabaseServiceKey !== 'your_service_role_key_here';

if (!isServiceKeyValid) {
    // Hard-fail so the misconfiguration surfaces immediately at startup
    // instead of causing silent RLS violations at runtime.
    throw new Error(
        '❌  SUPABASE_SERVICE_ROLE_KEY is missing or is still the placeholder value.\n' +
        '   Add a valid service role key to your .env file.\n' +
        '   Without it every write to RLS-protected tables (e.g. orders) will fail.'
    );
}

// Service role key bypasses RLS — safe for server-side use only.
// NEVER expose this key to client-side / mobile apps.
const supabase = createClient(supabaseUrl, supabaseServiceKey);

console.log('✅  Supabase: using service role key — RLS bypassed for backend operations.');

module.exports = { supabase };
