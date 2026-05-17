/**
 * enrich_product_colors.js
 *
 * One-time script: fetches every product image → asks Gemini Vision for its
 * 1-3 dominant colors → merges the color labels into the product's tags[] array.
 *
 * Run with:  node scripts/enrich_product_colors.js
 *            or: npm run enrich-colors
 *
 * Products that already have any recognized color in their tags are skipped.
 * Processes in batches of 10 with a 300 ms delay between batches to stay
 * within Gemini rate limits.
 */

require('dotenv').config();
const { createClient } = require('@supabase/supabase-js');
const { GoogleGenAI }  = require('@google/genai');

// ── Clients ───────────────────────────────────────────────────────────────────
const supabase = createClient(
    process.env.SUPABASE_URL,
    process.env.SUPABASE_SERVICE_ROLE_KEY
);

const ai = new GoogleGenAI({
    apiKey:     process.env.GEMINI_API_KEY,
    apiVersion: 'v1'
});

// ── Colour vocabulary the gate understands ────────────────────────────────────
const KNOWN_COLORS = new Set([
    'white', 'black', 'grey', 'charcoal', 'beige', 'cream', 'ivory',
    'brown', 'tan', 'gold', 'brass', 'silver',
    'navy', 'blue', 'slate', 'teal', 'sage', 'green',
    'red', 'rust', 'terracotta', 'blush', 'pink', 'orange',
    'lavender', 'purple'
]);

// Gemini prompt — strict JSON array, no prose
const GEMINI_PROMPT = `Analyze this product image. What are the 1-3 most dominant colors of this product itself (not the background)?
Return ONLY a JSON array of lowercase color names chosen strictly from this list:
["white", "black", "grey", "charcoal", "beige", "cream", "ivory", "brown", "tan", "gold", "brass", "silver", "navy", "blue", "slate", "teal", "sage", "green", "red", "rust", "terracotta", "blush", "pink", "orange", "lavender", "purple"]
Example output: ["white", "gold"]
Return ONLY the JSON array. No explanation, no markdown.`;

// ── Helpers ───────────────────────────────────────────────────────────────────

/** Fetch image as base64 via URL */
async function fetchBase64(url) {
    const res = await fetch(url);
    if (!res.ok) throw new Error(`HTTP ${res.status} for ${url}`);
    const arrayBuffer = await res.arrayBuffer();
    return Buffer.from(arrayBuffer).toString('base64');
}

/** Strip markdown fences if Gemini wraps the JSON */
function stripFences(text) {
    return String(text || '')
        .trim()
        .replace(/^```json\s*/i, '')
        .replace(/^```\s*/i, '')
        .replace(/\s*```$/i, '')
        .trim();
}

/** Ask Gemini Vision and return a color array, or null on failure */
async function getColorsFromGemini(product) {
    const GEMINI_MODEL = process.env.GEMINI_MODEL || 'gemini-2.0-flash';
    const base64 = await fetchBase64(product.image_url);

    const response = await ai.models.generateContent({
        model: GEMINI_MODEL,
        contents: [{
            role: 'user',
            parts: [
                { inlineData: { mimeType: 'image/jpeg', data: base64 } },
                { text: GEMINI_PROMPT }
            ]
        }],
        generationConfig: { temperature: 0.1 }
    });

    const raw = stripFences(response.text());
    const parsed = JSON.parse(raw);

    if (!Array.isArray(parsed)) throw new Error('Response is not an array');

    // Keep only recognized color names
    return parsed
        .map(c => String(c).toLowerCase().trim())
        .filter(c => KNOWN_COLORS.has(c));
}

// ── Main ──────────────────────────────────────────────────────────────────────
async function main() {
    console.log('🎨  Product Color Enrichment Script');
    console.log('────────────────────────────────────\n');

    if (!process.env.GEMINI_API_KEY) {
        console.error('❌  GEMINI_API_KEY is not set in .env');
        process.exit(1);
    }

    // 1. Fetch all products with an image_url
    const { data: products, error: fetchErr } = await supabase
        .from('products')
        .select('id, name, image_url, tags')
        .not('image_url', 'is', null);

    if (fetchErr) {
        console.error('❌  Failed to fetch products:', fetchErr.message);
        process.exit(1);
    }

    console.log(`📦  Fetched ${products.length} products total\n`);

    // 2. Split into needs-enrichment vs already-done
    const toEnrich = products.filter(p => {
        const existing = (p.tags || []).map(t => t.toLowerCase());
        return !existing.some(t => KNOWN_COLORS.has(t));
    });

    const skipped = products.length - toEnrich.length;
    console.log(`⏭️   Skipping ${skipped} products (already have color tags)`);
    console.log(`🔍  Enriching ${toEnrich.length} products...\n`);

    if (toEnrich.length === 0) {
        console.log('✅  Nothing to do — all products already have color tags.');
        return;
    }

    // 3. Process in batches of 10
    const BATCH_SIZE = 10;
    const BATCH_DELAY_MS = 300;

    let successCount = 0;
    let failCount    = 0;

    for (let i = 0; i < toEnrich.length; i += BATCH_SIZE) {
        const batch = toEnrich.slice(i, i + BATCH_SIZE);
        const batchNum = Math.floor(i / BATCH_SIZE) + 1;
        const totalBatches = Math.ceil(toEnrich.length / BATCH_SIZE);
        console.log(`\n📋  Batch ${batchNum}/${totalBatches}`);

        const results = await Promise.allSettled(
            batch.map(async (product) => {
                try {
                    const colorLabels = await getColorsFromGemini(product);

                    if (colorLabels.length === 0) {
                        console.warn(`  ⚠️  ${product.name} — Gemini returned no recognized colors, skipping`);
                        return;
                    }

                    // Merge into existing tags, deduplicating
                    const updatedTags = [...new Set([...(product.tags || []), ...colorLabels])];

                    const { error: updateErr } = await supabase
                        .from('products')
                        .update({ tags: updatedTags })
                        .eq('id', product.id);

                    if (updateErr) throw updateErr;

                    console.log(`  ✓  ${product.name} → [${colorLabels.join(', ')}]`);
                    successCount++;
                } catch (err) {
                    console.error(`  ✗  ${product.name} — ${err.message}`);
                    failCount++;
                }
            })
        );

        // 300 ms pause between batches (skip after last batch)
        if (i + BATCH_SIZE < toEnrich.length) {
            await new Promise(r => setTimeout(r, BATCH_DELAY_MS));
        }
    }

    // 4. Summary
    console.log('\n────────────────────────────────────');
    console.log(`🎉  Done!`);
    console.log(`    Total processed : ${toEnrich.length}`);
    console.log(`    Skipped          : ${skipped}`);
    console.log(`    ✅ Succeeded     : ${successCount}`);
    console.log(`    ❌ Failed        : ${failCount}`);
}

main().catch(err => {
    console.error('\nFatal error:', err.message);
    process.exit(1);
});
