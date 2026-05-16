/**
 * searchOrchestrator.js
 *
 * Master search pipeline. The single entry point called by ai.js.
 *
 * Pipeline:
 *   1. Normalize query
 *   2. Cache check
 *   3. Spell Correct → Synonym Expand → Intent Detect
 *   4. Fetch ranking signals in parallel (trending, popularity, conversions, profile)
 *   5. Personalized semantic search (primary)
 *   6. Fallback chain (if semantic fails or empty)
 *   7. Merge + Deduplicate
 *   8. Adaptive Ranking (9-signal)
 *   9. Personalization boost
 *  10. Pagination + Cleanup
 *  11. Cache write + Analytics log
 */

const queryProcessor = require('./queryProcessor');
const semanticSearchService = require('./semanticSearchService');
const fallbackSearchService = require('./fallbackSearchService');
const rankingEngine = require('./rankingEngine');
const personalizationEngine = require('./personalizationEngine');
const cacheService = require('./cacheService');
const analyticsService = require('./analyticsService');
const trendingService = require('./trendingService');

// Track if the spell dictionary has been initialized
let _dictionaryLoaded = false;

/**
 * Initialize the spell dictionary from product data.
 * Called once when the first search request comes in.
 */
async function ensureDictionary() {
    if (_dictionaryLoaded) return;

    try {
        const { supabase } = require('../../supabaseClient');
        const { data } = await supabase.from('products').select('name, category, tags');
        if (data) {
            queryProcessor.loadDictionary(data);
            _dictionaryLoaded = true;
        }
    } catch (err) {
        console.warn('Dictionary init failed:', err.message);
    }
}

/**
 * Execute the full search pipeline.
 *
 * @param {string} rawQuery — raw user input
 * @param {string} [deviceId] — optional device_id for personalization
 * @param {object} [options]
 * @param {number} [options.limit=20]
 * @param {number} [options.page=1]
 * @returns {Promise<Array>} — array of Product objects (same shape as current API)
 */
