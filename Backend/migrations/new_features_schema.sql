-- ========== FILE: migrations/new_features_schema.sql ==========
-- Williams Sonoma AI Hackathon - new feature schema
-- Safe to run multiple times (uses IF NOT EXISTS / guarded DO blocks).

-- Required for gen_random_uuid()
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- -----------------------------
-- New tables
-- -----------------------------

-- Group gifting: multiple people pool money for one registry item
CREATE TABLE IF NOT EXISTS registry_contributions (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    registry_item_id uuid NOT NULL REFERENCES registry_items(id) ON DELETE CASCADE,
    contributor_name text NOT NULL,
    amount numeric NOT NULL,
    message text,
    created_at timestamptz DEFAULT now()
);

-- Registry collaborators: co-planning access
CREATE TABLE IF NOT EXISTS registry_collaborators (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    registry_id uuid NOT NULL REFERENCES registries(id) ON DELETE CASCADE,
    email text NOT NULL,
    role text DEFAULT 'viewer',
    invited_at timestamptz DEFAULT now(),
    UNIQUE(registry_id, email)
);

-- Save for later (cart PS1)
CREATE TABLE IF NOT EXISTS save_for_later (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    device_id text NOT NULL,
    product_id int NOT NULL REFERENCES products(id) ON DELETE CASCADE,
    saved_at timestamptz DEFAULT now(),
    UNIQUE(device_id, product_id)
);

-- AI style profiles (generated per device, cached)
CREATE TABLE IF NOT EXISTS user_style_profiles (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    device_id text UNIQUE NOT NULL,
    style_name text,
    style_description text,
    top_categories text[],
    price_tier text,
    generated_at timestamptz DEFAULT now()
);

-- AI conversation history for the shopping assistant
CREATE TABLE IF NOT EXISTS ai_conversation_history (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    device_id text NOT NULL,
    session_id text NOT NULL,
    role text NOT NULL,
    content text NOT NULL,
    created_at timestamptz DEFAULT now()
);

-- Helpful indexes
CREATE INDEX IF NOT EXISTS idx_registry_contributions_item_id ON registry_contributions(registry_item_id);
CREATE INDEX IF NOT EXISTS idx_registry_collaborators_registry_id ON registry_collaborators(registry_id);
CREATE INDEX IF NOT EXISTS idx_save_for_later_device_id ON save_for_later(device_id);
CREATE INDEX IF NOT EXISTS idx_user_style_profiles_device_id ON user_style_profiles(device_id);
CREATE INDEX IF NOT EXISTS idx_ai_conversation_history_session ON ai_conversation_history(device_id, session_id, created_at DESC);

-- -----------------------------
-- Alter existing tables
-- -----------------------------
ALTER TABLE registries ADD COLUMN IF NOT EXISTS budget numeric DEFAULT 0;
ALTER TABLE registries ADD COLUMN IF NOT EXISTS share_token text UNIQUE DEFAULT gen_random_uuid()::text;
ALTER TABLE registries ADD COLUMN IF NOT EXISTS theme text;

ALTER TABLE registry_items ADD COLUMN IF NOT EXISTS price_snapshot numeric DEFAULT 0;
ALTER TABLE registry_items ADD COLUMN IF NOT EXISTS ai_reason text;

-- -----------------------------
-- RLS + permissive policies
-- Backend uses service role key (bypasses RLS), but enable policies for completeness.
-- -----------------------------

ALTER TABLE registry_contributions ENABLE ROW LEVEL SECURITY;
ALTER TABLE registry_collaborators ENABLE ROW LEVEL SECURITY;
ALTER TABLE save_for_later ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_style_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE ai_conversation_history ENABLE ROW LEVEL SECURITY;

