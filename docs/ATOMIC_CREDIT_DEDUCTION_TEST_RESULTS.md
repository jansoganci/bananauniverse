# Atomic Credit Deduction - Test Results

**Date:** 2025-11-15
**Phases Tested:** 1-5 (Database Schema, Atomic Procedure, Edge Function, Webhook, Cleanup)
**Tester:** [YOUR NAME]
**Environment:** [Staging/Production]

---

## Test Summary

| Category | Total Tests | Passed | Failed | Skipped |
|----------|-------------|--------|--------|---------|
| Database Tests | 3 | - | - | - |
| Edge Function Tests | 3 | - | - | - |
| Webhook Tests | 3 | - | - | - |
| Cleanup Tests | 2 | - | - | - |
| Integration Tests | 4 | - | - | - |
| **TOTAL** | **15** | **-** | **-** | **-** |

---

## Task 1: Database Tests

### Test 1.1: Atomic Job Creation (Happy Path)

**Objective:** Verify that `submit_job_atomic()` creates a job and deducts credits atomically.

**Prerequisites:**
- User has at least 1 credit
- Database migrations 088-089 applied

**Steps:**
1. Get initial credit balance:
   ```sql
   SELECT credits FROM user_credits WHERE user_id = '<USER_ID>';
   ```
   Record result: `___`

2. Call atomic procedure:
   ```sql
   SELECT submit_job_atomic(
       p_client_request_id := 'test-request-001',
       p_user_id := '<USER_ID>',
       p_device_id := NULL,
       p_idempotency_key := 'test-idempotency-001'
   );
   ```
   Record result: `___`

3. Verify job created with correct fields:
   ```sql
   SELECT id, fal_job_id, client_request_id, status, user_id
   FROM job_results
   WHERE client_request_id = 'test-request-001';
   ```
   Expected:
   - `id`: UUID (not NULL)
   - `fal_job_id`: NULL
   - `client_request_id`: 'test-request-001'
   - `status`: 'pending'
   - `user_id`: '<USER_ID>'

   Actual: `___`

4. Verify credit deducted:
   ```sql
   SELECT credits FROM user_credits WHERE user_id = '<USER_ID>';
   ```
   Expected: Initial balance - 1

   Actual: `___`

5. Verify transaction logged:
   ```sql
   SELECT amount, reason, idempotency_key
   FROM credit_transactions
   WHERE idempotency_key = 'test-idempotency-001';
   ```
   Expected:
   - `amount`: -1
   - `reason`: 'image_processing'
   - `idempotency_key`: 'test-idempotency-001'

   Actual: `___`

**Result:** [ ] PASS  [ ] FAIL

**Notes:**
-
-

---

### Test 1.2: Rollback on Insufficient Credits

**Objective:** Verify that transaction rolls back when user has insufficient credits.

**Prerequisites:**
- User has 0 credits

**Steps:**
1. Set user credits to 0:
   ```sql
   UPDATE user_credits SET credits = 0 WHERE user_id = '<USER_ID>';
   ```

2. Try to create job:
   ```sql
   SELECT submit_job_atomic(
       p_client_request_id := 'test-request-002',
       p_user_id := '<USER_ID>',
       p_device_id := NULL,
       p_idempotency_key := 'test-idempotency-002'
   );
   ```
   Expected result:
   ```json
   {
     "success": false,
     "error": "Insufficient credits",
     "credits_remaining": 0
   }
   ```

   Actual: `___`

3. Verify NO job created:
   ```sql
   SELECT COUNT(*) FROM job_results WHERE client_request_id = 'test-request-002';
   ```
   Expected: 0

   Actual: `___`

4. Verify credits still 0 (not negative):
   ```sql
   SELECT credits FROM user_credits WHERE user_id = '<USER_ID>';
   ```
   Expected: 0

   Actual: `___`

5. Verify NO transaction logged:
   ```sql
   SELECT COUNT(*) FROM credit_transactions WHERE idempotency_key = 'test-idempotency-002';
   ```
   Expected: 0

   Actual: `___`

**Result:** [ ] PASS  [ ] FAIL

**Notes:**
-
-

---

