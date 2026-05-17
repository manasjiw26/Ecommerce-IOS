/**
 * generate_image_embeddings.js
 *
 * One-time script: downloads every product image, generates a CLIP image
 * embedding (512-dim), and upserts it into product_embeddings.image_embedding.
 *
 * Run with:  node scripts/generate_image_embeddings.js
 */

require('dotenv').config();
const { createClient } = require('@supabase/supabase-js');

const supabase = createClient(
    process.env.SUPABASE_URL,
    process.env.SUPABASE_SERVICE_ROLE_KEY
);

function buildImageUrl(raw) {
    if (!raw) return null;
    if (raw.startsWith('http')) return raw;
    return null;
}

async function main() {
    // Dynamically import ESM-only @xenova/transformers
    const { pipeline, RawImage } = await import('@xenova/transformers');

    console.log('⏳  Loading CLIP model (first run downloads ~600 MB)…');
    const extractor = await pipeline(
        'image-feature-extraction',
        'Xenova/clip-vit-base-patch32'
    );
    console.log('✅  CLIP model ready.\n');

    // Fetch all products that have an image_url
    const { data: products, error: fetchErr } = await supabase
        .from('products')
        .select('id, name, image_url')
        .not('image_url', 'is', null);

    if (fetchErr) {
        console.error('Failed to fetch products:', fetchErr.message);
        process.exit(1);
    }

    console.log(`📦  Found ${products.length} products to embed.\n`);

    let success = 0;
    let failed  = 0;

    for (const product of products) {
        const imageUrl = buildImageUrl(product.image_url);
        if (!imageUrl) { failed++; continue; }

        try {
            // Load image from URL
            const image = await RawImage.fromURL(imageUrl);

            // Generate CLIP image embedding (512-dim)
            const output = await extractor(image, { pooling: 'mean', normalize: true });
            const embedding = Array.from(output.data);

            if (embedding.length !== 512) {
                console.warn(`⚠️   Product ${product.id} — unexpected embedding size: ${embedding.length}`);
            }

            // Upsert into product_embeddings
            const { error: upsertErr } = await supabase
                .from('product_embeddings')
                .upsert(
                    { product_id: product.id, image_embedding: embedding },
                    { onConflict: 'product_id' }
                );

            if (upsertErr) {
                console.error(`❌  Product ${product.id} (${product.name}) — DB error: ${upsertErr.message}`);
                failed++;
            } else {
                console.log(`✅  [${success + 1}/${products.length}] ${product.name}`);
                success++;
            }
        } catch (err) {
            console.error(`❌  Product ${product.id} (${product.name}) — ${err.message}`);
            failed++;
        }
    }

    console.log(`\n🎉  Done — ${success} embedded, ${failed} failed.`);
}

main().catch(err => {
    console.error('Fatal:', err);
    process.exit(1);
});
