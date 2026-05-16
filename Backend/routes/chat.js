const express = require('express');
const router = express.Router();
const { supabase } = require('../supabaseClient');
const { GoogleGenAI } = require('@google/genai');
const Groq = require('groq-sdk');

const ai = new GoogleGenAI({
    apiKey: process.env.GEMINI_API_KEY
});

const groq = new Groq({
    apiKey: process.env.GROQ_API_KEY || 'dummy' // prevent crash if not added yet
});

// POST /chat - Main LLM endpoint proxy using Groq with Gemini fallback
router.post('/', async (req, res) => {
    const { system, messages, max_tokens = 800 } = req.body;
    try {
        try {
            // Attempt Groq first
            const groqMessages = [
                { role: "system", content: system },
                ...messages.map(msg => ({
                    role: msg.role === 'assistant' ? 'assistant' : 'user',
                    content: msg.content
                }))
            ];
            
            const chatCompletion = await groq.chat.completions.create({
                messages: groqMessages,
                model: "llama-3.1-8b-instant",
                temperature: 0.7,
                max_tokens: max_tokens
            });
            
            console.log('✅ Response generated using Groq (llama-3.1-8b-instant)');
            return res.json({
                content: [{ text: chatCompletion.choices[0]?.message?.content || "" }]
            });
            
        } catch (groqError) {
            console.error('Groq Failed, falling back to Ollama Cloud API:', groqError.message);
            
            try {
                // Convert to Ollama API format
                const ollamaMessages = [
                    { role: "system", content: system },
                    ...messages.map(msg => ({
                        role: msg.role === 'assistant' ? 'assistant' : 'user',
                        content: msg.content
                    }))
                ];
                
                // Fetch requires Node 18+
                const response = await fetch('https://ai.amay.fun/api/chat', {
                    method: 'POST',
                    headers: {
                        'Content-Type': 'application/json',
                        'X-Custom-Auth': 'Janaki0510#'
                    },
                    body: JSON.stringify({
                        model: 'llama3.2:1b',
                        messages: ollamaMessages,
                        stream: false
                    })
                });
                
                if (!response.ok) {
                    throw new Error(`Ollama Cloud API failed with status ${response.status}`);
                }
                
                const data = await response.json();
                console.log('✅ Response generated using Ollama Cloud API (llama3.2:1b)');
                
                return res.json({
                    content: [{ text: data.message?.content || data.response || "" }]
                });
                
            } catch (ollamaError) {
                console.error('Ollama Failed, falling back to Gemini:', ollamaError.message);
                
                // Convert to Gemini API format
                let contents = messages.map(msg => ({
                    role: msg.role === 'assistant' ? 'model' : 'user',
                    parts: [{ text: msg.content }]
                }));

                const geminiResponse = await ai.models.generateContent({
                    model: 'gemini-2.5-flash',
                    systemInstruction: system,
                    contents: contents,
                    config: {
                        maxOutputTokens: max_tokens,
                        temperature: 0.7
                    }
                });
                console.log('✅ Response generated using Gemini (gemini-2.5-flash)');
                return res.json({
                    content: [{ text: geminiResponse.text }]
                });
            }
        }
    } catch (error) {
        console.error('LLM Chat Error:', error);
        res.status(500).json({ error: error.message });
    }
});

// Returns
router.post('/returns', async (req, res) => {
    const { order_id, payment_id, reason } = req.body;
    const { data, error } = await supabase.from('returns').insert([{ order_id, payment_id, reason }]);
    if (error) return res.status(500).json({ error: error.message });
    res.json({ success: true });
});

// Watchlist
router.post('/watchlist', async (req, res) => {
    const { device_id, product_id, threshold_price, type } = req.body;
    const { data, error } = await supabase.from('watchlist').insert([{ device_id, product_id, threshold_price, type: type || 'price_alert' }]);
    if (error) return res.status(500).json({ error: error.message });
    res.json({ success: true });
});

// Active deals
router.get('/deals/active', async (req, res) => {
    const { data, error } = await supabase.from('deals')
        .select('*, products(*)')
        .eq('is_active', true)
        .gt('expires_at', new Date().toISOString());
    if (error) return res.status(500).json({ error: error.message });
    
    const products = data.map(d => ({ ...d.products, deal_pct: d.discount_pct }));
    res.json(products);
});

// Promotions
router.get('/promotions', async (req, res) => {
    const { data, error } = await supabase.from('promotions').select('*').eq('is_active', true);
    if (error) return res.status(500).json({ error: error.message });
    res.json(data);
});

// Apply Promotion
router.post('/promotions/apply', async (req, res) => {
    const { code } = req.body;
    const { data, error } = await supabase.from('promotions').select('*').eq('code', code).eq('is_active', true).single();
    if (error || !data) return res.status(404).json({ error: 'Invalid or expired code' });
    res.json({ discount: data.discount_pct ? `${data.discount_pct}%` : `$${data.discount_fixed}`, promo: data });
});

// Loyalty points
router.get('/users/:userId/points', async (req, res) => {
    const { data, error } = await supabase.from('user_points').select('points').eq('user_id', req.params.userId).single();
    res.json({ points: data?.points ?? 0 });
});

// Chatbot feedback
router.post('/feedback', async (req, res) => {
    const { device_id, message_text, rating } = req.body;
    const { error } = await supabase.from('chatbot_feedback').insert([{ device_id, message_text, rating }]);
    if (error) return res.status(500).json({ error: error.message });
    res.json({ success: true });
});

// Reviews
router.post('/reviews', async (req, res) => {
    const { product_id, user_id, rating, body } = req.body;
    const { error } = await supabase.from('reviews').insert([{ product_id, user_id, rating, body }]);
    if (error) return res.status(500).json({ error: error.message });
    res.json({ success: true });
});

module.exports = router;