### Test 1.3: Idempotency Protection

**Objective:** Verify that duplicate requests return cached results without creating duplicate jobs.

**Prerequisites:**
- User has at least 1 credit
- Previous job from Test 1.1 still exists

**Steps:**
1. Call atomic procedure AGAIN with same idempotency key:
   ```sql
   SELECT submit_job_atomic(
       p_client_request_id := 'test-request-001',
       p_user_id := '<USER_ID>',
       p_device_id := NULL,
       p_idempotency_key := 'test-idempotency-001'
   );
   ```
   Expected result:
   ```json
   {
     "success": true,
     "credits_remaining": <BALANCE>,
     "job_id": "<JOB_ID>",
     "duplicate": true
   }
   ```

   Actual: `___`

2. Verify only ONE job exists:
   ```sql
   SELECT COUNT(*) FROM job_results WHERE client_request_id = 'test-request-001';
   ```
   Expected: 1

   Actual: `___`

3. Verify credit only deducted ONCE:
   ```sql
   SELECT COUNT(*) FROM credit_transactions WHERE idempotency_key = 'test-idempotency-001';
   ```
   Expected: 1

   Actual: `___`

**Result:** [ ] PASS  [ ] FAIL

**Notes:**
-
-

---

## Task 2: Edge Function Tests

### Test 2.1: Happy Path (End-to-End Success)

**Objective:** Verify Edge Function creates job, deducts credit, calls fal.ai, and updates job.

**Prerequisites:**
- User has at least 1 credit
- `FAL_AI_API_KEY` configured
- Edge Function deployed

**Steps:**
1. Get initial credit balance:
   ```bash
   curl -X POST 'https://<PROJECT>.supabase.co/rest/v1/rpc/get_credits' \
     -H "apikey: <ANON_KEY>" \
     -H "Authorization: Bearer <USER_JWT>" \
     -H "Content-Type: application/json"
   ```
   Record balance: `___`

2. Submit job via Edge Function:
   ```bash
   curl -X POST 'https://<PROJECT>.supabase.co/functions/v1/submit-job' \
     -H "apikey: <ANON_KEY>" \
     -H "Authorization: Bearer <USER_JWT>" \
     -H "Content-Type: application/json" \
     -d '{
       "image_url": "https://example.com/test.jpg",
       "prompt": "test prompt"
     }'
   ```
   Expected response:
   ```json
   {
     "success": true,
     "job_id": "<FAL_JOB_ID>",
     "status": "pending",
     "quota_info": {
       "credits_remaining": <BALANCE - 1>
     }
   }
   ```

   Actual: `___`

3. Check Edge Function logs:
   ```bash
   supabase functions logs submit-job
   ```
   Look for:
   - ✅ "Atomic job creation successful"
   - ✅ "Fal.ai submission successful"
   - ✅ "Job updated with fal_job_id"

   Notes: `___`

4. Verify job record:
   ```sql
   SELECT id, fal_job_id, status, user_id
   FROM job_results
   ORDER BY created_at DESC
   LIMIT 1;
   ```
   Expected:
   - `fal_job_id`: NOT NULL (set after fal.ai call)
   - `status`: 'pending'

   Actual: `___`

5. Verify credit deducted:
   ```bash
   curl -X POST 'https://<PROJECT>.supabase.co/rest/v1/rpc/get_credits' \
     -H "apikey: <ANON_KEY>" \
     -H "Authorization: Bearer <USER_JWT>" \
     -H "Content-Type: application/json"
   ```
   Expected: Initial balance - 1

   Actual: `___`

**Result:** [ ] PASS  [ ] FAIL

**Notes:**
-
-

---

### Test 2.2: Fal.ai Failure (Refund)

**Objective:** Verify that credit is refunded when fal.ai call fails.

**Prerequisites:**
- User has at least 1 credit
- Ability to simulate fal.ai failure (invalid API key or mock)

**Steps:**
1. Get initial credit balance
   Record: `___`

2. Temporarily break fal.ai (set invalid API key):
   ```bash
   # Update environment variable or use invalid prompt
   ```

