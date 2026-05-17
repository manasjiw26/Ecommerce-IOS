-- ========== FILE: migrations/fix_orders_rls.sql ==========
-- Fixes: "new row violates row-level security policy for table orders"
-- The orders table has RLS enabled but no INSERT (or other) policies defined.
-- This adds permissive policies so the backend service role key works correctly,
-- and also as a safety net when the anon key is used.
-- Safe to run multiple times.

-- Step 1: Make sure RLS is enabled (idempotent)
ALTER TABLE orders ENABLE ROW LEVEL SECURITY;

-- Step 2: Create permissive policies (guarded so re-running is safe)
DO $$
BEGIN

    -- SELECT: backend and authenticated users can read orders
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies
        WHERE schemaname = 'public'
          AND tablename  = 'orders'
          AND policyname = 'orders_select_all'
    ) THEN
        CREATE POLICY orders_select_all
            ON orders FOR SELECT
            USING (true);
    END IF;

    -- INSERT: allow inserts (backend uses service role key; this covers anon-key fallback)
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies
        WHERE schemaname = 'public'
          AND tablename  = 'orders'
          AND policyname = 'orders_insert_all'
    ) THEN
        CREATE POLICY orders_insert_all
            ON orders FOR INSERT
            WITH CHECK (true);
    END IF;

    -- UPDATE: allow updates (e.g. status changes)
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies
        WHERE schemaname = 'public'
          AND tablename  = 'orders'
          AND policyname = 'orders_update_all'
    ) THEN
        CREATE POLICY orders_update_all
            ON orders FOR UPDATE
            USING (true)
            WITH CHECK (true);
    END IF;

    -- DELETE: allow deletes (admin / cleanup operations)
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies
        WHERE schemaname = 'public'
          AND tablename  = 'orders'
          AND policyname = 'orders_delete_all'
    ) THEN
        CREATE POLICY orders_delete_all
            ON orders FOR DELETE
            USING (true);
    END IF;

END $$;
