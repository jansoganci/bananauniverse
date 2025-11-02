# 🧪 Quota System Integration Test Plan

**Purpose:** Comprehensive integration testing for quota system across all user types  
**Testing Method:** cURL commands (can be run from terminal)  
**Date:** November 1, 2025  
**Status:** Ready for execution

---

## 📋 Test Prerequisites

### Setup Required:

1. **Get your Supabase credentials:**
   ```bash
   # Supabase Project URL
   export SUPABASE_URL="https://jiorfutbmahpfgplkats.supabase.co"
   
   # Anon Key (for anonymous users)
   export ANON_KEY="${ANON_KEY}"
   
   # Service Role Key (for admin operations)
   # IMPORTANT: Never commit service role keys to git
   # Set via environment variable or .env file
   export SUPABASE_SERVICE_ROLE_KEY="${SUPABASE_SERVICE_ROLE_KEY}"
   ```

2. **Get Edge Function URL:**
   ```bash
   export EDGE_FUNCTION_URL="${SUPABASE_URL}/functions/v1/process-image"
   ```

3. **Test Image URL (Already uploaded to Supabase Storage):**
   ```bash
   export TEST_IMAGE_URL="https://jiorfutbmahpfgplkats.supabase.co/storage/v1/object/public/noname-banana-images-prod/uploads/test/test-image.jpg"
   ```

4. **Create test users and get JWT token:**
   ```bash
   # Step 1: Sign up a new test user
   SIGNUP_RESPONSE=$(curl -s -X POST "${SUPABASE_URL}/auth/v1/signup" \
     -H "apikey: ${ANON_KEY}" \
     -H "Content-Type: application/json" \
     -d '{
       "email": "test-user-'$(date +%s)'@test.com",
       "password": "TestPassword123!",
       "data": {
         "name": "Test User"
       }
     }')
   
   # Extract user ID and access token
   export TEST_USER_EMAIL=$(echo $SIGNUP_RESPONSE | jq -r '.user.email')
   export TEST_USER_ID=$(echo $SIGNUP_RESPONSE | jq -r '.user.id')
   export AUTH_USER_TOKEN=$(echo $SIGNUP_RESPONSE | jq -r '.access_token')
   
   # Print for verification
   echo "✅ User created:"
   echo "   User ID: $TEST_USER_ID"
   echo "   Email: $TEST_USER_EMAIL"
   echo "   Token: ${AUTH_USER_TOKEN:0:50}..."
   
   # Alternative: Sign in if user already exists
   # SIGNIN_RESPONSE=$(curl -s -X POST "${SUPABASE_URL}/auth/v1/token?grant_type=password" \
   #   -H "apikey: ${ANON_KEY}" \
   #   -H "Content-Type: application/json" \
   #   -d "{
   #     \"email\": \"${TEST_USER_EMAIL}\",
   #     \"password\": \"TestPassword123!\"
   #   }")
   # export AUTH_USER_TOKEN=$(echo $SIGNIN_RESPONSE | jq -r '.access_token')
   
   # Test Device IDs (for anonymous users)
   # Use UUIDs: test-device-free, test-device-premium, test-device-new
   ```
   
   **Note:** For authenticated user tests (Test 2.7, Test 3.3), you need `AUTH_USER_TOKEN` set above.

---

## 🎯 Test Scenarios Overview

| Category | Test Count | Priority |
|----------|-----------|----------|
| **Free User Tests** | 6 tests | 🔴 Critical |
| **Premium User Tests** | 7 tests | 🔴 Critical |
| **Subscription Flow Tests** | 5 tests | 🔴 Critical |
| **Refund Tests** | 3 tests | 🟡 High |
| **Anonymous User Tests** | 4 tests | 🟡 High |
| **Edge Cases** | 5 tests | 🟢 Medium |
| **TOTAL** | **30 tests** | |

---

## 1️⃣ FREE USER TESTS

### Test 1.1: Free User - Generate First Image (Quota: 0/5 → 1/5)

**Goal:** Verify free user can consume quota normally

```bash
# Step 1: Check initial quota
curl -X POST "${SUPABASE_URL}/rest/v1/rpc/get_quota" \
  -H "apikey: ${ANON_KEY}" \
  -H "Content-Type: application/json" \
  -d '{
    "p_user_id": null,
    "p_device_id": "test-device-free-1"
  }'

# Expected: {"quota_used": 0, "quota_limit": 5, "quota_remaining": 5}

# Step 2: Process image (consume quota)
curl -X POST "${EDGE_FUNCTION_URL}" \
  -H "Authorization: Bearer ${ANON_KEY}" \
  -H "Content-Type: application/json" \
  -d '{
    "image_url": "${TEST_IMAGE_URL}",
    "prompt": "Test prompt",
    "device_id": "test-device-free-1",
    "client_request_id": "test-request-001"
  }'

# Expected: Success response with processed image URL

# Step 3: Verify quota increased (1/5)
curl -X POST "${SUPABASE_URL}/rest/v1/rpc/get_quota" \
  -H "apikey: ${ANON_KEY}" \
  -H "Content-Type: application/json" \
  -d '{
    "p_user_id": null,
    "p_device_id": "test-device-free-1"
  }'

# Expected: {"quota_used": 1, "quota_limit": 5, "quota_remaining": 4}
```

**✅ Success Criteria:**
- Quota consumed: 0 → 1
- Image processed successfully
- No premium bypass occurred

---

### Test 1.2: Free User - Reach Daily Limit (Quota: 4/5 → 5/5)

**Goal:** Verify quota limit enforcement

```bash
# Pre-condition: Quota already at 4/5 (run Test 1.1 four times or manually set)

# Attempt to process 6th image
curl -X POST "${EDGE_FUNCTION_URL}" \
  -H "Authorization: Bearer ${ANON_KEY}" \
  -H "Content-Type: application/json" \
  -d '{
    "image_url": "${TEST_IMAGE_URL}",
    "prompt": "Test prompt",
    "device_id": "test-device-free-1",
    "client_request_id": "test-request-006"
  }'

# Expected: 429 status code with error: "Daily quota exceeded"
# Expected response body:
# {
#   "error": "Daily quota exceeded",
#   "quota_info": {
#     "quota_used": 5,
#     "quota_limit": 5,
#     "quota_remaining": 0
#   }
# }
```

