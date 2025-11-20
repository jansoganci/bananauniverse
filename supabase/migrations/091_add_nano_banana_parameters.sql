-- =====================================================
-- Migration 091: Add Nano Banana Model Parameters
-- Purpose: Support dual model system (nano-banana & nano-banana-pro)
-- Date: 2025-11-20
-- =====================================================
-- This migration adds:
-- 1. Model selection parameters to job_results
-- 2. Dynamic credit cost support
-- 3. Extended submit_job_atomic() function
-- =====================================================

DO $$
BEGIN
    RAISE NOTICE 'Starting Nano Banana parameters migration...';
END $$;

-- =====================================================
-- STEP 1: Add New Columns to job_results
-- =====================================================
-- Add columns for model configuration and processing parameters

ALTER TABLE job_results
ADD COLUMN IF NOT EXISTS model_type TEXT DEFAULT 'nano-banana',
ADD COLUMN IF NOT EXISTS aspect_ratio TEXT DEFAULT '1:1',
ADD COLUMN IF NOT EXISTS resolution TEXT,  -- '1K', '2K', '4K' for pro model, NULL for basic
ADD COLUMN IF NOT EXISTS output_format TEXT DEFAULT 'jpeg',
ADD COLUMN IF NOT EXISTS credit_cost INTEGER DEFAULT 1,
ADD COLUMN IF NOT EXISTS num_images INTEGER DEFAULT 1;

DO $$
BEGIN
    RAISE NOTICE '✅ Step 1: Added new columns to job_results table';
END $$;

-- =====================================================
-- STEP 2: Add Indexes for Performance
-- =====================================================
-- Partial indexes for efficient filtering

CREATE INDEX IF NOT EXISTS idx_job_results_model_type
ON job_results(model_type)
WHERE model_type IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_job_results_user_created
ON job_results(user_id, created_at DESC)
WHERE user_id IS NOT NULL;

DO $$
BEGIN
    RAISE NOTICE '✅ Step 2: Created performance indexes';
END $$;

-- =====================================================
-- STEP 3: Extend submit_job_atomic Function
-- =====================================================
-- Extend existing function to support new parameters
-- CRITICAL: Uses DEFAULT values for backward compatibility

