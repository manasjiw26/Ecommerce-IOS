-- Enable the pgvector extension for AI semantic search
CREATE EXTENSION IF NOT EXISTS vector;

-- Table to store AI chat history for each user
CREATE TABLE IF NOT EXISTS chat_sessions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    device_id TEXT NOT NULL, -- using device_id to support guest users
    messages JSONB DEFAULT '[]'::jsonb,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Table to store product embeddings (powers visual search & semantic search)
CREATE TABLE IF NOT EXISTS product_embeddings (
    product_id INT PRIMARY KEY REFERENCES products(id),
    embedding vector(1536)
);

-- Table for user wishlists
CREATE TABLE IF NOT EXISTS wishlists (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    device_id TEXT NOT NULL,
    product_id INT REFERENCES products(id),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(device_id, product_id)
);

-- Table to store AI-generated insights about a user's style/taste
CREATE TABLE IF NOT EXISTS user_profiles (
    device_id TEXT PRIMARY KEY,
    preferences JSONB DEFAULT '{}'::jsonb,
    style_tags TEXT[],
    last_updated TIMESTAMPTZ DEFAULT NOW()
);
