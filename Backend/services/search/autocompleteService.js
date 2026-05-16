/**
 * autocompleteService.js
 *
 * Provides fast type-ahead suggestions from cached product names,
 * as well as recent searches, trending searches, and category suggestions.
 * Product name list is refreshed every 5 minutes.
 */

const { supabase } = require('../../supabaseClient');
const cacheService = require('./cacheService');
const analyticsService = require('./analyticsService');
const queryProcessor = require('./queryProcessor');

// Local product name cache (refreshed periodically)
let _productNames = [];
let _categories = [];
let _lastRefresh = 0;
const REFRESH_INTERVAL = 5 * 60 * 1000; // 5 minutes

/**
 * Refresh the product name list from Supabase.
 */
async function refreshProductNames() {
    try {
        const { data, error } = await supabase
            .from('products')
            .select('id, name, category')
            .gt('stock', 0)
            .order('name', { ascending: true });

        if (!error && data) {
            _productNames = data.map(p => ({
                id: p.id,
                name: p.name,
                category: p.category,
                nameLower: p.name.toLowerCase(),
            }));
            
            // Extract unique categories
            const catSet = new Set(data.map(p => p.category).filter(Boolean));
            _categories = Array.from(catSet);
            
            // Load dictionary for spell correction
            queryProcessor.loadDictionary(data);
            
            _lastRefresh = Date.now();
        }
    } catch (err) {
        console.warn('Autocomplete refresh failed:', err.message);
    }
}

/**
 * Fetch recent searches for a device.
 */
async function getRecentSearches(deviceId) {
    if (!deviceId) return [];
    
    try {
        const { data, error } = await supabase
            .from('recent_searches')
            .select('query')
            .eq('device_id', deviceId)
            .order('created_at', { ascending: false })
            .limit(10);
            
        if (error || !data) return [];
        
        // Deduplicate
        const unique = [];
        const seen = new Set();
        for (const row of data) {
            const q = row.query.toLowerCase().trim();
            if (!seen.has(q)) {
                seen.add(q);
                unique.push(row.query); // Keep original casing
            }
        }
        
        return unique.slice(0, 5);
    } catch (err) {
        console.warn('Failed fetching recent searches:', err.message);
        return [];
    }
}

/**
 * Get autocomplete suggestions for a partial query.
 * Now returns a composite object containing recent, trending, categories, and products.
 *
 * @param {string} query — partial text typed by user (e.g. "sto")
 * @param {string} [deviceId] — optional device_id to fetch recent searches
 * @param {number} [limit=5]
 * @returns {Promise<object>}
 */
async function suggest(query, deviceId = null, limit = 5) {
    // Refresh if stale
    if (Date.now() - _lastRefresh > REFRESH_INTERVAL || _productNames.length === 0) {
        await refreshProductNames();
    }

    const result = {
        recent: [],
        trending: [],
        categories: [],
        products: []
    };

    // If query is empty, return recent and trending
    if (!query || query.trim().length === 0) {
        // Fetch recent searches
        if (deviceId) {
            result.recent = await getRecentSearches(deviceId);
        }
        
        // Fetch trending searches
        const cacheKeyTrending = 'autocomplete:trending_empty';
        let trending = await cacheService.get(cacheKeyTrending);
        if (!trending) {
            const trendingObjects = await analyticsService.getTrendingQueries(5);
            trending = trendingObjects.map(t => t.query);
            await cacheService.set(cacheKeyTrending, trending, 300); // 5 min cache
        }
        result.trending = trending;
        
        return result;
    }

    const qRaw = query.toLowerCase().trim();
    // Spell correct the query for autocomplete matching
    const { corrected: q } = queryProcessor.spellCorrect(queryProcessor.normalize(qRaw));
    console.log(`Autocomplete search: raw=${qRaw}, corrected=${q}, productsLoaded=${_productNames.length}`);

    // Check cache for this specific query
    const cacheKey = `autocomplete:${q}:${deviceId || 'anon'}`;
    const cached = await cacheService.get(cacheKey);
    if (cached) return cached;

    // Fetch recent searches that match the query
    if (deviceId) {
        const allRecent = await getRecentSearches(deviceId);
        result.recent = allRecent.filter(r => r.toLowerCase().includes(q));
    }

    // Match Categories
    result.categories = _categories.filter(c => c.toLowerCase().includes(q)).slice(0, 3);

    // Prefix match on product name words
    const matches = [];
    const seen = new Set();

    for (const product of _productNames) {
        if (seen.has(product.id)) continue;

        // Check if any word in the product name starts with the query
        const words = product.nameLower.split(/\s+/);
        const isMatch = product.nameLower.startsWith(q) ||
                        words.some(w => w.startsWith(q));

        if (isMatch) {
            matches.push({
                id: product.id,
                name: product.name,
                category: product.category,
            });
            seen.add(product.id);

            if (matches.length >= limit) break;
        }
    }

    // If not enough prefix matches, try substring (contains) matching
    if (matches.length < limit) {
        for (const product of _productNames) {
            if (seen.has(product.id)) continue;

            if (product.nameLower.includes(q)) {
                matches.push({
                    id: product.id,
                    name: product.name,
                    category: product.category,
                });
                seen.add(product.id);

                if (matches.length >= limit) break;
            }
        }
    }
    
    result.products = matches;

    // Cache for 1 minute
    await cacheService.set(cacheKey, result, 60);

    return result;
}

/**
 * Force a refresh of the product name cache.
 */
async function forceRefresh() {
    await refreshProductNames();
}

module.exports = { suggest, forceRefresh };
