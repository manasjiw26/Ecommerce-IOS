/**
 * analyticsService.js
 *
 * Comprehensive search analytics engine.
 * Handles:
 *   - Search event logging (fire-and-forget)
 *   - Click tracking
 *   - Conversion tracking
 *   - Performance metrics
 *   - Failed query logging
 *   - Batched writes for high throughput
 *
 * All writes are non-blocking. Analytics must NEVER slow down search.
 */

const { supabase } = require('../../supabaseClient');
const cacheService = require('./cacheService');

// ── Write Buffer (batched analytics) ──────────────────────────────────────────
const _writeBuffer = [];
const FLUSH_INTERVAL = 5000;   // 5 seconds
const MAX_BUFFER_SIZE = 50;

// Auto-flush buffer periodically
setInterval(() => {
    flushBuffer();
}, FLUSH_INTERVAL);

/**
 * Flush buffered analytics writes to Supabase in a single batch.
 */
async function flushBuffer() {
    if (_writeBuffer.length === 0) return;

    const batch = _writeBuffer.splice(0, MAX_BUFFER_SIZE);

    try {
        await supabase
            .from('search_analytics')
            .insert(batch);
    } catch {
        // Completely swallow — analytics must never crash the app
    }
}

// ══════════════════════════════════════════════════════════════════════════════
//  SEARCH EVENT LOGGING
// ══════════════════════════════════════════════════════════════════════════════

/**
 * Log a search event.
 * Writes to a buffer that flushes every 5 seconds for performance.
 *
 * @param {object} params
 * @param {string} params.query
 * @param {string} [params.correctedQuery]
 * @param {number} params.resultCount
 * @param {number} params.latencyMs
 * @param {string} params.source
 * @param {string} [params.deviceId]
 */
function log({ query, correctedQuery, resultCount, latencyMs, source, deviceId }) {
    _writeBuffer.push({
        query: query || '',
        corrected_query: correctedQuery || null,
        result_count: resultCount || 0,
        latency_ms: latencyMs || 0,
        source: source || 'unknown',
        device_id: deviceId || null,
    });

    // Flush immediately if buffer is full
    if (_writeBuffer.length >= MAX_BUFFER_SIZE) {
        flushBuffer();
    }
}

// ══════════════════════════════════════════════════════════════════════════════
//  CLICK TRACKING
// ══════════════════════════════════════════════════════════════════════════════

/**
 * Log a click event from search results.
 * Fire-and-forget.
 *
 * @param {object} params
 * @param {string} params.searchQuery — the query that produced the results
 * @param {number} params.productId — which product was clicked
 * @param {number} [params.position] — position in the result list (1-indexed)
 * @param {string} [params.deviceId]
 */
function logClick({ searchQuery, productId, position, deviceId }) {
    supabase
        .from('click_events')
        .insert([{
            search_query: searchQuery || '',
            product_id: productId,
            position: position || null,
            device_id: deviceId || null,
        }])
        .then(() => {})
        .catch(() => {});
}

// ══════════════════════════════════════════════════════════════════════════════
//  CONVERSION TRACKING
// ══════════════════════════════════════════════════════════════════════════════

/**
 * Log a conversion (purchase / add-to-cart that followed a search).
 * Fire-and-forget.
 *
 * @param {object} params
 * @param {string} params.searchQuery
 * @param {number} params.productId
 * @param {string} [params.deviceId]
 * @param {string} [params.conversionType='purchase']
 */
function logConversion({ searchQuery, productId, deviceId, conversionType }) {
    supabase
        .from('search_conversions')
        .insert([{
            search_query: searchQuery || '',
            product_id: productId,
            device_id: deviceId || null,
            conversion_type: conversionType || 'purchase',
        }])
        .then(() => {})
        .catch(() => {});
}

// ══════════════════════════════════════════════════════════════════════════════
//  TRENDING QUERIES (from search_analytics — legacy, kept for backward compat)
// ══════════════════════════════════════════════════════════════════════════════

/**
 * Fetch trending queries (top searches in the last 24 hours).
 * @param {number} [limit=10]
 * @returns {Promise<Array<{query: string, count: number}>>}
 */
