-- ========== FILE: migrations/v3_ambitious_features.sql ==========
-- Williams Sonoma AI Hackathon — v3 schema
-- Adds tables for: quiz profiles, occasion plans, product Q&A cache, notification log, cart intent events, curated collections
-- Safe to run multiple times (uses IF NOT EXISTS guards)

CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- ─────────────────────────────────────────────────────────────────────────────
-- Style quiz results (richer than user_style_profiles)
-- ─────────────────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS style_quiz_results (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    device_id text NOT NULL,
    answers jsonb NOT NULL DEFAULT '[]'::jsonb,
    profile jsonb NOT NULL DEFAULT '{}'::jsonb,
    created_at timestamptz DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_style_quiz_device ON style_quiz_results(device_id);

-- Add quiz-specific columns to style profile table
ALTER TABLE user_style_profiles ADD COLUMN IF NOT EXISTS personality_traits text[];
ALTER TABLE user_style_profiles ADD COLUMN IF NOT EXISTS avoid_categories text[];
ALTER TABLE user_style_profiles ADD COLUMN IF NOT EXISTS quiz_completed boolean DEFAULT false;
ALTER TABLE user_style_profiles ADD COLUMN IF NOT EXISTS style_tagline text;
ALTER TABLE user_style_profiles ADD COLUMN IF NOT EXISTS emoji text;

-- ─────────────────────────────────────────────────────────────────────────────
-- Occasion plans (saved shopping plans from occasion-planner)
-- ─────────────────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS occasion_plans (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    device_id text NOT NULL,
    occasion text NOT NULL,
    event_date date,
    budget numeric,
    guest_count int,
    plan jsonb NOT NULL DEFAULT '{}'::jsonb,
    created_at timestamptz DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_occasion_plans_device ON occasion_plans(device_id);

-- ─────────────────────────────────────────────────────────────────────────────
-- Product Q&A cache (avoid re-asking the same question repeatedly)
-- ─────────────────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS product_qa_cache (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    product_id int NOT NULL REFERENCES products(id) ON DELETE CASCADE,
    question_hash text NOT NULL,
    question text NOT NULL,
    answer jsonb NOT NULL DEFAULT '{}'::jsonb,
    created_at timestamptz DEFAULT now(),
    UNIQUE(product_id, question_hash)
);
CREATE INDEX IF NOT EXISTS idx_product_qa_product ON product_qa_cache(product_id);

-- ─────────────────────────────────────────────────────────────────────────────
-- Smart notifications log
-- ─────────────────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS notification_log (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    device_id text NOT NULL,
    trigger_type text NOT NULL,
    product_id int,
    registry_id uuid,
    notification jsonb NOT NULL DEFAULT '{}'::jsonb,
    sent_at timestamptz DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_notification_log_device ON notification_log(device_id);

-- ─────────────────────────────────────────────────────────────────────────────
-- Cart abandon signals (for intent prediction)
-- ─────────────────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS cart_intent_events (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    device_id text NOT NULL,
    event_type text NOT NULL,  -- 'view_cart', 'start_checkout', 'abandon', 'return'
    cart_snapshot jsonb DEFAULT '{}'::jsonb,
    created_at timestamptz DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_cart_intent_device ON cart_intent_events(device_id, created_at DESC);

-- ─────────────────────────────────────────────────────────────────────────────
-- Curated collections (saved by collection-builder)
-- ─────────────────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS curated_collections (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    theme text NOT NULL,
    collection_name text NOT NULL,
    collection_story text,
    product_ids int[] NOT NULL DEFAULT '{}'::int[],
    created_at timestamptz DEFAULT now()
);

-- ─────────────────────────────────────────────────────────────────────────────
-- Extend recent_searches with intent data
-- ─────────────────────────────────────────────────────────────────────────────
ALTER TABLE recent_searches ADD COLUMN IF NOT EXISTS parsed_intent jsonb;
ALTER TABLE recent_searches ADD COLUMN IF NOT EXISTS result_count int;

-- ─────────────────────────────────────────────────────────────────────────────
-- Extend registry_contributions for guest journeys
-- ─────────────────────────────────────────────────────────────────────────────
ALTER TABLE registry_contributions ADD COLUMN IF NOT EXISTS is_anonymous boolean DEFAULT false;
ALTER TABLE registry_contributions ADD COLUMN IF NOT EXISTS email text;

-- ─────────────────────────────────────────────────────────────────────────────
-- RLS — permissive for hackathon (service key bypasses anyway)
-- ─────────────────────────────────────────────────────────────────────────────
ALTER TABLE style_quiz_results ENABLE ROW LEVEL SECURITY;
ALTER TABLE occasion_plans ENABLE ROW LEVEL SECURITY;
ALTER TABLE product_qa_cache ENABLE ROW LEVEL SECURITY;
ALTER TABLE notification_log ENABLE ROW LEVEL SECURITY;
ALTER TABLE cart_intent_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE curated_collections ENABLE ROW LEVEL SECURITY;

DO $$
DECLARE
    tbl text;
    tables text[] := ARRAY[
        'style_quiz_results',
        'occasion_plans',
        'product_qa_cache',
        'notification_log',
        'cart_intent_events',
        'curated_collections'
    ];
BEGIN
    FOREACH tbl IN ARRAY tables LOOP
        -- SELECT
        IF NOT EXISTS (
            SELECT 1 FROM pg_policies WHERE schemaname='public' AND tablename=tbl AND policyname=tbl||'_select_all'
        ) THEN
            EXECUTE format('CREATE POLICY %I ON %I FOR SELECT USING (true)', tbl||'_select_all', tbl);
        END IF;

        -- INSERT
        IF NOT EXISTS (
            SELECT 1 FROM pg_policies WHERE schemaname='public' AND tablename=tbl AND policyname=tbl||'_insert_all'
        ) THEN
            EXECUTE format('CREATE POLICY %I ON %I FOR INSERT WITH CHECK (true)', tbl||'_insert_all', tbl);
        END IF;

        -- UPDATE
        IF NOT EXISTS (
            SELECT 1 FROM pg_policies WHERE schemaname='public' AND tablename=tbl AND policyname=tbl||'_update_all'
        ) THEN
            EXECUTE format('CREATE POLICY %I ON %I FOR UPDATE USING (true) WITH CHECK (true)', tbl||'_update_all', tbl);
        END IF;

        -- DELETE
        IF NOT EXISTS (
            SELECT 1 FROM pg_policies WHERE schemaname='public' AND tablename=tbl AND policyname=tbl||'_delete_all'
        ) THEN
            EXECUTE format('CREATE POLICY %I ON %I FOR DELETE USING (true)', tbl||'_delete_all', tbl);
        END IF;
    END LOOP;
END $$;

