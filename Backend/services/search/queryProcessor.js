/**
 * queryProcessor.js
 *
 * Full query preprocessing pipeline:
 *   normalize → spellCorrect → expandSynonyms → detectIntent
 */

const { distance } = require('fastest-levenshtein');

// ── SYNONYM MAP ───────────────────────────────────────────────────────────────
// Keys are what users might type; values are canonical terms in our catalog.
const SYNONYM_MAP = {
    // Furniture
    'couch': 'sofa',
    'settee': 'sofa',
    'loveseat': 'sofa',
    'tv unit': 'entertainment center',
    'tv stand': 'entertainment center',
    'wardrobe': 'closet',
    'bureau': 'dresser',
    'nightstand': 'bedside table',

    // Kitchen & Dining
    'pan': 'fry pan',
    'skillet': 'fry pan',
    'pot': 'dutch oven',
    'mug': 'cup',
    'glass': 'drinkware',
    'goblet': 'wine glass',
    'tumbler': 'glass',
    'flatware': 'silverware',
    'utensils': 'kitchen tools',
    'cutlery': 'knife',
    'chopping board': 'cutting board',

    // Decor & Lighting
    'lamp': 'light',
    'fixture': 'light',
    'candle holder': 'candlestick',
    'throw': 'blanket',
    'cushion': 'pillow',
    'rug': 'carpet',
    'drapes': 'curtains',
    'blinds': 'curtains',

    // Apparel / Textiles
    'hoodie': 'sweatshirt',
    'sneakers': 'shoes',
    'trainers': 'shoes',
    'napkin': 'linen',
    'towel': 'kitchen linen',
    'apron': 'kitchen linen',
    'tablecloth': 'table linen',
    'placemat': 'table linen',

    // Beverages
    'espresso': 'coffee',
    'latte': 'coffee',
    'brew': 'coffee',
    'kettle': 'tea',
    'teapot': 'tea',
    'french press': 'coffee maker',

    // Generic
    'cheap': 'affordable',
    'expensive': 'premium',
    'big': 'large',
    'small': 'compact',
    'tiny': 'compact',
};

// Category aliases — map common terms to actual DB category names
const CATEGORY_ALIASES = {
    'plates': 'Dinnerware',
    'dishes': 'Dinnerware',
    'bowls': 'Dinnerware',
    'pots': 'Cookware',
    'pans': 'Cookware',
    'skillets': 'Cookware',
    'frying pan': 'Cookware',
    'dutch oven': 'Cookware',
    'knife': 'Cutlery',
    'knives': 'Cutlery',
    'forks': 'Flatware',
    'spoons': 'Flatware',
    'silverware': 'Flatware',
    'glasses': 'Barware',
    'wine': 'Barware',
    'martini': 'Barware',
    'cocktail': 'Barware',
    'coffee': 'Coffee & Tea',
    'tea': 'Coffee & Tea',
    'espresso': 'Coffee & Tea',
    'serving': 'Serveware',
    'tray': 'Serveware',
    'platter': 'Serveware',
    'storage': 'Kitchen Storage',
    'container': 'Kitchen Storage',
    'jar': 'Kitchen Storage',
    'canister': 'Kitchen Storage',
    'towel': 'Kitchen Linens',
    'apron': 'Kitchen Linens',
    'napkin': 'Kitchen Linens',
    'decoration': 'Decor',
    'ornament': 'Decor',
    'vase': 'Decor',
};

// ── COLORS ────────────────────────────────────────────────────────────────────
const COLORS = [
    'white', 'black', 'red', 'blue', 'green', 'yellow', 'orange', 'pink',
    'purple', 'brown', 'gray', 'grey', 'gold', 'silver', 'beige', 'ivory',
    'navy', 'teal', 'cream', 'copper', 'bronze', 'marble', 'wood', 'natural',
];

// ── STYLES ────────────────────────────────────────────────────────────────────
const STYLES = [
    'modern', 'contemporary', 'rustic', 'vintage', 'minimalist', 'minimal',
    'industrial', 'bohemian', 'boho', 'farmhouse', 'traditional', 'classic',
    'scandinavian', 'mid-century', 'art deco', 'coastal', 'french', 'country',
    'elegant', 'luxury', 'premium', 'professional', 'handmade', 'artisan',
    'handcrafted', 'organic',
];

// ── ROOMS ─────────────────────────────────────────────────────────────────────
const ROOMS = [
    'kitchen', 'dining', 'dining room', 'living room', 'bedroom', 'bathroom',
    'office', 'patio', 'outdoor', 'garden', 'balcony', 'bar',
];

