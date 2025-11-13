-- =====================================================
-- Quick Verification: Transaction Logging
-- Run this in Supabase SQL Editor to verify logging works
-- =====================================================

-- Replace with your test device ID
-- Device ID from test: test-tx-log-1763053453

-- =====================================================
-- VERIFICATION 1: Check if transactions exist
-- =====================================================
SELECT 
    'VERIFICATION 1: Transaction Count' as test,
    COUNT(*) as transaction_count,
    CASE 
        WHEN COUNT(*) >= 3 THEN '✅ PASSED'
        ELSE '❌ FAILED - Expected at least 3 transactions'
    END as result
FROM credit_transactions
WHERE device_id = 'test-tx-log-1763053453';

-- =====================================================
-- VERIFICATION 2: Check transaction structure
-- =====================================================
SELECT 
    'VERIFICATION 2: Transaction Structure' as test,
    COUNT(*) as transactions_with_all_fields,
    CASE 
        WHEN COUNT(*) >= 3 
             AND COUNT(CASE WHEN amount IS NULL THEN 1 END) = 0
             AND COUNT(CASE WHEN balance_before IS NULL THEN 1 END) = 0
             AND COUNT(CASE WHEN balance_after IS NULL THEN 1 END) = 0
             AND COUNT(CASE WHEN reason IS NULL THEN 1 END) = 0
        THEN '✅ PASSED'
        ELSE '❌ FAILED - Missing required fields'
    END as result
FROM credit_transactions
WHERE device_id = 'test-tx-log-1763053453';

-- =====================================================
-- VERIFICATION 3: Check deduction transactions
-- =====================================================
SELECT 
    'VERIFICATION 3: Deduction Transactions' as test,
    COUNT(*) as deduction_count,
    SUM(ABS(amount)) as total_deducted,
    CASE 
        WHEN COUNT(*) >= 3 AND SUM(ABS(amount)) >= 3 THEN '✅ PASSED'
        ELSE '❌ FAILED - Expected 3 deductions totaling 3 credits'
    END as result
FROM credit_transactions
WHERE device_id = 'test-tx-log-1763053453'
  AND amount < 0
  AND reason = 'image_processing';

-- =====================================================
-- VERIFICATION 4: Check balance progression
-- =====================================================
SELECT 
    'VERIFICATION 4: Balance Progression' as test,
    MIN(balance_before) as min_balance_before,
    MAX(balance_after) as max_balance_after,
    CASE 
        WHEN MIN(balance_before) = 10 
             AND MAX(balance_after) <= 7 
             AND MAX(balance_after) >= 0
        THEN '✅ PASSED'
        ELSE '❌ FAILED - Balance progression incorrect'
    END as result
FROM credit_transactions
WHERE device_id = 'test-tx-log-1763053453'
  AND reason = 'image_processing';

-- =====================================================
-- VERIFICATION 5: Show actual transaction data
-- =====================================================
SELECT 
    'VERIFICATION 5: Transaction Details' as test,
    created_at,
    amount,
    balance_before,
    balance_after,
    reason,
    CASE 
        WHEN amount = -1 
             AND balance_before IS NOT NULL 
             AND balance_after IS NOT NULL 
             AND reason = 'image_processing'
        THEN '✅ VALID'
        ELSE '❌ INVALID'
    END as validation
FROM credit_transactions
WHERE device_id = 'test-tx-log-1763053453'
ORDER BY created_at ASC;

-- =====================================================
-- SUMMARY: Overall Status
-- =====================================================
SELECT 
    'SUMMARY' as test,
    CASE 
        WHEN (SELECT COUNT(*) FROM credit_transactions WHERE device_id = 'test-tx-log-1763053453') >= 3
             AND (SELECT COUNT(*) FROM credit_transactions WHERE device_id = 'test-tx-log-1763053453' AND amount < 0) >= 3
             AND (SELECT COUNT(*) FROM credit_transactions WHERE device_id = 'test-tx-log-1763053453' AND reason = 'image_processing') >= 3
        THEN '✅ ALL TESTS PASSED - Transaction logging is working!'
        ELSE '❌ SOME TESTS FAILED - Check individual verifications above'
    END as overall_status;

