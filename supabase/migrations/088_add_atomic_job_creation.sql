-- =====================================================
-- Migration 088: Add Atomic Job Creation Support
-- Purpose: Enable atomic credit deduction + job creation
-- Date: 2025-11-15
-- =====================================================
-- This migration modifies job_results table to support:
-- 1. Internal UUID primary key (allows job creation before fal.ai call)
-- 2. Nullable fal_job_id (set after fal.ai responds)
-- 3. client_request_id for webhook fallback lookup (race condition protection)
-- =====================================================

DO $$
BEGIN
    RAISE NOTICE 'Starting atomic job creation migration...';
END $$;

-- =====================================================
-- STEP 1: Drop Existing PRIMARY KEY Constraint
-- =====================================================
-- We need to drop the existing PRIMARY KEY on fal_job_id because:
-- - PostgreSQL does not allow multiple PRIMARY KEYs
-- - We need to change PK from fal_job_id to internal id
-- - fal_job_id will become nullable (set after fal.ai call)

ALTER TABLE job_results
DROP CONSTRAINT IF EXISTS job_results_pkey;

DO $$
BEGIN
    RAISE NOTICE '✅ Step 1: Dropped existing PRIMARY KEY constraint on fal_job_id';
END $$;

-- =====================================================
-- STEP 2: Add Internal ID Column
-- =====================================================
-- Add internal UUID column (not primary key yet)
-- This allows us to create job records BEFORE calling fal.ai

ALTER TABLE job_results
ADD COLUMN IF NOT EXISTS id UUID DEFAULT gen_random_uuid();

DO $$
BEGIN
    RAISE NOTICE '✅ Step 2a: Added id UUID column with default';
END $$;

-- =====================================================
-- STEP 3: Backfill ID for Existing Rows
-- =====================================================
-- Generate UUIDs for any existing rows (handles existing data)

UPDATE job_results
SET id = gen_random_uuid()
WHERE id IS NULL;

DO $$
BEGIN
    RAISE NOTICE '✅ Step 3: Backfilled id column for existing rows';
END $$;

-- =====================================================
-- STEP 4: Make ID NOT NULL and Set as PRIMARY KEY
-- =====================================================
-- Now that all rows have an id, enforce NOT NULL and set as PK

ALTER TABLE job_results
ALTER COLUMN id SET NOT NULL;

ALTER TABLE job_results
ADD CONSTRAINT job_results_pkey PRIMARY KEY (id);

DO $$
BEGIN
    RAISE NOTICE '✅ Step 4: Set id as NOT NULL and PRIMARY KEY';
END $$;

-- =====================================================
-- STEP 5: Make fal_job_id Nullable
-- =====================================================
-- fal_job_id will now be NULL initially (set after fal.ai responds)

ALTER TABLE job_results
ALTER COLUMN fal_job_id DROP NOT NULL;

DO $$
BEGIN
    RAISE NOTICE '✅ Step 5: Made fal_job_id nullable';
END $$;

-- =====================================================
-- STEP 6: Add Unique Index on fal_job_id
-- =====================================================
-- Replaces the old PRIMARY KEY constraint with a unique index
-- Uses WHERE clause to only index non-null values

CREATE UNIQUE INDEX IF NOT EXISTS idx_job_results_fal_job_id_unique
ON job_results(fal_job_id)
WHERE fal_job_id IS NOT NULL;

DO $$
BEGIN
    RAISE NOTICE '✅ Step 6: Created unique index on fal_job_id (partial, non-null only)';
END $$;

-- =====================================================
-- STEP 7: Add client_request_id Column
-- =====================================================
-- This column stores the client-generated request ID
-- Allows webhook to find job even if fal_job_id not set yet (race condition protection)

ALTER TABLE job_results
ADD COLUMN IF NOT EXISTS client_request_id TEXT;

DO $$
BEGIN
    RAISE NOTICE '✅ Step 7: Added client_request_id TEXT column';
END $$;

-- =====================================================
-- STEP 8: Backfill client_request_id for Existing Rows
-- =====================================================
-- For existing rows, use fal_job_id as fallback value
-- This ensures old jobs can still be found by webhook

UPDATE job_results
SET client_request_id = fal_job_id
WHERE client_request_id IS NULL
  AND fal_job_id IS NOT NULL;

DO $$
BEGIN
    RAISE NOTICE '✅ Step 8: Backfilled client_request_id from fal_job_id for existing rows';
END $$;