3. Submit job:
   ```bash
   curl -X POST 'https://<PROJECT>.supabase.co/functions/v1/submit-job' \
     -H "apikey: <ANON_KEY>" \
     -H "Authorization: Bearer <USER_JWT>" \
     -H "Content-Type: application/json" \
     -d '{
       "image_url": "https://example.com/test.jpg",
       "prompt": "test prompt"
     }'
   ```
   Expected: Error response (500 or 400)

   Actual: `___`

4. Check Edge Function logs:
   ```bash
   supabase functions logs submit-job
   ```
   Look for:
   - ✅ "Fal.ai submission failed - marking job as failed and refunding credit"
   - ✅ "Credit refund successful"

   Notes: `___`

5. Verify job marked as failed:
   ```sql
   SELECT status, error FROM job_results ORDER BY created_at DESC LIMIT 1;
   ```
   Expected:
   - `status`: 'failed'
   - `error`: Contains fal.ai error message

   Actual: `___`

6. Verify credit refunded:
   ```bash
   curl -X POST 'https://<PROJECT>.supabase.co/rest/v1/rpc/get_credits' \
     -H "apikey: <ANON_KEY>" \
     -H "Authorization: Bearer <USER_JWT>" \
     -H "Content-Type: application/json"
   ```
   Expected: Same as initial balance (refunded)

   Actual: `___`

