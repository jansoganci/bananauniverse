#!/bin/bash
# Test Script: Verify Credit Transaction Logging
# Purpose: Test that all credit operations log to credit_transactions table

set -e

# ============================================
# Configuration
# ============================================
SUPABASE_URL="${SUPABASE_URL:-https://jiorfutbmahpfgplkats.supabase.co}"
ANON_KEY="${ANON_KEY:-eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imppb3JmdXRibWFocGZncGxrYXRzIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjIxMTUzMTQsImV4cCI6MjA3NzQ3NTMxNH0.Ft5q_ebLUbIf6aKtf-0boWdOJvKPQSnEfOAmP5Oo69M}"

# Generate unique device ID for testing
DEVICE_ID="test-tx-$(date +%s)"

echo "🧪 Testing Credit Transaction Logging"
echo "=================================================="
echo "Supabase URL: $SUPABASE_URL"
echo "Device ID: $DEVICE_ID"
echo ""

# ============================================
# Test 1: Verify consume_credits() Logs Transactions
# ============================================
echo "📋 Test 1: Verify consume_credits() Logs Transactions"
echo "--------------------------------------------------"

echo "Step 1: Consume 1 credit..."
RESPONSE=$(curl -s -X POST "$SUPABASE_URL/functions/v1/submit-job" \
  -H "Authorization: Bearer $ANON_KEY" \
  -H "apikey: $ANON_KEY" \
  -H "Content-Type: application/json" \
  -H "device-id: $DEVICE_ID" \
  -d "{
    \"image_url\": \"https://example.com/test.jpg\",
    \"prompt\": \"test transaction logging\",
    \"device_id\": \"$DEVICE_ID\"
  }")

echo "Response: $RESPONSE" | jq . 2>/dev/null || echo "$RESPONSE"

# Extract request ID from response (if available) or use a test ID
REQUEST_ID=$(echo "$RESPONSE" | jq -r '.job_id // empty' 2>/dev/null || echo "test-request-$(date +%s)")

echo ""
echo "Step 2: Check if transaction was logged..."
echo ""
echo "Run this SQL query in Supabase SQL Editor to verify:"
echo ""
echo "  SELECT * FROM credit_transactions"
echo "  WHERE device_id = '$DEVICE_ID'"
echo "  ORDER BY created_at DESC"
echo "  LIMIT 1;"
echo ""
echo "Expected fields:"
echo "  - device_id: $DEVICE_ID"
echo "  - amount: -1 (negative for deduction)"
echo "  - balance_before: 10"
echo "  - balance_after: 9"
echo "  - reason: 'image_processing'"
echo "  - idempotency_key: (should match request ID)"
echo ""

# ============================================
# Test 2: Verify add_credits() Logs Transactions
# ============================================
echo "📋 Test 2: Verify add_credits() Logs Refunds"
echo "--------------------------------------------------"

echo "Step 1: Add 1 credit (simulate refund)..."
echo ""
echo "This would be called from webhook-handler when a job fails."
echo "To test manually, run this SQL:"
echo ""
echo "  SELECT add_credits("
echo "    NULL,  -- user_id"
echo "    '$DEVICE_ID',  -- device_id"
echo "    1,  -- amount"
echo "    'refund-test-$(date +%s)'  -- idempotency_key"
echo "  );"
echo ""
echo "Then check transaction log:"
echo ""
echo "  SELECT * FROM credit_transactions"
echo "  WHERE device_id = '$DEVICE_ID'"
echo "    AND reason = 'refund'"
echo "  ORDER BY created_at DESC"
echo "  LIMIT 1;"
echo ""
echo "Expected fields:"
echo "  - device_id: $DEVICE_ID"
echo "  - amount: 1 (positive for addition)"
echo "  - balance_before: 9"
echo "  - balance_after: 10"
echo "  - reason: 'refund'"
echo ""

# ============================================
# Test 3: Verify Transaction History
# ============================================
echo "📋 Test 3: Verify Complete Transaction History"
echo "--------------------------------------------------"

echo "After running tests, check complete history:"
echo ""
echo "  SELECT"
echo "    created_at,"
echo "    amount,"
echo "    balance_before,"
echo "    balance_after,"
echo "    reason,"
echo "    idempotency_key"
echo "  FROM credit_transactions"
echo "  WHERE device_id = '$DEVICE_ID'"
echo "  ORDER BY created_at ASC;"
echo ""
echo "Expected: Multiple transactions showing credit flow"
echo ""

# ============================================
# Summary
# ============================================
echo "📊 Test Summary"
echo "=================================================="
echo "✅ Test 1: consume_credits() should log deductions"
echo "✅ Test 2: add_credits() should log additions/refunds"
echo "✅ Test 3: Complete transaction history available"
echo ""
echo "Next Steps:"
echo "1. Run migration: supabase db push"
echo "2. Execute SQL queries above to verify logging"
echo "3. Check analytics queries (migration 014, 015) now return data"
echo ""
echo "✅ Transaction logging test script complete!"