**✅ Success Criteria:**
- Request rejected with 429 status
- Quota not increased (stays at 5/5)
- Clear error message returned

---

### Test 1.3: Free User - Idempotency Test (Same Request ID)

**Goal:** Verify duplicate requests don't consume quota twice

```bash
# Process same request twice with same client_request_id
curl -X POST "${EDGE_FUNCTION_URL}" \
  -H "Authorization: Bearer ${ANON_KEY}" \
  -H "Content-Type: application/json" \
  -d '{
    "image_url": "${TEST_IMAGE_URL}",
    "prompt": "Test prompt",
    "device_id": "test-device-free-2",
    "client_request_id": "idempotent-test-001"
  }'

# Wait 2 seconds, then send SAME request again
curl -X POST "${EDGE_FUNCTION_URL}" \
  -H "Authorization: Bearer ${ANON_KEY}" \
  -H "Content-Type: application/json" \
  -d '{
    "image_url": "${TEST_IMAGE_URL}",
    "prompt": "Test prompt",
    "device_id": "test-device-free-2",
    "client_request_id": "idempotent-test-001"
  }'

# Check quota
curl -X POST "${SUPABASE_URL}/rest/v1/rpc/get_quota" \
  -H "apikey: ${ANON_KEY}" \
  -H "Content-Type: application/json" \
  -d '{
    "p_user_id": null,
    "p_device_id": "test-device-free-2"
  }'

# Expected: quota_used = 1 (not 2!)
```

**✅ Success Criteria:**
- Both requests succeed (same result returned)
- Quota consumed only once
- Second request marked as idempotent

---

### Test 1.4: Free User - Concurrent Requests (Race Condition Test)

**Goal:** Verify row locking prevents over-consumption

```bash
# Send 3 requests simultaneously
for i in {1..3}; do
  curl -X POST "${EDGE_FUNCTION_URL}" \
    -H "Authorization: Bearer ${ANON_KEY}" \
    -H "Content-Type: application/json" \
    -d "{
      \"image_url\": \"${TEST_IMAGE_URL}\",
      \"prompt\": \"Test prompt\",
      \"device_id\": \"test-device-free-3\",
      \"client_request_id\": \"concurrent-test-00${i}\"
    }" &
done

wait

# Check quota
curl -X POST "${SUPABASE_URL}/rest/v1/rpc/get_quota" \
  -H "apikey: ${ANON_KEY}" \
  -H "Content-Type: application/json" \
  -d '{
    "p_user_id": null,
    "p_device_id": "test-device-free-3"
  }'

# Expected: quota_used = 3 (exactly, not 4 or 5!)
```

**✅ Success Criteria:**
- All 3 requests processed
- Quota increased by exactly 3 (not more)
- No race condition occurred

---

### Test 1.5: Free User - Refund on Processing Failure

**Goal:** Verify quota refunded when Fal.AI fails

```bash
# Step 1: Consume quota (quota: 0/5 → 1/5)
curl -X POST "${EDGE_FUNCTION_URL}" \
  -H "Authorization: Bearer ${ANON_KEY}" \
  -H "Content-Type: application/json" \
  -d '{
    "image_url": "${TEST_IMAGE_URL}",
    "prompt": "Test prompt",
    "device_id": "test-device-free-4",
    "client_request_id": "refund-test-001"
  }'

# Expected: 500 error (Fal.AI fails)

# Step 2: Check quota (should be refunded back to 0/5)
curl -X POST "${SUPABASE_URL}/rest/v1/rpc/get_quota" \
  -H "apikey: ${ANON_KEY}" \
  -H "Content-Type: application/json" \
  -d '{
    "p_user_id": null,
    "p_device_id": "test-device-free-4"
  }'

# Expected: {"quota_used": 0, "quota_limit": 5, "quota_remaining": 5}

# Step 3: Verify refund logged
curl -X GET "${SUPABASE_URL}/rest/v1/quota_consumption_log?request_id=eq.refund-test-001&select=refunded,refunded_at" \
  -H "apikey: ${SERVICE_ROLE_KEY}" \
  -H "Authorization: Bearer ${SERVICE_ROLE_KEY}"

# Expected: {"refunded": true, "refunded_at": "2025-11-01T..."}
```

**✅ Success Criteria:**
- Initial quota consumed (1/5)
- Processing fails
- Quota refunded (back to 0/5)
- Refund logged in database

---

### Test 1.6: Free User - Daily Quota Reset (Next Day)

**Goal:** Verify quota resets at midnight (next day)

```bash
# Pre-condition: Quota at 5/5 today

# Wait until next day OR manually update date in database:
# UPDATE daily_quotas SET date = CURRENT_DATE + 1 WHERE device_id = 'test-device-free-5';

# Try to process image
curl -X POST "${EDGE_FUNCTION_URL}" \
  -H "Authorization: Bearer ${ANON_KEY}" \
  -H "Content-Type: application/json" \
  -d '{
    "image_url": "${TEST_IMAGE_URL}",
    "prompt": "Test prompt",
    "device_id": "test-device-free-5",
    "client_request_id": "next-day-test-001"
  }'

# Expected: Success (quota resets to 0/5, now 1/5)
```

**✅ Success Criteria:**
- New day creates new quota record
- Previous day's quota doesn't affect new day
- User can process images again

---

## 2️⃣ PREMIUM USER TESTS

### Test 2.1: Premium User - Unlimited Quota Access

**Goal:** Verify premium users bypass quota limits

