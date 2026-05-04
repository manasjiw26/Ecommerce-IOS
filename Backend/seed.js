require('dotenv').config();
const { createClient } = require('@supabase/supabase-js');

const supabase = createClient(process.env.SUPABASE_URL, process.env.SUPABASE_ANON_KEY);

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
                name: 'Kitchen Decor Set 1',
                price: 49.99,
                description: 'High-quality kitchen decor set 1 perfect for your home.',
                image_url: 'gemini_kitchen_1.png',
                category: 'Decor',
                stock: 100
            },
            {
                name: 'Kitchen Decor Set 2',
                price: 59.99,
                description: 'High-quality kitchen decor set 2 perfect for your home.',
                image_url: 'gemini_kitchen_2.png',
                category: 'Decor',
                stock: 100
            },
            {
                name: 'Kitchen Decor Set 3',
                price: 39.99,
                description: 'High-quality kitchen decor set 3 perfect for your home.',
                image_url: 'gemini_kitchen_3.png',
                category: 'Decor',
                stock: 100
            },
            {
                name: 'Modern Kitchen Accessory',
                price: 24.99,
                description: 'High-quality modern kitchen accessory perfect for your home.',
                image_url: 'andrey_matveev_decor.jpg',
                category: 'Accessories',
                stock: 100
            },
            {
                name: 'Cooker King Frying Pan',
                price: 89.99,
                description: 'High-quality cooker king frying pan perfect for your home.',
                image_url: 'cooker_king_pan.jpg',
                category: 'Cookware',
                stock: 100
            },
            {
                name: 'Cooker King Stock Pot',
                price: 110,
                description: 'High-quality cooker king stock pot perfect for your home.',
                image_url: 'cooker_king_pot.jpg',
                category: 'Cookware',
                stock: 100
            },
            {
                name: 'Golden Horn Special Item',
                price: 15.99,
                description: 'High-quality golden horn special item perfect for your home.',
                image_url: 'golden_bridge_item.jpg',
                category: 'Accessories',
                stock: 100
            },
            {
                name: 'Designer Kitchen Tool',
                price: 34.5,
                description: 'High-quality designer kitchen tool perfect for your home.',
                image_url: 'jason_briscoe_kitchen.jpg',
                category: 'Tools',
                stock: 100
            },
            {
                name: 'Professional Kitchen Tool',
                price: 45,
                description: 'High-quality professional kitchen tool perfect for your home.',
                image_url: 'jota_sa_tool.jpg',
                category: 'Tools',
                stock: 100
            },
            {
                name: 'Elegant Dining Accessory',
                price: 28,
                description: 'High-quality elegant dining accessory perfect for your home.',
                image_url: 'lidye_accessories.jpg',
                category: 'Dining',
                stock: 100
            },
            {
                name: 'Minimalist Kitchen Decor',
                price: 65,
                description: 'High-quality minimalist kitchen decor perfect for your home.',
                image_url: 'luke_peterson_decor.jpg',
                category: 'Decor',
                stock: 100
            },
            {
                name: 'Classic Kitchen Essential',
                price: 19.99,
                description: 'High-quality classic kitchen essential perfect for your home.',
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
                name: 'Premium Mockup Set',
                price: 22,
                description: 'High-quality premium mockup set perfect for your home.',
                image_url: 'mockup_kitchen.jpg',
                category: 'Decor',
                stock: 100
            },
            {
                name: 'Noonbrew Coffee Set',
                price: 120,
                description: 'High-quality noonbrew coffee set perfect for your home.',
                image_url: 'noonbrew_coffee_maker.jpg',
                category: 'Appliances',
                stock: 100
            },
            {
                name: "Chef's Secret Tool",
                price: 33,
                description: "High-quality chef's secret tool perfect for your home.",
                image_url: 'odiseo_tool.jpg',
                category: 'Tools',
                stock: 100
            },
            {
                name: 'Gourmet Kitchen Accessory',
                price: 27.5,
                description: 'High-quality gourmet kitchen accessory perfect for your home.',
                image_url: 'olga_kovalski_kitchen.jpg',
                category: 'Accessories',
                stock: 100
            },
            {
                name: 'Modern Prep Tool',
                price: 38,
                description: 'High-quality modern prep tool perfect for your home.',
                image_url: 'prateek_item.jpg',
                category: 'Tools',
                stock: 100
            },
            {
                name: 'Nordic Kitchen Item 2',
                price: 55,
                description: 'High-quality nordic kitchen item 2 perfect for your home.',
                image_url: 'rayia_soderberg_2.jpg',
                category: 'Decor',
                stock: 100
            },
            {
                name: 'Nordic Kitchen Item 1',
                price: 55,
                description: 'High-quality nordic kitchen item 1 perfect for your home.',
                image_url: 'rayia_soderberg_1.jpg',
                category: 'Decor',
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
                name: 'Complete Pots & Pans Set',
                price: 499.99,
                description: 'High-quality complete pots & pans set perfect for your home.',
                image_url: 'cooking_set_pots_pans.jpg',
                category: 'Cookware',
                stock: 100
            },
            {
                name: 'Stylish Kitchen Centerpiece',
                price: 85,
                description: 'High-quality stylish kitchen centerpiece perfect for your home.',
                image_url: 'tamara_harhai_decor.jpg',
                category: 'Decor',
                stock: 100
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