// ── BUDGET PATTERNS ───────────────────────────────────────────────────────────
const BUDGET_PATTERNS = [
    { regex: /under\s*\$?(\d+)/i, type: 'max' },
    { regex: /below\s*\$?(\d+)/i, type: 'max' },
    { regex: /less\s*than\s*\$?(\d+)/i, type: 'max' },
    { regex: /cheap|budget|affordable|inexpensive/i, type: 'budget' },
    { regex: /premium|luxury|expensive|high[\s-]end/i, type: 'premium' },
    { regex: /\$(\d+)\s*[-–to]+\s*\$?(\d+)/i, type: 'range' },
];

// ── OCCASION KEYWORDS ─────────────────────────────────────────────────────────
const OCCASIONS = [
    'wedding', 'birthday', 'christmas', 'thanksgiving', 'housewarming',
    'gift', 'party', 'holiday', 'easter', 'anniversary', 'valentine',
    'bridal', 'baby shower', 'graduation', 'mothers day', 'fathers day',
];

// ══════════════════════════════════════════════════════════════════════════════
//  1. NORMALIZE
// ══════════════════════════════════════════════════════════════════════════════

/**
 * Normalize raw user input.
 * @param {string} query
 * @returns {string}
 */
function normalize(query) {
    if (!query || typeof query !== 'string') return '';

    let q = query
        .toLowerCase()
        .trim()
        // Remove emojis and special unicode
        .replace(/[\u{1F600}-\u{1F9FF}]/gu, '')
        .replace(/[\u{2600}-\u{26FF}]/gu, '')
        .replace(/[\u{2700}-\u{27BF}]/gu, '')
        .replace(/[\u{FE00}-\u{FE0F}]/gu, '')
        .replace(/[\u{1F000}-\u{1FFFF}]/gu, '')
        // Remove punctuation except hyphens and dollar signs (for budget queries)
        .replace(/[^\w\s\-$]/g, ' ')
        // Collapse multiple spaces
        .replace(/\s+/g, ' ')
        .trim();

    // Deduplicate consecutive identical tokens
    const tokens = q.split(' ');
    const deduped = tokens.filter((t, i) => i === 0 || t !== tokens[i - 1]);
    return deduped.join(' ');
}

// ══════════════════════════════════════════════════════════════════════════════
//  2. SPELL CORRECTION
// ══════════════════════════════════════════════════════════════════════════════

// Build a dictionary from product names, categories, and tags at startup
let _dictionary = [];

/**
 * Load product vocabulary for spell correction.
 * Called once at server boot with product data.
 * @param {Array} products — array of product objects
 */
function loadDictionary(products) {
    const words = new Set();

    for (const p of products) {
        // Split product names into individual words
        if (p.name) p.name.toLowerCase().split(/\s+/).forEach(w => words.add(w));
        if (p.category) p.category.toLowerCase().split(/[\s&]+/).forEach(w => words.add(w));
        if (p.tags && Array.isArray(p.tags)) {
            p.tags.forEach(t => t.toLowerCase().split(/\s+/).forEach(w => words.add(w)));
        }
    }

    // Add all synonym keys and values
    Object.keys(SYNONYM_MAP).forEach(k => k.split(/\s+/).forEach(w => words.add(w)));
    Object.values(SYNONYM_MAP).forEach(v => v.split(/\s+/).forEach(w => words.add(w)));

    // Add colors, styles, rooms
    COLORS.forEach(c => words.add(c));
    STYLES.forEach(s => s.split(/\s+/).forEach(w => words.add(w)));
    ROOMS.forEach(r => r.split(/\s+/).forEach(w => words.add(w)));

    // Filter out very short words (likely not useful for correction)
    _dictionary = [...words].filter(w => w.length >= 3);
    console.log(`📖  Spell dictionary loaded: ${_dictionary.length} words`);
}

/**
 * Correct spelling mistakes in a query.
 * @param {string} query — normalized query
 * @returns {{ corrected: string, wasCorrected: boolean }}
 */
function spellCorrect(query) {
    if (!query || _dictionary.length === 0) return { corrected: query, wasCorrected: false };

    const tokens = query.split(' ');
    let wasCorrected = false;
    const corrected = tokens.map(token => {
        // Skip short tokens, numbers, dollar signs
        if (token.length < 3 || /^\d+$/.test(token) || token.startsWith('$')) return token;

        // Already in dictionary → no correction needed
        if (_dictionary.includes(token)) return token;

        // Find closest match
        let bestMatch = token;
        let bestDist = Infinity;

        for (const dictWord of _dictionary) {
            // Only consider words of similar length (±2 chars)
            if (Math.abs(dictWord.length - token.length) > 2) continue;

            const dist = distance(token, dictWord);

            // Normalized similarity: 1 - (distance / max_length)
            const maxLen = Math.max(token.length, dictWord.length);
            const similarity = 1 - (dist / maxLen);

            if (dist < bestDist && similarity >= 0.65) {
                bestDist = dist;
                bestMatch = dictWord;
            }
        }

        if (bestMatch !== token) {
            wasCorrected = true;
        }
        return bestMatch;
    });

    return {
        corrected: corrected.join(' '),
        wasCorrected,
    };
}

