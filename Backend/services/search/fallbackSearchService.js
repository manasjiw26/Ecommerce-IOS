/**
 * fallbackSearchService.js
 *
 * Multi-tier fallback when semantic search fails or returns nothing:
 *   Level 1: ILIKE keyword search
 *   Level 2: Fuzzy Levenshtein name matching
 *   Level 3: Tag-based matching
 *   Level 4: Trending products (always non-empty)
 */

const { supabase } = require('../../supabaseClient');
const { distance } = require('fastest-levenshtein');

const SUPABASE_STORAGE_URL = 'https://czahuzfliuuhhegynsjr.supabase.co/storage/v1/object/public/Product%20Images';

/**
 * Fix image URLs (same logic as products.js).
 */
function fixImageUrl(product) {
    if (product.image_url && !product.image_url.startsWith('http')) {
        product.image_url = `${SUPABASE_STORAGE_URL}/${encodeURIComponent(product.image_url)}`;
    }
    return product;
}

// ── Level 1: Keyword ILIKE Search ─────────────────────────────────────────────

/**
 * @param {string} query
 * @param {number} [limit=20]
 * @returns {Promise<{ results: Array, source: string }>}
 */
async function keywordSearch(query, limit = 20) {
    const fallbackQuery = `%${query}%`;

    const { data, error } = await supabase
        .from('products')
        .select('*')
        .or(`name.ilike.${fallbackQuery},description.ilike.${fallbackQuery},category.ilike.${fallbackQuery}`)
        .order('stock', { ascending: false })
        .limit(limit);

    if (error) throw error;

    return {
        results: (data || []).map(fixImageUrl),
        source: 'keyword',
    };
}

// ── Level 2: Fuzzy Name Matching ──────────────────────────────────────────────

/**
 * Fuzzy search — compare query against all product names using Levenshtein.
 * @param {string} query
 * @param {number} [limit=20]
 * @returns {Promise<{ results: Array, source: string }>}
 */
async function fuzzySearch(query, limit = 20) {
    // Fetch all product names (this list is typically < 100 items)
    const { data: allProducts, error } = await supabase
        .from('products')
        .select('*');

    if (error) throw error;
    if (!allProducts || allProducts.length === 0) {
        return { results: [], source: 'fuzzy' };
    }

    const queryTokens = query.toLowerCase().split(' ').filter(t => t.length >= 2);

    // Score each product by how well its name/tags match query tokens
    const scored = allProducts.map(product => {
        const nameLower = product.name.toLowerCase();
        const nameTokens = nameLower.split(/\s+/);
        const tags = (product.tags || []).map(t => t.toLowerCase());

        let bestScore = 0;

        for (const qt of queryTokens) {
            // Check against name tokens
            for (const nt of nameTokens) {
                const maxLen = Math.max(qt.length, nt.length);
                const similarity = 1 - (distance(qt, nt) / maxLen);
                bestScore = Math.max(bestScore, similarity);
            }

            // Check against tags
            for (const tag of tags) {
                const tagTokens = tag.split(/\s+/);
                for (const tt of tagTokens) {
                    const maxLen = Math.max(qt.length, tt.length);
                    const similarity = 1 - (distance(qt, tt) / maxLen);
                    bestScore = Math.max(bestScore, similarity);
                }
            }
        }

        return { product: fixImageUrl(product), score: bestScore };
    });

    // Only include products with similarity >= 0.55
    const matches = scored
        .filter(s => s.score >= 0.55)
        .sort((a, b) => b.score - a.score)
        .slice(0, limit)
        .map(s => s.product);

    return {
        results: matches,
        source: 'fuzzy',
    };
}

// ── Level 3: Tag-Based Search ─────────────────────────────────────────────────

/**
 * Match query tokens against the `tags` JSONB array column.
 * @param {string} query
 * @param {number} [limit=20]
 * @returns {Promise<{ results: Array, source: string }>}
 */
async function tagSearch(query, limit = 20) {
    const tokens = query.toLowerCase().split(' ').filter(t => t.length >= 2);

    if (tokens.length === 0) return { results: [], source: 'tags' };

    // Supabase: `tags` is a text[] column. Use `cs` (contains) for array overlap.
    // We'll query for each token and merge results.
    const resultMap = new Map();

    for (const token of tokens) {
        const { data, error } = await supabase
            .from('products')
            .select('*')
            .contains('tags', [token])
            .limit(limit);

        if (!error && data) {
            for (const product of data) {
                if (!resultMap.has(product.id)) {
                    resultMap.set(product.id, fixImageUrl(product));
                }
            }
        }
    }

    return {
        results: Array.from(resultMap.values()).slice(0, limit),
        source: 'tags',
    };
}

// ── Level 4: Trending Products ────────────────────────────────────────────────

/**
 * Return top products by stock (proxy for popularity). Never empty.
 * @param {number} [limit=10]
 * @returns {Promise<{ results: Array, source: string }>}
 */
async function trendingProducts(limit = 10) {
    const { data, error } = await supabase
        .from('products')
        .select('*')
        .gt('stock', 0)
        .order('stock', { ascending: false })
        .limit(limit);

    if (error) throw error;

    return {
        results: (data || []).map(fixImageUrl),
        source: 'trending',
    };
}

// ── Orchestrated Fallback ─────────────────────────────────────────────────────

/**
 * Run the full fallback chain. Returns the first tier that produces results.
 * @param {string} query — processed query
 * @param {number} [limit=20]
 * @returns {Promise<{ results: Array, source: string }>}
 */
async function search(query, limit = 20) {
    // Level 1: Keyword
    try {
        const keyword = await keywordSearch(query, limit);
        if (keyword.results.length > 0) return keyword;
    } catch (e) {
        console.warn('Keyword search failed:', e.message);
    }

    // Level 2: Fuzzy
    try {
        const fuzzy = await fuzzySearch(query, limit);
        if (fuzzy.results.length > 0) return fuzzy;
    } catch (e) {
        console.warn('Fuzzy search failed:', e.message);
    }

    // Level 3: Tags
    try {
        const tags = await tagSearch(query, limit);
        if (tags.results.length > 0) return tags;
    } catch (e) {
        console.warn('Tag search failed:', e.message);
    }

    // Level 4: Trending (always returns something)
    try {
        return await trendingProducts(limit);
    } catch (e) {
        console.error('Even trending products failed:', e.message);
        return { results: [], source: 'none' };
    }
}

module.exports = {
    search,
    keywordSearch,
    fuzzySearch,
    tagSearch,
    trendingProducts,
};
