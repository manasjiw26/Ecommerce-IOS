/**
 * cacheService.js
 * 
 * Dual-backend caching: Redis (if REDIS_URL set) or in-memory LRU fallback.
 * Callers interact through get/set/invalidate — backend is transparent.
 */

const { LRUCache } = require('lru-cache');

// ── In-Memory LRU (always available) ──────────────────────────────────────────
const memoryCache = new LRUCache({
    max: 256,
    ttl: 5 * 60 * 1000, // 5 minutes default
});

// ── Redis (optional) ──────────────────────────────────────────────────────────
let redis = null;
let redisReady = false;

if (process.env.REDIS_URL) {
    try {
        const Redis = require('ioredis');
        redis = new Redis(process.env.REDIS_URL, {
            maxRetriesPerRequest: 2,
            connectTimeout: 3000,
            lazyConnect: true,
        });

        redis.connect().then(() => {
            redisReady = true;
            console.log('✅  Redis cache connected');
        }).catch(err => {
            console.warn('⚠️  Redis connection failed, using in-memory cache:', err.message);
            redis = null;
        });

        redis.on('error', () => {
            // Silently degrade — LRU takes over
            redisReady = false;
        });

        redis.on('ready', () => {
            redisReady = true;
        });
    } catch (err) {
        console.warn('⚠️  ioredis not installed, using in-memory cache only');
    }
} else {
    console.log('ℹ️  No REDIS_URL set — using in-memory LRU cache');
}

// ── Public API ────────────────────────────────────────────────────────────────

/**
 * Get a cached value by key.
 * @param {string} key
 * @returns {Promise<any|null>}
 */
async function get(key) {
    try {
        // Try Redis first
        if (redisReady && redis) {
            const val = await redis.get(key);
            if (val) return JSON.parse(val);
        }

        // Fallback to LRU
        const memVal = memoryCache.get(key);
        return memVal || null;
    } catch {
        // Any error → treat as cache miss
        return null;
    }
}

/**
 * Set a cached value.
 * @param {string} key
 * @param {any} data — will be JSON-serialized
 * @param {number} [ttlSeconds=300] — time-to-live in seconds
 */
async function set(key, data, ttlSeconds = 300) {
    try {
        const serialized = JSON.stringify(data);

        // Write to both backends for consistency
        memoryCache.set(key, data, { ttl: ttlSeconds * 1000 });

        if (redisReady && redis) {
            await redis.set(key, serialized, 'EX', ttlSeconds);
        }
    } catch {
        // Cache write failure is non-critical
    }
}

/**
 * Invalidate cache entries matching a pattern.
 * @param {string} pattern — e.g. 'search:*'
 */
async function invalidate(pattern) {
    try {
        // Clear all LRU entries (no pattern support in lru-cache)
        memoryCache.clear();

        if (redisReady && redis) {
            const keys = await redis.keys(pattern);
            if (keys.length > 0) {
                await redis.del(...keys);
            }
        }
    } catch {
        // Non-critical
    }
}

/**
 * Check if cache backend is available.
 * @returns {{ redis: boolean, memory: boolean }}
 */
function status() {
    return {
        redis: redisReady,
        memory: true,
        entries: memoryCache.size,
    };
}

module.exports = { get, set, invalidate, status };
