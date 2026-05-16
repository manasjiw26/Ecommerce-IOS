require('dotenv').config();
const express = require('express');
const cors = require('cors');
const rateLimit = require('express-rate-limit');
const path = require('path');

const app = express();
const PORT = process.env.PORT || 3000;

// Middleware
app.use(cors());
app.use(express.json({ limit: '10mb' })); // Combined: 10mb limit for large payloads
app.use(express.urlencoded({ limit: '10mb', extended: true }));

// ── Rate Limiting ─────────────────────────────────────────────────────────────
// 100 requests per minute per IP for AI endpoints
const aiLimiter = rateLimit({
    windowMs: 60 * 1000,    // 1 minute
    max: 100,               // limit each IP to 100 requests per window
    standardHeaders: true,  // Return rate limit info in `RateLimit-*` headers
    legacyHeaders: false,
    message: { error: 'Too many requests. Please try again in a minute.' },
    keyGenerator: (req) => {
        return req.headers['x-forwarded-for'] || req.ip;
    },
});

// Apply rate limiter to AI endpoints
app.use('/ai', aiLimiter);

// ── Request ID ────────────────────────────────────────────────────────────────
app.use((req, res, next) => {
    req.requestId = `req_${Date.now()}_${Math.random().toString(36).substr(2, 6)}`;
    res.setHeader('X-Request-Id', req.requestId);
    next();
});

// Serve static images
app.use('/images', express.static(path.join(__dirname, 'product_images')));

// Routes
app.use('/products', require('./routes/products'));
app.use('/cart', require('./routes/cart'));
app.use('/orders', require('./routes/orders'));
app.use('/payment', require('./routes/payment'));
app.use('/auth', require('./routes/auth'));
app.use('/ai', require('./routes/ai'));
app.use('/registry', require('./routes/registry'));
app.use('/chat', require('./routes/chat'));

const { supabase } = require('./supabaseClient');

// Ensure orders table has the required columns (run once on startup)
async function runMigrations() {
    try {
        const testCols = ['items_summary', 'image_url', 'payment_id'];
        for (const col of testCols) {
            const { error } = await supabase.rpc('add_column_if_not_exists', {
                p_table: 'orders', p_column: col, p_type: 'text', p_default: "''"
            });
            if (error) {
                // RPC might not exist — silently continue
            }
        }
    } catch (_) {}
}
runMigrations();

// Health check endpoint
app.get('/', (req, res) => {
    res.json({ message: 'Welcome to ShopEase API!' });
});

app.listen(PORT, () => {
    console.log(`Server is running on port ${PORT}`);
});
