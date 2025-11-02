-- =====================================================
-- Migration 041: Fix Subscription Injection Vulnerability
-- Purpose: Prevent unauthorized premium subscription creation
-- Security: CRITICAL - Block anon/authenticated from calling sync_subscription
-- Date: January 27, 2025
-- =====================================================

-- =====================================================
-- SECURITY FIX: Revoke sync_subscription from public roles
-- =====================================================
-- ISSUE: Migration 038 granted EXECUTE to anon and authenticated users
-- RISK: Anyone could call sync_subscription with fake transaction_id
-- IMPACT: Unlimited free premium access (financial loss)
--
-- FIX: Only service_role (backend webhook) should sync subscriptions
-- BREAKING: iOS app MUST call via authenticated backend, not directly

-- Remove dangerous permissions
REVOKE EXECUTE ON FUNCTION sync_subscription(UUID, TEXT, TEXT, TEXT, TIMESTAMPTZ, TEXT)
FROM anon, authenticated;

-- Only allow service_role (Edge Function, backend webhooks)
-- Note: service_role already has access via SECURITY DEFINER
-- This is explicit documentation of intent
GRANT EXECUTE ON FUNCTION sync_subscription(UUID, TEXT, TEXT, TEXT, TIMESTAMPTZ, TEXT)
TO service_role;

-- Log security fix
DO $$
BEGIN
    RAISE NOTICE '[SECURITY] sync_subscription now restricted to service_role only';
    RAISE NOTICE '[SECURITY] anon and authenticated roles can no longer create fake subscriptions';
END $$;

-- =====================================================
-- Migration Complete
-- =====================================================
-- ✅ CRITICAL FIX APPLIED: Subscription injection prevented
-- Security Impact:
--   - Prevents fake premium subscription creation
--   - Blocks financial exploitation
--   - Enforces StoreKit validation flow
--
-- Migration Path:
--   - Non-breaking for legitimate users (iOS app uses backend)
--   - Breaking for direct API callers (intentionally)
--
-- Testing Required:
--   1. Verify anon user cannot call sync_subscription
--   2. Verify authenticated user cannot call sync_subscription
--   3. Verify service_role CAN call sync_subscription
--   4. Test premium subscription flow through StoreKit
--
-- Rollback (if needed):
-- GRANT EXECUTE ON FUNCTION sync_subscription(...) TO anon, authenticated;