7. Verify refund transaction logged:
   ```sql
   SELECT amount, reason FROM credit_transactions
   WHERE idempotency_key LIKE 'refund-%'
   ORDER BY created_at DESC
   LIMIT 1;
   ```
   Expected:
   - `amount`: 1 (positive, it's a refund)
   - `reason`: Contains 'refund' or similar

   Actual: `___`

**Result:** [ ] PASS  [ ] FAIL

**Notes:**
-
-

---

### Test 2.3: Duplicate Request (Idempotency)

**Objective:** Verify that duplicate requests are handled idempotently.

**Prerequisites:**
- User has at least 1 credit

**Steps:**
1. Submit job with custom request ID:
   ```bash
   curl -X POST 'https://<PROJECT>.supabase.co/functions/v1/submit-job' \
     -H "apikey: <ANON_KEY>" \
     -H "Authorization: Bearer <USER_JWT>" \
     -H "Content-Type: application/json" \
     -H "x-request-id: duplicate-test-001" \
     -d '{
       "image_url": "https://example.com/test.jpg",
       "prompt": "test prompt"
     }'
   ```
   Record response: `___`

2. Submit SAME request again (same x-request-id):
   ```bash
   curl -X POST 'https://<PROJECT>.supabase.co/functions/v1/submit-job' \
     -H "apikey: <ANON_KEY>" \
     -H "Authorization: Bearer <USER_JWT>" \
     -H "Content-Type: application/json" \
     -H "x-request-id: duplicate-test-001" \
     -d '{
       "image_url": "https://example.com/test.jpg",
       "prompt": "test prompt"
     }'
   ```
   Expected: Same response as first request

   Actual: `___`

3. Check logs for idempotency message:
   ```bash
   supabase functions logs submit-job
   ```
   Look for: "Idempotent request: returning cached result"

   Notes: `___`

4. Verify only ONE job created:
   ```sql
   SELECT COUNT(*) FROM job_results WHERE client_request_id = 'duplicate-test-001';
   ```
   Expected: 1

   Actual: `___`

5. Verify credit only deducted ONCE:
   ```sql
   SELECT COUNT(*) FROM credit_transactions
   WHERE idempotency_key = 'duplicate-test-001';
   ```
   Expected: 1 (deduction), possibly 1 refund if test 2.2 failed

   Actual: `___`

**Result:** [ ] PASS  [ ] FAIL

**Notes:**
-
-

---

## Task 3: Webhook Tests

### Test 3.1: Normal Webhook (fal_job_id Lookup)

**Objective:** Verify webhook finds job by `fal_job_id` in normal case.

**Prerequisites:**
- Job submitted and `fal_job_id` updated
- Webhook URL configured

**Steps:**
1. Submit job and wait for `fal_job_id` to be set:
   ```sql
   SELECT id, fal_job_id, client_request_id, status
   FROM job_results
   ORDER BY created_at DESC
   LIMIT 1;
   ```
   Record `fal_job_id`: `___`

2. Send test webhook (simulate fal.ai callback):
   ```bash
   curl -X POST 'https://<PROJECT>.supabase.co/functions/v1/webhook-handler' \
     -H "Content-Type: application/json" \
     -d '{
       "request_id": "<FAL_JOB_ID>",
       "status": "OK",
       "payload": {
         "images": [
           {
             "url": "https://fal.media/test-image.jpg",
             "content_type": "image/jpeg"
           }
         ]
       }
     }'
   ```
   Expected: 200 OK response

   Actual: `___`

3. Check webhook logs:
   ```bash
   supabase functions logs webhook-handler
   ```
   Look for:
   - ✅ "Valid pending job found"
   - ✅ "foundBy: fal_job_id" (NOT client_request_id)

   Notes: `___`

4. Verify job completed:
   ```sql
   SELECT status, image_url FROM job_results WHERE fal_job_id = '<FAL_JOB_ID>';
   ```
   Expected:
   - `status`: 'completed'
   - `image_url`: NOT NULL

   Actual: `___`

**Result:** [ ] PASS  [ ] FAIL

**Notes:**
-
-

---

### Test 3.2: Race Condition (client_request_id Fallback)

**Objective:** Verify webhook can find job by `client_request_id` when `fal_job_id` not set yet.

**Prerequisites:**
- Direct database access to create test job

**Steps:**
1. Create job with NULL `fal_job_id`:
   ```sql
   INSERT INTO job_results (user_id, device_id, status, client_request_id, fal_job_id)
   VALUES ('<USER_ID>', NULL, 'pending', 'race-test-001', NULL)
   RETURNING id, client_request_id;
   ```
   Record `client_request_id`: `___`

2. Send webhook with `client_request_id` in query params:
   ```bash
   curl -X POST 'https://<PROJECT>.supabase.co/functions/v1/webhook-handler?client_request_id=race-test-001' \
     -H "Content-Type: application/json" \
     -d '{
       "request_id": "fake-fal-job-id-123",
       "status": "OK",
       "payload": {
         "images": [
           {
             "url": "https://fal.media/test-image.jpg",
             "content_type": "image/jpeg"
           }
         ]
       }
     }'
   ```
   Expected: 200 OK response

   Actual: `___`

3. Check webhook logs:
   ```bash
   supabase functions logs webhook-handler
   ```
   Look for:
   - ✅ "RACE CONDITION DETECTED: Job found by client_request_id"
   - ✅ "foundBy: client_request_id"

   Notes: `___`

4. Verify job updated with `fal_job_id`:
   ```sql
   SELECT fal_job_id, status FROM job_results WHERE client_request_id = 'race-test-001';
   ```
   Expected:
   - `fal_job_id`: 'fake-fal-job-id-123' (now set)
   - `status`: 'completed'

   Actual: `___`

**Result:** [ ] PASS  [ ] FAIL

**Notes:**
-
-

---

### Test 3.3: Duplicate Webhook (Idempotency)

**Objective:** Verify duplicate webhooks are handled idempotently.

**Prerequisites:**
- Completed job from Test 3.1

**Steps:**
1. Send same webhook again:
   ```bash
   curl -X POST 'https://<PROJECT>.supabase.co/functions/v1/webhook-handler' \
     -H "Content-Type: application/json" \
     -d '{
       "request_id": "<FAL_JOB_ID>",
       "status": "OK",
       "payload": {
         "images": [
           {
             "url": "https://fal.media/test-image.jpg",
             "content_type": "image/jpeg"
           }
         ]
       }
     }'
   ```
   Expected: 200 OK response with "Job already processed" message

   Actual: `___`

2. Check webhook logs:
   ```bash
   supabase functions logs webhook-handler
   ```
   Look for: "Job already processed (idempotent)"

   Notes: `___`

3. Verify job status unchanged:
   ```sql
   SELECT status, updated_at FROM job_results WHERE fal_job_id = '<FAL_JOB_ID>';
   ```
   Expected: Same as before (no changes)

   Actual: `___`

**Result:** [ ] PASS  [ ] FAIL

**Notes:**
-
-

---

## Task 4: Cleanup Tests

### Test 4.1: Orphaned Job Refund

**Objective:** Verify cleanup function refunds credits for orphaned jobs.

**Prerequisites:**
- User has at least 1 credit
- Direct database access

**Steps:**
1. Get initial credit balance:
   ```sql
   SELECT credits FROM user_credits WHERE user_id = '<USER_ID>';
   ```
   Record: `___`

2. Create orphaned job (pending, older than 24 hours):
   ```sql
   INSERT INTO job_results (user_id, device_id, status, client_request_id, created_at)
   VALUES (
       '<USER_ID>',
       NULL,
       'pending',
       'orphaned-test-001',
       NOW() - INTERVAL '25 hours'
   )
   RETURNING id;
   ```
   Record job ID: `___`

3. Deduct credit manually (simulate credit was already deducted):
   ```sql
   UPDATE user_credits SET credits = credits - 1 WHERE user_id = '<USER_ID>';
   ```

4. Verify job is pending and old:
   ```sql
   SELECT status, created_at FROM job_results WHERE id = '<JOB_ID>';
   ```
   Confirm: status = 'pending', created_at > 24 hours ago

   Actual: `___`

5. Run cleanup function:
   ```sql
   SELECT cleanup_job_results();
   ```
   Record result (number of jobs deleted): `___`

6. Check PostgreSQL logs:
   ```bash
   # Look for: "[CLEANUP] Deleted X jobs, refunded Y credits"
   ```
   Notes: `___`

7. Verify job deleted:
   ```sql
   SELECT COUNT(*) FROM job_results WHERE id = '<JOB_ID>';
   ```
   Expected: 0

   Actual: `___`

8. Verify credit refunded:
   ```sql
   SELECT credits FROM user_credits WHERE user_id = '<USER_ID>';
   ```
   Expected: Initial balance (refunded)

   Actual: `___`

9. Verify refund transaction logged:
   ```sql
   SELECT amount, reason, idempotency_key
   FROM credit_transactions
   WHERE reason = 'orphaned_job_refund'
     AND idempotency_key = 'cleanup-refund-<JOB_ID>'
   ORDER BY created_at DESC
   LIMIT 1;
   ```
   Expected:
   - `amount`: 1
   - `reason`: 'orphaned_job_refund'

   Actual: `___`

**Result:** [ ] PASS  [ ] FAIL

**Notes:**
-
-

---

### Test 4.2: Deadlock Protection

**Objective:** Verify cleanup doesn't deadlock when rows are locked.

**Prerequisites:**
- Multiple orphaned jobs
- Ability to create concurrent transactions

**Steps:**
1. Create 3 orphaned jobs for same user:
   ```sql
   INSERT INTO job_results (user_id, device_id, status, client_request_id, created_at)
   VALUES
       ('<USER_ID>', NULL, 'pending', 'deadlock-test-001', NOW() - INTERVAL '25 hours'),
       ('<USER_ID>', NULL, 'pending', 'deadlock-test-002', NOW() - INTERVAL '25 hours'),
       ('<USER_ID>', NULL, 'pending', 'deadlock-test-003', NOW() - INTERVAL '25 hours');
   ```

2. In Transaction 1 (keep open):
   ```sql
   BEGIN;
   SELECT credits FROM user_credits WHERE user_id = '<USER_ID>' FOR UPDATE;
   -- DO NOT COMMIT YET
   ```

3. In Transaction 2, run cleanup:
   ```sql
   SELECT cleanup_job_results();
   ```
   Expected: Function completes WITHOUT deadlock

   Actual: `___`

4. Check PostgreSQL logs:
   ```bash
   # Look for: "[CLEANUP] Skipped refund for job X (row locked)"
   ```
   Notes: `___`

5. Commit Transaction 1:
   ```sql
   COMMIT;
   ```

6. Run cleanup again:
   ```sql
   SELECT cleanup_job_results();
   ```
   Expected: Now refunds the previously locked jobs

   Actual: `___`

7. Verify all jobs deleted:
   ```sql
   SELECT COUNT(*) FROM job_results
   WHERE client_request_id IN ('deadlock-test-001', 'deadlock-test-002', 'deadlock-test-003');
   ```
   Expected: 0 (all deleted)

   Actual: `___`

**Result:** [ ] PASS  [ ] FAIL

**Notes:**
-
-

---

## Task 5: Integration Tests

### Test 5.1: Happy Path (End-to-End)

**Objective:** Complete end-to-end test from job submission to completion.

**Prerequisites:**
- User has at least 1 credit
- All services running

**Steps:**
1. Record initial state:
   ```sql
   SELECT credits FROM user_credits WHERE user_id = '<USER_ID>';
   ```
   Initial credits: `___`

2. Submit job:
   ```bash
   curl -X POST 'https://<PROJECT>.supabase.co/functions/v1/submit-job' \
     -H "apikey: <ANON_KEY>" \
     -H "Authorization: Bearer <USER_JWT>" \
     -H "Content-Type: application/json" \
     -d '{
       "image_url": "https://example.com/test.jpg",
       "prompt": "test prompt"
     }'
   ```
   Record job_id: `___`

3. Wait for webhook (fal.ai callback)
   Time waited: `___`

4. Check final job status:
   ```sql
   SELECT status, image_url, fal_job_id FROM job_results WHERE id = '<JOB_ID>';
   ```
   Expected:
   - `status`: 'completed'
   - `image_url`: NOT NULL
   - `fal_job_id`: NOT NULL

   Actual: `___`

5. Check final credit balance:
   ```sql
   SELECT credits FROM user_credits WHERE user_id = '<USER_ID>';
   ```
   Expected: Initial credits - 1

   Actual: `___`

6. Verify only ONE credit transaction:
   ```sql
   SELECT COUNT(*) FROM credit_transactions
   WHERE user_id = '<USER_ID>'
     AND amount = -1
     AND created_at > NOW() - INTERVAL '5 minutes';
   ```
   Expected: 1

   Actual: `___`

**Result:** [ ] PASS  [ ] FAIL

**Notes:**
-
-

---

### Test 5.2: Failure Path (Refund)

**Objective:** Verify credit refunded when job fails.

**Prerequisites:**
- User has at least 1 credit
- Ability to simulate failure

**Steps:**
1. Record initial credits:
   ```sql
   SELECT credits FROM user_credits WHERE user_id = '<USER_ID>';
   ```
   Initial: `___`

2. Submit job (will fail):
   ```bash
   # Use invalid parameters or disabled API key
   ```
   Record response: `___`

3. Check job status:
   ```sql
   SELECT status, error FROM job_results ORDER BY created_at DESC LIMIT 1;
   ```
   Expected:
   - `status`: 'failed'
   - `error`: Contains error message

   Actual: `___`

4. Check final credits:
   ```sql
   SELECT credits FROM user_credits WHERE user_id = '<USER_ID>';
   ```
   Expected: Same as initial (refunded)

   Actual: `___`

5. Verify refund transaction:
   ```sql
   SELECT amount, reason FROM credit_transactions
   WHERE user_id = '<USER_ID>'
   ORDER BY created_at DESC
   LIMIT 2;
   ```
   Expected: 2 transactions (deduction -1, refund +1)

   Actual: `___`

**Result:** [ ] PASS  [ ] FAIL

**Notes:**
-
-

---

### Test 5.3: Race Condition (Webhook Before Update)

**Objective:** Verify system handles webhook arriving before `fal_job_id` is updated.

**Prerequisites:**
- Ability to control timing

**Steps:**
1. Submit job:
   ```bash
   curl -X POST 'https://<PROJECT>.supabase.co/functions/v1/submit-job' \
     -H "apikey: <ANON_KEY>" \
     -H "Authorization: Bearer <USER_JWT>" \
     -H "Content-Type: application/json" \
     -d '{
       "image_url": "https://example.com/test.jpg",
       "prompt": "test prompt"
     }'
   ```
   Record job_id from response: `___`

2. Get client_request_id:
   ```sql
   SELECT client_request_id FROM job_results WHERE id = '<JOB_ID>';
   ```
   Record: `___`

3. Send webhook IMMEDIATELY (before fal_job_id update):
   ```bash
   curl -X POST 'https://<PROJECT>.supabase.co/functions/v1/webhook-handler?client_request_id=<CLIENT_REQUEST_ID>' \
     -H "Content-Type: application/json" \
     -d '{
       "request_id": "early-webhook-fal-id",
       "status": "OK",
       "payload": {
         "images": [{"url": "https://fal.media/test.jpg", "content_type": "image/jpeg"}]
       }
     }'
   ```

4. Check webhook logs:
   ```bash
   supabase functions logs webhook-handler
   ```
   Look for: "RACE CONDITION DETECTED"

   Found: [ ] YES  [ ] NO

5. Verify job completed:
   ```sql
   SELECT status, fal_job_id FROM job_results WHERE id = '<JOB_ID>';
   ```
   Expected:
   - `status`: 'completed'
   - `fal_job_id`: 'early-webhook-fal-id'

   Actual: `___`

**Result:** [ ] PASS  [ ] FAIL

**Notes:**
-
-

---

### Test 5.4: Network Timeout (Cleanup Refund)

**Objective:** Verify orphaned jobs are cleaned up and refunded after 24 hours.

**Prerequisites:**
- User has at least 1 credit
- Direct database access

**Steps:**
1. Simulate job submission + credit deduction:
   ```sql
   -- Get current balance
   SELECT credits FROM user_credits WHERE user_id = '<USER_ID>';
   -- Record: ___

   -- Deduct credit
   UPDATE user_credits SET credits = credits - 1 WHERE user_id = '<USER_ID>';

   -- Create orphaned job (25 hours old)
   INSERT INTO job_results (user_id, device_id, status, client_request_id, created_at)
   VALUES ('<USER_ID>', NULL, 'pending', 'timeout-test-001', NOW() - INTERVAL '25 hours')
   RETURNING id;
   ```

2. Run cleanup:
   ```sql
   SELECT cleanup_job_results();
   ```
   Record result: `___`

3. Verify job deleted:
   ```sql
   SELECT COUNT(*) FROM job_results WHERE client_request_id = 'timeout-test-001';
   ```
   Expected: 0

   Actual: `___`

4. Verify credit refunded:
   ```sql
   SELECT credits FROM user_credits WHERE user_id = '<USER_ID>';
   ```
   Expected: Back to original balance

   Actual: `___`

5. Verify refund logged:
   ```sql
   SELECT reason, amount FROM credit_transactions
   WHERE reason = 'orphaned_job_refund'
   ORDER BY created_at DESC
   LIMIT 1;
   ```
   Expected: amount = 1, reason = 'orphaned_job_refund'

   Actual: `___`

**Result:** [ ] PASS  [ ] FAIL

**Notes:**
-
-

---

## Issues Found

### Issue #1
**Title:**
**Severity:** [ ] Critical  [ ] High  [ ] Medium  [ ] Low
**Description:**
**Steps to Reproduce:**
**Expected:**
**Actual:**
**Workaround:**
**Fix Required:**

### Issue #2
**Title:**
**Severity:** [ ] Critical  [ ] High  [ ] Medium  [ ] Low
**Description:**
**Steps to Reproduce:**
**Expected:**
**Actual:**
**Workaround:**
**Fix Required:**

---

## Recommendations

1. **Before Production Deployment:**
   - [ ] All tests pass
   - [ ] No critical issues found
   - [ ] Performance acceptable (< 500ms for job submission)
   - [ ] Error messages are user-friendly
   - [ ] Logging is sufficient for debugging

2. **Monitoring Setup:**
   - [ ] Set up alerts for failed jobs
   - [ ] Monitor credit refund rate
   - [ ] Track race condition frequency
   - [ ] Monitor cleanup function execution

3. **Documentation:**
   - [ ] Update API documentation
   - [ ] Document error codes
   - [ ] Create troubleshooting guide
   - [ ] Update deployment guide

---

## Conclusion

**Overall Status:** [ ] READY FOR PRODUCTION  [ ] NEEDS FIXES  [ ] BLOCKED

**Summary:**


**Tester Signature:** _______________
**Date:** _______________
