-- =====================================================
-- Migration 057: Webhook Rate Limiting
-- Purpose: Prevent webhook spam/DoS attacks
-- Date: 2025-11-13
-- =====================================================

-- =====================================================
-- TABLE: webhook_rate_limit
-- =====================================================
CREATE TABLE IF NOT EXISTS public.webhook_rate_limit (
    ip_address TEXT PRIMARY KEY,
    request_count INTEGER NOT NULL DEFAULT 1,
    window_start TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    last_request TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- =====================================================
-- INDEXES
-- =====================================================
CREATE INDEX IF NOT EXISTS idx_webhook_rate_limit_window
    ON public.webhook_rate_limit(window_start);

-- =====================================================
-- FUNCTION: check_webhook_rate_limit
-- =====================================================
CREATE OR REPLACE FUNCTION check_webhook_rate_limit(
    p_ip_address TEXT,
    p_max_requests INTEGER DEFAULT 100,
    p_window_seconds INTEGER DEFAULT 60
)
RETURNS BOOLEAN AS $$
DECLARE
    v_current_window TIMESTAMPTZ;
    v_existing_record RECORD;
BEGIN
    -- Calculate current time window (1-minute buckets)
    v_current_window := DATE_TRUNC('minute', NOW());

    -- Try to get existing record for this IP in current window
    SELECT * INTO v_existing_record
    FROM webhook_rate_limit
    WHERE ip_address = p_ip_address
      AND window_start = v_current_window
    FOR UPDATE;  -- Lock to prevent race conditions

    IF NOT FOUND THEN
        -- First request in this window - create new record
        INSERT INTO webhook_rate_limit (ip_address, request_count, window_start, last_request)
        VALUES (p_ip_address, 1, v_current_window, NOW())
        ON CONFLICT (ip_address) DO UPDATE
        SET request_count = 1,
            window_start = v_current_window,
            last_request = NOW();

        RAISE LOG '[RATE-LIMIT] New window for IP %: 1/%', p_ip_address, p_max_requests;
        RETURN TRUE;  -- Allow request
    ELSE
        -- Check if limit exceeded
        IF v_existing_record.request_count >= p_max_requests THEN
            RAISE LOG '[RATE-LIMIT] Limit exceeded for IP %: %/%', p_ip_address, v_existing_record.request_count, p_max_requests;
            RETURN FALSE;  -- Deny request
        ELSE
            -- Increment counter
            UPDATE webhook_rate_limit
            SET request_count = request_count + 1,
                last_request = NOW()
            WHERE ip_address = p_ip_address
              AND window_start = v_current_window;

            RAISE LOG '[RATE-LIMIT] IP % allowed: %/%', p_ip_address, v_existing_record.request_count + 1, p_max_requests;
            RETURN TRUE;  -- Allow request
        END IF;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        RAISE LOG '[RATE-LIMIT] ERROR: %', SQLERRM;
        RETURN TRUE;  -- Allow request on error (fail open)
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =====================================================
-- CLEANUP FUNCTION
-- =====================================================
CREATE OR REPLACE FUNCTION cleanup_webhook_rate_limit()
RETURNS INTEGER AS $$
DECLARE
    deleted_count INTEGER;
BEGIN
    -- Delete records older than 5 minutes
    DELETE FROM webhook_rate_limit
    WHERE window_start < NOW() - INTERVAL '5 minutes';

    GET DIAGNOSTICS deleted_count = ROW_COUNT;

    RAISE LOG '[RATE-LIMIT] Cleaned up % old records', deleted_count;
    RETURN deleted_count;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =====================================================
-- PERMISSIONS
-- =====================================================
ALTER FUNCTION check_webhook_rate_limit(TEXT, INTEGER, INTEGER) OWNER TO postgres;
GRANT EXECUTE ON FUNCTION check_webhook_rate_limit(TEXT, INTEGER, INTEGER) TO service_role;

ALTER FUNCTION cleanup_webhook_rate_limit() OWNER TO postgres;
GRANT EXECUTE ON FUNCTION cleanup_webhook_rate_limit() TO service_role;

-- =====================================================
-- COMMENTS
-- =====================================================
COMMENT ON TABLE public.webhook_rate_limit IS
'Rate limiting table for webhook-handler. Tracks request counts per IP per minute.';

COMMENT ON FUNCTION check_webhook_rate_limit(TEXT, INTEGER, INTEGER) IS
'Checks if IP address has exceeded rate limit (default 100 req/min). Returns TRUE to allow, FALSE to deny.';

COMMENT ON FUNCTION cleanup_webhook_rate_limit() IS
'Deletes rate limit records older than 5 minutes. Should be called periodically.';

-- =====================================================
-- VERIFICATION
-- =====================================================
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'webhook_rate_limit') THEN
        RAISE EXCEPTION 'webhook_rate_limit table not created';
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_proc WHERE proname = 'check_webhook_rate_limit') THEN
        RAISE EXCEPTION 'check_webhook_rate_limit function not created';
    END IF;

    RAISE NOTICE 'SUCCESS: Webhook rate limiting created (100 req/min per IP)';
END $$;
