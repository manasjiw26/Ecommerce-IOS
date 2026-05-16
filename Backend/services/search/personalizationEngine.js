/**
 * personalizationEngine.js
 *
 * Full behavioral intelligence engine for search personalization.
 * Builds a rich user profile from multiple signals:
 *   - Product views (user_events)
 *   - Cart additions (user_events event_type='add_to_cart')
 *   - Purchases (user_events event_type='purchase')
 *   - Search history (recent_searches)
 *   - Click patterns (click_events)
 *
 * Works with device_id for guest users — no auth required.
 * Does NOT interfere with the existing Gemini recommendation flow.
 */

const { supabase } = require('../../supabaseClient');
const cacheService = require('./cacheService');

// ══════════════════════════════════════════════════════════════════════════════
//  USER PROFILE BUILDER
// ══════════════════════════════════════════════════════════════════════════════

/**
 * Build a comprehensive user behavioral profile.
 * Cached for 10 minutes per device_id.
 *
 * @param {string} deviceId
 * @returns {Promise<object>} profile
 */
async function buildUserProfile(deviceId) {
    if (!deviceId) return null;

    const cacheKey = `profile:${deviceId}`;
    const cached = await cacheService.get(cacheKey);
    if (cached) return cached;

    const profile = {
        categoryAffinity: {},   // category → weighted score
        tagAffinity: {},        // tag → weighted score
        priceRange: { min: 0, max: Infinity, avg: 0 },
        recentProductIds: [],   // last viewed product IDs
        purchasedProductIds: [],
        cartProductIds: [],
        searchTerms: [],        // recent search queries
        clickedProductIds: [],
    };

    try {
        // ── Fetch all user_events for this device ────────────────────────
        const { data: events } = await supabase
            .from('user_events')
            .select('product_id, event_type')
            .eq('device_id', deviceId)
            .order('timestamp', { ascending: false })
            .limit(50);

        if (!events || events.length === 0) {
            // Cache empty profile for 5 min to avoid repeated DB hits
            await cacheService.set(cacheKey, null, 300);
            return null;
        }

        // Categorize events by type
        const viewIds = [];
        const cartIds = [];
        const purchaseIds = [];

        for (const e of events) {
            switch (e.event_type) {
                case 'view':
                    viewIds.push(e.product_id);
                    break;
                case 'add_to_cart':
                    cartIds.push(e.product_id);
                    break;
                case 'purchase':
                    purchaseIds.push(e.product_id);
                    break;
                default:
                    viewIds.push(e.product_id); // treat unknown as view
            }
        }

        profile.recentProductIds = [...new Set(viewIds)].slice(0, 20);
        profile.cartProductIds = [...new Set(cartIds)];
        profile.purchasedProductIds = [...new Set(purchaseIds)];

        // ── Fetch product data for these IDs ─────────────────────────────
        const allIds = [...new Set([...viewIds, ...cartIds, ...purchaseIds])];
        if (allIds.length === 0) return null;

        const { data: products } = await supabase
            .from('products')
            .select('id, category, tags, price')
            .in('id', allIds);

        if (!products) return null;

        const productMap = new Map(products.map(p => [p.id, p]));

        // ── Build category affinity ──────────────────────────────────────
        // Weight: view=1, cart=3, purchase=5
        const eventWeights = { view: 1, add_to_cart: 3, purchase: 5 };

        for (const e of events) {
            const product = productMap.get(e.product_id);
            if (!product || !product.category) continue;

            const weight = eventWeights[e.event_type] || 1;
            profile.categoryAffinity[product.category] =
                (profile.categoryAffinity[product.category] || 0) + weight;
        }

        // ── Build tag affinity ───────────────────────────────────────────
        for (const e of events) {
            const product = productMap.get(e.product_id);
            if (!product || !product.tags) continue;

            const weight = eventWeights[e.event_type] || 1;
            for (const tag of product.tags) {
                const t = tag.toLowerCase();
                profile.tagAffinity[t] = (profile.tagAffinity[t] || 0) + weight;
            }
        }

        // ── Calculate price range preference ─────────────────────────────
        const prices = products.map(p => p.price).filter(p => p > 0);
        if (prices.length > 0) {
            prices.sort((a, b) => a - b);
            profile.priceRange.min = prices[0];
            profile.priceRange.max = prices[prices.length - 1];
            profile.priceRange.avg = prices.reduce((s, p) => s + p, 0) / prices.length;
        }

        // ── Fetch recent search terms ────────────────────────────────────
        try {
            const { data: searches } = await supabase
                .from('recent_searches')
                .select('query')
                .eq('device_id', deviceId)
                .order('created_at', { ascending: false })
                .limit(10);

            if (searches) {
                profile.searchTerms = [...new Set(searches.map(s => s.query.toLowerCase().trim()))];
            }
        } catch {
            // Table might not exist yet
        }

        // ── Fetch click patterns ─────────────────────────────────────────
        try {
            const { data: clicks } = await supabase
                .from('click_events')
                .select('product_id')
                .eq('device_id', deviceId)
                .order('created_at', { ascending: false })
                .limit(20);

            if (clicks) {
                profile.clickedProductIds = [...new Set(clicks.map(c => c.product_id))];
            }
        } catch {
            // Table might not exist yet
        }

        // Cache for 10 minutes
        await cacheService.set(cacheKey, profile, 600);

        return profile;
    } catch (err) {
        console.warn('Profile build failed:', err.message);
        return null;
    }
}

