-- ========== FILE: migrations/fix_registry_rls.sql ==========
-- This script safely provides permissive RLS policies for the registries and registry_items tables.
-- Run this in your Supabase SQL Editor if you are relying on the Anon key instead of the Service Role key.

DO $$ 
BEGIN
    -- 1. Policies for registries
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname = 'public' AND tablename = 'registries' AND policyname = 'registries_select_all') THEN
        CREATE POLICY registries_select_all ON registries FOR SELECT USING (true);
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname = 'public' AND tablename = 'registries' AND policyname = 'registries_insert_all') THEN
        CREATE POLICY registries_insert_all ON registries FOR INSERT WITH CHECK (true);
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname = 'public' AND tablename = 'registries' AND policyname = 'registries_update_all') THEN
        CREATE POLICY registries_update_all ON registries FOR UPDATE USING (true) WITH CHECK (true);
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname = 'public' AND tablename = 'registries' AND policyname = 'registries_delete_all') THEN
        CREATE POLICY registries_delete_all ON registries FOR DELETE USING (true);
    END IF;

    -- 2. Policies for registry_items
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname = 'public' AND tablename = 'registry_items' AND policyname = 'registry_items_select_all') THEN
        CREATE POLICY registry_items_select_all ON registry_items FOR SELECT USING (true);
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname = 'public' AND tablename = 'registry_items' AND policyname = 'registry_items_insert_all') THEN
        CREATE POLICY registry_items_insert_all ON registry_items FOR INSERT WITH CHECK (true);
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname = 'public' AND tablename = 'registry_items' AND policyname = 'registry_items_update_all') THEN
        CREATE POLICY registry_items_update_all ON registry_items FOR UPDATE USING (true) WITH CHECK (true);
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname = 'public' AND tablename = 'registry_items' AND policyname = 'registry_items_delete_all') THEN
        CREATE POLICY registry_items_delete_all ON registry_items FOR DELETE USING (true);
    END IF;
    -- 3. Policies for registry_events
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname = 'public' AND tablename = 'registry_events' AND policyname = 'registry_events_select_all') THEN
        CREATE POLICY registry_events_select_all ON registry_events FOR SELECT USING (true);
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname = 'public' AND tablename = 'registry_events' AND policyname = 'registry_events_insert_all') THEN
        CREATE POLICY registry_events_insert_all ON registry_events FOR INSERT WITH CHECK (true);
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname = 'public' AND tablename = 'registry_events' AND policyname = 'registry_events_update_all') THEN
        CREATE POLICY registry_events_update_all ON registry_events FOR UPDATE USING (true) WITH CHECK (true);
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname = 'public' AND tablename = 'registry_events' AND policyname = 'registry_events_delete_all') THEN
        CREATE POLICY registry_events_delete_all ON registry_events FOR DELETE USING (true);
    END IF;

END $$;
