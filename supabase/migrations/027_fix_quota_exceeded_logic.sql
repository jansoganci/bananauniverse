-- Migration 027: Fix quota exceeded logic in consume_quota function
-- 
-- ISSUE: Quota exceeded check uses > instead of >=
-- When quota reaches limit (5/5), the check v_used > v_limit fails because 5 > 5 is false
-- Should be v_used >= v_limit to properly detect quota exceeded

CREATE OR REPLACE FUNCTION consume_quota(
    p_user_id UUID DEFAULT NULL,
    p_device_id TEXT DEFAULT NULL,
    p_is_premium BOOLEAN DEFAULT FALSE,
    p_client_request_id UUID DEFAULT NULL
)
RETURNS JSONB AS $$
DECLARE
    v_today DATE;
    v_used INTEGER;
    v_limit INTEGER;
    v_success BOOLEAN;
    v_error_message TEXT;
    v_record_id UUID;
BEGIN
    -- CRITICAL FIX: Set session variable for RLS policies if device_id is provided
    -- This ensures anonymous user RLS policies work correctly
    IF p_device_id IS NOT NULL THEN
        PERFORM set_config('request.device_id', p_device_id, true);
        RAISE LOG '[QUOTA] Set session variable request.device_id = %', p_device_id;
    END IF;

    -- LOG: Function called
    RAISE LOG '[QUOTA] consume_quota() called: user_id=%, device_id=%, request_id=%, is_premium=%', 
        p_user_id, p_device_id, p_client_request_id, p_is_premium;
    
    -- Validate inputs
    IF p_user_id IS NULL AND p_device_id IS NULL THEN
        RAISE LOG '[QUOTA] ERROR: Missing user_id and device_id';
        RETURN jsonb_build_object(
            'success', false,
            'error', 'Either user_id or device_id must be provided',
            'quota_used', 0,
            'quota_limit', 5,
            'quota_remaining', 0
        );
    END IF;
    
    v_today := CURRENT_DATE;
    
    -- IDEMPOTENCY CHECK: Prevent double-charging
    IF p_client_request_id IS NOT NULL THEN
        SELECT COUNT(*) INTO v_used
        FROM quota_consumption_log
        WHERE request_id = p_client_request_id;
        
        IF v_used > 0 THEN
            RAISE LOG '[QUOTA] Idempotent request: request_id=% already processed', p_client_request_id;
            
            -- Return cached result
            SELECT quota_used, quota_limit INTO v_used, v_limit
            FROM quota_consumption_log
            WHERE request_id = p_client_request_id
            LIMIT 1;
            
            RETURN jsonb_build_object(
                'success', true,
                'idempotent', true,
                'quota_used', v_used,
                'quota_limit', v_limit,
                'quota_remaining', v_limit - v_used
            );
        END IF;
    END IF;
    
    -- PREMIUM BYPASS: Premium users get unlimited quota
    IF p_is_premium THEN
        RAISE LOG '[QUOTA] Premium user detected - bypassing quota';
        
        -- Still log the consumption for audit
        IF p_client_request_id IS NOT NULL THEN
            INSERT INTO quota_consumption_log (
                request_id, user_id, device_id, consumed_at, 
                quota_used, quota_limit, success, error_message
            ) VALUES (
                p_client_request_id, p_user_id, p_device_id, NOW(),
                0, 999999, true, 'Premium bypass'
            );
        END IF;
        
        RETURN jsonb_build_object(
            'success', true,
            'quota_used', 0,
            'quota_limit', 999999,
            'quota_remaining', 999999,
            'premium_bypass', true
        );
    END IF;
    
    -- FIXED UPSERT: Use proper logic with correct WHERE clause matching unique index
    BEGIN
        -- Try to insert first
        INSERT INTO daily_quotas (user_id, device_id, date, used, limit_value)
        VALUES (p_user_id, p_device_id, v_today, 1, 5)
        RETURNING used, limit_value, id INTO v_used, v_limit, v_record_id;
        
        RAISE LOG '[QUOTA] INSERTED new record: used=%, limit=%', v_used, v_limit;
        
    EXCEPTION
        WHEN unique_violation THEN
            -- Record exists, update it
            RAISE LOG '[QUOTA] Record exists, updating...';
            
            -- CRITICAL FIX: Match the unique index structure exactly
            -- This handles NULL values correctly using COALESCE
            UPDATE daily_quotas
            SET 
                used = used + 1,
                updated_at = NOW()
            WHERE COALESCE(user_id::text, '') = COALESCE(p_user_id::text, '')
            AND COALESCE(device_id, '') = COALESCE(p_device_id, '')
            AND date = v_today
            AND used < limit_value
            RETURNING used, limit_value, id INTO v_used, v_limit, v_record_id;
            
            -- If no rows were updated (quota exceeded), get current values
            IF NOT FOUND THEN
                RAISE LOG '[QUOTA] No rows updated (quota exceeded), getting current values...';
                SELECT used, limit_value, id INTO v_used, v_limit, v_record_id
                FROM daily_quotas
                WHERE COALESCE(user_id::text, '') = COALESCE(p_user_id::text, '')
                AND COALESCE(device_id, '') = COALESCE(p_device_id, '')
                AND date = v_today;
            END IF;
            
            RAISE LOG '[QUOTA] UPDATED existing record: used=%, limit=%', v_used, v_limit;
    END;
    
    -- CRITICAL FIX: Check if quota exceeded (use >= instead of >)
    IF v_used >= v_limit THEN
        v_success := false;
        v_error_message := 'Daily quota exceeded';
        RAISE LOG '[QUOTA] ERROR: Quota exceeded - used=%, limit=%', v_used, v_limit;
    ELSE
        v_success := true;
        v_error_message := NULL;
        RAISE LOG '[QUOTA] SUCCESS: Quota consumed - used=%, remaining=%', v_used, v_limit - v_used;
    END IF;
    
    -- Log consumption for audit and idempotency
    IF p_client_request_id IS NOT NULL THEN
        INSERT INTO quota_consumption_log (
            request_id, user_id, device_id, consumed_at, 
            quota_used, quota_limit, success, error_message
        ) VALUES (
            p_client_request_id, p_user_id, p_device_id, NOW(),
            v_used, v_limit, v_success, v_error_message
        );
        
        RAISE LOG '[QUOTA] Logged consumption: request_id=%', p_client_request_id;
    END IF;
    
    -- Return result
    RETURN jsonb_build_object(
        'success', v_success,
        'error', v_error_message,
        'quota_used', v_used,
        'quota_limit', v_limit,
        'quota_remaining', GREATEST(0, v_limit - v_used)
    );
    
