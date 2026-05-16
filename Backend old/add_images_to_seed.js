const fs = require('fs');
const path = require('path');

const imagesMap = [
  {"original": "Gemini_Generated_Image_fcnng0fcnng0fcnn (1).png", "new": "gemini_kitchen_1.png", "title": "Kitchen Decor Set 1", "category": "Decor", "price": 49.99},
  {"original": "Gemini_Generated_Image_fcnng0fcnng0fcnn (2).png", "new": "gemini_kitchen_2.png", "title": "Kitchen Decor Set 2", "category": "Decor", "price": 59.99},
  {"original": "Gemini_Generated_Image_fcnng0fcnng0fcnn.png", "new": "gemini_kitchen_3.png", "title": "Kitchen Decor Set 3", "category": "Decor", "price": 39.99},
  {"original": "andrey-matveev-OtlyMBQC3ow-unsplash.jpg", "new": "andrey_matveev_decor.jpg", "title": "Modern Kitchen Accessory", "category": "Accessories", "price": 24.99},
  {"original": "cooker-king-2ryIlbZ1G7Q-unsplash.jpg", "new": "cooker_king_pan.jpg", "title": "Cooker King Frying Pan", "category": "Cookware", "price": 89.99},
  {"original": "cooker-king-AOVtEuU9UGc-unsplash.jpg", "new": "cooker_king_pot.jpg", "title": "Cooker King Stock Pot", "category": "Cookware", "price": 110.00},
  {"original": "golden-horn-bridge-TltxDchmYpc-unsplash.jpg", "new": "golden_bridge_item.jpg", "title": "Golden Horn Special Item", "category": "Accessories", "price": 15.99},
  {"original": "jason-briscoe-PkkLkjJdUZw-unsplash.jpg", "new": "jason_briscoe_kitchen.jpg", "title": "Designer Kitchen Tool", "category": "Tools", "price": 34.50},
  {"original": "jota-s-a-1W6OalmU0lY-unsplash.jpg", "new": "jota_sa_tool.jpg", "title": "Professional Kitchen Tool", "category": "Tools", "price": 45.00},
  {"original": "lidye-fJIfOzw_e7U-unsplash.jpg", "new": "lidye_accessories.jpg", "title": "Elegant Dining Accessory", "category": "Dining", "price": 28.00},
  {"original": "luke-peterson-OIZPSX6vlgg-unsplash.jpg", "new": "luke_peterson_decor.jpg", "title": "Minimalist Kitchen Decor", "category": "Decor", "price": 65.00},
  {"original": "mario-raj-KLE_PZmhe3Y-unsplash.jpg", "new": "mario_raj_item.jpg", "title": "Classic Kitchen Essential", "category": "Essentials", "price": 19.99},
  {"original": "meghna-r-YmEoHKxhOqg-unsplash.jpg", "new": "meghna_r_bowl.jpg", "title": "Artisan Ceramic Bowl", "category": "Dining", "price": 42.00},
  {"original": "mockup-graphics-0ZgEvwSS4k0-unsplash.jpg", "new": "mockup_kitchen.jpg", "title": "Premium Mockup Set", "category": "Decor", "price": 22.00},
  {"original": "noonbrew-1iAWW9t37Rw-unsplash.jpg", "new": "noonbrew_coffee_maker.jpg", "title": "Noonbrew Coffee Set", "category": "Appliances", "price": 120.00},
  {"original": "odiseo-castrejon-xPPoMWL4r_A-unsplash.jpg", "new": "odiseo_tool.jpg", "title": "Chef's Secret Tool", "category": "Tools", "price": 33.00},
  {"original": "olga-kovalski-1-G4rkjK0wI-unsplash.jpg", "new": "olga_kovalski_kitchen.jpg", "title": "Gourmet Kitchen Accessory", "category": "Accessories", "price": 27.50},
  {"original": "prateek-katyal-E_KaxEEkDeE-unsplash.jpg", "new": "prateek_item.jpg", "title": "Modern Prep Tool", "category": "Tools", "price": 38.00},
  {"original": "rayia-soderberg-FUsq49lD1xY-unsplash 2.jpg", "new": "rayia_soderberg_2.jpg", "title": "Nordic Kitchen Item 2", "category": "Decor", "price": 55.00},
  {"original": "rayia-soderberg-FUsq49lD1xY-unsplash.jpg", "new": "rayia_soderberg_1.jpg", "title": "Nordic Kitchen Item 1", "category": "Decor", "price": 55.00},
  {"original": "savernake-knives-vwI_eMs-2Ms-unsplash.jpg", "new": "savernake_knives.jpg", "title": "Savernake Professional Knife", "category": "Cutlery", "price": 250.00},
  {"original": "side-view-cooking-set-pots-pans-wooden-shelves-jpg.jpg", "new": "cooking_set_pots_pans.jpg", "title": "Complete Pots & Pans Set", "category": "Cookware", "price": 499.99},
  {"original": "tamara-harhai-NgLO-4P2uok-unsplash.jpg", "new": "tamara_harhai_decor.jpg", "title": "Stylish Kitchen Centerpiece", "category": "Decor", "price": 85.00}
];

const sourceDir = '/Users/apple/Downloads/images';
const targetDir = '/Users/apple/Downloads/ecommerce/Ecommerce-IOS/Backend/product_images';

// Ensure target dir exists
if (!fs.existsSync(targetDir)) {
  fs.mkdirSync(targetDir, { recursive: true });
}

// Copy and rename images
const additionalProducts = [];
for (const item of imagesMap) {
  const srcPath = path.join(sourceDir, item.original);
  const destPath = path.join(targetDir, item.new);
  
  if (fs.existsSync(srcPath)) {
    fs.copyFileSync(srcPath, destPath);
    console.log(`Copied: ${item.new}`);
    
    additionalProducts.push({
      name: item.title,
      price: item.price,
      description: `High-quality ${item.title.toLowerCase()} perfect for your home.`,
      image_url: item.new,
      category: item.category,
      stock: 100
    });
  } else {
    console.warn(`File not found: ${srcPath}`);
  }
}

// Update seed.js
const seedJsPath = '/Users/apple/Downloads/ecommerce/Ecommerce-IOS/Backend/seed.js';
let seedJsContent = fs.readFileSync(seedJsPath, 'utf8');

// Find the insertion point (the closing bracket of the insert array)
const closingBracketIndex = seedJsContent.lastIndexOf(']).select();');

if (closingBracketIndex !== -1) {
    let newProductsString = '';
    for (const product of additionalProducts) {
        newProductsString += `,
            {
                name: '${product.name}',
                price: ${product.price},
                description: '${product.description}',
                image_url: '${product.image_url}',
                category: '${product.category}',
                stock: ${product.stock}
            }`;
    }
    
    seedJsContent = seedJsContent.substring(0, closingBracketIndex) + newProductsString + '\n        ' + seedJsContent.substring(closingBracketIndex);
    fs.writeFileSync(seedJsPath, seedJsContent);
    console.log(`Successfully added ${additionalProducts.length} new products to seed.js`);
} else {
    console.error("Could not find the closing bracket ']).select();' in seed.js");
}
