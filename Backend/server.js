require('dotenv').config();
const express = require('express');
const cors = require('cors');

const app = express();
const PORT = process.env.PORT || 3000;

const path = require('path');

// Middleware
app.use(cors());
app.use(express.json());

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

const { supabase } = require('./supabaseClient');

// Ensure orders table has the required columns (run once on startup)
async function runMigrations() {
    try {
        // Try inserting a test order with new fields; if it errors the column doesn't exist
        const testCols = ['items_summary', 'image_url', 'payment_id'];
        for (const col of testCols) {
            const { error } = await supabase.rpc('add_column_if_not_exists', {
                p_table: 'orders', p_column: col, p_type: 'text', p_default: "''"
            });
            if (error) {
                // RPC might not exist — silently continue, user must run SQL manually
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