```bash
# Step 1: Create premium subscription (via SQL or API)
curl -X POST "${SUPABASE_URL}/rest/v1/subscriptions" \
  -H "apikey: ${SERVICE_ROLE_KEY}" \
  -H "Authorization: Bearer ${SERVICE_ROLE_KEY}" \
  -H "Content-Type: application/json" \
  -d '{
    "user_id": null,
    "device_id": "test-device-premium-1",
    "status": "active",
    "product_id": "premium_monthly",
    "expires_at": "2026-11-01T00:00:00Z",
    "original_transaction_id": "test-txn-premium-001",
    "platform": "ios"
  }'

# Step 2: Process 10 images in a row
for i in {1..10}; do
  curl -X POST "${EDGE_FUNCTION_URL}" \
    -H "Authorization: Bearer ${ANON_KEY}" \
    -H "Content-Type: application/json" \
    -d "{
      \"image_url\": \"${TEST_IMAGE_URL}\",
      \"prompt\": \"Test prompt\",
      \"device_id\": \"test-device-premium-1\",
      \"client_request_id\": \"premium-test-00${i}\"
    }"
done

# Step 3: Verify quota still shows 0 (or unlimited)
curl -X POST "${SUPABASE_URL}/rest/v1/rpc/get_quota" \
  -H "apikey: ${ANON_KEY}" \
  -H "Content-Type: application/json" \
  -d '{
    "p_user_id": null,
    "p_device_id": "test-device-premium-1"
  }'

# Expected: All 10 requests succeed
# Quota may show 0 or 999999 (premium bypass)
```

**✅ Success Criteria:**
- All 10 requests succeed
- No quota limit enforced
- Premium status verified server-side

---

### Test 2.2: Premium User - Generate 6-7 Images (Unlimited Test)

**Goal:** Verify premium user can generate unlimited images

```bash
# Process 7 images
for i in {1..7}; do
  curl -X POST "${EDGE_FUNCTION_URL}" \
    -H "Authorization: Bearer ${ANON_KEY}" \
    -H "Content-Type: application/json" \
    -d "{
      \"image_url\": \"${TEST_IMAGE_URL}\",
      \"prompt\": \"Test prompt ${i}\",
      \"device_id\": \"test-device-premium-2\",
      \"client_request_id\": \"premium-7test-00${i}\"
    }"
done

# Verify all succeeded (check each response status = 200)
```

**✅ Success Criteria:**
- All 7 requests return 200 OK
- No 429 (quota exceeded) errors
- Premium bypass working correctly

---

### Test 2.3: Premium User - Subscription Expires (Fallback to Free)

**Goal:** Verify premium users fall back to free tier when subscription expires

```bash
# Step 1: Create expired subscription
curl -X POST "${SUPABASE_URL}/rest/v1/subscriptions" \
  -H "apikey: ${SERVICE_ROLE_KEY}" \
  -H "Authorization: Bearer ${SERVICE_ROLE_KEY}" \
  -H "Content-Type: application/json" \
  -d '{
    "user_id": null,
    "device_id": "test-device-premium-expired",
    "status": "expired",
    "product_id": "premium_monthly",
    "expires_at": "2024-01-01T00:00:00Z",
    "original_transaction_id": "test-txn-expired-001",
    "platform": "ios"
  }'

# Step 2: Try to process image
curl -X POST "${EDGE_FUNCTION_URL}" \
  -H "Authorization: Bearer ${ANON_KEY}" \
  -H "Content-Type: application/json" \
  -d '{
    "image_url": "${TEST_IMAGE_URL}",
    "prompt": "Test prompt",
    "device_id": "test-device-premium-expired",
    "client_request_id": "expired-test-001"
  }'

# Expected: Success (free tier quota applies)

# Step 3: Process 5 more images
for i in {2..6}; do
  curl -X POST "${EDGE_FUNCTION_URL}" \
    -H "Authorization: Bearer ${ANON_KEY}" \
    -H "Content-Type: application/json" \
    -d "{
      \"image_url\": \"${TEST_IMAGE_URL}\",
      \"prompt\": \"Test prompt\",
      \"device_id\": \"test-device-premium-expired\",
      \"client_request_id\": \"expired-test-00${i}\"
    }"
done

# Step 4: 6th request should fail (quota exceeded)
curl -X POST "${EDGE_FUNCTION_URL}" \
  -H "Authorization: Bearer ${ANON_KEY}" \
  -H "Content-Type: application/json" \
  -d '{
    "image_url": "${TEST_IMAGE_URL}",
    "prompt": "Test prompt",
    "device_id": "test-device-premium-expired",
    "client_request_id": "expired-test-007"
  }'

# Expected: 429 error (quota exceeded)
```

**✅ Success Criteria:**
- First 5 requests succeed (free tier quota)
- 6th request rejected (quota exceeded)
- Expired subscription not granting premium access

---

### Test 2.4: Premium User - Refund Test

**Goal:** Verify premium users can also get refunds on failures

```bash
# Step 1: Process image with invalid URL (will fail)
curl -X POST "${EDGE_FUNCTION_URL}" \
  -H "Authorization: Bearer ${ANON_KEY}" \
  -H "Content-Type: application/json" \
  -d '{
    "image_url": "https://invalid-url-fail.com/image.jpg",
    "prompt": "Test prompt",
    "device_id": "test-device-premium-refund",
    "client_request_id": "premium-refund-001"
  }'

# Expected: 500 error

# Step 2: Check refund logged (premium users still get refunds)
curl -X GET "${SUPABASE_URL}/rest/v1/quota_consumption_log?request_id=eq.premium-refund-001&select=refunded,refunded_at,quota_used" \
  -H "apikey: ${SERVICE_ROLE_KEY}" \
  -H "Authorization: Bearer ${SERVICE_ROLE_KEY}"

# Expected: {"refunded": true, "refunded_at": "...", "quota_used": 0}
```

**✅ Success Criteria:**
- Processing fails
- Refund logged in database
- System handles premium user refunds correctly

---

### Test 2.5: Premium User - Unsubscribe Test

**Goal:** Verify unsubscribe flow works correctly

