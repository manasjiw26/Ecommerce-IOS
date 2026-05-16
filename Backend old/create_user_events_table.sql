-- Create the user_events table to track user behavior for the AI Recommendation Engine
CREATE TABLE IF NOT EXISTS user_events (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    device_id TEXT NOT NULL,
    product_id INT REFERENCES products(id),
    event_type TEXT NOT NULL, -- e.g., 'view', 'add_to_cart', 'purchase'
    timestamp TIMESTAMPTZ DEFAULT NOW()
);
