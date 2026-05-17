require('dotenv').config();
const { supabase } = require('./supabaseClient');

async function run() {
    try {
        console.log('Testing RPC exec_sql...');
        const { data, error } = await supabase.rpc('exec_sql', { sql: 'SELECT 1;' });
        if (error) {
            console.log('RPC error:', error);
        } else {
            console.log('RPC success! Result:', data);
        }
    } catch (err) {
        console.error(err);
    }
}
run();