DO $$
BEGIN
    -- registry_contributions
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname = 'public' AND tablename = 'registry_contributions' AND policyname = 'registry_contributions_select_all') THEN
        CREATE POLICY registry_contributions_select_all ON registry_contributions FOR SELECT USING (true);
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname = 'public' AND tablename = 'registry_contributions' AND policyname = 'registry_contributions_insert_all') THEN
        CREATE POLICY registry_contributions_insert_all ON registry_contributions FOR INSERT WITH CHECK (true);
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname = 'public' AND tablename = 'registry_contributions' AND policyname = 'registry_contributions_update_all') THEN
        CREATE POLICY registry_contributions_update_all ON registry_contributions FOR UPDATE USING (true) WITH CHECK (true);
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname = 'public' AND tablename = 'registry_contributions' AND policyname = 'registry_contributions_delete_all') THEN
        CREATE POLICY registry_contributions_delete_all ON registry_contributions FOR DELETE USING (true);
    END IF;

    -- registry_collaborators
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname = 'public' AND tablename = 'registry_collaborators' AND policyname = 'registry_collaborators_select_all') THEN
        CREATE POLICY registry_collaborators_select_all ON registry_collaborators FOR SELECT USING (true);
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname = 'public' AND tablename = 'registry_collaborators' AND policyname = 'registry_collaborators_insert_all') THEN
        CREATE POLICY registry_collaborators_insert_all ON registry_collaborators FOR INSERT WITH CHECK (true);
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname = 'public' AND tablename = 'registry_collaborators' AND policyname = 'registry_collaborators_update_all') THEN
        CREATE POLICY registry_collaborators_update_all ON registry_collaborators FOR UPDATE USING (true) WITH CHECK (true);
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname = 'public' AND tablename = 'registry_collaborators' AND policyname = 'registry_collaborators_delete_all') THEN
        CREATE POLICY registry_collaborators_delete_all ON registry_collaborators FOR DELETE USING (true);
    END IF;

    -- save_for_later
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname = 'public' AND tablename = 'save_for_later' AND policyname = 'save_for_later_select_all') THEN
        CREATE POLICY save_for_later_select_all ON save_for_later FOR SELECT USING (true);
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname = 'public' AND tablename = 'save_for_later' AND policyname = 'save_for_later_insert_all') THEN
        CREATE POLICY save_for_later_insert_all ON save_for_later FOR INSERT WITH CHECK (true);
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname = 'public' AND tablename = 'save_for_later' AND policyname = 'save_for_later_update_all') THEN
        CREATE POLICY save_for_later_update_all ON save_for_later FOR UPDATE USING (true) WITH CHECK (true);
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname = 'public' AND tablename = 'save_for_later' AND policyname = 'save_for_later_delete_all') THEN
        CREATE POLICY save_for_later_delete_all ON save_for_later FOR DELETE USING (true);
    END IF;

    -- user_style_profiles
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname = 'public' AND tablename = 'user_style_profiles' AND policyname = 'user_style_profiles_select_all') THEN
        CREATE POLICY user_style_profiles_select_all ON user_style_profiles FOR SELECT USING (true);
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname = 'public' AND tablename = 'user_style_profiles' AND policyname = 'user_style_profiles_insert_all') THEN
        CREATE POLICY user_style_profiles_insert_all ON user_style_profiles FOR INSERT WITH CHECK (true);
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname = 'public' AND tablename = 'user_style_profiles' AND policyname = 'user_style_profiles_update_all') THEN
        CREATE POLICY user_style_profiles_update_all ON user_style_profiles FOR UPDATE USING (true) WITH CHECK (true);
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname = 'public' AND tablename = 'user_style_profiles' AND policyname = 'user_style_profiles_delete_all') THEN
        CREATE POLICY user_style_profiles_delete_all ON user_style_profiles FOR DELETE USING (true);
    END IF;

    -- ai_conversation_history
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname = 'public' AND tablename = 'ai_conversation_history' AND policyname = 'ai_conversation_history_select_all') THEN
        CREATE POLICY ai_conversation_history_select_all ON ai_conversation_history FOR SELECT USING (true);
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname = 'public' AND tablename = 'ai_conversation_history' AND policyname = 'ai_conversation_history_insert_all') THEN
        CREATE POLICY ai_conversation_history_insert_all ON ai_conversation_history FOR INSERT WITH CHECK (true);
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname = 'public' AND tablename = 'ai_conversation_history' AND policyname = 'ai_conversation_history_update_all') THEN
        CREATE POLICY ai_conversation_history_update_all ON ai_conversation_history FOR UPDATE USING (true) WITH CHECK (true);
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname = 'public' AND tablename = 'ai_conversation_history' AND policyname = 'ai_conversation_history_delete_all') THEN
        CREATE POLICY ai_conversation_history_delete_all ON ai_conversation_history FOR DELETE USING (true);
    END IF;
END $$;

