-- Migration: Add admin access to credits tables for analytics
-- Author: AI Assistant
-- Date: 2025-01-20
-- Description: Enables admin users to access credits data for business analytics

-- =====================================================
-- 1. ADD ADMIN SUBSCRIPTION TIER
-- =====================================================

-- Update profiles table to allow ADMIN tier
ALTER TABLE profiles 
DROP CONSTRAINT IF EXISTS profiles_subscription_tier_check;

ALTER TABLE profiles 
ADD CONSTRAINT profiles_subscription_tier_check 
CHECK (subscription_tier IN ('free', 'pro', 'ADMIN'));

-- Add comment for documentation
COMMENT ON COLUMN profiles.subscription_tier IS 'User subscription tier: free, pro, or ADMIN';

-- =====================================================
-- 2. CREATE ADMIN DETECTION FUNCTION
-- =====================================================

-- Drop existing function if it exists
DROP FUNCTION IF EXISTS public.is_admin_user(UUID);

-- Helper function to check if a user is admin
CREATE OR REPLACE FUNCTION public.is_admin_user(user_uuid UUID DEFAULT auth.uid())
RETURNS BOOLEAN AS $$
BEGIN
  -- Return false if no user UUID provided
  IF user_uuid IS NULL THEN
    RETURN FALSE;
  END IF;
  
  -- Check if user has ADMIN subscription tier
  RETURN EXISTS (
    SELECT 1 FROM profiles 
    WHERE id = user_uuid 
    AND subscription_tier = 'ADMIN'
  );
EXCEPTION
  WHEN OTHERS THEN
    -- Return false for safety if there's any error
    RETURN FALSE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant execute permission to authenticated users