```bash
# Step 1: Cancel subscription (set status to 'cancelled')
curl -X PATCH "${SUPABASE_URL}/rest/v1/subscriptions?original_transaction_id=eq.test-txn-premium-001" \
  -H "apikey: ${SERVICE_ROLE_KEY}" \
  -H "Authorization: Bearer ${SERVICE_ROLE_KEY}" \
  -H "Content-Type: application/json" \
  -d '{
    "status": "cancelled",
    "updated_at": "now()"
  }'

# Step 2: Process image (should still work until expires_at)
curl -X POST "${EDGE_FUNCTION_URL}" \
  -H "Authorization: Bearer ${ANON_KEY}" \
  -H "Content-Type: application/json" \
  -d '{
    "image_url": "${TEST_IMAGE_URL}",
    "prompt": "Test prompt",
    "device_id": "test-device-premium-1",
    "client_request_id": "unsub-test-001"
  }'

# Expected: Success (subscription still valid until expires_at)

# Step 3: Update expires_at to past
curl -X PATCH "${SUPABASE_URL}/rest/v1/subscriptions?original_transaction_id=eq.test-txn-premium-001" \
  -H "apikey: ${SERVICE_ROLE_KEY}" \
  -H "Authorization: Bearer ${SERVICE_ROLE_KEY}" \
  -H "Content-Type: application/json" \
  -d '{
    "expires_at": "2024-01-01T00:00:00Z"
  }'

# Step 4: Process image (should now use free tier)
curl -X POST "${EDGE_FUNCTION_URL}" \
  -H "Authorization: Bearer ${ANON_KEY}" \
  -H "Content-Type: application/json" \
  -d '{
    "image_url": "${TEST_IMAGE_URL}",
    "prompt": "Test prompt",
    "device_id": "test-device-premium-1",
    "client_request_id": "unsub-test-002"
  }'

# Expected: Success (free tier quota applies)
```

**✅ Success Criteria:**
- Subscription cancellation works
- Premium access continues until expires_at
- After expiration, falls back to free tier

---

### Test 2.6: Premium User - Multiple Concurrent Requests

**Goal:** Verify premium users handle high concurrency

```bash
# Send 20 requests simultaneously
for i in {1..20}; do
  curl -X POST "${EDGE_FUNCTION_URL}" \
    -H "Authorization: Bearer ${ANON_KEY}" \
    -H "Content-Type: application/json" \
    -d "{
      \"image_url\": \"${TEST_IMAGE_URL}\",
      \"prompt\": \"Test prompt\",
      \"device_id\": \"test-device-premium-concurrent\",
      \"client_request_id\": \"premium-concurrent-00${i}\"
    }" &
done

wait

# Verify all succeeded (check exit codes)
```

**✅ Success Criteria:**
- All 20 requests succeed
- No quota limits enforced
- System handles high load for premium users

---

### Test 2.7: Premium User - Authenticated User (User ID instead of Device ID)

**Goal:** Verify authenticated premium users work with user_id

```bash
# Step 1: Create subscription with user_id (authenticated user)
curl -X POST "${SUPABASE_URL}/rest/v1/subscriptions" \
  -H "apikey: ${SERVICE_ROLE_KEY}" \
  -H "Authorization: Bearer ${SERVICE_ROLE_KEY}" \
  -H "Content-Type: application/json" \
  -d '{
    "user_id": "test-user-id-001",
    "device_id": null,
    "status": "active",
    "product_id": "premium_monthly",
    "expires_at": "2026-11-01T00:00:00Z",
    "original_transaction_id": "test-txn-user-001",
    "platform": "ios"
  }'

# Step 2: Process image with user_id (authenticated request)
curl -X POST "${EDGE_FUNCTION_URL}" \
  -H "Authorization: Bearer ${AUTH_USER_TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{
    "image_url": "${TEST_IMAGE_URL}",
    "prompt": "Test prompt",
    "client_request_id": "auth-premium-001"
  }'

# Expected: Success (premium bypass with user_id)
```

**✅ Success Criteria:**
- Authenticated user premium check works
- User_id-based subscription verified
- Premium access granted correctly

---

## 3️⃣ SUBSCRIPTION FLOW TESTS

### Test 3.1: Free User → Purchase Subscription → Premium Access

**Goal:** Verify complete purchase flow

```bash
# Step 1: Start as free user (quota: 0/5)
# Process 3 images
for i in {1..3}; do
  curl -X POST "${EDGE_FUNCTION_URL}" \
    -H "Authorization: Bearer ${ANON_KEY}" \
    -H "Content-Type: application/json" \
    -d "{
      \"image_url\": \"${TEST_IMAGE_URL}\",
      \"prompt\": \"Test prompt\",
      \"device_id\": \"test-device-upgrade\",
      \"client_request_id\": \"pre-upgrade-00${i}\"
    }"
done

# Step 2: Check quota (should be 3/5)
curl -X POST "${SUPABASE_URL}/rest/v1/rpc/get_quota" \
  -H "apikey: ${ANON_KEY}" \
  -H "Content-Type: application/json" \
  -d '{
    "p_user_id": null,
    "p_device_id": "test-device-upgrade"
  }'

# Expected: {"quota_used": 3, "quota_limit": 5}

# Step 3: Simulate subscription purchase (sync_subscription call)
curl -X POST "${SUPABASE_URL}/rest/v1/rpc/sync_subscription" \
  -H "apikey: ${ANON_KEY}" \
  -H "Authorization: Bearer ${ANON_KEY}" \
  -H "Content-Type: application/json" \
  -d '{
    "p_user_id": null,
    "p_device_id": "test-device-upgrade",
    "p_product_id": "premium_monthly",
    "p_transaction_id": "test-txn-upgrade-001",
    "p_expires_at": "2026-11-01T00:00:00Z",
    "p_platform": "ios"
  }'

# Step 4: Process image (should now bypass quota)
curl -X POST "${EDGE_FUNCTION_URL}" \
  -H "Authorization: Bearer ${ANON_KEY}" \
  -H "Content-Type: application/json" \
  -d '{
    "image_url": "${TEST_IMAGE_URL}",
    "prompt": "Test prompt",
    "device_id": "test-device-upgrade",
    "client_request_id": "post-upgrade-001"
  }'

# Expected: Success (premium bypass)

# Step 5: Process 10 more images (unlimited)
for i in {2..11}; do
  curl -X POST "${EDGE_FUNCTION_URL}" \
    -H "Authorization: Bearer ${ANON_KEY}" \
    -H "Content-Type: application/json" \
    -d "{
      \"image_url\": \"${TEST_IMAGE_URL}\",
      \"prompt\": \"Test prompt\",
      \"device_id\": \"test-device-upgrade\",
      \"client_request_id\": \"post-upgrade-00${i}\"
    }"
done

# Expected: All succeed (unlimited access)
```

**✅ Success Criteria:**
- Free tier quota consumed (3/5)
- Subscription created successfully
- Premium access granted immediately
- Unlimited quota after upgrade

---

### Test 3.2: Premium User → Subscription Expires → Free Tier

