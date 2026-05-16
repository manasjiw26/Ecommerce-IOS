/**
 * trendingService.js
 *
 * Calculates and serves trending queries and trending products.
 * Uses a time-decayed scoring algorithm — recent activity is weighted
 * more heavily than older activity.
 *
 * Trending data is recalculated lazily (every 10 minutes) and cached.
 */

const { supabase } = require('../../supabaseClient');
const cacheService = require('./cacheService');

const RECALC_INTERVAL = 10 * 60 * 1000; // 10 minutes
let _lastCalcTime = 0;

// ══════════════════════════════════════════════════════════════════════════════
//  TRENDING QUERIES
// ══════════════════════════════════════════════════════════════════════════════

/**
 * Calculate trending search queries using time-decayed frequency scoring.
 * Queries from the last 1 hour weigh 4x, last 6 hours 2x, last 24 hours 1x.
 *
 * @param {number} [limit=10]
 * @returns {Promise<Array<{query: string, score: number}>>}
 */
async function getTrendingQueries(limit = 10) {
    const cacheKey = 'trending:queries';
    const cached = await cacheService.get(cacheKey);
    if (cached) return cached;

    try {
        const now = Date.now();
        const oneHourAgo = new Date(now - 1 * 60 * 60 * 1000).toISOString();
        const sixHoursAgo = new Date(now - 6 * 60 * 60 * 1000).toISOString();
        const oneDayAgo = new Date(now - 24 * 60 * 60 * 1000).toISOString();

        // Fetch recent search analytics
        const { data, error } = await supabase
            .from('search_analytics')
            .select('query, created_at')
            .gte('created_at', oneDayAgo)
            .order('created_at', { ascending: false })
            .limit(500);

        if (error || !data || data.length === 0) return [];

        // Score each query with time decay
        const scores = {};
        for (const row of data) {
            const q = row.query.toLowerCase().trim();
            if (q.length < 2) continue;

            const createdAt = new Date(row.created_at).getTime();
            let weight = 1;
            if (createdAt >= new Date(oneHourAgo).getTime()) weight = 4;
            else if (createdAt >= new Date(sixHoursAgo).getTime()) weight = 2;

            scores[q] = (scores[q] || 0) + weight;
        }

        const trending = Object.entries(scores)
            .sort((a, b) => b[1] - a[1])
            .slice(0, limit)
            .map(([query, score]) => ({ query, score }));

        // Cache for 10 minutes
        await cacheService.set(cacheKey, trending, 600);

        // Also persist to trending_searches table (fire-and-forget)
        persistTrendingQueries(trending);

        return trending;
    } catch (err) {
        console.warn('Trending queries calculation failed:', err.message);
        return [];
    }
}

/**
 * Persist calculated trending queries to the trending_searches table.
 * Fire-and-forget — errors are swallowed.
 */
function persistTrendingQueries(trending) {
    if (!trending || trending.length === 0) return;

    for (const item of trending) {
        supabase
            .from('trending_searches')
            .upsert({
                query: item.query,
                score: item.score,
                updated_at: new Date().toISOString(),
            }, { onConflict: 'query' })
            .then(() => {})
            .catch(() => {});
    }
}

// ══════════════════════════════════════════════════════════════════════════════
//  TRENDING PRODUCTS
// ══════════════════════════════════════════════════════════════════════════════

/**
 * Calculate trending products by combining:
 *  - Recent click frequency (from click_events)
 *  - Recent view frequency (from user_events)
 *  - Recent purchase frequency (from search_conversions)
 *
 * Falls back to stock-based popularity if no event data exists.
 *
 * @param {number} [limit=10]
 * @returns {Promise<Array<{productId: number, score: number}>>}
 */
async function getTrendingProducts(limit = 10) {
    const cacheKey = 'trending:products';
    const cached = await cacheService.get(cacheKey);
    if (cached) return cached;

    try {
        const oneDayAgo = new Date(Date.now() - 24 * 60 * 60 * 1000).toISOString();
        const scores = {};

        // Signal 1: Recent views from user_events (weight: 1)
        const { data: views } = await supabase
            .from('user_events')
            .select('product_id')
            .gte('timestamp', oneDayAgo)
            .limit(300);

        if (views) {
            for (const v of views) {
                scores[v.product_id] = (scores[v.product_id] || 0) + 1;
            }
        }

        // Signal 2: Recent clicks from click_events (weight: 3)
        try {
            const { data: clicks } = await supabase
                .from('click_events')
                .select('product_id')
                .gte('created_at', oneDayAgo)
                .limit(300);

            if (clicks) {
                for (const c of clicks) {
                    scores[c.product_id] = (scores[c.product_id] || 0) + 3;
                }
            }
        } catch {
            // Table might not exist yet
        }

        // Signal 3: Recent conversions (weight: 10)
        try {
            const { data: conversions } = await supabase
                .from('search_conversions')
                .select('product_id')
                .gte('created_at', oneDayAgo)
                .limit(100);

            if (conversions) {
                for (const c of conversions) {
                    scores[c.product_id] = (scores[c.product_id] || 0) + 10;
                }
            }
        } catch {
            // Table might not exist yet
        }

        const trending = Object.entries(scores)
            .sort((a, b) => b[1] - a[1])
            .slice(0, limit)
            .map(([productId, score]) => ({ productId: parseInt(productId), score }));

        // Cache for 10 minutes
        await cacheService.set(cacheKey, trending, 600);

        return trending;
    } catch (err) {
        console.warn('Trending products calculation failed:', err.message);
        return [];
    }
}

/**
 * Get a product_id → trending_score map for use by the ranking engine.
 * @returns {Promise<object>} — e.g. { 65: 15, 66: 8 }
 */
async function getTrendingProductScores() {
    const trending = await getTrendingProducts(50);
    const map = {};
    for (const item of trending) {
        map[item.productId] = item.score;
    }
    return map;
}

/**
 * Get popularity scores (order counts per product) for the ranking engine.
 * Cached for 30 minutes.
 * @returns {Promise<object>} — e.g. { 65: 5, 66: 12 }
 */
async function getPopularityScores() {
    const cacheKey = 'popularity:orders';
    const cached = await cacheService.get(cacheKey);
    if (cached) return cached;

    try {
        // Count orders per product from the orders table
        const { data: orders } = await supabase
            .from('orders')
            .select('items_summary')
            .limit(500);

        const counts = {};
        if (orders) {
            for (const order of orders) {
                // items_summary is a text field, so we can't easily parse product IDs.
                // Fallback: use user_events with event_type='purchase'
            }
        }

        // Better approach: count purchase events
        const { data: purchases } = await supabase
            .from('user_events')
            .select('product_id')
            .eq('event_type', 'purchase')
            .limit(500);

        if (purchases) {
            for (const p of purchases) {
                counts[p.product_id] = (counts[p.product_id] || 0) + 1;
            }
        }

        await cacheService.set(cacheKey, counts, 1800); // 30 min
        return counts;
    } catch {
        return {};
    }
}

module.exports = {
    getTrendingQueries,
    getTrendingProducts,
    getTrendingProductScores,
    getPopularityScores,
};
