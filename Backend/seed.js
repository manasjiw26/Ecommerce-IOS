require('dotenv').config();
const { createClient } = require('@supabase/supabase-js');

const supabase = createClient(process.env.SUPABASE_URL, process.env.SUPABASE_SERVICE_ROLE_KEY);

async function checkAndSeed() {
    console.log("Checking products...");
    let { data, error } = await supabase.from('products').select('*');
    if (error) {
        console.error("Error fetching products:", error);
        return;
    }
    
    const existingNames = new Set(data ? data.map(p => p.name) : []);
    const allProducts = [
            {
                name: 'Williams-Sonoma Classic Apron',
                price: 29.95,
                description: 'Our classic cooking apron made from durable cotton.',
                image_url: 'williams_sonoma_apron.png',
                category: 'Kitchen Linens',
                stock: 50
            },
            {
                name: 'Le Creuset Dutch Oven',
                price: 350.00,
                description: 'Signature cast iron dutch oven, perfect for slow cooking.',
                image_url: 'le_creuset_dutch_oven.png',
                category: 'Cookware',
                stock: 25
            },
            {
                name: 'KitchenAid Artisan Stand Mixer',
                price: 449.99,
                description: 'Iconic stand mixer for all your baking needs.',
                image_url: 'kitchenaid_mixer.png',
                category: 'Appliances',
                stock: 15
            },
            {
                name: 'Wüsthof Classic 8-Inch Chef\'s Knife',
                price: 170.00,
                description: 'Precision-forged, high-carbon stainless steel knife.',
                image_url: 'wusthof_chef_knife.png',
                category: 'Cutlery',
                stock: 40
            },
            {
                name: 'Copper Frying Pan',
                price: 199.50,
                description: 'Professional grade copper frying pan with stainless steel interior.',
                image_url: 'copper_frying_pan.png',
                category: 'Cookware',
                stock: 20
            }
        ,
            {
                name: 'Marble Countertop Kitchen Set',
                price: 49.99,
                description: 'A polished countertop styling set for a refined, modern kitchen.',
                image_url: 'gemini_kitchen_1.png',
                category: 'Decor',
                stock: 100
            },
            {
                name: 'Modern Pantry Canister Collection',
                price: 59.99,
                description: 'Coordinated pantry canisters that keep daily essentials organized and display-ready.',
                image_url: 'gemini_kitchen_2.png',
                category: 'Decor',
                stock: 100
            },
            {
                name: 'Artisan Tabletop Serveware Set',
                price: 39.99,
                description: 'A warm serveware accent set made for casual entertaining and everyday meals.',
                image_url: 'gemini_kitchen_3.png',
                category: 'Decor',
                stock: 100
            },
            {
                name: 'Acacia Wood Serving Board',
                price: 24.99,
                description: 'A natural wood serving board for cheese, bread, appetizers, and counter display.',
                image_url: 'andrey_matveev_decor.jpg',
                category: 'Accessories',
                stock: 100
            },
            {
                name: 'Nonstick Everyday Fry Pan',
                price: 89.99,
                description: 'A durable nonstick fry pan designed for eggs, sauteed vegetables, and weeknight cooking.',
                image_url: 'cooker_king_pan.jpg',
                category: 'Cookware',
                stock: 100
            },
            {
                name: 'Stainless Steel Stock Pot',
                price: 110,
                description: 'A roomy stainless steel pot for pasta, soups, stocks, and batch cooking.',
                image_url: 'cooker_king_pot.jpg',
                category: 'Cookware',
                stock: 100
            },
            {
                name: 'Gold Finish Bottle Opener',
                price: 15.99,
                description: 'A polished gold-tone bar accessory that adds a premium touch to entertaining.',
                image_url: 'golden_bridge_item.jpg',
                category: 'Accessories',
                stock: 100
            },
            {
                name: 'Beechwood Utensil Set',
                price: 34.5,
                description: 'Essential wooden prep tools that are gentle on cookware and beautiful on the counter.',
                image_url: 'jason_briscoe_kitchen.jpg',
                category: 'Tools',
                stock: 100
            },
            {
                name: 'Stainless Steel Prep Tongs',
                price: 45,
                description: 'Professional-grade kitchen tongs for turning, tossing, plating, and serving.',
                image_url: 'jota_sa_tool.jpg',
                category: 'Tools',
                stock: 100
            },
            {
                name: 'Linen Napkin & Ring Set',
                price: 28,
                description: 'A refined table-setting accent for dinners, brunches, and special occasions.',
                image_url: 'lidye_accessories.jpg',
                category: 'Dining',
                stock: 100
            },
            {
                name: 'Minimal Ceramic Vase',
                price: 65,
                description: 'A clean ceramic accent piece for shelves, islands, consoles, and dining tables.',
                image_url: 'luke_peterson_decor.jpg',
                category: 'Decor',
                stock: 100
            },
            {
                name: 'Cotton Kitchen Towel Set',
                price: 19.99,
                description: 'Soft, absorbent cotton towels for drying hands, dishes, and prep surfaces.',
                image_url: 'mario_raj_item.jpg',
                category: 'Essentials',
                stock: 100
            },
            {
                name: 'Artisan Ceramic Bowl',
                price: 42,
                description: 'High-quality artisan ceramic bowl perfect for your home.',
                image_url: 'meghna_r_bowl.jpg',
                category: 'Dining',
                stock: 100
            },
            {
                name: 'White Stoneware Dinner Set',
                price: 22,
                description: 'Simple stoneware pieces with a clean profile for everyday dining.',
                image_url: 'mockup_kitchen.jpg',
                category: 'Dining',
                stock: 100
            },
            {
                name: 'Glass Pour-Over Coffee Maker',
                price: 120,
                description: 'A cafe-inspired pour-over setup for slow mornings and precise coffee brewing.',
                image_url: 'noonbrew_coffee_maker.jpg',
                category: 'Appliances',
                stock: 100
            },
            {
                name: 'Chef Prep Peeler',
                price: 33,
                description: 'A compact prep tool for peeling vegetables, citrus, and delicate garnishes.',
                image_url: 'odiseo_tool.jpg',
                category: 'Tools',
                stock: 100
            },
            {
                name: 'Olive Wood Salt Cellar',
                price: 27.5,
                description: 'A countertop salt cellar that keeps finishing salt close while adding natural texture.',
                image_url: 'olga_kovalski_kitchen.jpg',
                category: 'Accessories',
                stock: 100
            },
            {
                name: 'Silicone Spatula Set',
                price: 38,
                description: 'Flexible heat-resistant spatulas for mixing, folding, scraping, and sauteing.',
                image_url: 'prateek_item.jpg',
                category: 'Tools',
                stock: 100
            },
            {
                name: 'Scandinavian Serve Bowl',
                price: 55,
                description: 'A minimalist serving bowl with soft Nordic styling for salads, fruit, and sides.',
                image_url: 'rayia_soderberg_2.jpg',
                category: 'Dining',
                stock: 100
            },
            {
                name: 'Scandinavian Stoneware Platter',
                price: 55,
                description: 'A low-profile stoneware platter for family-style serving and layered table settings.',
                image_url: 'rayia_soderberg_1.jpg',
                category: 'Dining',
                stock: 100
            },
            {
                name: 'Savernake Professional Knife',
                price: 250,
                description: 'High-quality savernake professional knife perfect for your home.',
                image_url: 'savernake_knives.jpg',
                category: 'Cutlery',
                stock: 100
            },
            {
                name: 'Complete Stainless Cookware Set',
                price: 499.99,
                description: 'A complete pots and pans collection for searing, simmering, boiling, and sauteing.',
                image_url: 'cooking_set_pots_pans.jpg',
                category: 'Cookware',
                stock: 100
            },
            {
                name: 'Decorative Fruit Bowl Centerpiece',
                price: 85,
                description: 'A sculptural centerpiece for kitchen islands, dining tables, and open shelving.',
                image_url: 'tamara_harhai_decor.jpg',
                category: 'Decor',
                stock: 100
            },
            {
                name: 'Heritage Enamel Dutch Oven',
                price: 329.95,
                description: 'A premium enameled Dutch oven for braising, baking, roasting, and slow simmering.',
                image_url: 'https://images.pexels.com/photos/30981355/pexels-photo-30981355.jpeg?auto=compress&cs=tinysrgb&w=900',
                category: 'Cookware',
                stock: 18
            },
            {
                name: 'Copper Core Saute Pan',
                price: 219.95,
                description: 'A polished saute pan with responsive heat control for sauces, searing, and delicate reductions.',
                image_url: 'https://images.pexels.com/photos/17542995/pexels-photo-17542995.jpeg?auto=compress&cs=tinysrgb&w=900',
                category: 'Cookware',
                stock: 22
            },
            {
                name: 'Olivewood Prep Board',
                price: 74.95,
                description: 'A richly grained serving and prep board that moves beautifully from counter to table.',
                image_url: 'https://images.pexels.com/photos/3847514/pexels-photo-3847514.jpeg?auto=compress&cs=tinysrgb&w=900',
                category: 'Accessories',
                stock: 36
            },
            {
                name: 'Professional Knife Block Set',
                price: 299.95,
                description: 'A balanced cutlery set with essential blades for everyday prep and confident entertaining.',
                image_url: 'https://images.pexels.com/photos/8175345/pexels-photo-8175345.jpeg?auto=compress&cs=tinysrgb&w=900',
                category: 'Cutlery',
                stock: 14
            },
            {
                name: 'Marble Salt & Spice Cellars',
                price: 49.95,
                description: 'Weighted marble cellars for finishing salts, spices, and countertop mise en place.',
                image_url: 'https://images.pexels.com/photos/8176603/pexels-photo-8176603.jpeg?auto=compress&cs=tinysrgb&w=900',
                category: 'Accessories',
                stock: 40
            },
            {
                name: 'Artisan Stoneware Dinnerware',
                price: 149.95,
                description: 'Layered stoneware place settings with organic edges and a restaurant-quality feel.',
                image_url: 'https://images.pexels.com/photos/8176590/pexels-photo-8176590.jpeg?auto=compress&cs=tinysrgb&w=900',
                category: 'Dining',
                stock: 28
            },
            {
                name: 'French Press Coffee Set',
                price: 89.95,
                description: 'A glass-and-steel coffee service set designed for rich brews and slow weekend mornings.',
                image_url: 'https://images.pexels.com/photos/11885824/pexels-photo-11885824.jpeg?auto=compress&cs=tinysrgb&w=900',
                category: 'Appliances',
                stock: 24
            },
            {
                name: 'Brushed Steel Mixing Bowls',
                price: 64.95,
                description: 'Nested stainless steel bowls for baking prep, salad tossing, marinades, and storage.',
                image_url: 'https://images.pexels.com/photos/15852126/pexels-photo-15852126.jpeg?auto=compress&cs=tinysrgb&w=900',
                category: 'Bakeware',
                stock: 32
            },
            {
                name: 'Linen Table Runner Collection',
                price: 69.95,
                description: 'Washed linen table textiles that bring a soft, tailored finish to everyday dining.',
                image_url: 'https://images.pexels.com/photos/15569110/pexels-photo-15569110.jpeg?auto=compress&cs=tinysrgb&w=900',
                category: 'Kitchen Linens',
                stock: 30
            },
            {
                name: 'Walnut Utensil Crock Set',
                price: 54.95,
                description: 'Countertop-ready wooden tools and a matching crock for an organized, chef-inspired station.',
                image_url: 'https://images.pexels.com/photos/3432605/pexels-photo-3432605.jpeg?auto=compress&cs=tinysrgb&w=900',
                category: 'Tools',
                stock: 34
            }
    ];

    const productsToInsert = allProducts.filter(p => !existingNames.has(p.name));

    if (productsToInsert.length > 0) {
        console.log(`Found ${productsToInsert.length} new products to insert. Seeding database...`);
        const { data: insertData, error: insertError } = await supabase.from('products').insert(productsToInsert).select();
        
        if (insertError) {
            console.error("Insert failed! This usually means RLS is enabled and blocking it:", insertError);
        } else {
            console.log(`Successfully seeded ${insertData.length} new products.`);
        }
    } else {
        console.log("No new products to insert. Database is up to date!");
    }
}

checkAndSeed();
