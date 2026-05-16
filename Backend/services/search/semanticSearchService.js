/**
 * semanticSearchService.js
 *
 * Wraps the Xenova embedding model + Supabase hybrid_search RPC.
 * Caches embeddings so repeated queries don't re-compute vectors.
 */

const { supabase } = require('../../supabaseClient');
const cacheService = require('./cacheService');

// ── Embedding Model ───────────────────────────────────────────────────────────
let pipeline = null;
let embedderInstance = null;
let modelReady = false;

// Load transformers at module init (non-blocking)
(async () => {
    try {
        const transformers = await import('@xenova/transformers');
        pipeline = transformers.pipeline;
        // Pre-warm the model
        embedderInstance = await pipeline('feature-extraction', 'Xenova/all-MiniLM-L6-v2');
        modelReady = true;
        console.log('✅  Semantic embedding model loaded');
    } catch (err) {
        console.warn('⚠️  Embedding model load failed:', err.message);
    }
})();

/**
 * Generate a 384-dim embedding for a text string.
 * Results are cached under `emb:<text>` with 30-minute TTL.
 *
 * @param {string} text
 * @returns {Promise<number[]>}
 */
async function getEmbedding(text) {
    if (!text) throw new Error('Empty text for embedding');

    // Check cache first
    const cacheKey = `emb:${text}`;
    const cached = await cacheService.get(cacheKey);
    if (cached) return cached;

    if (!modelReady || !embedderInstance) {
        throw new Error('Embedding model not loaded yet');
    }

    const output = await embedderInstance(text, { pooling: 'mean', normalize: true });
    const embedding = Array.from(output.data);

    // Cache embedding for 30 minutes
    await cacheService.set(cacheKey, embedding, 1800);

    return embedding;
}

/**
 * Run semantic search via Supabase hybrid_search RPC.
 *
 * @param {string} queryText — processed query string
 * @param {object} [options]
 * @param {number} [options.matchCount=20]
 * @returns {Promise<{ results: Array, source: string }>}
 */
async function search(queryText, options = {}) {
    const { matchCount = 20 } = options;

    const embedding = await getEmbedding(queryText);

    const { data, error } = await supabase.rpc('hybrid_search', {
        query_text: queryText,
        query_embedding: embedding,
        match_count: matchCount,
    });

    if (error) throw error;

    return {
        results: data || [],
        source: 'semantic',
    };
}

/**
 * Check if the embedding model is loaded and ready.
 * @returns {boolean}
 */
function isReady() {
    return modelReady;
}

module.exports = {
    search,
    getEmbedding,
    isReady,
};