-- =====================================================
-- STEP 9: Create Lookup Index on client_request_id
-- =====================================================
-- Fast lookup for webhook queries
-- Uses WHERE clause to only index non-null values

CREATE INDEX IF NOT EXISTS idx_job_results_client_request_id
ON job_results(client_request_id)
WHERE client_request_id IS NOT NULL;

DO $$
BEGIN
    RAISE NOTICE '✅ Step 9: Created lookup index on client_request_id (partial, non-null only)';
END $$;

-- =====================================================
-- STEP 10: Add Unique Constraint on client_request_id
-- =====================================================
-- Prevents duplicate requests
-- Uses WHERE clause to only enforce uniqueness for non-null values

CREATE UNIQUE INDEX IF NOT EXISTS idx_job_results_client_request_unique
ON job_results(client_request_id)
WHERE client_request_id IS NOT NULL;

DO $$
BEGIN
    RAISE NOTICE '✅ Step 10: Created unique constraint on client_request_id (partial, non-null only)';
END $$;

-- =====================================================
-- VERIFICATION
-- =====================================================

DO $$
DECLARE
    v_id_exists BOOLEAN;
    v_id_is_pk BOOLEAN;
    v_fal_job_id_nullable BOOLEAN;
    v_client_request_id_exists BOOLEAN;
BEGIN
    -- Check if id column exists
    SELECT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'job_results' AND column_name = 'id'
    ) INTO v_id_exists;

    -- Check if id is the PRIMARY KEY
    SELECT EXISTS (
        SELECT 1 FROM information_schema.table_constraints tc
        JOIN information_schema.key_column_usage kcu
          ON tc.constraint_name = kcu.constraint_name
        WHERE tc.table_name = 'job_results'
          AND tc.constraint_type = 'PRIMARY KEY'
          AND kcu.column_name = 'id'
    ) INTO v_id_is_pk;

    -- Check if fal_job_id is nullable
    SELECT is_nullable = 'YES'
    FROM information_schema.columns
    WHERE table_name = 'job_results' AND column_name = 'fal_job_id'
    INTO v_fal_job_id_nullable;

    -- Check if client_request_id exists
    SELECT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'job_results' AND column_name = 'client_request_id'
    ) INTO v_client_request_id_exists;

    -- Verify all changes
    IF NOT v_id_exists THEN
        RAISE EXCEPTION 'VERIFICATION FAILED: id column not found';
    END IF;

    IF NOT v_id_is_pk THEN
        RAISE EXCEPTION 'VERIFICATION FAILED: id is not PRIMARY KEY';
    END IF;

    IF NOT v_fal_job_id_nullable THEN
        RAISE EXCEPTION 'VERIFICATION FAILED: fal_job_id is not nullable';
    END IF;

    IF NOT v_client_request_id_exists THEN
        RAISE EXCEPTION 'VERIFICATION FAILED: client_request_id column not found';
    END IF;

    RAISE NOTICE '========================================';
    RAISE NOTICE 'Migration 088: Atomic Job Creation';
    RAISE NOTICE '========================================';
    RAISE NOTICE '✅ id column: EXISTS (UUID, PRIMARY KEY)';
    RAISE NOTICE '✅ fal_job_id: NULLABLE (with unique index)';
    RAISE NOTICE '✅ client_request_id: EXISTS (with indexes)';
    RAISE NOTICE '========================================';
    RAISE NOTICE '🎉 SUCCESS: Schema ready for atomic job creation!';
    RAISE NOTICE '========================================';
END $$;

-- =====================================================
-- COMMENTS
-- =====================================================

COMMENT ON COLUMN job_results.id IS 'Internal UUID primary key - allows job creation before fal.ai call';
COMMENT ON COLUMN job_results.fal_job_id IS 'External fal.ai job ID - set after fal.ai responds (nullable initially)';
COMMENT ON COLUMN job_results.client_request_id IS 'Client-generated request ID - used for webhook fallback lookup';

-- =====================================================
-- PHASE 2: Atomic Stored Procedure
-- =====================================================
-- Create submit_job_atomic() function that:
-- - Deducts credits and creates job in ONE transaction
-- - Handles both authenticated and anonymous users
-- - Includes idempotency protection
-- - Returns job_id and credits_remaining
-- =====================================================

CREATE OR REPLACE FUNCTION submit_job_atomic(
    p_client_request_id TEXT,
    p_user_id UUID DEFAULT NULL,
    p_device_id TEXT DEFAULT NULL,
    p_idempotency_key TEXT DEFAULT NULL
)
RETURNS JSONB AS $$
DECLARE
    v_balance INTEGER;
    v_job_id UUID;
    v_result JSONB;