**Goal:** Verify expiration flow

```bash
# Step 1: Start as premium user
# Process 10 images
for i in {1..10}; do
  curl -X POST "${EDGE_FUNCTION_URL}" \
    -H "Authorization: Bearer ${ANON_KEY}" \
    -H "Content-Type: application/json" \
    -d "{
      \"image_url\": \"${TEST_IMAGE_URL}\",
      \"prompt\": \"Test prompt\",
      \"device_id\": \"test-device-expire\",
      \"client_request_id\": \"premium-before-00${i}\"
    }"
done

# Expected: All succeed

# Step 2: Expire subscription
curl -X PATCH "${SUPABASE_URL}/rest/v1/subscriptions?original_transaction_id=eq.test-txn-expire-001" \
  -H "apikey: ${SERVICE_ROLE_KEY}" \
  -H "Authorization: Bearer ${SERVICE_ROLE_KEY}" \
  -H "Content-Type: application/json" \
  -d '{
    "status": "expired",
    "expires_at": "2024-01-01T00:00:00Z"
  }'

# Step 3: Process image (should use free tier quota)
curl -X POST "${EDGE_FUNCTION_URL}" \
  -H "Authorization: Bearer ${ANON_KEY}" \
  -H "Content-Type: application/json" \
  -d '{
    "image_url": "${TEST_IMAGE_URL}",
    "prompt": "Test prompt",
    "device_id": "test-device-expire",
    "client_request_id": "after-expire-001"
  }'

# Expected: Success (free tier, quota: 1/5)

# Step 4: Process 5 more images
for i in {2..6}; do
  curl -X POST "${EDGE_FUNCTION_URL}" \
    -H "Authorization: Bearer ${ANON_KEY}" \
    -H "Content-Type: application/json" \
    -d "{
      \"image_url\": \"${TEST_IMAGE_URL}\",
      \"prompt\": \"Test prompt\",
      \"device_id\": \"test-device-expire\",
      \"client_request_id\": \"after-expire-00${i}\"
    }"
done

# Step 5: 6th request should fail (quota exceeded)
curl -X POST "${EDGE_FUNCTION_URL}" \
  -H "Authorization: Bearer ${ANON_KEY}" \
  -H "Content-Type: application/json" \
  -d '{
    "image_url": "${TEST_IMAGE_URL}",
    "prompt": "Test prompt",
    "device_id": "test-device-expire",
    "client_request_id": "after-expire-007"
  }'

# Expected: 429 error (quota exceeded)
```

**✅ Success Criteria:**
- Premium access works initially
- Expiration detected correctly
- Falls back to free tier
- Quota limit enforced after expiration

---

### Test 3.3: Anonymous User → Upgrade → Migrate to Authenticated

**Goal:** Verify device_id → user_id migration

```bash
# Step 1: Start as anonymous user (device_id)
# Process 2 images
for i in {1..2}; do
  curl -X POST "${EDGE_FUNCTION_URL}" \
    -H "Authorization: Bearer ${ANON_KEY}" \
    -H "Content-Type: application/json" \
    -d "{
      \"image_url\": \"${TEST_IMAGE_URL}\",
      \"prompt\": \"Test prompt\",
      \"device_id\": \"test-device-migrate\",
      \"client_request_id\": \"anon-before-00${i}\"
    }"
done

# Step 2: Upgrade (create subscription with device_id)
curl -X POST "${SUPABASE_URL}/rest/v1/rpc/sync_subscription" \
  -H "apikey: ${ANON_KEY}" \
  -H "Authorization: Bearer ${ANON_KEY}" \
  -H "Content-Type: application/json" \
  -d '{
    "p_user_id": null,
    "p_device_id": "test-device-migrate",
    "p_product_id": "premium_monthly",
    "p_transaction_id": "test-txn-migrate-001",
    "p_expires_at": "2026-11-01T00:00:00Z",
    "p_platform": "ios"
  }'

# Step 3: User signs up (authenticates)
# Migrate subscription from device_id to user_id
curl -X PATCH "${SUPABASE_URL}/rest/v1/subscriptions?original_transaction_id=eq.test-txn-migrate-001" \
  -H "apikey: ${SERVICE_ROLE_KEY}" \
  -H "Authorization: Bearer ${SERVICE_ROLE_KEY}" \
  -H "Content-Type: application/json" \
  -d '{
    "user_id": "test-user-migrated-001",
    "device_id": null
  }'

# Step 4: Process image with authenticated token
curl -X POST "${EDGE_FUNCTION_URL}" \
  -H "Authorization: Bearer ${AUTH_USER_TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{
    "image_url": "${TEST_IMAGE_URL}",
    "prompt": "Test prompt",
    "client_request_id": "auth-after-migrate-001"
  }'

# Expected: Success (premium access with user_id)
```

**✅ Success Criteria:**
- Anonymous user quota works
- Subscription created with device_id
- Migration to user_id successful
- Premium access continues after migration

---

### Test 3.4: Subscription Renewal (Auto-Renewal)

**Goal:** Verify subscription renewal updates correctly

```bash
# Step 1: Existing subscription expires soon
curl -X PATCH "${SUPABASE_URL}/rest/v1/subscriptions?original_transaction_id=eq.test-txn-renew-001" \
  -H "apikey: ${SERVICE_ROLE_KEY}" \
  -H "Authorization: Bearer ${SERVICE_ROLE_KEY}" \
  -H "Content-Type: application/json" \
  -d '{
    "expires_at": "2025-11-02T00:00:00Z"
  }'

# Step 2: Simulate renewal (update expires_at)
curl -X POST "${SUPABASE_URL}/rest/v1/rpc/sync_subscription" \
  -H "apikey: ${ANON_KEY}" \
  -H "Authorization: Bearer ${ANON_KEY}" \
  -H "Content-Type: application/json" \
  -d '{
    "p_user_id": null,
    "p_device_id": "test-device-renewal",
    "p_product_id": "premium_monthly",
    "p_transaction_id": "test-txn-renew-001",
    "p_expires_at": "2026-12-01T00:00:00Z",
    "p_platform": "ios"
  }'

# Expected: Subscription updated (upsert by original_transaction_id)

# Step 3: Verify premium access continues
curl -X POST "${EDGE_FUNCTION_URL}" \
  -H "Authorization: Bearer ${ANON_KEY}" \
  -H "Content-Type: application/json" \
  -d '{
    "image_url": "${TEST_IMAGE_URL}",
    "prompt": "Test prompt",
    "device_id": "test-device-renewal",
    "client_request_id": "renewal-test-001"
  }'

# Expected: Success (premium access maintained)
```

