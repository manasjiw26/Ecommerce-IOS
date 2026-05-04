require('dotenv').config();
const { createClient } = require('@supabase/supabase-js');
const supabase = createClient(process.env.SUPABASE_URL, process.env.SUPABASE_ANON_KEY);

async function fix() {
    await supabase.from('products').update({ image_url: 'williams_sonoma_apron.png' }).eq('name', 'Williams-Sonoma Classic Apron');
    await supabase.from('products').update({ image_url: 'le_creuset_dutch_oven.png' }).eq('name', 'Le Creuset Dutch Oven');
    await supabase.from('products').update({ image_url: 'wusthof_chef_knife.png' }).eq('name', "Wüsthof Chef's Knife");
    await supabase.from('products').update({ image_url: 'copper_frying_pan.png' }).eq('name', 'Copper Frying Pan');
    await supabase.from('products').update({ image_url: 'kitchenaid_mixer.png' }).eq('name', 'KitchenAid Artisan Stand Mixer');
    console.log("Done fixing old products!");
}
fix();