async function getTrendingQueries(limit = 10) {
    const cacheKey = 'analytics:trending';
    const cached = await cacheService.get(cacheKey);
    if (cached) return cached;

    try {
        const since = new Date(Date.now() - 24 * 60 * 60 * 1000).toISOString();

        const { data, error } = await supabase
            .from('search_analytics')
            .select('query')
            .gte('created_at', since)
            .order('created_at', { ascending: false })
            .limit(200);

        if (error || !data) return [];

        const counts = {};
        for (const row of data) {
            const q = row.query.toLowerCase().trim();
            if (q.length >= 2) {
                counts[q] = (counts[q] || 0) + 1;
            }
        }

        const trending = Object.entries(counts)
            .sort((a, b) => b[1] - a[1])
            .slice(0, limit)
            .map(([query, count]) => ({ query, count }));

        await cacheService.set(cacheKey, trending, 600);

        return trending;
    } catch {
        return [];
    }
}

// ══════════════════════════════════════════════════════════════════════════════
//  METRICS & DIAGNOSTICS
// ══════════════════════════════════════════════════════════════════════════════

/**
 * Get search performance metrics for the last N hours.
 * Cached for 15 minutes.
 *
 * @param {number} [hours=24]
 * @returns {Promise<object>}
 */
async function getMetrics(hours = 24) {
    const cacheKey = `metrics:${hours}h`;
    const cached = await cacheService.get(cacheKey);
    if (cached) return cached;

    try {
        const since = new Date(Date.now() - hours * 60 * 60 * 1000).toISOString();

        const { data, error } = await supabase
            .from('search_analytics')
            .select('query, result_count, latency_ms, source')
            .gte('created_at', since)
            .order('created_at', { ascending: false })
            .limit(1000);

        if (error || !data || data.length === 0) {
            return { totalSearches: 0, avgLatency: 0, zeroResultRate: 0, cacheHitRate: 0 };
        }

        const totalSearches = data.length;
        const avgLatency = Math.round(data.reduce((s, d) => s + (d.latency_ms || 0), 0) / totalSearches);
        const zeroResults = data.filter(d => d.result_count === 0).length;
        const cacheHits = data.filter(d => d.source === 'cache').length;

        // Source distribution
        const sourceDistribution = {};
        for (const d of data) {
            sourceDistribution[d.source || 'unknown'] = (sourceDistribution[d.source || 'unknown'] || 0) + 1;
        }

        // Failed queries (0 results)
        const failedQueries = {};
        for (const d of data) {
            if (d.result_count === 0) {
                const q = d.query.toLowerCase().trim();
                failedQueries[q] = (failedQueries[q] || 0) + 1;
            }
        }
        const topFailedQueries = Object.entries(failedQueries)
            .sort((a, b) => b[1] - a[1])
            .slice(0, 10)
            .map(([query, count]) => ({ query, count }));

        // Latency buckets
        const latencyBuckets = { '<100ms': 0, '100-300ms': 0, '300-500ms': 0, '500ms+': 0 };
        for (const d of data) {
            const ms = d.latency_ms || 0;
            if (ms < 100) latencyBuckets['<100ms']++;
            else if (ms < 300) latencyBuckets['100-300ms']++;
            else if (ms < 500) latencyBuckets['300-500ms']++;
            else latencyBuckets['500ms+']++;
        }

        const metrics = {
            totalSearches,
            avgLatency,
            zeroResultRate: Math.round((zeroResults / totalSearches) * 100) / 100,
            cacheHitRate: Math.round((cacheHits / totalSearches) * 100) / 100,
            sourceDistribution,
            topFailedQueries,
            latencyBuckets,
        };

        await cacheService.set(cacheKey, metrics, 900); // 15 min

        return metrics;
    } catch (err) {
        console.warn('Metrics calculation failed:', err.message);
        return { totalSearches: 0, avgLatency: 0 };
    }
}

/**
 * Get conversion scores per product (how often a product is purchased after search).
 * @returns {Promise<object>} — product_id → conversion_count
 */
async function getConversionScores() {
    const cacheKey = 'analytics:conversions';
    const cached = await cacheService.get(cacheKey);
    if (cached) return cached;

    try {
        const { data } = await supabase
            .from('search_conversions')
            .select('product_id')
            .limit(500);

        const counts = {};
        if (data) {
            for (const row of data) {
                counts[row.product_id] = (counts[row.product_id] || 0) + 1;
            }
        }

        await cacheService.set(cacheKey, counts, 1800); // 30 min
        return counts;
    } catch {
        return {};
    }
}

module.exports = {
    log,
    logClick,
    logConversion,
    getTrendingQueries,
    getMetrics,
    getConversionScores,
    flushBuffer,
};