EXCEPTION
    WHEN OTHERS THEN
        RAISE LOG '[QUOTA] EXCEPTION: %', SQLERRM;
        RETURN jsonb_build_object(
            'success', false,
            'error', 'Database error: ' || SQLERRM,
            'quota_used', 0,
            'quota_limit', 5,
            'quota_remaining', 0
        );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant execute permissions (ensure they're still in place)
GRANT EXECUTE ON FUNCTION consume_quota(UUID, TEXT, BOOLEAN, UUID) TO anon, authenticated, service_role;

-- Log the migration
INSERT INTO cleanup_logs (operation, details, created_at)
VALUES ('quota_exceeded_logic_fix', 
        jsonb_build_object(
            'migration', '027_fix_quota_exceeded_logic',
            'fix', 'Changed quota exceeded check from v_used > v_limit to v_used >= v_limit',
            'expected_impact', 'Quota exceeded error should now work correctly when limit is reached'
        ), 
        NOW());

-- Final completion log
DO $$
BEGIN
    RAISE LOG '[QUOTA-FIX] ✅ Migration 027: Quota exceeded logic fix applied successfully';
    RAISE LOG '[QUOTA-FIX] Key fix: Changed quota exceeded check from > to >=';
    RAISE LOG '[QUOTA-FIX] This should fix the issue where 6th call succeeds instead of failing';
END $$;
