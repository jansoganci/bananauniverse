-- Migration 032: Fix WHERE Clause to Match Unique Constraint Exactly
-- The WHERE clause must match the unique constraint structure exactly

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
    -- Set session variable for RLS if device_id provided
    IF p_device_id IS NOT NULL THEN
        PERFORM set_config('request.device_id', p_device_id, true);
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
    
    -- IDEMPOTENCY CHECK
    IF p_client_request_id IS NOT NULL THEN
        SELECT COUNT(*) INTO v_used
        FROM quota_consumption_log
        WHERE request_id = p_client_request_id;
        
        IF v_used > 0 THEN
            RAISE LOG '[QUOTA] Idempotent request: request_id=% already processed', p_client_request_id;
            
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
    
    -- PREMIUM BYPASS
    IF p_is_premium THEN
        RAISE LOG '[QUOTA] Premium user detected - bypassing quota';
        
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
    
    -- UPSERT with WHERE clause that matches unique constraint exactly
    BEGIN
        INSERT INTO daily_quotas (user_id, device_id, date, used, limit_value)
        VALUES (p_user_id, p_device_id, v_today, 1, 5)
        RETURNING used, limit_value, id INTO v_used, v_limit, v_record_id;
        
        RAISE LOG '[QUOTA] INSERTED new record: used=%, limit=%', v_used, v_limit;
        
    EXCEPTION
        WHEN unique_violation THEN
            RAISE LOG '[QUOTA] Record exists, updating...';
            
            -- FIXED: WHERE clause now matches unique constraint exactly
            -- Unique constraint: (COALESCE(user_id::text, ''), device_id, date)
            -- WHERE clause: COALESCE(user_id::text, '') = COALESCE(p_user_id::text, '') AND device_id = p_device_id
            UPDATE daily_quotas
            SET 
                used = used + 1,
                updated_at = NOW()
            WHERE COALESCE(user_id::text, '') = COALESCE(p_user_id::text, '')
            AND device_id = p_device_id  -- Direct comparison to match unique constraint
            AND date = v_today
            RETURNING used, limit_value, id INTO v_used, v_limit, v_record_id;
            
            IF NOT FOUND THEN
                SELECT used, limit_value, id INTO v_used, v_limit, v_record_id
                FROM daily_quotas
                WHERE COALESCE(user_id::text, '') = COALESCE(p_user_id::text, '')
                AND device_id = p_device_id  -- Direct comparison to match unique constraint
                AND date = v_today;
            END IF;
            
            RAISE LOG '[QUOTA] UPDATED existing record: used=%, limit=%', v_used, v_limit;
    END;
    
    -- Check quota (this will now properly detect when used > limit)
    IF v_used > v_limit THEN
        v_success := false;
        v_error_message := 'Daily quota exceeded';
        RAISE LOG '[QUOTA] ERROR: Quota exceeded - used=%, limit=%', v_used, v_limit;
    ELSE
        v_success := true;
        v_error_message := NULL;
        RAISE LOG '[QUOTA] SUCCESS: Quota consumed - used=%, remaining=%', v_used, v_limit - v_used;
    END IF;
    
    -- Log consumption
    IF p_client_request_id IS NOT NULL THEN
        INSERT INTO quota_consumption_log (
            request_id, user_id, device_id, consumed_at, 
            quota_used, quota_limit, success, error_message
        ) VALUES (
            p_client_request_id, p_user_id, p_device_id, NOW(),
            v_used, v_limit, v_success, v_error_message
        );
        
        RAISE LOG '[QUOTA] Logged consumption: success=%', v_success;
    END IF;
    
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

-- Ensure proper role ownership
ALTER FUNCTION consume_quota(UUID, TEXT, BOOLEAN, UUID) OWNER TO postgres;

-- Comments
COMMENT ON FUNCTION consume_quota(UUID, TEXT, BOOLEAN, UUID) IS 'Fixed WHERE clause to match unique constraint exactly (device_id = p_device_id) for proper UPDATE operations';
