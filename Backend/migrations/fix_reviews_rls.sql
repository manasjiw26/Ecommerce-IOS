-- ========== FILE: migrations/fix_reviews_rls.sql ==========
-- This script provides permissive RLS policies for the `reviews` table.
-- Run this in your Supabase SQL Editor to unblock posting reviews.

DO $$ 
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname = 'public' AND tablename = 'reviews' AND policyname = 'reviews_select_all') THEN
        CREATE POLICY reviews_select_all ON reviews FOR SELECT USING (true);
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname = 'public' AND tablename = 'reviews' AND policyname = 'reviews_insert_all') THEN
        CREATE POLICY reviews_insert_all ON reviews FOR INSERT WITH CHECK (true);
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname = 'public' AND tablename = 'reviews' AND policyname = 'reviews_update_all') THEN
        CREATE POLICY reviews_update_all ON reviews FOR UPDATE USING (true) WITH CHECK (true);
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname = 'public' AND tablename = 'reviews' AND policyname = 'reviews_delete_all') THEN
        CREATE POLICY reviews_delete_all ON reviews FOR DELETE USING (true);
    END IF;
END $$;
