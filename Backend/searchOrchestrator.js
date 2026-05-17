// ========== FILE: searchOrchestrator.js ==========
const { supabase } = require('./supabaseClient');

let embedderPromise = null;
async function getEmbedder() {
    if (!embedderPromise) {
        embedderPromise = (async () => {
            const transformers = await import('@xenova/transformers');
            return transformers.pipeline('feature-extraction', 'Xenova/all-MiniLM-L6-v2');
        })();
    }
    return embedderPromise;
}

async function getLocalEmbedding(text) {
    const embedder = await getEmbedder();
    const output = await embedder(text, { pooling: 'mean', normalize: true });
    return Array.from(output.data);
}

async function searchOrchestrator(query, matchCount = 20) {
    const q = (query || '').trim();
    if (!q) return [];

    try {
        const queryEmbedding = await getLocalEmbedding(q);
        const { data, error } = await supabase.rpc('hybrid_search', {
            query_text: q,
            query_embedding: queryEmbedding,
            match_count: matchCount
        });
        if (error) throw error;
        return data || [];
    } catch (e) {
        const fallbackQuery = `%${q}%`;
        const { data: fallbackData, error: fallbackError } = await supabase
            .from('products')
            .select('*')
            .or(`name.ilike.${fallbackQuery},description.ilike.${fallbackQuery},category.ilike.${fallbackQuery}`)
            .order('stock', { ascending: false })
            .limit(matchCount);
        if (fallbackError) throw fallbackError;
        return fallbackData || [];
    }
}

module.exports = { searchOrchestrator };
