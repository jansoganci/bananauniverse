-- =====================================================
-- Migration 090: Fix Idempotency Job ID Lookup
-- Purpose: Fix bug where idempotency check returns wrong job_id
-- Date: 2025-11-15
-- =====================================================
-- BUG FIX:
-- The idempotency check was looking up job_id from credit_transactions.id
-- (which is the transaction ID, not the job ID).
-- 
-- SOLUTION:
-- Check idempotency_keys table FIRST (which caches the correct job_id
-- in response_body), then fall back to credit_transactions + job_results join.
-- =====================================================

DO $$
BEGIN
    RAISE NOTICE 'Fixing idempotency job_id lookup bug...';
END $$;

-- =====================================================
-- Fix submit_job_atomic() Idempotency Check
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
    -- STEP 3: Idempotency Check (FIXED)
    -- ========================================
    -- Check if this request was already processed
    IF p_idempotency_key IS NOT NULL THEN
        -- FIX: Check idempotency_keys table FIRST (has cached job_id)
        SELECT response_body INTO v_result
        FROM idempotency_keys
        WHERE idempotency_key = p_idempotency_key
        AND (
            (user_id IS NOT NULL AND user_id = p_user_id) OR
            (device_id IS NOT NULL AND device_id = p_device_id)
        )
        LIMIT 1;

        IF v_result IS NOT NULL THEN
            -- Add duplicate flag to cached response
            v_result := v_result || jsonb_build_object('duplicate', TRUE);
            RAISE LOG '[CREDITS] Idempotent request: returning cached result for key=%', p_idempotency_key;
            RETURN v_result;
        END IF;

        -- Fallback: Check credit_transactions + join with job_results to get job_id
        SELECT jsonb_build_object(
            'success', TRUE,
            'credits_remaining', ct.balance_after,
            'job_id', jr.id::text,
            'duplicate', TRUE
        ) INTO v_result
        FROM credit_transactions ct
        INNER JOIN job_results jr ON (
            (ct.user_id IS NOT NULL AND jr.user_id = ct.user_id) OR
            (ct.device_id IS NOT NULL AND jr.device_id = ct.device_id)
        )
        WHERE ct.idempotency_key = p_idempotency_key
        AND (
            (ct.user_id IS NOT NULL AND ct.user_id = p_user_id) OR
            (ct.device_id IS NOT NULL AND ct.device_id = p_device_id)
        )
        AND jr.client_request_id = p_client_request_id
        ORDER BY ct.created_at DESC
        LIMIT 1;

        IF v_result IS NOT NULL THEN
            RAISE LOG '[CREDITS] Idempotent request: returning result from credit_transactions for key=%', p_idempotency_key;
            RETURN v_result;
        END IF;

        -- Fallback: Check job_results for existing job with same client_request_id
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
COMMENT ON FUNCTION submit_job_atomic IS 'Atomically deducts credits and creates job record. All-or-nothing transaction with idempotency protection. Supports both authenticated and anonymous users. FIXED: Idempotency check now correctly returns cached job_id from idempotency_keys table.';

-- =====================================================
-- VERIFICATION
-- =====================================================

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_proc WHERE proname = 'submit_job_atomic') THEN
        RAISE EXCEPTION 'VERIFICATION FAILED: submit_job_atomic function not found';
    END IF;

    RAISE NOTICE '========================================';
    RAISE NOTICE 'Migration 090: Idempotency Fix';
    RAISE NOTICE '========================================';
    RAISE NOTICE '✅ submit_job_atomic() idempotency check FIXED';
    RAISE NOTICE '✅ Now checks idempotency_keys table FIRST';
    RAISE NOTICE '✅ Returns correct job_id from cached response';
    RAISE NOTICE '✅ Fallback to credit_transactions + job_results join';
    RAISE NOTICE '========================================';
    RAISE NOTICE '🎉 SUCCESS: Idempotency bug fixed!';
    RAISE NOTICE '========================================';
END $$;