BEGIN
    -- ========================================
    -- STEP 1: Set RLS Session Config
    -- ========================================
    -- Set device_id session variable for RLS policies
    IF p_device_id IS NOT NULL THEN
        PERFORM set_config('request.device_id', p_device_id, true);
    END IF;

    -- ========================================
    -- STEP 2: Input Validation
    -- ========================================
    -- Validate that either user_id OR device_id is provided
    IF p_user_id IS NULL AND p_device_id IS NULL THEN
        RETURN jsonb_build_object(
            'success', FALSE,
            'error', 'Either user_id or device_id required'
        );
    END IF;

    -- Validate that client_request_id is provided
    IF p_client_request_id IS NULL THEN
        RETURN jsonb_build_object(
            'success', FALSE,
            'error', 'client_request_id is required'
        );
    END IF;

    -- ========================================
    -- STEP 3: Idempotency Check (Part 1)
    -- ========================================
    -- Check if this request was already processed
    IF p_idempotency_key IS NOT NULL THEN
        -- Check credit_transactions for existing transaction
        SELECT jsonb_build_object(
            'success', TRUE,
            'credits_remaining', balance_after,
            'job_id', id::text,
            'duplicate', TRUE
        ) INTO v_result
        FROM credit_transactions
        WHERE idempotency_key = p_idempotency_key
        AND (
            (user_id IS NOT NULL AND user_id = p_user_id) OR
            (device_id IS NOT NULL AND device_id = p_device_id)
        )
        LIMIT 1;

        IF v_result IS NOT NULL THEN
            RAISE LOG '[CREDITS] Idempotent request: returning cached result for key=%', p_idempotency_key;
            RETURN v_result;
        END IF;

        -- Check job_results for existing job with same client_request_id
        SELECT id INTO v_job_id
        FROM job_results
        WHERE client_request_id = p_client_request_id
        LIMIT 1;

        IF FOUND THEN
            -- Get current balance
            IF p_user_id IS NOT NULL THEN
                SELECT credits INTO v_balance FROM user_credits WHERE user_id = p_user_id;
            ELSE
                SELECT credits INTO v_balance FROM anonymous_credits WHERE device_id = p_device_id;
            END IF;

            RETURN jsonb_build_object(
                'success', TRUE,
                'credits_remaining', COALESCE(v_balance, 0),
                'job_id', v_job_id::text,
                'duplicate', TRUE
            );
        END IF;
    END IF;

    -- ========================================
    -- STEP 4: Atomic Transaction
    -- ========================================
    -- All-or-nothing: deduct credits + create job + log transaction
    BEGIN
        -- ========================================
        -- AUTHENTICATED USERS
        -- ========================================
        IF p_user_id IS NOT NULL THEN
            -- Lock row and check credits (prevents race conditions)
            SELECT credits INTO v_balance
            FROM user_credits
            WHERE user_id = p_user_id
            FOR UPDATE;

            -- Create record if doesn't exist (auto-grant 10 credits)
            IF NOT FOUND THEN
                INSERT INTO user_credits (user_id, credits)
                VALUES (p_user_id, 10)
                RETURNING credits INTO v_balance;
            END IF;

            -- Check if sufficient balance
            IF v_balance < 1 THEN
                RETURN jsonb_build_object(
                    'success', FALSE,
                    'error', 'Insufficient credits',
                    'credits_remaining', v_balance
                );
            END IF;

            -- Deduct 1 credit
            UPDATE user_credits
            SET credits = credits - 1
            WHERE user_id = p_user_id
            RETURNING credits INTO v_balance;

            -- Create job record (fal_job_id will be NULL initially)
            INSERT INTO job_results (
                user_id,
                device_id,
                status,
                client_request_id,
                fal_job_id  -- NULL initially, set after fal.ai responds
            )
            VALUES (
                p_user_id,
                NULL,
                'pending',
                p_client_request_id,
                NULL
            )
            RETURNING id INTO v_job_id;

            -- Log transaction (audit trail)
            INSERT INTO credit_transactions (
                user_id,
                amount,
                balance_after,
                reason,
                idempotency_key,
                created_at
            ) VALUES (
                p_user_id,
                -1,
                v_balance,
                'image_processing',
                p_idempotency_key,
                NOW()
            );

        -- ========================================
        -- ANONYMOUS USERS
        -- ========================================
        ELSIF p_device_id IS NOT NULL THEN
            -- Lock row and check credits (prevents race conditions)
            SELECT credits INTO v_balance
            FROM anonymous_credits
            WHERE device_id = p_device_id
            FOR UPDATE;

            -- Create record if doesn't exist (auto-grant 10 credits)
            IF NOT FOUND THEN
                INSERT INTO anonymous_credits (device_id, credits)
                VALUES (p_device_id, 10)
                RETURNING credits INTO v_balance;
            END IF;

            -- Check if sufficient balance
            IF v_balance < 1 THEN
                RETURN jsonb_build_object(
                    'success', FALSE,
                    'error', 'Insufficient credits',
                    'credits_remaining', v_balance
                );
            END IF;

            -- Deduct 1 credit
            UPDATE anonymous_credits
            SET credits = credits - 1
            WHERE device_id = p_device_id
            RETURNING credits INTO v_balance;

            -- Create job record (fal_job_id will be NULL initially)
            INSERT INTO job_results (
                user_id,
                device_id,
                status,
                client_request_id,
                fal_job_id  -- NULL initially, set after fal.ai responds
            )
            VALUES (
                NULL,
                p_device_id,
                'pending',
                p_client_request_id,
                NULL
            )
            RETURNING id INTO v_job_id;

            -- Log transaction (audit trail)
            INSERT INTO credit_transactions (
                device_id,
                amount,
                balance_after,
                reason,
                idempotency_key,
                created_at
            ) VALUES (
                p_device_id,
                -1,
                v_balance,
                'image_processing',
                p_idempotency_key,
                NOW()
            );
        END IF;

        -- ========================================
        -- STEP 5: Cache Idempotency Result
        -- ========================================
        -- Store result for future duplicate requests
        IF p_idempotency_key IS NOT NULL THEN
            INSERT INTO idempotency_keys (user_id, device_id, idempotency_key, response_status, response_body)
            VALUES (p_user_id, p_device_id, p_idempotency_key, 200, jsonb_build_object(
                'success', TRUE,
                'credits_remaining', v_balance,
                'job_id', v_job_id::text
            ))
            ON CONFLICT (COALESCE(user_id::text, ''), COALESCE(device_id, ''), idempotency_key)
            DO UPDATE SET response_body = jsonb_build_object(
                'success', TRUE,
                'credits_remaining', v_balance,
                'job_id', v_job_id::text
            );
        END IF;

        -- ========================================
        -- STEP 6: Return Success
        -- ========================================
        RETURN jsonb_build_object(
            'success', TRUE,
            'credits_remaining', v_balance,
            'job_id', v_job_id::text,
            'duplicate', FALSE
        );

    EXCEPTION
        -- ========================================
        -- STEP 7: Exception Handler
        -- ========================================
        -- Transaction automatically rolls back on ANY error
        -- Credits NOT deducted, job NOT created
        WHEN OTHERS THEN
            RAISE LOG '[CREDITS] Atomic transaction failed: %', SQLERRM;
            RETURN jsonb_build_object(
                'success', FALSE,
                'error', 'Transaction failed: ' || SQLERRM
            );
    END;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Add function comment
