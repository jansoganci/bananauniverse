-- =====================================================
-- Migration 092: Add device_id to user_credits
-- Purpose: Support hybrid authentication (user_id OR device_id)
-- Date: 2025-11-20
-- =====================================================
-- This migration merges the anonymous_credits table functionality
-- into user_credits by adding device_id column support
-- =====================================================

DO $$
BEGIN
    RAISE NOTICE 'Starting device_id migration for user_credits...';
END $$;

-- =====================================================
-- STEP 1: Add device_id Column to user_credits
-- =====================================================

ALTER TABLE user_credits
ADD COLUMN IF NOT EXISTS device_id TEXT;

DO $$
BEGIN
    RAISE NOTICE '✅ Step 1: Added device_id column to user_credits';
END $$;

-- =====================================================
-- STEP 2: Make user_id Nullable (Either user_id OR device_id)
-- =====================================================

ALTER TABLE user_credits
ALTER COLUMN user_id DROP NOT NULL;

DO $$
BEGIN
    RAISE NOTICE '✅ Step 2: Made user_id nullable (now supports device_id-only records)';
END $$;

-- =====================================================
-- STEP 3: Add Constraint to Ensure Either user_id OR device_id
-- =====================================================

ALTER TABLE user_credits
DROP CONSTRAINT IF EXISTS user_credits_identifier_check;

ALTER TABLE user_credits
ADD CONSTRAINT user_credits_identifier_check
CHECK (
    (user_id IS NOT NULL AND device_id IS NULL) OR
    (user_id IS NULL AND device_id IS NOT NULL) OR
    (user_id IS NOT NULL AND device_id IS NOT NULL)
);

DO $$
BEGIN
    RAISE NOTICE '✅ Step 3: Added constraint to ensure user_id OR device_id exists';
END $$;

-- =====================================================
-- STEP 4: Add Unique Constraint on device_id
-- =====================================================

CREATE UNIQUE INDEX IF NOT EXISTS idx_user_credits_device_id_unique
ON user_credits(device_id)
WHERE device_id IS NOT NULL;

DO $$
BEGIN
    RAISE NOTICE '✅ Step 4: Added unique index on device_id';
END $$;

-- =====================================================
-- STEP 5: Migrate Data from anonymous_credits (if exists)
-- =====================================================

DO $$
BEGIN
    -- Check if anonymous_credits table exists
    IF EXISTS (SELECT FROM information_schema.tables WHERE table_name = 'anonymous_credits') THEN
        -- Migrate anonymous credits to user_credits
        INSERT INTO user_credits (device_id, credits, created_at, updated_at, credits_total, initial_grant_claimed)
        SELECT
            device_id,
            credits,
            created_at,
            updated_at,
            credits AS credits_total,  -- Assume current balance is total for old data
            TRUE AS initial_grant_claimed  -- Mark as claimed since they already have credits
        FROM anonymous_credits
        ON CONFLICT (device_id) WHERE device_id IS NOT NULL DO NOTHING;

        RAISE NOTICE '✅ Step 5: Migrated data from anonymous_credits to user_credits';
    ELSE
        RAISE NOTICE '⏭️  Step 5: anonymous_credits table does not exist, skipping migration';
    END IF;
END $$;

-- =====================================================
-- STEP 6: Update RLS Policies for device_id Support
-- =====================================================

-- Drop old policies
DROP POLICY IF EXISTS "Users can view their own credits" ON user_credits;
DROP POLICY IF EXISTS "Users can update their own credits" ON user_credits;
DROP POLICY IF EXISTS "Users can insert their own credits" ON user_credits;

-- New policy: Users can view their own credits (authenticated)
CREATE POLICY "Users can view their own credits"
ON user_credits
FOR SELECT
USING (auth.uid() = user_id);

-- New policy: Anonymous users can view their credits via device_id
CREATE POLICY "Anonymous users can view their credits"
ON user_credits
FOR SELECT
USING (
    device_id IS NOT NULL AND
    current_setting('request.device_id', true) = device_id
);

-- New policy: Users can update their own credits (authenticated)
CREATE POLICY "Users can update their own credits"
ON user_credits
FOR UPDATE
USING (auth.uid() = user_id);

-- New policy: Anonymous users can update their credits via device_id
CREATE POLICY "Anonymous users can update their credits"
ON user_credits
FOR UPDATE
USING (
    device_id IS NOT NULL AND
    current_setting('request.device_id', true) = device_id
);

-- New policy: Service role can manage all credits (for Edge Functions)
CREATE POLICY "Service role can manage all credits"
ON user_credits
FOR ALL
USING (auth.jwt()->>'role' = 'service_role');

DO $$
BEGIN
    RAISE NOTICE '✅ Step 6: Updated RLS policies for hybrid auth support';
END $$;

-- =====================================================
-- STEP 7: Add device_id to credit_transactions
-- =====================================================

ALTER TABLE credit_transactions
ADD COLUMN IF NOT EXISTS device_id TEXT;

-- Make user_id nullable in credit_transactions too
ALTER TABLE credit_transactions
ALTER COLUMN user_id DROP NOT NULL;

-- Add constraint to ensure either user_id OR device_id
ALTER TABLE credit_transactions
DROP CONSTRAINT IF EXISTS credit_transactions_identifier_check;

ALTER TABLE credit_transactions
ADD CONSTRAINT credit_transactions_identifier_check
CHECK (user_id IS NOT NULL OR device_id IS NOT NULL);

-- Add index for device_id lookups
CREATE INDEX IF NOT EXISTS idx_credit_transactions_device_id
ON credit_transactions(device_id)
WHERE device_id IS NOT NULL;

DO $$
BEGIN
    RAISE NOTICE '✅ Step 7: Added device_id support to credit_transactions';
END $$;

-- =====================================================
-- VERIFICATION
-- =====================================================

DO $$
DECLARE
    v_column_exists BOOLEAN;
    v_constraint_exists BOOLEAN;
BEGIN
    -- Check if device_id column exists in user_credits
    SELECT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'user_credits' AND column_name = 'device_id'
    ) INTO v_column_exists;

    -- Check if constraint exists
    SELECT EXISTS (
        SELECT 1 FROM information_schema.table_constraints
        WHERE table_name = 'user_credits'
        AND constraint_name = 'user_credits_identifier_check'
    ) INTO v_constraint_exists;

    IF NOT v_column_exists THEN
        RAISE EXCEPTION 'VERIFICATION FAILED: device_id column not added to user_credits';
    END IF;

    IF NOT v_constraint_exists THEN
        RAISE EXCEPTION 'VERIFICATION FAILED: identifier check constraint not added';
    END IF;

    RAISE NOTICE '========================================';
    RAISE NOTICE 'Migration 092: Add device_id to user_credits';
    RAISE NOTICE '========================================';
    RAISE NOTICE '✅ device_id column added to user_credits';
    RAISE NOTICE '✅ user_id made nullable';
    RAISE NOTICE '✅ Hybrid auth constraint added';
    RAISE NOTICE '✅ RLS policies updated';
    RAISE NOTICE '✅ credit_transactions updated';
    RAISE NOTICE '========================================';
    RAISE NOTICE '🎉 SUCCESS: Migration complete!';
    RAISE NOTICE '========================================';
END $$;
