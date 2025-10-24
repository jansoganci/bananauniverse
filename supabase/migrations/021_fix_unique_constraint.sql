-- Migration 021: Fix unique constraint for anonymous users
-- Uses COALESCE-based unique index to properly handle NULL user_id values

-- 1. Drop the existing unique constraint
ALTER TABLE daily_quotas DROP CONSTRAINT IF EXISTS daily_quotas_user_id_device_id_date_key;

-- 2. Create a COALESCE-based unique index that treats NULL user_id as empty string
CREATE UNIQUE INDEX daily_quotas_unique_user_device_date 
ON daily_quotas (COALESCE(user_id::text, ''), device_id, date);

-- 3. Update the consume_quota function to use the new unique constraint logic
CREATE OR REPLACE FUNCTION consume_quota(
    p_user_id UUID DEFAULT NULL,
    p_device_id TEXT DEFAULT NULL,
    p_is_premium BOOLEAN DEFAULT FALSE,
    p_client_request_id UUID DEFAULT NULL
)
RETURNS JSONB AS $$
DECLARE
    v_identity_key TEXT;
    v_today DATE;
    v_used INTEGER;
    v_limit INTEGER;
    v_success BOOLEAN;
    v_error_message TEXT;
    v_existing_record RECORD;
BEGIN
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
    
    -- Set identity key (user_id for authenticated, device_id for anonymous)
    v_identity_key := COALESCE(p_user_id::text, p_device_id);
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
    
    -- Check if record exists for today
    SELECT * INTO v_existing_record
    FROM daily_quotas
    WHERE (user_id = p_user_id OR (user_id IS NULL AND p_user_id IS NULL))
    AND (device_id = p_device_id OR (device_id IS NULL AND p_device_id IS NULL))
    AND date = v_today
    LIMIT 1;
    
    -- UPSERT quota record (atomic operation)
    IF v_existing_record IS NOT NULL THEN
        -- Update existing record
        UPDATE daily_quotas
        SET 
            used = used + 1,
            updated_at = NOW()
        WHERE id = v_existing_record.id
        AND used < limit_value
        RETURNING used, limit_value INTO v_used, v_limit;
        
        -- If no rows were updated (quota exceeded), get current values
        IF NOT FOUND THEN
            SELECT used, limit_value INTO v_used, v_limit
            FROM daily_quotas
            WHERE id = v_existing_record.id;
        END IF;
    ELSE
        -- Insert new record
        INSERT INTO daily_quotas (user_id, device_id, date, used, limit_value)
        VALUES (p_user_id, p_device_id, v_today, 1, 5)
        RETURNING used, limit_value INTO v_used, v_limit;
    END IF;
    
    -- LOG: Upsert result
    RAISE LOG '[QUOTA] UPSERT result: used=%, limit=%', v_used, v_limit;
    
    -- Check if quota exceeded
    IF v_used > v_limit THEN
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

-- 4. Grant execute permissions
GRANT EXECUTE ON FUNCTION consume_quota(UUID, TEXT, BOOLEAN, UUID) TO anon, authenticated, service_role;