COMMENT ON FUNCTION submit_job_atomic IS 'Atomically deducts credits and creates job record. All-or-nothing transaction with idempotency protection. Supports both authenticated and anonymous users.';

-- =====================================================
-- PHASE 2 VERIFICATION
-- =====================================================

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_proc WHERE proname = 'submit_job_atomic') THEN
        RAISE EXCEPTION 'VERIFICATION FAILED: submit_job_atomic function not created';
    END IF;

    RAISE NOTICE '========================================';
    RAISE NOTICE 'Phase 2: Atomic Stored Procedure';
    RAISE NOTICE '========================================';
    RAISE NOTICE '✅ submit_job_atomic(): CREATED';
    RAISE NOTICE '✅ Handles authenticated users';
    RAISE NOTICE '✅ Handles anonymous users';
    RAISE NOTICE '✅ Idempotency protection enabled';
    RAISE NOTICE '✅ Atomic transaction (all-or-nothing)';
    RAISE NOTICE '✅ Auto-rollback on failure';
    RAISE NOTICE '========================================';
    RAISE NOTICE '🎉 SUCCESS: Atomic procedure ready!';
    RAISE NOTICE '========================================';
END $$;

-- =====================================================
-- Migration Complete
-- =====================================================
-- ✅ PHASE 1: Schema changes applied
-- ✅ PHASE 2: Atomic stored procedure created
-- ✅ Ready for Edge Function integration (Phase 3)
