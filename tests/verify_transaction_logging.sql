-- =====================================================
-- Verification Script: Transaction Logging
-- Purpose: Verify that credit operations log to credit_transactions table
-- =====================================================

-- Test Device ID (use the one from the test run)
-- Replace 'test-device-1763053377' with your actual test device ID

-- =====================================================
-- Test 1: Verify consume_credits() Logged Transactions
-- =====================================================

SELECT 
    'Test 1: Check consume_credits() transactions' as test_name,
    COUNT(*) as transaction_count,
    SUM(CASE WHEN amount < 0 THEN 1 ELSE 0 END) as deductions,
    SUM(CASE WHEN amount > 0 THEN 1 ELSE 0 END) as additions,
    MIN(created_at) as first_transaction,
    MAX(created_at) as last_transaction
FROM credit_transactions
WHERE device_id = 'test-device-1763053377'
  AND reason = 'image_processing';

-- Expected: Should show 10 transactions (one for each credit consumed)

-- =====================================================
-- Test 2: Verify Transaction Details
-- =====================================================

SELECT 
    'Test 2: Transaction details' as test_name,
    created_at,
    device_id,
    amount,
    balance_before,
    balance_after,
    reason,
    idempotency_key,
    transaction_metadata
FROM credit_transactions
WHERE device_id = 'test-device-1763053377'
ORDER BY created_at ASC;

-- Expected: 
-- - 10 rows (one per credit consumed)
-- - amount: -1 for all (negative for deduction)
-- - balance_before: 10, 9, 8, 7, 6, 5, 4, 3, 2, 1
-- - balance_after: 9, 8, 7, 6, 5, 4, 3, 2, 1, 0
-- - reason: 'image_processing' for all
-- - idempotency_key: should match request IDs

-- =====================================================
-- Test 3: Test add_credits() Logging
-- =====================================================

-- Add 1 credit (simulate refund)
SELECT add_credits(
    NULL,                              -- user_id (NULL for anonymous)
    'test-device-1763053377',          -- device_id
    1,                                 -- amount
    'refund-test-verification'        -- idempotency_key
) as refund_result;

-- Check if refund transaction was logged
SELECT 
    'Test 3: Refund transaction logged' as test_name,
    created_at,
    device_id,
    amount,
    balance_before,
    balance_after,
    reason,
    idempotency_key
FROM credit_transactions
WHERE device_id = 'test-device-1763053377'
  AND reason = 'refund'
  AND idempotency_key = 'refund-test-verification'
ORDER BY created_at DESC
LIMIT 1;

-- Expected:
-- - amount: 1 (positive for addition)
-- - balance_before: 0
-- - balance_after: 1
-- - reason: 'refund'
-- - idempotency_key: 'refund-test-verification'

-- =====================================================
-- Test 4: Verify Complete Transaction History
-- =====================================================

SELECT 
    'Test 4: Complete transaction history' as test_name,
    COUNT(*) as total_transactions,
    COUNT(DISTINCT reason) as unique_reasons,
    SUM(CASE WHEN amount < 0 THEN ABS(amount) ELSE 0 END) as total_deducted,
    SUM(CASE WHEN amount > 0 THEN amount ELSE 0 END) as total_added,
    MIN(balance_after) as min_balance,
    MAX(balance_after) as max_balance
FROM credit_transactions
WHERE device_id = 'test-device-1763053377';

-- Expected:
-- - total_transactions: 11 (10 consumptions + 1 refund)
-- - unique_reasons: 2 ('image_processing', 'refund')
-- - total_deducted: 10
-- - total_added: 1
-- - min_balance: 0
-- - max_balance: 1

-- =====================================================
-- Test 5: Verify Analytics Queries Now Work
-- =====================================================

-- Test daily usage summary (should return data now)
SELECT 
    'Test 5: Analytics query test' as test_name,
    COUNT(*) as daily_transactions,
    SUM(CASE WHEN amount < 0 THEN ABS(amount) ELSE 0 END) as credits_spent,
    SUM(CASE WHEN amount > 0 THEN amount ELSE 0 END) as credits_added
FROM credit_transactions
WHERE DATE(created_at) = CURRENT_DATE
  AND device_id = 'test-device-1763053377';

-- Expected: Should return data (not empty)

-- =====================================================
-- Summary
-- =====================================================

SELECT 
    '✅ Transaction Logging Verification Complete' as status,
    'Check results above to verify all tests passed' as next_steps;

