# 🧪 Credit System Testing Guide

**Quick Start:** Run comprehensive stress tests on the credit management system

---

## 📋 Overview

This guide provides everything you need to test the credit system comprehensively, including:

- ✅ Normal flows (authenticated & anonymous users)
- ⚠️ Edge cases (insufficient credits, invalid inputs)
- 🏃 Race conditions (concurrent requests)
- 🚨 Abuse vectors (replay attacks, injection attempts)

---

## 🚀 Quick Start

### 1. Set Environment Variables

```bash
export SUPABASE_URL="https://jiorfutbmahpfgplkats.supabase.co"
export SUPABASE_ANON_KEY="your_anon_key_here"
export SUPABASE_SERVICE_KEY="your_service_key_here"  # Optional, for admin tests
export FAL_WEBHOOK_TOKEN="your_webhook_token"       # Optional, for webhook tests
```

### 2. Run Automated Test Suite

```bash
cd /Users/jans./Downloads/banana.universe
./tests/credit_system_stress_test.sh
```

### 3. Review Results

The script will output:
- ✅ Passed tests (green)
- ❌ Failed tests (red)
- Summary with total pass/fail counts

---

## 📚 Documentation

### Full Analysis Document
**Location:** `docs/CREDIT_SYSTEM_SECURITY_AUDIT.md`

Contains:
- Complete system architecture
- All entry points and attack surfaces
- Detailed test scenarios with cURL commands
- Expected results matrix
- Known issues and recommendations

### Test Script
**Location:** `tests/credit_system_stress_test.sh`

Automated test suite covering:
- Normal flows
- Edge cases
- Race conditions
- Abuse vectors

---

## 🎯 Test Categories

### Category 1: Normal Flows ✅
- Get credits (anonymous user)
- Add credits
- Consume credits
- Submit job (Edge Function)
- Webhook refund

### Category 2: Edge Cases ⚠️
- Insufficient credits
- Idempotency (duplicate requests)
- Invalid amounts (negative, zero)
- Missing identifiers

### Category 3: Race Conditions 🏃
- Concurrent requests (same idempotency key)
- Concurrent requests (different keys, limited credits)

### Category 4: Abuse Vectors 🚨
- Replay attacks
- Negative credit injection
- Cross-user credit theft attempts
- Webhook token spoofing

---

## 🔍 Manual Testing

### Test Individual Scenarios

#### Get Credits
```bash
curl -X POST "${SUPABASE_URL}/rest/v1/rpc/get_credits" \
  -H "apikey: ${SUPABASE_ANON_KEY}" \
  -H "Content-Type: application/json" \
  -d '{"p_device_id": "test-device-123"}'
```

#### Consume Credits
```bash
curl -X POST "${SUPABASE_URL}/rest/v1/rpc/consume_credits" \
  -H "apikey: ${SUPABASE_ANON_KEY}" \
  -H "Content-Type: application/json" \
  -d '{
    "p_device_id": "test-device-123",
    "p_amount": 1,
    "p_idempotency_key": "test-key-123"
  }'
```

#### Add Credits
```bash
curl -X POST "${SUPABASE_URL}/rest/v1/rpc/add_credits" \
  -H "apikey: ${SUPABASE_ANON_KEY}" \
  -H "Content-Type: application/json" \
  -d '{
    "p_device_id": "test-device-123",
    "p_amount": 10,
    "p_idempotency_key": "add-key-123"
  }'
```

---

## 📊 Verification Queries

### Check Credit Balance
```sql
-- Anonymous user
SELECT * FROM anonymous_credits WHERE device_id = 'test-device-123';

-- Authenticated user
SELECT * FROM user_credits WHERE user_id = 'test-user-123';
```

### Check Transaction Log
```sql
SELECT * FROM credit_transactions 
WHERE device_id = 'test-device-123' 
ORDER BY created_at DESC 
LIMIT 10;
```

### Check Idempotency Keys
```sql
SELECT * FROM idempotency_keys 
WHERE device_id = 'test-device-123' 
ORDER BY created_at DESC 
LIMIT 10;
```

---

## ⚠️ Known Issues

### Critical 🔴
1. **IAP Webhook Signature Not Verified**
   - Location: `supabase/functions/iap-webhook/index.ts`
   - Risk: Fake refund notifications could remove credits
   - Status: ⚠️ Needs implementation

### Medium Priority 🟡
2. **Idempotency Key Reuse**
   - Risk: If attacker knows key, they can replay
   - Mitigation: Use cryptographically random keys

3. **Anonymous Device ID Spoofing**
   - Risk: If device_id is predictable, could be spoofed
   - Mitigation: Use UUIDs, validate format

---

## 🎯 Success Criteria

All tests should verify:
- ✅ Normal flows work correctly
- ✅ Edge cases handled gracefully
- ✅ No race conditions cause double-charging
- ✅ All abuse vectors blocked
- ✅ Transaction logging complete
- ✅ Idempotency prevents duplicates

---

## 📝 Next Steps

1. **Run the automated test suite**
   ```bash
   ./tests/credit_system_stress_test.sh
   ```

2. **Review the full analysis**
   - Read `docs/CREDIT_SYSTEM_SECURITY_AUDIT.md`
   - Understand all test scenarios

3. **Execute manual tests**
   - Use cURL commands from the audit document
   - Test specific scenarios you're concerned about

4. **Verify results**
   - Check database tables
   - Review transaction logs
   - Confirm idempotency keys

5. **Fix any issues found**
   - Address critical issues first
   - Update test suite if needed

---

## 🆘 Troubleshooting

### Test Script Fails
- Check environment variables are set
- Verify SUPABASE_URL and SUPABASE_ANON_KEY are correct
- Ensure you have network access

### Tests Timeout
- Check Supabase project status
- Verify rate limits aren't exceeded
- Try running tests individually

### Unexpected Results
- Review the audit document for expected behavior
- Check database directly for state
- Verify RLS policies are correct

---

**Ready to test?** Run `./tests/credit_system_stress_test.sh` and review the results!