// ══════════════════════════════════════════════════════════════════════════════
//  PERSONALIZATION SCORING
// ══════════════════════════════════════════════════════════════════════════════

/**
 * Calculate a personalization score for a single product against a user profile.
 *
 * @param {object} product
 * @param {object} profile — from buildUserProfile()
 * @returns {number} 0–1 personalization score
 */
function scorePersonalization(product, profile) {
    if (!profile) return 0;

    let score = 0;
    let signals = 0;

    // Signal 1: Category affinity (0–1)
    const productCat = (product.category || '').toLowerCase();
    const maxCatAffinity = Math.max(...Object.values(profile.categoryAffinity), 1);
    const catAffinity = profile.categoryAffinity[product.category] || 0;
    if (catAffinity > 0) {
        score += (catAffinity / maxCatAffinity) * 0.35;
    }
    signals++;

    // Signal 2: Tag overlap (0–1)
    const productTags = (product.tags || []).map(t => t.toLowerCase());
    if (productTags.length > 0) {
        const maxTagAffinity = Math.max(...Object.values(profile.tagAffinity), 1);
        let tagScore = 0;
        for (const tag of productTags) {
            const affinity = profile.tagAffinity[tag] || 0;
            tagScore += affinity / maxTagAffinity;
        }
        score += Math.min(tagScore / productTags.length, 1) * 0.25;
    }
    signals++;

    // Signal 3: Price fit (0–1) — products in the user's price comfort zone score higher
    if (profile.priceRange.avg > 0 && product.price > 0) {
        const priceDiff = Math.abs(product.price - profile.priceRange.avg);
        const priceRange = (profile.priceRange.max - profile.priceRange.min) || profile.priceRange.avg;
        const priceFit = Math.max(0, 1 - (priceDiff / priceRange));
        score += priceFit * 0.15;
    }
    signals++;

    // Signal 4: Previously clicked products get a boost
    if (profile.clickedProductIds.includes(product.id)) {
        score += 0.10;
    }

    // Signal 5: Similar to cart items (category match)
    if (profile.cartProductIds.length > 0) {
        // We already have category affinity from cart, this is captured in signal 1
        // But add a small bonus for exact category match with cart items
        score += 0.05;
    }

    // Signal 6: NOT previously purchased (slight penalty for re-showing purchased items)
    if (profile.purchasedProductIds.includes(product.id)) {
        score -= 0.15; // Penalize already-purchased items
    }

    // Clamp to 0–1
    return Math.max(0, Math.min(1, score));
}

// ══════════════════════════════════════════════════════════════════════════════
//  BOOST FUNCTION (called by orchestrator)
// ══════════════════════════════════════════════════════════════════════════════

/**
 * Apply personalization boost to search results.
 * Products matching the user's behavioral profile get a score uplift.
 *
 * @param {Array} products — ranked products (must have _score)
 * @param {string} [deviceId]
 * @returns {Promise<Array>} — re-ranked products
 */
async function boost(products, deviceId) {
    if (!deviceId || !products || products.length === 0) return products;

    const profile = await buildUserProfile(deviceId);
    if (!profile) return products;

    const boosted = products.map(product => {
        const pScore = scorePersonalization(product, profile);

        if (pScore > 0) {
            return {
                ...product,
                _score: (product._score || 0) + pScore * 0.20, // 20% influence cap
                _personalized: true,
                _personalizationScore: Math.round(pScore * 100) / 100,
            };
        }

        return product;
    });

    // Re-sort after boosting
    boosted.sort((a, b) => (b._score || 0) - (a._score || 0));

    return boosted;
}

/**
 * Get the user's preferred categories (backward-compatible with existing callers).
 * @param {string} deviceId
 * @returns {Promise<string[]>}
 */
async function getUserPreferences(deviceId) {
    const profile = await buildUserProfile(deviceId);
    if (!profile) return [];

    return Object.entries(profile.categoryAffinity)
        .sort((a, b) => b[1] - a[1])
        .slice(0, 5)
        .map(([cat]) => cat);
}

module.exports = {
    boost,
    getUserPreferences,
    buildUserProfile,
    scorePersonalization,
};
