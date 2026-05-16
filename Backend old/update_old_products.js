require('dotenv').config();
const { createClient } = require('@supabase/supabase-js');

const supabaseUrl = process.env.SUPABASE_URL;
const supabaseKey = process.env.SUPABASE_SERVICE_ROLE_KEY || process.env.SUPABASE_ANON_KEY;

if (!supabaseUrl || !supabaseKey) {
    console.error('Missing SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY/SUPABASE_ANON_KEY.');
    console.error('Add them to Backend/.env or export them before running this script.');
    process.exit(1);
}

const supabase = createClient(supabaseUrl, supabaseKey);

const productUpdates = [
    {
        image_url: 'gemini_kitchen_1.png',
        name: 'Marble Countertop Kitchen Set',
        description: 'A polished countertop styling set for a refined, modern kitchen.',
        category: 'Decor'
    },
    {
        image_url: 'gemini_kitchen_2.png',
        name: 'Modern Pantry Canister Collection',
        description: 'Coordinated pantry canisters that keep daily essentials organized and display-ready.',
        category: 'Decor'
    },
    {
        image_url: 'gemini_kitchen_3.png',
        name: 'Artisan Tabletop Serveware Set',
        description: 'A warm serveware accent set made for casual entertaining and everyday meals.',
        category: 'Decor'
    },
    {
        image_url: 'andrey_matveev_decor.jpg',
        name: 'Acacia Wood Serving Board',
        description: 'A natural wood serving board for cheese, bread, appetizers, and counter display.',
        category: 'Accessories'
    },
    {
        image_url: 'cooker_king_pan.jpg',
        name: 'Nonstick Everyday Fry Pan',
        description: 'A durable nonstick fry pan designed for eggs, sauteed vegetables, and weeknight cooking.',
        category: 'Cookware'
    },
    {
        image_url: 'cooker_king_pot.jpg',
        name: 'Stainless Steel Stock Pot',
        description: 'A roomy stainless steel pot for pasta, soups, stocks, and batch cooking.',
        category: 'Cookware'
    },
    {
        image_url: 'golden_bridge_item.jpg',
        name: 'Gold Finish Bottle Opener',
        description: 'A polished gold-tone bar accessory that adds a premium touch to entertaining.',
        category: 'Accessories'
    },
    {
        image_url: 'jason_briscoe_kitchen.jpg',
        name: 'Beechwood Utensil Set',
        description: 'Essential wooden prep tools that are gentle on cookware and beautiful on the counter.',
        category: 'Tools'
    },
    {
        image_url: 'jota_sa_tool.jpg',
        name: 'Stainless Steel Prep Tongs',
        description: 'Professional-grade kitchen tongs for turning, tossing, plating, and serving.',
        category: 'Tools'
    },
    {
        image_url: 'lidye_accessories.jpg',
        name: 'Linen Napkin & Ring Set',
        description: 'A refined table-setting accent for dinners, brunches, and special occasions.',
        category: 'Dining'
    },
    {
        image_url: 'luke_peterson_decor.jpg',
        name: 'Minimal Ceramic Vase',
        description: 'A clean ceramic accent piece for shelves, islands, consoles, and dining tables.',
        category: 'Decor'
    },
    {
        image_url: 'mario_raj_item.jpg',
        name: 'Cotton Kitchen Towel Set',
        description: 'Soft, absorbent cotton towels for drying hands, dishes, and prep surfaces.',
        category: 'Essentials'
    },
    {
        image_url: 'mockup_kitchen.jpg',
        name: 'White Stoneware Dinner Set',
        description: 'Simple stoneware pieces with a clean profile for everyday dining.',
        category: 'Dining'
    },
    {
        image_url: 'noonbrew_coffee_maker.jpg',
        name: 'Glass Pour-Over Coffee Maker',
        description: 'A cafe-inspired pour-over setup for slow mornings and precise coffee brewing.',
        category: 'Appliances'
    },
    {
        image_url: 'odiseo_tool.jpg',
        name: 'Chef Prep Peeler',
        description: 'A compact prep tool for peeling vegetables, citrus, and delicate garnishes.',
        category: 'Tools'
    },
    {
        image_url: 'olga_kovalski_kitchen.jpg',
        name: 'Olive Wood Salt Cellar',
        description: 'A countertop salt cellar that keeps finishing salt close while adding natural texture.',
        category: 'Accessories'
    },
    {
        image_url: 'prateek_item.jpg',
        name: 'Silicone Spatula Set',
        description: 'Flexible heat-resistant spatulas for mixing, folding, scraping, and sauteing.',
        category: 'Tools'
    },
    {
        image_url: 'rayia_soderberg_1.jpg',
        name: 'Scandinavian Stoneware Platter',
        description: 'A low-profile stoneware platter for family-style serving and layered table settings.',
        category: 'Dining'
    },
    {
        image_url: 'rayia_soderberg_2.jpg',
        name: 'Scandinavian Serve Bowl',
        description: 'A minimalist serving bowl with soft Nordic styling for salads, fruit, and sides.',
        category: 'Dining'
    },
    {
        image_url: 'savernake_knives.jpg',
        name: 'Savernake Professional Knife',
        description: 'A precision kitchen knife for confident slicing, chopping, and prep work.',
        category: 'Cutlery'
    },
    {
        image_url: 'cooking_set_pots_pans.jpg',
        name: 'Complete Stainless Cookware Set',
        description: 'A complete pots and pans collection for searing, simmering, boiling, and sauteing.',
        category: 'Cookware'
    },
    {
        image_url: 'tamara_harhai_decor.jpg',
        name: 'Decorative Fruit Bowl Centerpiece',
        description: 'A sculptural centerpiece for kitchen islands, dining tables, and open shelving.',
        category: 'Decor'
    }
];

async function updateProducts() {
    for (const product of productUpdates) {
        const { image_url, ...fields } = product;
        const { error } = await supabase
            .from('products')
            .update(fields)
            .or(`image_url.eq.${image_url},image_url.ilike.%${image_url}`);

        if (error) {
            console.error(`Failed to update ${image_url}:`, error.message);
            process.exitCode = 1;
        } else {
            console.log(`Updated ${image_url} -> ${fields.name}`);
        }
    }
}

updateProducts();
