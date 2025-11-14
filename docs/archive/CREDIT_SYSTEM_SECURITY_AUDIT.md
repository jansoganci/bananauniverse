# 🔒 Credit System Security Audit & Test Plan

**Date:** 2025-01-27  
**Purpose:** Comprehensive security analysis and stress testing of credit management system

---

## 📋 Table of Contents

1. [System Architecture Overview](#system-architecture-overview)
2. [Entry Points & Attack Surfaces](#entry-points--attack-surfaces)
3. [Normal Flow Scenarios](#normal-flow-scenarios)
4. [Edge Cases](#edge-cases)
5. [Abuse Vectors & Exploits](#abuse-vectors--exploits)
6. [Test Scenarios (cURL)](#test-scenarios-curl)
7. [Expected Results Matrix](#expected-results-matrix)

---

## 🏗️ System Architecture Overview

### Core Components

1. **Database Functions (PostgreSQL)**
   - `consume_credits(p_user_id, p_device_id, p_amount, p_idempotency_key)` - Deducts credits
   - `add_credits(p_user_id, p_device_id, p_amount, p_idempotency_key)` - Adds credits
   - `get_credits(p_user_id, p_device_id)` - Reads balance

2. **Edge Functions (Deno)**
   - `submit-job` - Consumes 1 credit, submits to fal.ai
   - `webhook-handler` - Refunds 1 credit on FAILED status
   - `verify-iap-purchase` - Grants credits from IAP purchase
   - `iap-webhook` - Removes credits on refund notification

3. **Data Tables**
   - `user_credits` - Authenticated user balances
   - `anonymous_credits` - Anonymous user balances
   - `credit_transactions` - Audit trail
   - `idempotency_keys` - Prevents duplicate operations
   - `iap_transactions` - IAP purchase history

### Security Mechanisms

- ✅ **Idempotency**: Prevents double-charging via `idempotency_keys` table
- ✅ **Row-Level Security (RLS)**: Users can only access their own credits
- ✅ **Atomic Operations**: `FOR UPDATE` locks prevent race conditions
- ✅ **Transaction Logging**: All operations logged to `credit_transactions`
- ✅ **Input Validation**: Amount must be positive, user_id OR device_id required

---

## 🎯 Entry Points & Attack Surfaces

### 1. Direct RPC Calls (Database Functions)
- **Risk Level:** 🔴 HIGH (if RLS bypassed)
- **Access:** `authenticated`, `anon`, `service_role`
- **Protection:** RLS policies, idempotency checks

### 2. Edge Functions
- **submit-job**: Requires auth or device_id
- **webhook-handler**: Requires `FAL_WEBHOOK_TOKEN`
- **verify-iap-purchase**: Requires auth or device_id + Apple JWT verification
- **iap-webhook**: Requires Apple webhook signature (currently not verified)

### 3. IAP Purchase Flow
- **Client → verify-iap-purchase**: Transaction JWT from Apple
- **Apple → iap-webhook**: Refund notifications

### 4. Webhook Flow
- **fal.ai → webhook-handler**: Job completion/failure callbacks

---

## ✅ Normal Flow Scenarios

### Scenario 1: Authenticated User - Successful Job Submission
1. User authenticates → gets JWT
2. Calls `submit-job` with JWT + image + prompt
3. `consume_credits()` deducts 1 credit
4. Job submitted to fal.ai
5. Webhook received → image uploaded → credits remain deducted

### Scenario 2: Anonymous User - Successful Job Submission
1. User generates device_id (UUID)
2. Calls `submit-job` with device_id + image + prompt
3. `consume_credits()` deducts 1 credit from `anonymous_credits`
4. Job submitted to fal.ai
5. Webhook received → image uploaded → credits remain deducted

### Scenario 3: Failed Job - Credit Refund
1. Job submitted → 1 credit deducted
2. fal.ai returns FAILED status
3. `webhook-handler` calls `add_credits()` with idempotency key `refund-{job_id}`
4. 1 credit refunded

### Scenario 4: IAP Purchase - Credit Grant
1. User purchases credits via StoreKit
2. Client sends transaction JWT to `verify-iap-purchase`
3. Apple transaction verified
4. `add_credits()` grants credits (10/25/50/100)
5. Transaction logged to `iap_transactions`

### Scenario 5: IAP Refund - Credit Removal
1. Apple sends REFUND notification to `iap-webhook`
2. Function finds transaction in `iap_transactions`
3. `consume_credits()` removes granted credits
4. Transaction status updated to 'refunded'

---

## ⚠️ Edge Cases

### EC1: Insufficient Credits
- **Test:** User with 0 credits tries to submit job
- **Expected:** 402 Payment Required, no credit deduction

### EC2: Concurrent Requests (Race Condition)
- **Test:** 10 simultaneous requests with same idempotency_key
- **Expected:** Only first request processes, others return cached result

### EC3: Concurrent Requests (Different Keys)
- **Test:** 10 simultaneous requests with different idempotency_keys, user has 5 credits
- **Expected:** First 5 succeed, last 5 fail with 402

### EC4: Missing Idempotency Key
- **Test:** Request without idempotency_key
- **Expected:** Request processes normally (no idempotency protection)

### EC5: Invalid Amount (Negative/Zero)
- **Test:** `consume_credits(p_amount: -1)` or `p_amount: 0`
- **Expected:** Error: "Amount must be positive"

### EC6: Missing User/Device ID
- **Test:** `consume_credits()` with both user_id and device_id as NULL
- **Expected:** Error: "Either user_id or device_id required"

### EC7: Premium User Bypass
- **Test:** User with active subscription tries to consume credits
- **Expected:** Credits bypassed, returns `is_premium: true, credits_remaining: 999999`

### EC8: Anonymous User → Authenticated User Migration
- **Test:** Anonymous user (device_id) signs up, then uses same device_id
- **Expected:** Separate balances (no automatic merge)

### EC9: Webhook Refund - Already Refunded
- **Test:** Webhook handler receives duplicate FAILED notification
- **Expected:** Idempotency prevents double refund

### EC10: IAP Purchase - Duplicate Transaction
- **Test:** Same `original_transaction_id` submitted twice
- **Expected:** Idempotency returns cached result, no double grant

### EC11: IAP Refund - Transaction Not Found
- **Test:** Refund notification for unknown transaction
- **Expected:** 404, no credit deduction

### EC12: IAP Refund - Already Refunded
- **Test:** Duplicate refund notification
- **Expected:** Status check prevents double deduction

---

## 🚨 Abuse Vectors & Exploits

### AV1: Replay Attack (Idempotency Bypass)
- **Attack:** Reuse old idempotency_key from previous successful request
- **Risk:** 🔴 HIGH
- **Protection:** Idempotency keys are cached, but attacker could reuse if they know the key
- **Test:** Submit same idempotency_key twice → should return cached result

### AV2: Double Spending (Race Condition)
- **Attack:** Send 2 requests simultaneously with different idempotency_keys, user has 1 credit
- **Risk:** 🟡 MEDIUM
- **Protection:** `FOR UPDATE` lock should prevent this
- **Test:** Concurrent requests → only one should succeed

### AV3: Negative Credit Injection
- **Attack:** Try to add negative credits via `add_credits(p_amount: -100)`
- **Risk:** 🟢 LOW
- **Protection:** Validation checks `p_amount > 0`
- **Test:** Should return error

### AV4: Cross-User Credit Theft
- **Attack:** Authenticated user tries to consume credits for another user_id
- **Risk:** 🟢 LOW
- **Protection:** RLS policies prevent access to other users' credits
- **Test:** Should fail with RLS violation

### AV5: Anonymous Device ID Spoofing
- **Attack:** Use another user's device_id to access their credits
- **Risk:** 🟡 MEDIUM
- **Protection:** RLS uses `current_setting('request.device_id')` which is set by Edge Function
- **Test:** Direct RPC call with different device_id → should fail

### AV6: IAP Receipt Replay
- **Attack:** Reuse same transaction JWT multiple times
- **Risk:** 🟡 MEDIUM
- **Protection:** Idempotency key based on `original_transaction_id`
- **Test:** Same transaction JWT twice → should return cached result

### AV7: Webhook Token Spoofing
- **Attack:** Send fake webhook without valid `FAL_WEBHOOK_TOKEN`
- **Risk:** 🟢 LOW
- **Protection:** Token verification in `webhook-handler`
- **Test:** Request without token → 401 Unauthorized

### AV8: Apple Webhook Signature Bypass
- **Attack:** Send fake refund notification without Apple signature
- **Risk:** 🔴 HIGH (currently not verified!)
- **Protection:** ⚠️ **MISSING** - `iap-webhook` doesn't verify signature
- **Test:** Send fake refund → should verify signature (currently doesn't)

### AV9: Idempotency Key Collision
- **Attack:** Two different users use same idempotency_key
- **Risk:** 🟢 LOW
- **Protection:** Idempotency key is scoped to (user_id, device_id, key)
- **Test:** Same key for different users → should work independently

### AV10: Credit Balance Overflow
- **Attack:** Add extremely large amount of credits
- **Risk:** 🟡 MEDIUM
- **Protection:** INTEGER type limit (2,147,483,647)
- **Test:** Add 2 billion credits → should work but hit DB limit

### AV11: Transaction Logging Bypass
- **Attack:** Direct RPC call to bypass transaction logging
- **Risk:** 🟢 LOW
- **Protection:** Logging is inside `consume_credits()` and `add_credits()` functions
- **Test:** All operations should log to `credit_transactions`

### AV12: Premium Status Bypass
- **Attack:** Try to bypass premium check by manipulating subscription table
- **Risk:** 🟡 MEDIUM
- **Protection:** Premium check queries `subscriptions` table directly
- **Test:** User without subscription → should consume credits normally

---

## 🧪 Test Scenarios (cURL)

### Prerequisites

```bash
# Environment variables
export SUPABASE_URL="https://jiorfutbmahpfgplkats.supabase.co"
export SUPABASE_ANON_KEY="your_anon_key"
export SUPABASE_SERVICE_KEY="your_service_key"
export FAL_WEBHOOK_TOKEN="your_webhook_token"
export DEVICE_ID_1="test-device-$(uuidgen)"
export DEVICE_ID_2="test-device-$(uuidgen)"
export USER_ID_1="test-user-$(uuidgen)"
```

---

### Test Category 1: Normal Flows

#### Test 1.1: Authenticated User - Get Credits
```bash
curl -X POST "${SUPABASE_URL}/rest/v1/rpc/get_credits" \
  -H "apikey: ${SUPABASE_ANON_KEY}" \
  -H "Authorization: Bearer ${JWT_TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{"p_user_id": "'${USER_ID_1}'"}'
```

#### Test 1.2: Anonymous User - Get Credits
```bash
curl -X POST "${SUPABASE_URL}/rest/v1/rpc/get_credits" \
  -H "apikey: ${SUPABASE_ANON_KEY}" \
  -H "Content-Type: application/json" \
  -d '{"p_device_id": "'${DEVICE_ID_1}'"}'
```

#### Test 1.3: Anonymous User - Consume 1 Credit (Success)
```bash
IDEMPOTENCY_KEY_1="test-$(uuidgen)"
curl -X POST "${SUPABASE_URL}/rest/v1/rpc/consume_credits" \
  -H "apikey: ${SUPABASE_ANON_KEY}" \
  -H "Content-Type: application/json" \
  -d '{
    "p_device_id": "'${DEVICE_ID_1}'",
    "p_amount": 1,
    "p_idempotency_key": "'${IDEMPOTENCY_KEY_1}'"
  }'
```

#### Test 1.4: Anonymous User - Add 10 Credits
```bash
IDEMPOTENCY_KEY_2="add-$(uuidgen)"
curl -X POST "${SUPABASE_URL}/rest/v1/rpc/add_credits" \
  -H "apikey: ${SUPABASE_ANON_KEY}" \
  -H "Content-Type: application/json" \
  -d '{
    "p_device_id": "'${DEVICE_ID_1}'",
    "p_amount": 10,
    "p_idempotency_key": "'${IDEMPOTENCY_KEY_2}'"
  }'
```

---

### Test Category 2: Edge Cases

#### Test 2.1: Insufficient Credits
```bash
# First, consume all credits
for i in {1..10}; do
  curl -X POST "${SUPABASE_URL}/rest/v1/rpc/consume_credits" \
    -H "apikey: ${SUPABASE_ANON_KEY}" \
    -H "Content-Type: application/json" \
    -d '{
      "p_device_id": "'${DEVICE_ID_1}'",
      "p_amount": 1,
      "p_idempotency_key": "test-insufficient-'${i}'"
    }'
done

# Then try to consume one more
curl -X POST "${SUPABASE_URL}/rest/v1/rpc/consume_credits" \
  -H "apikey: ${SUPABASE_ANON_KEY}" \
  -H "Content-Type: application/json" \
  -d '{
    "p_device_id": "'${DEVICE_ID_1}'",
    "p_amount": 1,
    "p_idempotency_key": "test-insufficient-11"
  }'
# Expected: {"success": false, "error": "Insufficient credits"}
```

#### Test 2.2: Idempotency - Duplicate Request
```bash
IDEMPOTENCY_KEY_DUP="dup-$(uuidgen)"
# First request
curl -X POST "${SUPABASE_URL}/rest/v1/rpc/consume_credits" \
  -H "apikey: ${SUPABASE_ANON_KEY}" \
  -H "Content-Type: application/json" \
  -d '{
    "p_device_id": "'${DEVICE_ID_1}'",
    "p_amount": 1,
    "p_idempotency_key": "'${IDEMPOTENCY_KEY_DUP}'"
  }'

# Duplicate request (same key)
curl -X POST "${SUPABASE_URL}/rest/v1/rpc/consume_credits" \
  -H "apikey: ${SUPABASE_ANON_KEY}" \
  -H "Content-Type: application/json" \
  -d '{
    "p_device_id": "'${DEVICE_ID_1}'",
    "p_amount": 1,
    "p_idempotency_key": "'${IDEMPOTENCY_KEY_DUP}'"
  }'
# Expected: Same response as first request (cached)
```

#### Test 2.3: Invalid Amount (Negative)
```bash
curl -X POST "${SUPABASE_URL}/rest/v1/rpc/consume_credits" \
  -H "apikey: ${SUPABASE_ANON_KEY}" \
  -H "Content-Type: application/json" \
  -d '{
    "p_device_id": "'${DEVICE_ID_1}'",
    "p_amount": -1,
    "p_idempotency_key": "test-negative"
  }'
# Expected: {"success": false, "error": "Amount must be positive"}
```

#### Test 2.4: Invalid Amount (Zero)
```bash
curl -X POST "${SUPABASE_URL}/rest/v1/rpc/consume_credits" \
  -H "apikey: ${SUPABASE_ANON_KEY}" \
  -H "Content-Type: application/json" \
  -d '{
    "p_device_id": "'${DEVICE_ID_1}'",
    "p_amount": 0,
    "p_idempotency_key": "test-zero"
  }'
# Expected: {"success": false, "error": "Amount must be positive"}
```

#### Test 2.5: Missing User/Device ID
```bash
curl -X POST "${SUPABASE_URL}/rest/v1/rpc/consume_credits" \
  -H "apikey: ${SUPABASE_ANON_KEY}" \
  -H "Content-Type: application/json" \
  -d '{
    "p_amount": 1,
    "p_idempotency_key": "test-missing-id"
  }'
# Expected: {"success": false, "error": "Either user_id or device_id required"}
```

---

### Test Category 3: Race Conditions

#### Test 3.1: Concurrent Requests (Same Idempotency Key)
```bash
IDEMPOTENCY_KEY_RACE="race-$(uuidgen)"
# Launch 10 concurrent requests
for i in {1..10}; do
  curl -X POST "${SUPABASE_URL}/rest/v1/rpc/consume_credits" \
    -H "apikey: ${SUPABASE_ANON_KEY}" \
    -H "Content-Type: application/json" \
    -d '{
      "p_device_id": "'${DEVICE_ID_1}'",
      "p_amount": 1,
      "p_idempotency_key": "'${IDEMPOTENCY_KEY_RACE}'"
    }' &
done
wait
# Expected: All 10 requests return same cached result, only 1 credit deducted
```

#### Test 3.2: Concurrent Requests (Different Keys, Limited Credits)
```bash
# Add 5 credits first
curl -X POST "${SUPABASE_URL}/rest/v1/rpc/add_credits" \
  -H "apikey: ${SUPABASE_ANON_KEY}" \
  -H "Content-Type: application/json" \
  -d '{
    "p_device_id": "'${DEVICE_ID_1}'",
    "p_amount": 5,
    "p_idempotency_key": "add-race-$(uuidgen)"
  }'

# Launch 10 concurrent requests with different keys
for i in {1..10}; do
  curl -X POST "${SUPABASE_URL}/rest/v1/rpc/consume_credits" \
    -H "apikey: ${SUPABASE_ANON_KEY}" \
    -H "Content-Type: application/json" \
    -d '{
      "p_device_id": "'${DEVICE_ID_1}'",
      "p_amount": 1,
      "p_idempotency_key": "race-diff-'${i}'"
    }' &
done
wait
# Expected: First 5 succeed, last 5 fail with insufficient credits
```

---

### Test Category 4: Edge Function Flows

#### Test 4.1: Submit Job - Anonymous User (Success)
```bash
JOB_ID_1="job-$(uuidgen)"
curl -X POST "${SUPABASE_URL}/functions/v1/submit-job" \
  -H "apikey: ${SUPABASE_ANON_KEY}" \
  -H "Content-Type: application/json" \
  -H "device-id: ${DEVICE_ID_1}" \
  -d '{
    "image_url": "https://example.com/test.jpg",
    "prompt": "enhance this image",
    "device_id": "'${DEVICE_ID_1}'",
    "client_request_id": "'${JOB_ID_1}'"
  }'
# Expected: 200 OK, job_id returned, 1 credit deducted
```

#### Test 4.2: Submit Job - Insufficient Credits
```bash
# Consume all credits first (10 initial + any added)
# Then submit job
JOB_ID_2="job-$(uuidgen)"
curl -X POST "${SUPABASE_URL}/functions/v1/submit-job" \
  -H "apikey: ${SUPABASE_ANON_KEY}" \
  -H "Content-Type: application/json" \
  -H "device-id: ${DEVICE_ID_1}" \
  -d '{
    "image_url": "https://example.com/test.jpg",
    "prompt": "enhance this image",
    "device_id": "'${DEVICE_ID_1}'",
    "client_request_id": "'${JOB_ID_2}'"
  }'
# Expected: 402 Payment Required
```

#### Test 4.3: Webhook Handler - Failed Job (Refund)
```bash
FAL_JOB_ID="fal-$(uuidgen)"
curl -X POST "${SUPABASE_URL}/functions/v1/webhook-handler" \
  -H "Content-Type: application/json" \
  -H "x-fal-webhook-token: ${FAL_WEBHOOK_TOKEN}" \
  -d '{
    "request_id": "'${FAL_JOB_ID}'",
    "status": "FAILED",
    "error": "Processing failed"
  }'
# Expected: 200 OK, 1 credit refunded
```

---

### Test Category 5: IAP Flows

#### Test 5.1: Verify IAP Purchase (Mock Transaction)
```bash
# Note: This requires a valid Apple transaction JWT
# For testing, you'll need to generate a test transaction from StoreKit
TRANSACTION_JWT="eyJ..." # Real JWT from Apple
curl -X POST "${SUPABASE_URL}/functions/v1/verify-iap-purchase" \
  -H "apikey: ${SUPABASE_ANON_KEY}" \
  -H "Authorization: Bearer ${JWT_TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{
    "transaction_jwt": "'${TRANSACTION_JWT}'",
    "product_id": "credits_10",
    "device_id": "'${DEVICE_ID_1}'"
  }'
# Expected: 200 OK, credits granted
```

#### Test 5.2: IAP Webhook - Refund Notification
```bash
# Note: This requires a valid Apple webhook payload
curl -X POST "${SUPABASE_URL}/functions/v1/iap-webhook" \
  -H "Content-Type: application/json" \
  -d '{
    "signedPayload": "eyJ...",
    "notificationType": "REFUND",
    "data": {
      "signedTransactionInfo": "eyJ..."
    }
  }'
# Expected: 200 OK, credits removed
```

---

### Test Category 6: Abuse Vectors

#### Test 6.1: Replay Attack (Old Idempotency Key)
```bash
# Use an idempotency key from a previous successful request
OLD_KEY="old-key-from-previous-request"
curl -X POST "${SUPABASE_URL}/rest/v1/rpc/consume_credits" \
  -H "apikey: ${SUPABASE_ANON_KEY}" \
  -H "Content-Type: application/json" \
  -d '{
    "p_device_id": "'${DEVICE_ID_1}'",
    "p_amount": 1,
    "p_idempotency_key": "'${OLD_KEY}'"
  }'
# Expected: Returns cached result (no new deduction)
```

#### Test 6.2: Cross-User Credit Theft Attempt
```bash
# Try to consume credits for another user's device_id
curl -X POST "${SUPABASE_URL}/rest/v1/rpc/consume_credits" \
  -H "apikey: ${SUPABASE_ANON_KEY}" \
  -H "Content-Type: application/json" \
  -d '{
    "p_device_id": "victim-device-id",
    "p_amount": 1,
    "p_idempotency_key": "attack-$(uuidgen)"
  }'
# Expected: RLS violation or 0 credits (if device doesn't exist)
```

#### Test 6.3: Webhook Token Spoofing
```bash
curl -X POST "${SUPABASE_URL}/functions/v1/webhook-handler" \
  -H "Content-Type: application/json" \
  -H "x-fal-webhook-token: fake-token" \
  -d '{
    "request_id": "fake-job-id",
    "status": "FAILED"
  }'
# Expected: 401 Unauthorized
```

#### Test 6.4: Negative Credit Injection Attempt
```bash
curl -X POST "${SUPABASE_URL}/rest/v1/rpc/add_credits" \
  -H "apikey: ${SUPABASE_ANON_KEY}" \
  -H "Content-Type: application/json" \
  -d '{
    "p_device_id": "'${DEVICE_ID_1}'",
    "p_amount": -100,
    "p_idempotency_key": "negative-$(uuidgen)"
  }'
# Expected: {"success": false, "error": "Amount must be positive"}
```

---

## 📊 Expected Results Matrix

| Test ID | Scenario | Expected Status | Expected Credits | Notes |
|---------|----------|----------------|------------------|-------|
| 1.1 | Get credits (auth) | 200 | Current balance | |
| 1.2 | Get credits (anon) | 200 | 10 (initial) | |
| 1.3 | Consume 1 credit | 200 | 9 remaining | |
| 1.4 | Add 10 credits | 200 | 19 remaining | |
| 2.1 | Insufficient credits | 402 | 0 remaining | Error message |
| 2.2 | Duplicate idempotency | 200 | Same as first | Cached result |
| 2.3 | Negative amount | 400 | No change | Validation error |
| 2.4 | Zero amount | 400 | No change | Validation error |
| 2.5 | Missing ID | 400 | No change | Validation error |
| 3.1 | Race (same key) | 200 x10 | 1 deduction | All cached |
| 3.2 | Race (diff keys) | 200 x5, 402 x5 | 0 remaining | 5 succeed, 5 fail |
| 4.1 | Submit job | 200 | 1 deducted | Job created |
| 4.2 | Submit job (no credits) | 402 | 0 remaining | Job rejected |
| 4.3 | Webhook refund | 200 | 1 refunded | |
| 6.1 | Replay attack | 200 | No change | Cached result |
| 6.2 | Cross-user theft | 403/0 | No change | RLS violation |
| 6.3 | Token spoofing | 401 | No change | Auth failed |
| 6.4 | Negative injection | 400 | No change | Validation error |

---

## 🔍 Verification Queries

### Check Credit Balance
```sql
SELECT * FROM anonymous_credits WHERE device_id = 'test-device-id';
SELECT * FROM user_credits WHERE user_id = 'test-user-id';
```

### Check Transaction Log
```sql
SELECT * FROM credit_transactions 
WHERE device_id = 'test-device-id' 
ORDER BY created_at DESC 
LIMIT 10;
```

### Check Idempotency Keys
```sql
SELECT * FROM idempotency_keys 
WHERE device_id = 'test-device-id' 
ORDER BY created_at DESC 
LIMIT 10;
```

### Check IAP Transactions
```sql
SELECT * FROM iap_transactions 
WHERE device_id = 'test-device-id' 
ORDER BY created_at DESC;
```

---

## ⚠️ Known Issues & Recommendations

### Critical Issues

1. **🔴 IAP Webhook Signature Not Verified**
   - **Location:** `iap-webhook/index.ts`
   - **Risk:** Fake refund notifications could remove credits
   - **Fix:** Implement Apple JWKS signature verification

### Medium Priority

2. **🟡 Idempotency Key Reuse**
   - **Risk:** If attacker knows idempotency key, they can replay
   - **Mitigation:** Use cryptographically random keys, rotate frequently

3. **🟡 Anonymous Device ID Spoofing**
   - **Risk:** If device_id is predictable, could be spoofed
   - **Mitigation:** Use UUIDs, validate format

### Low Priority

4. **🟢 Transaction Logging Performance**
   - **Risk:** High-volume operations could slow down
   - **Mitigation:** Consider async logging for high-traffic scenarios

---

## 📝 Test Execution Plan

1. **Phase 1: Normal Flows** (Tests 1.1 - 1.4)
   - Verify basic functionality
   - Expected: All pass

2. **Phase 2: Edge Cases** (Tests 2.1 - 2.5)
   - Verify error handling
   - Expected: All return appropriate errors

3. **Phase 3: Race Conditions** (Tests 3.1 - 3.2)
   - Verify concurrency safety
   - Expected: No double-charging

4. **Phase 4: Edge Functions** (Tests 4.1 - 4.3)
   - Verify integration
   - Expected: Proper credit flow

5. **Phase 5: Abuse Vectors** (Tests 6.1 - 6.4)
   - Verify security
   - Expected: All attacks blocked

---

## 🎯 Success Criteria

- ✅ All normal flows work correctly
- ✅ All edge cases handled gracefully
- ✅ No race conditions cause double-charging
- ✅ All abuse vectors blocked
- ✅ Transaction logging complete
- ✅ Idempotency prevents duplicates

---

**Next Steps:** Execute test scenarios one by one and document results.