GRANT EXECUTE ON FUNCTION public.is_admin_user(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.is_admin_user(UUID) TO service_role;

-- Add comment for documentation
COMMENT ON FUNCTION public.is_admin_user(UUID) IS 'Returns true if the specified user has ADMIN subscription tier';

-- =====================================================
-- 3. ADD ADMIN RLS POLICIES FOR USER_CREDITS
-- =====================================================

-- Admin can view all user credits (for analytics)
CREATE POLICY "Admin can view all user credits" ON user_credits
    FOR SELECT USING (public.is_admin_user());

-- Admin can view all user credit details (including quota data)
CREATE POLICY "Admin can view all user credit details" ON user_credits
    FOR SELECT USING (public.is_admin_user());

-- =====================================================
-- 4. ADD ADMIN RLS POLICIES FOR CREDIT_TRANSACTIONS
-- =====================================================

-- Admin can view all credit transactions (for audit trail analytics)
CREATE POLICY "Admin can view all credit transactions" ON credit_transactions
    FOR SELECT USING (public.is_admin_user());

-- =====================================================
-- 5. ADD ADMIN RLS POLICIES FOR ANONYMOUS_CREDITS
-- =====================================================

-- Enable RLS on anonymous_credits if not already enabled
ALTER TABLE anonymous_credits ENABLE ROW LEVEL SECURITY;

-- Admin can view all anonymous credits (for analytics)
CREATE POLICY "Admin can view all anonymous credits" ON anonymous_credits
    FOR SELECT USING (public.is_admin_user());

-- Keep existing anonymous access (no RLS for anonymous users)
-- This allows anonymous users to manage their credits without authentication
-- Note: Anonymous credits don't have user-specific RLS policies

-- =====================================================
-- 6. CREATE ANALYTICS VIEWS FOR ADMIN
-- =====================================================

-- Drop existing view if it exists
DROP VIEW IF EXISTS admin_credit_analytics;

-- Aggregated analytics view for admin dashboard
CREATE VIEW admin_credit_analytics AS
SELECT 
    DATE(created_at) as date,
    COUNT(*) as total_transactions,
    SUM(CASE WHEN amount > 0 THEN amount ELSE 0 END) as credits_added,
    SUM(CASE WHEN amount < 0 THEN ABS(amount) ELSE 0 END) as credits_spent,
    COUNT(DISTINCT user_id) as unique_users,
    SUM(CASE WHEN source = 'purchase' THEN amount ELSE 0 END) as purchase_credits,
    SUM(CASE WHEN source = 'spend' THEN ABS(amount) ELSE 0 END) as spent_credits
FROM credit_transactions
GROUP BY DATE(created_at)
ORDER BY date DESC;

-- Grant access to admin users only
GRANT SELECT ON admin_credit_analytics TO authenticated;

-- Add comment for documentation
COMMENT ON VIEW admin_credit_analytics IS 'Daily aggregated credit analytics for admin users';

-- =====================================================
-- 7. CREATE USER SUMMARY VIEW FOR ADMIN
-- =====================================================

-- Drop existing view if it exists
DROP VIEW IF EXISTS admin_user_credit_summary;

-- User credit summary view for admin
CREATE VIEW admin_user_credit_summary AS
SELECT 
    uc.user_id,
    p.email,
    p.subscription_tier,
    uc.credits as current_credits,
    uc.daily_quota_used,
    uc.daily_quota_limit,
    uc.last_quota_reset,
    uc.created_at as credits_created_at,
    uc.updated_at as credits_updated_at,
    COUNT(ct.id) as total_transactions,
    SUM(CASE WHEN ct.amount > 0 THEN ct.amount ELSE 0 END) as lifetime_credits_added,
    SUM(CASE WHEN ct.amount < 0 THEN ABS(ct.amount) ELSE 0 END) as lifetime_credits_spent
FROM user_credits uc
LEFT JOIN profiles p ON uc.user_id = p.id
LEFT JOIN credit_transactions ct ON uc.user_id = ct.user_id
GROUP BY uc.user_id, p.email, p.subscription_tier, uc.credits, uc.daily_quota_used, 
         uc.daily_quota_limit, uc.last_quota_reset, uc.created_at, uc.updated_at
ORDER BY uc.created_at DESC;

-- Grant access to admin users only
GRANT SELECT ON admin_user_credit_summary TO authenticated;

-- Add comment for documentation
COMMENT ON VIEW admin_user_credit_summary IS 'User credit summary for admin analytics';

-- =====================================================
-- 8. CREATE ANONYMOUS CREDITS SUMMARY VIEW
-- =====================================================

-- Drop existing view if it exists
DROP VIEW IF EXISTS admin_anonymous_credit_summary;

-- Anonymous credits summary view for admin
CREATE VIEW admin_anonymous_credit_summary AS
SELECT 
    device_id,
    credits as current_credits,
    daily_quota_used,
    daily_quota_limit,
    last_quota_reset,
    created_at,
    updated_at,
    EXTRACT(EPOCH FROM (NOW() - created_at))/86400 as days_since_created
FROM anonymous_credits
ORDER BY created_at DESC;

-- Grant access to admin users only
GRANT SELECT ON admin_anonymous_credit_summary TO authenticated;

-- Add comment for documentation
COMMENT ON VIEW admin_anonymous_credit_summary IS 'Anonymous credits summary for admin analytics';

-- =====================================================
-- 9. SECURITY NOTES
-- =====================================================

-- IMPORTANT SECURITY NOTES:
-- 1. Admin access is ONLY available through Supabase dashboard or direct SQL
-- 2. Admin functions are NOT exposed in the iOS app
-- 3. All admin access is logged by Supabase for audit purposes
-- 4. Admin users must have subscription_tier = 'ADMIN' in profiles table
-- 5. RLS policies ensure only admin users can access analytics data

-- To grant admin access to a user:
-- UPDATE profiles SET subscription_tier = 'ADMIN' WHERE id = 'user-uuid-here';

-- To revoke admin access:
-- UPDATE profiles SET subscription_tier = 'free' WHERE id = 'user-uuid-here';