async function execute(rawQuery, deviceId, options = {}) {
    const startTime = Date.now();
    const { limit = 20, page = 1, category = null, maxPrice = null, tags = [] } = options;

    // ── Step 0: Ensure dictionary is loaded ──────────────────────────────
    await ensureDictionary();

    // ── Step 1: Normalize ────────────────────────────────────────────────
    const normalized = queryProcessor.normalize(rawQuery);
    if (!normalized) {
        return [];
    }

    // ── Step 2: Cache Check ──────────────────────────────────────────────
    const cacheKey = `search:${normalized}:${page}:c=${category || 'all'}:p=${maxPrice || 'all'}:t=${tags.join(',')}`;
    const cached = await cacheService.get(cacheKey);
    if (cached) {
        const latency = Date.now() - startTime;
        analyticsService.log({
            query: rawQuery,
            correctedQuery: normalized,
            resultCount: cached.length,
            latencyMs: latency,
            source: 'cache',
            deviceId,
        });
        // Still apply personalization even on cache hit
        const personalized = await personalizationEngine.boost(cached, deviceId);
        return stripScoring(personalized);
    }

    // ── Step 3: Query Processing ─────────────────────────────────────────
    const { corrected, wasCorrected } = queryProcessor.spellCorrect(normalized);
    const queryAfterSpell = corrected;
    const { expanded, synonymsApplied } = queryProcessor.expandSynonyms(queryAfterSpell);
    const intent = queryProcessor.detectIntent(expanded);

    // ── Step 4: Fetch ranking signals in PARALLEL ────────────────────────
    // These are all async and independent — run them concurrently for speed.
    const [
        trendingScores,
        popularityCounts,
        conversionCounts,
        userProfile,
    ] = await Promise.all([
        trendingService.getTrendingProductScores().catch(() => ({})),
        trendingService.getPopularityScores().catch(() => ({})),
        analyticsService.getConversionScores().catch(() => ({})),
        deviceId ? personalizationEngine.buildUserProfile(deviceId).catch(() => null) : Promise.resolve(null),
    ]);

    const rankingSignals = {
        trendingScores,
        popularityCounts,
        conversionCounts,
        userProfile,
    };

    // ── Step 5: Semantic Search (primary) ─────────────────────────────────
    let semanticResults = [];
    let searchSource = 'semantic';

    if (semanticSearchService.isReady()) {
        try {
            const semantic = await semanticSearchService.search(expanded, { matchCount: limit * 2 });
            semanticResults = semantic.results;
            searchSource = semantic.source;
        } catch (err) {
            console.warn('Semantic search failed, falling back:', err.message);
        }
    }

    // ── Step 6: Fallback chain ───────────────────────────────────────────
    let fallbackResults = [];

    if (semanticResults.length === 0) {
        // Full fallback: personalized category → keyword → fuzzy → tags → trending
        if (userProfile && Object.keys(userProfile.categoryAffinity).length > 0) {
            // Try personalized category search first
            try {
                const topCategory = Object.entries(userProfile.categoryAffinity)
                    .sort((a, b) => b[1] - a[1])[0]?.[0];

                if (topCategory) {
                    const { supabase } = require('../../supabaseClient');
                    const { data } = await supabase
                        .from('products')
                        .select('*')
                        .eq('category', topCategory)
                        .ilike('name', `%${queryAfterSpell}%`)
                        .limit(limit);

                    if (data && data.length > 0) {
                        fallbackResults = data;
                        searchSource = 'personalized_keyword';
                    }
                }
            } catch {
                // Non-critical
            }
        }

        // If personalized fallback didn't produce results, use standard fallback chain
        if (fallbackResults.length === 0) {
            const fallback = await fallbackSearchService.search(queryAfterSpell, limit * 2);
            fallbackResults = fallback.results;
            searchSource = fallback.source;
        }
    } else if (semanticResults.length < 5) {
        // Augment with fallback
        try {
            const augment = await fallbackSearchService.keywordSearch(queryAfterSpell, 10);
            fallbackResults = augment.results;
        } catch {
            // Non-critical
        }
    }

    // ── Step 7: Merge + Deduplicate ──────────────────────────────────────
    const mergedMap = new Map();

    for (const product of semanticResults) {
        mergedMap.set(product.id, product);
    }
    for (const product of fallbackResults) {
        if (!mergedMap.has(product.id)) {
            mergedMap.set(product.id, product);
        }
    }

    const merged = Array.from(mergedMap.values());

    // ── Step 8: Adaptive Ranking (9-signal) ──────────────────────────────
    const ranked = rankingEngine.rank(merged, intent, expanded, rankingSignals);

    // ── Step 9: Personalization Boost ─────────────────────────────────────
    const personalized = await personalizationEngine.boost(ranked, deviceId);

    // ── Step 10: Hard Filtering ──────────────────────────────────────────
    let filtered = personalized;
    
    if (category) {
        filtered = filtered.filter(p => p.category === category);
    }
    
    if (maxPrice) {
        filtered = filtered.filter(p => p.price <= maxPrice);
    }
    
    if (tags && tags.length > 0) {
        filtered = filtered.filter(p => {
            const productTags = (p.tags || []).map(t => t.toLowerCase());
            return tags.some(t => productTags.includes(t.toLowerCase()));
        });
    }

    // ── Step 11: Pagination + Cleanup ────────────────────────────────────
    const offset = (page - 1) * limit;
    const paginated = filtered.slice(offset, offset + limit);
    const finalResults = stripScoring(paginated);

    // ── Step 12: Cache Write + Analytics ──────────────────────────────────
    const latency = Date.now() - startTime;

    // Cache pre-personalization results (personalization is per-user)
    // For cached filtered results, we cache the unpaginated filtered array up to a large limit
    await cacheService.set(cacheKey, stripScoring(filtered.slice(0, limit * 2)), 300);

    analyticsService.log({
        query: rawQuery,
        correctedQuery: wasCorrected ? queryAfterSpell : null,
        resultCount: finalResults.length,
        latencyMs: latency,
        source: searchSource,
        deviceId,
    });

    // Log pipeline metadata for debugging
    if (process.env.NODE_ENV !== 'production') {
        const profileTag = userProfile ? ' 👤' : ' 🌐';
        console.log(`🔍  Search: "${rawQuery}" → "${queryAfterSpell}" | ${finalResults.length} results | ${latency}ms | source: ${searchSource}${profileTag}${wasCorrected ? ' (corrected)' : ''}${synonymsApplied.length ? ` | synonyms: ${synonymsApplied.join(', ')}` : ''}`);
    }

    return finalResults;
}

/**
 * Strip internal scoring fields from products for the API response.
 */
function stripScoring(products) {
    return products.map(p => {
        const { _score, _debug, _similarity, similarity, _personalized, _personalizationScore, ...clean } = p;
        return clean;
    });
}

module.exports = { execute };
