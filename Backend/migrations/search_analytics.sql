-- ══════════════════════════════════════════════════════════════════════════════
--  SEARCH ANALYTICS SCHEMA — Hearth & Table
--  Run this in your Supabase SQL Editor to enable all analytics features.
-- ══════════════════════════════════════════════════════════════════════════════

-- Search Analytics Table (core search logging)
CREATE TABLE IF NOT EXISTS search_analytics (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    query TEXT NOT NULL,
    corrected_query TEXT,
    clicked_product_id INT,
    result_count INT DEFAULT 0,
    latency_ms INT,
    source TEXT,       -- 'semantic', 'keyword', 'fuzzy', 'tags', 'trending', 'cache'
    user_id UUID,
    device_id TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_search_analytics_query ON search_analytics(query);
CREATE INDEX IF NOT EXISTS idx_search_analytics_created ON search_analytics(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_search_analytics_device ON search_analytics(device_id);

-- Recent Searches Table
CREATE TABLE IF NOT EXISTS recent_searches (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    query TEXT NOT NULL,
    user_id UUID,
    device_id TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_recent_searches_device ON recent_searches(device_id);
CREATE INDEX IF NOT EXISTS idx_recent_searches_created ON recent_searches(created_at DESC);

-- Trending Searches Table (materialized scores, updated periodically)
CREATE TABLE IF NOT EXISTS trending_searches (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    query TEXT NOT NULL UNIQUE,
    score INT DEFAULT 0,
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_trending_searches_score ON trending_searches(score DESC);

-- Click Events Table (tracks what users click from search results)
CREATE TABLE IF NOT EXISTS click_events (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    search_query TEXT NOT NULL,
    product_id INT NOT NULL,
    position INT,          -- position in the result list (1-indexed)
    device_id TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_click_events_product ON click_events(product_id);
CREATE INDEX IF NOT EXISTS idx_click_events_device ON click_events(device_id);
CREATE INDEX IF NOT EXISTS idx_click_events_created ON click_events(created_at DESC);

-- Search Conversions Table (tracks purchases that followed a search)
CREATE TABLE IF NOT EXISTS search_conversions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    search_query TEXT NOT NULL,
    product_id INT NOT NULL,
    device_id TEXT,
    conversion_type TEXT DEFAULT 'purchase', -- 'purchase', 'add_to_cart', 'wishlist'
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_conversions_product ON search_conversions(product_id);
CREATE INDEX IF NOT EXISTS idx_conversions_query ON search_conversions(search_query);
CREATE INDEX IF NOT EXISTS idx_conversions_created ON search_conversions(created_at DESC);