// ══════════════════════════════════════════════════════════════════════════════
//  3. SYNONYM EXPANSION
// ══════════════════════════════════════════════════════════════════════════════

/**
 * Expand query with synonyms. Returns augmented query string.
 * @param {string} query — normalized + spell-corrected query
 * @returns {{ expanded: string, synonymsApplied: string[] }}
 */
function expandSynonyms(query) {
    const synonymsApplied = [];
    let expanded = query;

    // Check multi-word synonyms first (longer keys take priority)
    const sortedKeys = Object.keys(SYNONYM_MAP).sort((a, b) => b.length - a.length);

    for (const key of sortedKeys) {
        if (expanded.includes(key)) {
            const replacement = SYNONYM_MAP[key];
            // Append the synonym rather than replacing — keeps original intent + adds canonical term
            if (!expanded.includes(replacement)) {
                expanded = expanded + ' ' + replacement;
                synonymsApplied.push(`${key}→${replacement}`);
            }
        }
    }

    return { expanded, synonymsApplied };
}

// ══════════════════════════════════════════════════════════════════════════════
//  4. INTENT DETECTION
// ══════════════════════════════════════════════════════════════════════════════

/**
 * Extract structured intent from query.
 * @param {string} query — processed query
 * @returns {object} intent
 */
function detectIntent(query) {
    const intent = {
        product: null,     // raw product search terms
        category: null,    // mapped DB category
        color: null,
        style: null,
        room: null,
        budget: null,      // { type: 'max'|'budget'|'premium'|'range', value?, min?, max? }
        occasion: null,
        tokens: [],        // all meaningful tokens for tag matching
    };

    const tokens = query.split(' ').filter(t => t.length >= 2);
    intent.tokens = tokens;

    // Color detection
    for (const color of COLORS) {
        if (query.includes(color)) {
            intent.color = color;
            break;
        }
    }

    // Style detection
    for (const style of STYLES) {
        if (query.includes(style)) {
            intent.style = style;
            break;
        }
    }

    // Room detection
    for (const room of ROOMS) {
        if (query.includes(room)) {
            intent.room = room;
            break;
        }
    }

    // Occasion detection
    for (const occasion of OCCASIONS) {
        if (query.includes(occasion)) {
            intent.occasion = occasion;
            break;
        }
    }

    // Budget detection
    for (const pattern of BUDGET_PATTERNS) {
        const match = query.match(pattern.regex);
        if (match) {
            if (pattern.type === 'max') {
                intent.budget = { type: 'max', value: parseInt(match[1]) };
            } else if (pattern.type === 'range') {
                intent.budget = { type: 'range', min: parseInt(match[1]), max: parseInt(match[2]) };
            } else {
                intent.budget = { type: pattern.type };
            }
            break;
        }
    }

    // Category detection via aliases
    for (const [alias, category] of Object.entries(CATEGORY_ALIASES)) {
        if (query.includes(alias)) {
            intent.category = category;
            break;
        }
    }

    // Product intent = remaining tokens after removing detected attributes
    const attributeWords = new Set();
    if (intent.color) intent.color.split(' ').forEach(w => attributeWords.add(w));
    if (intent.style) intent.style.split(' ').forEach(w => attributeWords.add(w));
    if (intent.room) intent.room.split(' ').forEach(w => attributeWords.add(w));
    if (intent.occasion) intent.occasion.split(' ').forEach(w => attributeWords.add(w));
    ['under', 'below', 'less', 'than', 'cheap', 'budget', 'affordable',
     'premium', 'luxury', 'expensive', 'for', 'in', 'the', 'a', 'my'].forEach(w => attributeWords.add(w));

    const productTokens = tokens.filter(t => !attributeWords.has(t) && !/^\$?\d+$/.test(t));
    if (productTokens.length > 0) {
        intent.product = productTokens.join(' ');
    }

    return intent;
}

module.exports = {
    normalize,
    spellCorrect,
    expandSynonyms,
    detectIntent,
    loadDictionary,
};