**✅ Success Criteria:**
- Renewal updates subscription correctly
- Premium access continues without interruption
- expires_at updated properly

---

### Test 3.5: Multiple Subscriptions (Same User/Device)

**Goal:** Verify idempotency of sync_subscription (same transaction_id)

```bash
# Step 1: Sync subscription
curl -X POST "${SUPABASE_URL}/rest/v1/rpc/sync_subscription" \
  -H "apikey: ${ANON_KEY}" \
  -H "Authorization: Bearer ${ANON_KEY}" \
  -H "Content-Type: application/json" \
  -d '{
    "p_user_id": null,
    "p_device_id": "test-device-duplicate",
    "p_product_id": "premium_monthly",
    "p_transaction_id": "test-txn-duplicate-001",
    "p_expires_at": "2026-11-01T00:00:00Z",
    "p_platform": "ios"
  }'

# Step 2: Sync same subscription again (same transaction_id)
curl -X POST "${SUPABASE_URL}/rest/v1/rpc/sync_subscription" \
  -H "apikey: ${ANON_KEY}" \
  -H "Authorization: Bearer ${ANON_KEY}" \
  -H "Content-Type: application/json" \
  -d '{
    "p_user_id": null,
    "p_device_id": "test-device-duplicate",
    "p_product_id": "premium_monthly",
    "p_transaction_id": "test-txn-duplicate-001",
    "p_expires_at": "2026-11-01T00:00:00Z",
    "p_platform": "ios"
  }'

# Expected: Idempotent (upsert, no duplicate record)

# Step 3: Verify only one record exists
curl -X GET "${SUPABASE_URL}/rest/v1/subscriptions?original_transaction_id=eq.test-txn-duplicate-001" \
  -H "apikey: ${SERVICE_ROLE_KEY}" \
  -H "Authorization: Bearer ${SERVICE_ROLE_KEY}"

# Expected: Single record returned
```

**✅ Success Criteria:**
- No duplicate subscriptions created
- Upsert works correctly
- Same transaction_id updates existing record

---

## 4️⃣ REFUND TESTS

### Test 4.1: Refund Idempotency (Prevent Double Refund)

**Goal:** Verify refund can't be processed twice

```bash
# Step 1: Process image (will fail)
curl -X POST "${EDGE_FUNCTION_URL}" \
  -H "Authorization: Bearer ${ANON_KEY}" \
  -H "Content-Type: application/json" \
  -d '{
    "image_url": "https://invalid-url-fail.com/image.jpg",
    "prompt": "Test prompt",
    "device_id": "test-device-refund-idempotent",
    "client_request_id": "refund-idempotent-001"
  }'

# Expected: 500 error, refund called automatically

# Step 2: Manually call refund again (should be idempotent)
curl -X POST "${SUPABASE_URL}/rest/v1/rpc/refund_quota" \
  -H "apikey: ${ANON_KEY}" \
  -H "Authorization: Bearer ${ANON_KEY}" \
  -H "Content-Type: application/json" \
  -d '{
    "p_user_id": null,
    "p_device_id": "test-device-refund-idempotent",
    "p_client_request_id": "refund-idempotent-001"
  }'

# Expected: Success but idempotent (no double refund)

# Step 3: Check refund status
curl -X GET "${SUPABASE_URL}/rest/v1/quota_consumption_log?request_id=eq.refund-idempotent-001&select=refunded,quota_used" \
  -H "apikey: ${SERVICE_ROLE_KEY}" \
  -H "Authorization: Bearer ${SERVICE_ROLE_KEY}"

# Expected: {"refunded": true, "quota_used": 1} (refunded once)
```

**✅ Success Criteria:**
- First refund succeeds
- Second refund call idempotent (no double refund)
- Quota refunded only once

---

### Test 4.2: Refund Edge Case (No Quota to Refund)

**Goal:** Verify refund handles edge cases gracefully

```bash
# Step 1: Try to refund for request that never consumed quota
curl -X POST "${SUPABASE_URL}/rest/v1/rpc/refund_quota" \
  -H "apikey: ${ANON_KEY}" \
  -H "Authorization: Bearer ${ANON_KEY}" \
  -H "Content-Type: application/json" \
  -d '{
    "p_user_id": null,
    "p_device_id": "test-device-no-refund",
    "p_client_request_id": "nonexistent-request-001"
  }'

# Expected: Error or graceful handling (no record found)
```

**✅ Success Criteria:**
- System handles missing request gracefully
- No crash or unexpected error
- Appropriate error message returned

---

### Test 4.3: Refund After Quota Reset (Next Day)

**Goal:** Verify refund works correctly across day boundaries

```bash
# Step 1: Process image on Day 1 (quota: 4/5 → 5/5)
curl -X POST "${EDGE_FUNCTION_URL}" \
  -H "Authorization: Bearer ${ANON_KEY}" \
  -H "Content-Type: application/json" \
  -d '{
    "image_url": "https://invalid-url-fail.com/image.jpg",
    "prompt": "Test prompt",
    "device_id": "test-device-refund-crossday",
    "client_request_id": "crossday-refund-001"
  }'

# Expected: 500 error, refund called

# Step 2: Manually set date to next day in database
# UPDATE daily_quotas SET date = CURRENT_DATE + 1 WHERE device_id = 'test-device-refund-crossday';

# Step 3: Try to refund (should find Day 1 record)
curl -X POST "${SUPABASE_URL}/rest/v1/rpc/refund_quota" \
  -H "apikey: ${ANON_KEY}" \
  -H "Authorization: Bearer ${ANON_KEY}" \
  -H "Content-Type: application/json" \
  -d '{
    "p_user_id": null,
    "p_device_id": "test-device-refund-crossday",
    "p_client_request_id": "crossday-refund-001"
  }'

# Expected: Success (refund applied to correct day's quota)
```

