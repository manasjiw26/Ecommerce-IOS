const fs = require('fs');
const https = require('https');
const { execSync } = require('child_process');

const targetDir = '/Users/apple/Downloads/ecommerce/Ecommerce-IOS/Backend/product_images';

const newProducts = [
  // Aesthetic images generated locally
  {
    name: "Aurum Brass Pour-Over Kettle",
    price: 85.00,
    description: "A stunning brass pour-over coffee kettle on a minimalist white marble kitchen counter.",
    image_url: "aurum_brass_kettle.png",
    category: "Appliances",
    stock: 25
  },
  {
    name: "Obsidian Matte Espresso Machine",
    price: 499.00,
    description: "A matte black professional espresso machine with wooden accents.",
    image_url: "obsidian_espresso_machine.png",
    category: "Appliances",
    stock: 10
  },
  {
    name: "Lumina Ribbed Glass Carafe",
    price: 34.50,
    description: "An elegant ribbed glass water carafe with a gold lid.",
    image_url: "lumina_glass_carafe.png",
    category: "Dining",
    stock: 40
  },
  {
    name: "Verdant Sage Ceramic Mugs",
    price: 24.00,
    description: "A stack of handcrafted sage green ceramic coffee mugs.",
    image_url: "verdant_sage_mugs.png",
    category: "Dining",
    stock: 60
  }
];

const onlineImages = [
  {
    url: "https://images.unsplash.com/photo-1556910103-1c02745aae4d?w=800&q=70",
    name: "Online Kitchen Tools Set",
    file: "online_kitchen_tools.jpg",
    price: 45.00,
    category: "Tools",
    description: "A beautiful set of professional kitchen tools."
  },
  {
    url: "https://images.unsplash.com/photo-1581622558667-3419a8dc5f83?w=800&q=70",
    name: "Online Premium Pots & Pans",
    file: "online_pots_pans.jpg",
    price: 199.99,
    category: "Cookware",
    description: "High-quality pots and pans for everyday cooking."
  },
  {
    url: "https://images.unsplash.com/photo-1590499092404-585a060411fb?w=800&q=70",
    name: "Online Modern Cutlery",
    file: "online_cutlery.jpg",
    price: 75.00,
    category: "Cutlery",
    description: "Sleek and modern cutlery set for dining."
  },
  {
    url: "https://images.unsplash.com/photo-1584286595398-a59f21d313f5?w=800&q=70",
    name: "Online Kitchen Setup Collection",
    file: "online_kitchen_setup.jpg",
    price: 120.00,
    category: "Decor",
    description: "A complete kitchen aesthetic setup collection."
  }
];

function downloadImage(url, filename) {
  return new Promise((resolve, reject) => {
    const file = fs.createWriteStream(filename);
    https.get(url, (response) => {
      response.pipe(file);
      file.on('finish', () => {
        file.close();
        resolve();
      });
    }).on('error', (err) => {
      fs.unlink(filename, () => {});
      reject(err);
    });
  });
}

async function processOnlineImages() {
  for (const img of onlineImages) {
    const filePath = `${targetDir}/${img.file}`;
    console.log(`Downloading ${img.file}...`);
    try {
        await downloadImage(img.url, filePath);
        // Resize and compress just to be absolutely sure it's under 1MB
        execSync(`sips -Z 800 "${filePath}"`);
        console.log(`Successfully processed ${img.file}`);
        
        newProducts.push({
            name: img.name,
            price: img.price,
            description: img.description,
            image_url: img.file,
            category: img.category,
            stock: 30
        });
    } catch (e) {
        console.error(`Failed to download/process ${img.file}: ${e}`);
    }
  }
  
  // Update seed.js
  const seedJsPath = '/Users/apple/Downloads/ecommerce/Ecommerce-IOS/Backend/seed.js';
  let seedJsContent = fs.readFileSync(seedJsPath, 'utf8');

  const closingBracketIndex = seedJsContent.lastIndexOf(']).select();');

  if (closingBracketIndex !== -1) {
      let newProductsString = '';
      for (const product of newProducts) {
          newProductsString += `,
              {
                  name: '${product.name.replace(/'/g, "\\'")}',
                  price: ${product.price},
                  description: '${product.description.replace(/'/g, "\\'")}',
                  image_url: '${product.image_url}',
                  category: '${product.category}',
                  stock: ${product.stock}
              }`;
      }
      
      seedJsContent = seedJsContent.substring(0, closingBracketIndex) + newProductsString + '\n        ' + seedJsContent.substring(closingBracketIndex);
      fs.writeFileSync(seedJsPath, seedJsContent);
      console.log(`Successfully added ${newProducts.length} new products to seed.js`);
  } else {
      console.error("Could not find the closing bracket ']).select();' in seed.js");
  }
}

processOnlineImages();
