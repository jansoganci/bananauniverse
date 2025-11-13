-- =====================================================
-- Migration 050: Robust Quota System (Perplexity Recommendations)
-- Purpose: Implement server-authoritative, atomic quota system
-- Based on production best practices
-- =====================================================

-- =====================================================
-- STEP 1: Create Idempotency Keys Table
-- =====================================================
-- Separate table for idempotency (better than quota_consumption_log)
CREATE TABLE IF NOT EXISTS idempotency_keys (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    device_id TEXT,
    idempotency_key TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    response_status INTEGER,
    response_body JSONB
);

-- Create unique index with expression (PostgreSQL allows expressions in indexes)
CREATE UNIQUE INDEX IF NOT EXISTS idx_idempotency_unique 
ON idempotency_keys (
    COALESCE(user_id::text, ''),
    COALESCE(device_id, ''),
    idempotency_key
);

CREATE INDEX IF NOT EXISTS idx_idempotency_user ON idempotency_keys(user_id) WHERE user_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_idempotency_device ON idempotency_keys(device_id) WHERE device_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_idempotency_key ON idempotency_keys(idempotency_key);

-- Enable RLS
ALTER TABLE idempotency_keys ENABLE ROW LEVEL SECURITY;

-- RLS Policies (similar to daily_quotas)
CREATE POLICY "users_select_own_idempotency" ON idempotency_keys
    FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "anon_select_device_idempotency" ON idempotency_keys
    FOR SELECT USING (
        device_id IS NOT NULL 
        AND device_id = current_setting('request.device_id', true)
    );

-- =====================================================
-- STEP 2: Update daily_quotas table with UTC timezone
-- =====================================================
-- Add is_premium column if it doesn't exist
DO $$ 
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'daily_quotas' AND column_name = 'is_premium'
    ) THEN
        ALTER TABLE daily_quotas ADD COLUMN is_premium BOOLEAN NOT NULL DEFAULT FALSE;
    END IF;
END $$;

-- Update default quota limit to 3 (consistent with your requirements)
ALTER TABLE daily_quotas ALTER COLUMN limit_value SET DEFAULT 3;