**✅ Success Criteria:**
- Refund finds correct day's quota record
- Quota refunded correctly
- Cross-day refund handled properly

---

## 5️⃣ ANONYMOUS USER TESTS

### Test 5.1: Anonymous User - New Device Gets Free Quota

**Goal:** Verify new anonymous users get 5 free generations

```bash
# Process image with new device_id
curl -X POST "${EDGE_FUNCTION_URL}" \
  -H "Authorization: Bearer ${ANON_KEY}" \
  -H "Content-Type: application/json" \
  -d '{
    "image_url": "${TEST_IMAGE_URL}",
    "prompt": "Test prompt",
    "device_id": "test-device-anon-new",
    "client_request_id": "anon-new-001"
  }'

# Check quota
curl -X POST "${SUPABASE_URL}/rest/v1/rpc/get_quota" \
  -H "apikey: ${ANON_KEY}" \
  -H "Content-Type: application/json" \
  -d '{
    "p_user_id": null,
    "p_device_id": "test-device-anon-new"
  }'

# Expected: {"quota_used": 1, "quota_limit": 5, "quota_remaining": 4}
```

**✅ Success Criteria:**
- New device gets 5 free generations
- Quota record created automatically
- Anonymous user can process images

---

### Test 5.2: Anonymous User - Device ID Spoofing Prevention (RLS)

**Goal:** Verify RLS prevents accessing other users' quota

```bash
# Step 1: User A processes image
curl -X POST "${EDGE_FUNCTION_URL}" \
  -H "Authorization: Bearer ${ANON_KEY}" \
  -H "Content-Type: application/json" \
  -d '{
    "image_url": "${TEST_IMAGE_URL}",
    "prompt": "Test prompt",
    "device_id": "test-device-user-a",
    "client_request_id": "user-a-001"
  }'

# Step 2: User B tries to access User A's quota (spoofing)
curl -X POST "${SUPABASE_URL}/rest/v1/rpc/get_quota" \
  -H "apikey: ${ANON_KEY}" \
  -H "Authorization: Bearer ${ANON_KEY}" \
  -H "Content-Type: application/json" \
  -d '{
    "p_user_id": null,
    "p_device_id": "test-device-user-a"
  }'

# Expected: RLS blocks or returns empty (can't see other device's quota)
# OR: Returns quota only if device_id matches session variable
```

**✅ Success Criteria:**
- RLS prevents cross-device data access
- Each device sees only its own quota
- Security enforced correctly

---

### Test 5.3: Anonymous User - Upgrade to Premium

**Goal:** Verify anonymous users can upgrade

```bash
# Step 1: Create subscription with device_id
curl -X POST "${SUPABASE_URL}/rest/v1/rpc/sync_subscription" \
  -H "apikey: ${ANON_KEY}" \
  -H "Authorization: Bearer ${ANON_KEY}" \
  -H "Content-Type: application/json" \
  -d '{
    "p_user_id": null,
    "p_device_id": "test-device-anon-upgrade",
    "p_product_id": "premium_monthly",
    "p_transaction_id": "test-txn-anon-upgrade-001",
    "p_expires_at": "2026-11-01T00:00:00Z",
    "p_platform": "ios"
  }'

# Step 2: Process image (should bypass quota)
curl -X POST "${EDGE_FUNCTION_URL}" \
  -H "Authorization: Bearer ${ANON_KEY}" \
  -H "Content-Type: application/json" \
  -d '{
    "image_url": "${TEST_IMAGE_URL}",
    "prompt": "Test prompt",
    "device_id": "test-device-anon-upgrade",
    "client_request_id": "anon-upgrade-001"
  }'

# Expected: Success (premium bypass)
```

**✅ Success Criteria:**
- Anonymous user can upgrade
- Premium access granted with device_id
- Unlimited quota works for anonymous premium users

---

### Test 5.4: Anonymous User - Multiple Devices (Isolation)

**Goal:** Verify device isolation works correctly

```bash
# Device 1: Process 3 images
for i in {1..3}; do
  curl -X POST "${EDGE_FUNCTION_URL}" \
    -H "Authorization: Bearer ${ANON_KEY}" \
    -H "Content-Type: application/json" \
    -d "{
      \"image_url\": \"${TEST_IMAGE_URL}\",
      \"prompt\": \"Test prompt\",
      \"device_id\": \"test-device-isolation-1\",
      \"client_request_id\": \"isolate-dev1-00${i}\"
    }"
done

# Device 2: Process 2 images
for i in {1..2}; do
  curl -X POST "${EDGE_FUNCTION_URL}" \
    -H "Authorization: Bearer ${ANON_KEY}" \
    -H "Content-Type: application/json" \
    -d "{
      \"image_url\": \"${TEST_IMAGE_URL}\",
      \"prompt\": \"Test prompt\",
      \"device_id\": \"test-device-isolation-2\",
      \"client_request_id\": \"isolate-dev2-00${i}\"
    }"
done

# Check quotas separately
curl -X POST "${SUPABASE_URL}/rest/v1/rpc/get_quota" \
  -H "apikey: ${ANON_KEY}" \
  -H "Content-Type: application/json" \
  -d '{
    "p_user_id": null,
    "p_device_id": "test-device-isolation-1"
  }'

curl -X POST "${SUPABASE_URL}/rest/v1/rpc/get_quota" \
  -H "apikey: ${ANON_KEY}" \
  -H "Content-Type: application/json" \
  -d '{
    "p_user_id": null,
    "p_device_id": "test-device-isolation-2"
  }'

# Expected:
# Device 1: {"quota_used": 3, "quota_limit": 5}
# Device 2: {"quota_used": 2, "quota_limit": 5}
```

**✅ Success Criteria:**
- Each device has separate quota
- No cross-contamination between devices
- Isolation maintained correctly

---

## 6️⃣ EDGE CASES

### Test 6.1: Missing Parameters (Error Handling)

**Goal:** Verify graceful error handling

```bash
# Missing device_id and user_id
curl -X POST "${EDGE_FUNCTION_URL}" \
  -H "Authorization: Bearer ${ANON_KEY}" \
  -H "Content-Type: application/json" \
  -d '{
    "image_url": "${TEST_IMAGE_URL}",
    "prompt": "Test prompt"
  }'

# Expected: 400 or 401 error with clear message
```

