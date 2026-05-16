/**
 * rankingEngine.js
 *
 * Adaptive 9-signal product ranking engine.
 * Combines:
 *   1. Semantic similarity
 *   2. Keyword/text relevance
 *   3. Personalization score
 *   4. Trending score
 *   5. Popularity (purchase frequency)
 *   6. Conversion score
 *   7. Stock/inventory availability
 *   8. Category + intent match
 *   9. Freshness
 *
 * Plus: color/style intent bonuses and budget multiplier.
 */

const { distance } = require('fastest-levenshtein');

// ── Adaptive Weights ──────────────────────────────────────────────────────────
// These weights can shift based on context (e.g., personalized queries
// get more personalization weight, new-user queries use more popularity).
const BASE_WEIGHTS = {
    semanticSimilarity: 0.22,
    textRelevance:      0.15,
    personalization:    0.15,
    trending:           0.08,
    popularity:         0.08,
    conversion:         0.07,
    stockAvailability:  0.10,
    categoryMatch:      0.10,
    freshness:          0.05,
};

/**
 * Adapt weights based on context.
 * - If user has a profile, boost personalization weight.
 * - If user is new (no profile), boost popularity + trending weights.
 * - If there's a strong category intent, boost category weight.
 */
function adaptWeights(hasProfile, intent) {
    const w = { ...BASE_WEIGHTS };

    if (hasProfile) {
        // Known user: personalization matters more
        w.personalization = 0.20;
        w.popularity = 0.05;
        w.trending = 0.05;
        // Rebalance
        w.semanticSimilarity = 0.20;
        w.textRelevance = 0.13;
    } else {
        // New user: lean on crowd wisdom
        w.personalization = 0.02;
        w.popularity = 0.14;
        w.trending = 0.14;
        w.semanticSimilarity = 0.22;
        w.textRelevance = 0.16;
    }

    if (intent && intent.category) {
        // Strong category intent: boost category match
        w.categoryMatch = 0.15;
        w.textRelevance = Math.max(w.textRelevance - 0.03, 0.05);
        w.freshness = 0.02;
    }

    return w;
}

// ══════════════════════════════════════════════════════════════════════════════
//  INDIVIDUAL SCORING FUNCTIONS
// ══════════════════════════════════════════════════════════════════════════════

/** Text relevance: name match is 2x, description match is 1x. */
function scoreTextRelevance(product, queryTokens) {
    if (!queryTokens || queryTokens.length === 0) return 0;

    const name = (product.name || '').toLowerCase();
    const desc = (product.description || '').toLowerCase();

    let matchCount = 0;
    for (const token of queryTokens) {
        if (name.includes(token)) matchCount += 2;
        else if (desc.includes(token)) matchCount += 1;
    }

    const maxPossible = queryTokens.length * 2;
    return Math.min(matchCount / maxPossible, 1);
}

/** Stock availability score. Out-of-stock gets 0.1 penalty, not zero. */
function scoreStock(product) {
    const stock = product.stock ?? 0;
    if (stock <= 0) return 0.1;
    if (stock >= 50) return 1.0;
    return 0.1 + (stock / 50) * 0.9;
}

/** Category match against detected intent. */
function scoreCategoryMatch(product, intent) {
    if (!intent || !intent.category) return 0.5;
    const productCat = (product.category || '').toLowerCase();
    const intentCat = intent.category.toLowerCase();
    return productCat === intentCat ? 1.0 : 0.0;
}

/** Tag overlap between query tokens and product tags. */
function scoreTagRelevance(product, queryTokens) {
    const tags = (product.tags || []).map(t => t.toLowerCase());
    if (tags.length === 0 || queryTokens.length === 0) return 0;

    let matchCount = 0;
    for (const token of queryTokens) {
        for (const tag of tags) {
            if (tag.includes(token) || token.includes(tag)) {
                matchCount++;
                break;
            }
        }
    }

    return Math.min(matchCount / queryTokens.length, 1);
}

/** Freshness: products <7 days old get full score, decays over 90 days. */
function scoreFreshness(product) {
    if (!product.created_at) return 0.5;

    const ageMs = Date.now() - new Date(product.created_at).getTime();
    const ageDays = ageMs / (1000 * 60 * 60 * 24);

    if (ageDays <= 7) return 1.0;
    if (ageDays >= 90) return 0.1;
    return 1.0 - ((ageDays - 7) / 83) * 0.9;
}

/** Popularity from order/purchase counts. */
function scorePopularity(product, popularityCounts = {}) {
    const count = popularityCounts[product.id] || 0;
    if (count > 0) return Math.min(count / 10, 1);
    return scoreStock(product) * 0.3; // Weak fallback
}

/** Trending score for a product. */
function scoreTrending(product, trendingScores = {}) {
    const score = trendingScores[product.id] || 0;
    if (score <= 0) return 0;
    // Normalize: score of 20+ is max
    return Math.min(score / 20, 1);
}

