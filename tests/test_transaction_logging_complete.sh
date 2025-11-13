#!/bin/bash
# Complete Test: Verify Transaction Logging is Working
# Purpose: Test that transactions are logged after migration 065

set -e

# ============================================
# Configuration
# ============================================
SUPABASE_URL="${SUPABASE_URL:-https://jiorfutbmahpfgplkats.supabase.co}"
ANON_KEY="${ANON_KEY:-eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imppb3JmdXRibWFocGZncGxrYXRzIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjIxMTUzMTQsImV4cCI6MjA3NzQ3NTMxNH0.Ft5q_ebLUbIf6aKtf-0boWdOJvKPQSnEfOAmP5Oo69M}"

# Generate unique device ID for testing
DEVICE_ID="test-tx-log-$(date +%s)"

echo "🧪 Complete Transaction Logging Test"
echo "=================================================="
echo "Supabase URL: $SUPABASE_URL"
echo "Device ID: $DEVICE_ID"
echo ""

# ============================================
# Test 1: Consume Credits and Verify Logging
# ============================================
echo "📋 Test 1: Consume Credits and Verify Transactions Logged"
echo "--------------------------------------------------"

echo "Step 1: Consuming 3 credits (submitting 3 jobs)..."
for i in {1..3}; do
  echo "  Submitting job #$i..."
  RESPONSE=$(curl -s -X POST "$SUPABASE_URL/functions/v1/submit-job" \
    -H "Authorization: Bearer $ANON_KEY" \
    -H "apikey: $ANON_KEY" \
    -H "Content-Type: application/json" \
    -H "device-id: $DEVICE_ID" \
    -d "{
      \"image_url\": \"https://example.com/test-$i.jpg\",
      \"prompt\": \"test transaction logging $i\",
      \"device_id\": \"$DEVICE_ID\"
    }")
  
  HTTP_CODE=$(echo "$RESPONSE" | grep -o '"success":true' || echo "")
  if [ -n "$HTTP_CODE" ]; then
    CREDITS=$(echo "$RESPONSE" | grep -o '"credits_remaining":[0-9]*' | cut -d: -f2)
    echo "    ✅ Job #$i succeeded. Credits remaining: $CREDITS"
  else
    echo "    ⚠️  Job #$i response: $RESPONSE"
  fi
  
  sleep 1
done

echo ""
echo "Step 2: Verify transactions were logged..."
echo ""
echo "Run this SQL query in Supabase SQL Editor:"
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
echo "Expected:"
echo "  - 3 transactions"
echo "  - amount: -1, -1, -1 (all negative)"
echo "  - balance_before: 10, 9, 8"
echo "  - balance_after: 9, 8, 7"
echo "  - reason: 'image_processing'"
echo ""

# ============================================
# Test 2: Add Credits (Refund) and Verify Logging
# ============================================
echo "📋 Test 2: Add Credits (Refund) and Verify Transaction Logged"
echo "--------------------------------------------------"

echo "Step 1: Adding 1 credit (simulate refund)..."
echo ""
echo "Run this SQL in Supabase SQL Editor:"
echo ""
echo "  SELECT add_credits("
echo "    NULL,"
echo "    '$DEVICE_ID',"
echo "    1,"
echo "    'refund-test-$(date +%s)'"
echo "  );"
echo ""
echo "Step 2: Verify refund transaction was logged..."
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
echo "    AND reason = 'refund'"
echo "  ORDER BY created_at DESC"
echo "  LIMIT 1;"
echo ""
echo "Expected:"
echo "  - amount: 1 (positive)"
echo "  - balance_before: 7"
echo "  - balance_after: 8"
echo "  - reason: 'refund'"
echo ""

# ============================================
# Test 3: Verify Analytics Queries Work
# ============================================
echo "📋 Test 3: Verify Analytics Queries Return Data"
echo "--------------------------------------------------"

echo "Run this SQL query:"
echo ""
echo "  SELECT"
echo "    COUNT(*) as total_transactions,"
echo "    SUM(CASE WHEN amount < 0 THEN ABS(amount) ELSE 0 END) as credits_spent,"
echo "    SUM(CASE WHEN amount > 0 THEN amount ELSE 0 END) as credits_added,"
echo "    COUNT(DISTINCT reason) as unique_reasons"
echo "  FROM credit_transactions"
echo "  WHERE device_id = '$DEVICE_ID';"
echo ""
echo "Expected:"
echo "  - total_transactions: 4 (3 consumptions + 1 refund)"
echo "  - credits_spent: 3"
echo "  - credits_added: 1"
echo "  - unique_reasons: 2 ('image_processing', 'refund')"
echo ""

# ============================================
# Summary
# ============================================
echo "📊 Test Summary"
echo "=================================================="
echo "✅ Test 1: consume_credits() should log 3 transactions"
echo "✅ Test 2: add_credits() should log 1 refund transaction"
echo "✅ Test 3: Analytics queries should return data"
echo ""
echo "Device ID for SQL queries: $DEVICE_ID"
echo ""
echo "Next Steps:"
echo "1. Run the SQL queries above in Supabase SQL Editor"
echo "2. Verify transaction counts and data structure"
echo "3. Check that analytics queries return data"
echo ""
echo "✅ Transaction logging test script complete!"