-- Ensure date column uses UTC
-- (Already uses CURRENT_DATE which is server timezone, but we'll be explicit in functions)

-- =====================================================
-- STEP 3: Atomic consume_quota Function (Server-Authoritative)
-- =====================================================
CREATE OR REPLACE FUNCTION consume_quota(
    p_user_id UUID DEFAULT NULL,
    p_device_id TEXT DEFAULT NULL,
    p_idempotency_key TEXT DEFAULT NULL
)
RETURNS JSONB AS $$
DECLARE
    v_today DATE;
    v_quota_record RECORD;
    v_result JSONB;
    v_is_premium BOOLEAN := FALSE;
    v_identifier TEXT;
BEGIN
    -- Set device_id session for RLS
    IF p_device_id IS NOT NULL THEN
        PERFORM set_config('request.device_id', p_device_id, true);
    END IF;

    -- Validate inputs
    IF p_user_id IS NULL AND p_device_id IS NULL THEN
        RETURN jsonb_build_object(
            'success', FALSE,
            'error', 'Either user_id or device_id required',
            'quota_used', 0,
            'quota_limit', 3,
            'quota_remaining', 0,
            'is_premium', FALSE
        );
    END IF;

    -- Use UTC for quota date (critical for timezone correctness)
    v_today := (NOW() AT TIME ZONE 'UTC')::DATE;
    v_identifier := COALESCE(p_user_id::text, p_device_id);

    -- ========================================
    -- STEP 1: IDEMPOTENCY CHECK (Return cached result)
    -- ========================================
    IF p_idempotency_key IS NOT NULL THEN
        SELECT response_body INTO v_result
        FROM idempotency_keys
        WHERE (COALESCE(user_id::text, '') = COALESCE(p_user_id::text, '')
               AND COALESCE(device_id, '') = COALESCE(p_device_id, ''))
          AND idempotency_key = p_idempotency_key;

        IF FOUND AND v_result IS NOT NULL THEN
            RAISE LOG '[QUOTA] Idempotent request: returning cached result for key=%', p_idempotency_key;
            RETURN v_result;
        END IF;
    END IF;

    -- ========================================
    -- STEP 2: CHECK PREMIUM STATUS (Server-Side)
    -- ========================================
    SELECT EXISTS(
        SELECT 1 FROM subscriptions
        WHERE (
            (p_user_id IS NOT NULL AND user_id = p_user_id)
            OR (p_device_id IS NOT NULL AND device_id = p_device_id)
        )
        AND status = 'active'
        AND expires_at > NOW()
        AND status != 'cancelled'
    ) INTO v_is_premium;

    RAISE LOG '[QUOTA] Premium check: user_id=%, device_id=%, is_premium=%',
        p_user_id, p_device_id, v_is_premium;

    -- Premium users bypass quota
    IF v_is_premium THEN
        v_result := jsonb_build_object(
            'success', TRUE,
            'is_premium', TRUE,
            'quota_used', 0,
            'quota_limit', 999999,
            'quota_remaining', 999999
        );

        -- Cache idempotency result
        IF p_idempotency_key IS NOT NULL THEN
            INSERT INTO idempotency_keys (user_id, device_id, idempotency_key, response_status, response_body)
            VALUES (p_user_id, p_device_id, p_idempotency_key, 200, v_result)
            ON CONFLICT ON CONSTRAINT idx_idempotency_unique 
            DO UPDATE SET response_body = v_result;
        END IF;

        RETURN v_result;
    END IF;

    -- ========================================
    -- STEP 3: ATOMIC QUOTA CHECK + CONSUME
    -- ========================================
    -- Get or create quota record for today
    -- Note: daily_quotas table has UNIQUE(user_id, device_id, date) constraint
    -- We need to handle NULL values properly
    INSERT INTO daily_quotas (user_id, device_id, date, used, limit_value, is_premium)
    VALUES (p_user_id, p_device_id, v_today, 0, 3, FALSE)
    ON CONFLICT (user_id, device_id, date) DO NOTHING;

    -- Lock row and get current quota state (FOR UPDATE prevents race conditions)
    SELECT * INTO v_quota_record
    FROM daily_quotas
    WHERE COALESCE(user_id::text, '') = COALESCE(p_user_id::text, '')
      AND COALESCE(device_id, '') = COALESCE(p_device_id, '')
      AND date = v_today
    FOR UPDATE;  -- ← CRITICAL: Row-level lock prevents concurrent modifications

    -- Check quota availability WHILE HOLDING LOCK
    IF v_quota_record.used >= v_quota_record.limit_value THEN
        v_result := jsonb_build_object(
            'success', FALSE,
            'error', 'Daily quota exceeded',
            'quota_used', v_quota_record.used,
            'quota_limit', v_quota_record.limit_value,
            'quota_remaining', 0,
            'is_premium', FALSE
        );
    ELSE
        -- Atomically increment quota
        UPDATE daily_quotas
        SET used = used + 1,
            updated_at = NOW()
        WHERE COALESCE(user_id::text, '') = COALESCE(p_user_id::text, '')
          AND COALESCE(device_id, '') = COALESCE(p_device_id, '')
          AND date = v_today
        RETURNING used, limit_value INTO v_quota_record.used, v_quota_record.limit_value;

        v_result := jsonb_build_object(
            'success', TRUE,
            'quota_used', v_quota_record.used,
            'quota_limit', v_quota_record.limit_value,
            'quota_remaining', v_quota_record.limit_value - v_quota_record.used,
            'is_premium', FALSE
        );

        RAISE LOG '[QUOTA] Consumed: %/%', v_quota_record.used, v_quota_record.limit_value;
    END IF;

    -- ========================================
    -- STEP 4: CACHE IDEMPOTENCY RESULT
    -- ========================================
    IF p_idempotency_key IS NOT NULL THEN
        INSERT INTO idempotency_keys (user_id, device_id, idempotency_key, response_status, response_body)
        VALUES (p_user_id, p_device_id, p_idempotency_key, 
                CASE WHEN (v_result->>'success')::boolean THEN 200 ELSE 429 END,
                v_result)
        ON CONFLICT ON CONSTRAINT idx_idempotency_unique 
        DO UPDATE SET response_body = v_result;
    END IF;

    RETURN v_result;

EXCEPTION
    WHEN OTHERS THEN
        RAISE LOG '[QUOTA] ERROR: %', SQLERRM;
        RETURN jsonb_build_object(
            'success', FALSE,
            'error', 'Database error: ' || SQLERRM,
            'quota_used', 0,
            'quota_limit', 3,
            'quota_remaining', 0,
            'is_premium', FALSE
        );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Ensure proper ownership and permissions
ALTER FUNCTION consume_quota(UUID, TEXT, TEXT) OWNER TO postgres;
GRANT EXECUTE ON FUNCTION consume_quota(UUID, TEXT, TEXT) TO anon, authenticated, service_role;

-- =====================================================
-- STEP 4: Simplified get_quota Function (Read-Only)
-- =====================================================
CREATE OR REPLACE FUNCTION get_quota(
    p_user_id UUID DEFAULT NULL,
    p_device_id TEXT DEFAULT NULL
)
RETURNS JSONB AS $$
DECLARE
    v_today DATE;
    v_used INTEGER;
    v_limit INTEGER;
    v_is_premium BOOLEAN := FALSE;
BEGIN
    -- Set device_id session for RLS
    IF p_device_id IS NOT NULL THEN
        PERFORM set_config('request.device_id', p_device_id, true);
    END IF;

    -- Validate inputs
    IF p_user_id IS NULL AND p_device_id IS NULL THEN
        RETURN jsonb_build_object(
            'success', FALSE,
            'error', 'Either user_id or device_id required',
            'quota_used', 0,
            'quota_limit', 3,
            'quota_remaining', 0,
            'is_premium', FALSE
        );
    END IF;

    -- Use UTC for quota date
    v_today := (NOW() AT TIME ZONE 'UTC')::DATE;

    -- Check premium status
    SELECT EXISTS(
        SELECT 1 FROM subscriptions
        WHERE (
            (p_user_id IS NOT NULL AND user_id = p_user_id)
            OR (p_device_id IS NOT NULL AND device_id = p_device_id)
        )
        AND status = 'active'
        AND expires_at > NOW()
        AND status != 'cancelled'
    ) INTO v_is_premium;

    -- Premium users get unlimited
    IF v_is_premium THEN
        RETURN jsonb_build_object(
            'success', TRUE,
            'is_premium', TRUE,
            'quota_used', 0,
            'quota_limit', 999999,
            'quota_remaining', 999999
        );
    END IF;

    -- Get quota record (create if doesn't exist)
    -- Note: daily_quotas table has UNIQUE(user_id, device_id, date) constraint
    INSERT INTO daily_quotas (user_id, device_id, date, used, limit_value, is_premium)
    VALUES (p_user_id, p_device_id, v_today, 0, 3, FALSE)
    ON CONFLICT (user_id, device_id, date) DO NOTHING;

    -- Get current values
    SELECT COALESCE(used, 0), COALESCE(limit_value, 3) INTO v_used, v_limit
    FROM daily_quotas
    WHERE COALESCE(user_id::text, '') = COALESCE(p_user_id::text, '')
      AND COALESCE(device_id, '') = COALESCE(p_device_id, '')
      AND date = v_today;

    RETURN jsonb_build_object(
        'success', TRUE,
        'is_premium', FALSE,
        'quota_used', COALESCE(v_used, 0),
        'quota_limit', COALESCE(v_limit, 3),
        'quota_remaining', GREATEST(COALESCE(v_limit, 3) - COALESCE(v_used, 0), 0)
    );

EXCEPTION
    WHEN OTHERS THEN
        RAISE LOG '[GET_QUOTA] ERROR: %', SQLERRM;
        RETURN jsonb_build_object(
            'success', FALSE,
            'error', 'Database error: ' || SQLERRM,
            'quota_used', 0,
            'quota_limit', 3,
            'quota_remaining', 0,
            'is_premium', FALSE
        );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

ALTER FUNCTION get_quota(UUID, TEXT) OWNER TO postgres;
GRANT EXECUTE ON FUNCTION get_quota(UUID, TEXT) TO anon, authenticated, service_role;

-- =====================================================
-- Migration Complete
-- =====================================================
-- ✅ Server-authoritative quota system implemented
-- ✅ Atomic operations with FOR UPDATE locks
-- ✅ Proper idempotency handling
-- ✅ UTC timezone for daily resets
-- ✅ Consistent quota limit of 3
-- ✅ Premium status checked server-side
--
-- Next: Update iOS app to remove client-side quota decisions
-- See: HybridCreditManager.swift updates