/** Conversion score: how often this product converts from search. */
function scoreConversion(product, conversionCounts = {}) {
    const count = conversionCounts[product.id] || 0;
    if (count <= 0) return 0;
    // Normalize: 5+ conversions is max
    return Math.min(count / 5, 1);
}

/** Color/style intent bonus. */
function scoreIntentBonus(product, intent) {
    let bonus = 0;
    const name = (product.name || '').toLowerCase();
    const desc = (product.description || '').toLowerCase();
    const tags = (product.tags || []).map(t => t.toLowerCase());
    const allText = name + ' ' + desc + ' ' + tags.join(' ');

    if (intent.color && allText.includes(intent.color)) bonus += 0.08;
    if (intent.style && allText.includes(intent.style)) bonus += 0.07;

    return bonus;
}

/** Budget penalty multiplier. */
function budgetMultiplier(product, intent) {
    if (!intent || !intent.budget) return 1.0;

    const price = product.price || 0;
    const budget = intent.budget;

    if (budget.type === 'max' && price > budget.value) return 0.3;
    if (budget.type === 'range') {
        if (price < budget.min || price > budget.max) return 0.4;
    }
    if (budget.type === 'budget' && price > 100) return 0.5;
    if (budget.type === 'premium' && price < 50) return 0.5;

    return 1.0;
}

// ══════════════════════════════════════════════════════════════════════════════
//  MAIN RANKING FUNCTION
// ══════════════════════════════════════════════════════════════════════════════

/**
 * Rank products with adaptive 9-signal scoring.
 *
 * @param {Array} products
 * @param {object} intent — from queryProcessor.detectIntent()
 * @param {string} query — processed query string
 * @param {object} [signals={}] — external scoring signals
 * @param {object} [signals.popularityCounts] — product_id → order count
 * @param {object} [signals.trendingScores] — product_id → trending score
 * @param {object} [signals.conversionCounts] — product_id → conversion count
 * @param {object} [signals.userProfile] — from personalizationEngine.buildUserProfile()
 * @returns {Array} sorted products with _score attached
 */
function rank(products, intent, query, signals = {}) {
    if (!products || products.length === 0) return [];

    const {
        popularityCounts = {},
        trendingScores = {},
        conversionCounts = {},
        userProfile = null,
    } = signals;

    const queryTokens = (query || '').split(' ').filter(t => t.length >= 2);
    const hasProfile = !!userProfile;
    const weights = adaptWeights(hasProfile, intent);

    // Import personalization scoring inline (avoids circular deps)
    let scorePersonalization;
    try {
        const pe = require('./personalizationEngine');
        scorePersonalization = pe.scorePersonalization;
    } catch {
        scorePersonalization = () => 0;
    }

    const scored = products.map(product => {
        // 9 core signals
        const semantic     = product._similarity || product.similarity || 0;
        const text         = scoreTextRelevance(product, queryTokens);
        const personal     = userProfile ? scorePersonalization(product, userProfile) : 0;
        const trending     = scoreTrending(product, trendingScores);
        const popular      = scorePopularity(product, popularityCounts);
        const conversion   = scoreConversion(product, conversionCounts);
        const stock        = scoreStock(product);
        const category     = scoreCategoryMatch(product, intent);
        const fresh        = scoreFreshness(product);

        // Weighted composite
        let score =
            semantic   * weights.semanticSimilarity +
            text       * weights.textRelevance +
            personal   * weights.personalization +
            trending   * weights.trending +
            popular    * weights.popularity +
            conversion * weights.conversion +
            stock      * weights.stockAvailability +
            category   * weights.categoryMatch +
            fresh      * weights.freshness;

        // Tag relevance adds on top (not weighted separately to keep 9 clean signals)
        score += scoreTagRelevance(product, queryTokens) * 0.05;

        // Intent bonuses
        score += scoreIntentBonus(product, intent);

        // Budget multiplier
        score *= budgetMultiplier(product, intent);

        return {
            ...product,
            _score: Math.round(score * 1000) / 1000,
            _debug: {
                semantic:   Math.round(semantic * 100) / 100,
                text:       Math.round(text * 100) / 100,
                personal:   Math.round(personal * 100) / 100,
                trending:   Math.round(trending * 100) / 100,
                popular:    Math.round(popular * 100) / 100,
                conversion: Math.round(conversion * 100) / 100,
                stock:      Math.round(stock * 100) / 100,
                category:   Math.round(category * 100) / 100,
                fresh:      Math.round(fresh * 100) / 100,
                weights:    hasProfile ? 'personalized' : 'default',
            },
        };
    });

    scored.sort((a, b) => b._score - a._score);

    return scored;
}

module.exports = { rank, BASE_WEIGHTS, adaptWeights };