**✅ Success Criteria:**
- Clear error message
- No crash or undefined behavior
- Appropriate status code returned

---

### Test 6.2: Invalid Image URL (Fal.AI Failure)

**Goal:** Verify refund on invalid URL

```bash
curl -X POST "${EDGE_FUNCTION_URL}" \
  -H "Authorization: Bearer ${ANON_KEY}" \
  -H "Content-Type: application/json" \
  -d '{
    "image_url": "not-a-valid-url",
    "prompt": "Test prompt",
    "device_id": "test-device-invalid-url",
    "client_request_id": "invalid-url-001"
  }'

# Expected: 500 error, quota refunded
```

**✅ Success Criteria:**
- Error handled gracefully
- Quota refunded
- User can retry

---

### Test 6.3: Expired Subscription with Grace Period

**Goal:** Verify grace period handling

```bash
# Create subscription with grace_period status
curl -X POST "${SUPABASE_URL}/rest/v1/subscriptions" \
  -H "apikey: ${SERVICE_ROLE_KEY}" \
  -H "Authorization: Bearer ${SERVICE_ROLE_KEY}" \
  -H "Content-Type: application/json" \
  -d '{
    "user_id": null,
    "device_id": "test-device-grace",
    "status": "grace_period",
    "product_id": "premium_monthly",
    "expires_at": "2024-01-01T00:00:00Z",
    "original_transaction_id": "test-txn-grace-001",
    "platform": "ios"
  }'

# Process image
curl -X POST "${EDGE_FUNCTION_URL}" \
  -H "Authorization: Bearer ${ANON_KEY}" \
  -H "Content-Type: application/json" \
  -d '{
    "image_url": "${TEST_IMAGE_URL}",
    "prompt": "Test prompt",
    "device_id": "test-device-grace",
    "client_request_id": "grace-test-001"
  }'

# Expected: Behavior depends on implementation (may use free tier or still premium)
```

**✅ Success Criteria:**
- Grace period handled correctly
- Clear behavior defined
- No undefined states

---

### Test 6.4: Very Long Prompt (Input Validation)

**Goal:** Verify input validation works

```bash
# Send extremely long prompt
curl -X POST "${EDGE_FUNCTION_URL}" \
  -H "Authorization: Bearer ${ANON_KEY}" \
  -H "Content-Type: application/json" \
  -d "{
    \"image_url\": \"${TEST_IMAGE_URL}\",
    \"prompt\": \"$(python3 -c 'print(\"A\" * 10000)')\",
    \"device_id\": \"test-device-long-prompt\",
    \"client_request_id\": \"long-prompt-001\"
  }"

# Expected: 400 error or truncated prompt (depends on validation)
```

**✅ Success Criteria:**
- Input validated
- System doesn't crash
- Appropriate error or truncation

---

### Test 6.5: Network Timeout (Retry Handling)

**Goal:** Verify idempotency prevents double-charge on retry

```bash
# Step 1: Send request (simulate timeout)
curl -X POST "${EDGE_FUNCTION_URL}" \
  --max-time 1 \
  -H "Authorization: Bearer ${ANON_KEY}" \
  -H "Content-Type: application/json" \
  -d '{
    "image_url": "${TEST_IMAGE_URL}",
    "prompt": "Test prompt",
    "device_id": "test-device-timeout",
    "client_request_id": "timeout-retry-001"
  }'

# Step 2: Retry with same request_id (simulate client retry)
curl -X POST "${EDGE_FUNCTION_URL}" \
  -H "Authorization: Bearer ${ANON_KEY}" \
  -H "Content-Type: application/json" \
  -d '{
    "image_url": "${TEST_IMAGE_URL}",
    "prompt": "Test prompt",
    "device_id": "test-device-timeout",
    "client_request_id": "timeout-retry-001"
  }'

# Check quota
curl -X POST "${SUPABASE_URL}/rest/v1/rpc/get_quota" \
  -H "apikey: ${ANON_KEY}" \
  -H "Content-Type: application/json" \
  -d '{
    "p_user_id": null,
    "p_device_id": "test-device-timeout"
  }'

# Expected: quota_used = 1 (not 2, idempotent)
```

**✅ Success Criteria:**
- Retry doesn't double-charge
- Idempotency prevents duplicate consumption
- Quota correct after retry

---

## 📊 Test Execution Checklist

### Pre-Test Setup:
- [ ] Set environment variables (SUPABASE_URL, ANON_KEY, etc.)
- [ ] Create test device IDs
- [ ] Create test user IDs (if testing authenticated flows)
- [ ] Prepare test image URLs
- [ ] Clear any existing test data from previous runs

### Execution Order:
1. [ ] Run Free User Tests (1.1 → 1.6)
2. [ ] Run Premium User Tests (2.1 → 2.7)
3. [ ] Run Subscription Flow Tests (3.1 → 3.5)
4. [ ] Run Refund Tests (4.1 → 4.3)
5. [ ] Run Anonymous User Tests (5.1 → 5.4)
6. [ ] Run Edge Cases (6.1 → 6.5)

### Post-Test Cleanup:
- [ ] Clean up test subscriptions
- [ ] Clean up test quota records
- [ ] Clean up test consumption logs
- [ ] Document any failures or edge cases found

---

## 🎯 Expected Results Summary

| Test Category | Total Tests | Expected Pass | Expected Fail |
|---------------|-------------|---------------|---------------|
| Free User | 6 | 6 | 0 |
| Premium User | 7 | 7 | 0 |
| Subscription Flow | 5 | 5 | 0 |
| Refund | 3 | 3 | 0 |
| Anonymous User | 4 | 4 | 0 |
| Edge Cases | 5 | 5 | 0 |
| **TOTAL** | **30** | **30** | **0** |

---

## 📝 Notes

- **Test Duration:** Approximately 2-3 hours for full execution
- **Prerequisites:** Valid Supabase credentials, Edge Function deployed, test images available
- **Automation:** These tests can be converted to automated test scripts (bash, Python, etc.)
- **Monitoring:** Use Supabase logs to verify database operations
- **Debugging:** Check `quota_consumption_log` table for detailed audit trail

---

**Last Updated:** November 1, 2025  
**Status:** Ready for Execution ✅

