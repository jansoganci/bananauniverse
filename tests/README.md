# Quota System Test Suite

## Overview

Comprehensive curl-based test suite for verifying the quota system end-to-end, including consumption, idempotency, refunds, and premium bypass logic.

## Prerequisites

- `curl` installed
- `python3` (for JSON formatting)
- Supabase project running (local or remote)
- Network access to your Supabase instance

## Setup

### Option 1: Local Development

```bash
# Start local Supabase
supabase start

# Set environment variable
export SUPABASE_URL=http://localhost:54321

# Run tests
./tests/curl_quota_suite.sh
```

### Option 2: Production/Remote

```bash
# Set your production Supabase URL
export SUPABASE_URL=https://your-project.supabase.co

# Get your anon key from Supabase dashboard
# Update line in curl_quota_suite.sh:
# Replace "anon_key_replace_me" with your actual anon key

# Run tests
./tests/curl_quota_suite.sh
```

## Test Scenarios

### Test 1: Basic Consumption ✅
- **Goal**: Verify quota consumption works
- **Action**: Single successful request
- **Expected**: HTTP 200, `quota_used = 1`

### Test 2: Idempotent Request 🔄
- **Goal**: Verify idempotency prevents double-charging
- **Action**: Same `client_request_id` as Test 1
- **Expected**: HTTP 200, `idempotent = true`, quota unchanged

### Test 3: Quota Exceeded ⚠️
- **Goal**: Verify daily quota limit enforced
- **Action**: 6 rapid requests (limit is 5)
- **Expected**: HTTP 429 on 6th request

### Test 4: Auto Refund Trigger 💰
- **Goal**: Verify automatic refund on AI failure
- **Action**: Invalid image URL (simulates Fal.AI error)
- **Expected**: HTTP 200 (processing fails), trigger fires automatically

### Test 5: Refund Limit 🛑
- **Goal**: Verify max 2 refunds/day enforced
- **Action**: 3 failed requests in succession
- **Expected**: First 2 refunded, 3rd may hit limit

### Test 6: Premium Bypass 👑
- **Goal**: Verify premium users bypass quota
- **Action**: Request with `is_premium: true`
- **Expected**: HTTP 200, `quota_used = 0`, unlimited quota

### Test 7: get_quota Initialization 🔧
- **Goal**: Verify RPC creates records on demand
- **Action**: Direct call to `get_quota` RPC
- **Expected**: HTTP 200, initializes if missing, returns current quota

## Output

Each test prints:
- HTTP status code (color-coded)
- Request ID and details
- Response JSON (formatted)
- Quota information
- Verification results

## Expected Log Output

```
═══════════════════════════════════════════════════════════════
  QUOTA SYSTEM TEST SUITE
  Base URL: http://localhost:54321
  Test Device ID: test_device_1234567890
═══════════════════════════════════════════════════════════════

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
TEST 1: Basic Consumption - First Request
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
✅ HTTP Status: 200

Quota Info:
  "quota_info": {
    "quota_used": 1,
    "quota_limit": 5,
    "quota_remaining": 4
  }
```

## Troubleshooting

### "Connection refused" Error
- **Fix**: Ensure Supabase is running locally or use production URL

### "401 Unauthorized" Error
- **Fix**: Update anon key in script (Test 7 only)

### "Cannot find uuidgen"
- **Fix**: Install `uuidgen` or use alternative UUID generator

### Quota Not Incrementing
- **Fix**: Check database migrations are applied
- **Fix**: Verify RLS policies allow quota consumption

## Database Verification

After running tests, verify in database:

```sql
-- Check quota records
SELECT * FROM daily_quotas 
WHERE device_id LIKE 'test_device%'
ORDER BY created_at DESC;

-- Check consumption logs
SELECT * FROM quota_consumption_log
WHERE request_id IN (
  SELECT request_id FROM quota_consumption_log
  WHERE device_id LIKE 'test_device%'
  ORDER BY consumed_at DESC
  LIMIT 10
);
```

## Continuous Integration

To integrate into CI/CD:

```bash
# Run tests and capture output
./tests/curl_quota_suite.sh > test_results.log 2>&1

# Check for failures
if grep -q "❌" test_results.log; then
  echo "Tests failed!"
  exit 1
fi

echo "All tests passed!"
exit 0
```

## Next Steps

After running tests:
1. Review quota logs in Supabase dashboard
2. Verify auto-refund trigger fired correctly
3. Check RLS policies allow all operations
4. Confirm migrations applied successfully