CREATE OR REPLACE FUNCTION submit_job_atomic(
    p_client_request_id TEXT,
    p_user_id UUID DEFAULT NULL,
    p_device_id TEXT DEFAULT NULL,
    p_idempotency_key TEXT DEFAULT NULL,
    -- NEW PARAMETERS (all have defaults for backward compatibility):
    p_credit_cost INTEGER DEFAULT 1,           -- Dynamic cost (was hardcoded to 1)
    p_model_type TEXT DEFAULT 'nano-banana',   -- Model selection
    p_aspect_ratio TEXT DEFAULT '1:1',         -- Aspect ratio
    p_output_format TEXT DEFAULT 'jpeg',       -- Output format
    p_resolution TEXT DEFAULT NULL,            -- Resolution tier ('1K', '2K', '4K', pro only)
    p_num_images INTEGER DEFAULT 1             -- Number of images
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
        LIMIT 1;

        IF v_result IS NOT NULL THEN
            RAISE NOTICE '[IDEMPOTENCY] Duplicate request detected: %', p_idempotency_key;
            RETURN v_result;
        END IF;
    END IF;

    -- ========================================
    -- STEP 4: Get Current Balance
    -- ========================================
    SELECT COALESCE(credits, 0) INTO v_balance
    FROM user_credits
    WHERE (p_user_id IS NOT NULL AND user_id = p_user_id)
       OR (p_device_id IS NOT NULL AND device_id = p_device_id)
    LIMIT 1;

    -- If no record exists, create one with 10 credits
    IF v_balance IS NULL THEN
        -- Try to insert for authenticated user
        IF p_user_id IS NOT NULL THEN
            INSERT INTO user_credits (user_id, credits, created_at, updated_at)
            VALUES (p_user_id, 10, now(), now())
            ON CONFLICT (user_id) DO NOTHING;
        END IF;

        -- Try to insert for anonymous user (device_id)
        IF p_device_id IS NOT NULL AND p_user_id IS NULL THEN
            INSERT INTO user_credits (device_id, credits, created_at, updated_at)
            VALUES (p_device_id, 10, now(), now())
            ON CONFLICT (device_id) DO NOTHING;
        END IF;

        v_balance := 10;
    END IF;

    -- ========================================
    -- STEP 5: Check Sufficient Credits
    -- ========================================
    -- CHANGED: Use p_credit_cost instead of hardcoded 1
    IF v_balance < p_credit_cost THEN
        RETURN jsonb_build_object(
            'success', FALSE,
            'error', 'Insufficient credits',
            'credits_remaining', v_balance,
            'credits_required', p_credit_cost
        );
    END IF;

    -- ========================================
    -- STEP 6: Deduct Credits
    -- ========================================
    -- CHANGED: Deduct p_credit_cost instead of hardcoded 1
    UPDATE user_credits
    SET credits = credits - p_credit_cost,
        updated_at = now()
    WHERE (p_user_id IS NOT NULL AND user_id = p_user_id)
       OR (p_device_id IS NOT NULL AND device_id = p_device_id)
    RETURNING credits INTO v_balance;

    -- ========================================
    -- STEP 7: Create Job Record
    -- ========================================
    -- CHANGED: Add new columns to INSERT
    INSERT INTO job_results (
        client_request_id,
        user_id,
        device_id,
        status,
        model_type,         -- NEW
        aspect_ratio,       -- NEW
        output_format,      -- NEW
        resolution,         -- NEW
        num_images,         -- NEW
        credit_cost,        -- NEW
        created_at
    ) VALUES (
        p_client_request_id,
        p_user_id,
        p_device_id,
        'pending',
        p_model_type,       -- NEW
        p_aspect_ratio,     -- NEW
        p_output_format,    -- NEW
        p_resolution,       -- NEW
        p_num_images,       -- NEW
        p_credit_cost,      -- NEW
        now()
    ) RETURNING id INTO v_job_id;

    -- ========================================
    -- STEP 8: Log Transaction
    -- ========================================
    -- CHANGED: Log p_credit_cost instead of hardcoded 1
    INSERT INTO credit_transactions (
        user_id,
        device_id,
        amount,
        balance_after,
        reason,
        created_at,
        idempotency_key,
        id  -- Link to job_results.id
    ) VALUES (
        p_user_id,
        p_device_id,
        -p_credit_cost,  -- CHANGED from -1
        v_balance,
        format('image_generation_%s', p_model_type),  -- Include model type
        now(),
        p_idempotency_key,
        v_job_id
    );

    -- ========================================
    -- STEP 9: Return Success
    -- ========================================
    RETURN jsonb_build_object(
        'success', TRUE,
        'job_id', v_job_id::text,
        'credits_remaining', v_balance,
        'duplicate', FALSE
    );

EXCEPTION
    WHEN OTHERS THEN
        RAISE WARNING '[ERROR] submit_job_atomic failed: %', SQLERRM;
        RETURN jsonb_build_object(
            'success', FALSE,
            'error', SQLERRM
        );
END;
$$ LANGUAGE plpgsql;

DO $$
BEGIN
    RAISE NOTICE '✅ Step 3: Extended submit_job_atomic() function';
END $$;

-- =====================================================
-- STEP 4: Add Column Comments
-- =====================================================

COMMENT ON COLUMN job_results.model_type IS 'AI model used: nano-banana or nano-banana-pro';
COMMENT ON COLUMN job_results.aspect_ratio IS 'Output aspect ratio (1:1, 16:9, 9:16, 4:3, etc.)';
COMMENT ON COLUMN job_results.resolution IS 'Resolution tier for pro model (1K, 2K, 4K)';
COMMENT ON COLUMN job_results.output_format IS 'Output format (jpeg, png, webp)';
COMMENT ON COLUMN job_results.credit_cost IS 'Credits deducted for this job';
COMMENT ON COLUMN job_results.num_images IS 'Number of input images processed';

DO $$
BEGIN
    RAISE NOTICE '✅ Step 4: Added column comments';
END $$;

-- =====================================================
-- VERIFICATION
-- =====================================================

DO $$
DECLARE
    v_columns_exist BOOLEAN;
    v_function_exists BOOLEAN;
BEGIN
    -- Check if all new columns exist
    SELECT COUNT(*) = 6 INTO v_columns_exist
    FROM information_schema.columns
    WHERE table_name = 'job_results'
      AND column_name IN ('model_type', 'aspect_ratio', 'resolution', 'output_format', 'credit_cost', 'num_images');

    -- Check if function exists with new parameters
    SELECT EXISTS (
        SELECT 1 FROM pg_proc
        WHERE proname = 'submit_job_atomic'
    ) INTO v_function_exists;

    -- Verify changes
    IF NOT v_columns_exist THEN
        RAISE EXCEPTION 'VERIFICATION FAILED: Not all columns were created';
    END IF;

    IF NOT v_function_exists THEN
        RAISE EXCEPTION 'VERIFICATION FAILED: submit_job_atomic function not found';
    END IF;

    RAISE NOTICE '========================================';
    RAISE NOTICE 'Migration 091: Nano Banana Parameters';
    RAISE NOTICE '========================================';
    RAISE NOTICE '✅ New columns: 6 added to job_results';
    RAISE NOTICE '✅ Indexes: 2 created for performance';
    RAISE NOTICE '✅ Function: submit_job_atomic extended';
    RAISE NOTICE '✅ Backward compatibility: Maintained via DEFAULTs';
    RAISE NOTICE '========================================';
    RAISE NOTICE '🎉 SUCCESS: Migration complete!';
    RAISE NOTICE '========================================';
END $$;
