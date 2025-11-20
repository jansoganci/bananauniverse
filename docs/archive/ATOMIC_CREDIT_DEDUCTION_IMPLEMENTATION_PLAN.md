# Atomic Credit Deduction - Complete Implementation Plan

## 🎯 Goal
Implement atomic credit deduction + job creation to prevent credit loss on failures.

---

## ⚠️ Critical Fixes Applied

**Issues identified and fixed:**
1. ✅ **PRIMARY KEY conflict** - Fixed: Drop existing PK constraint before adding new one
2. ✅ **Missing data migration** - Fixed: Backfill `id` and `client_request_id` for existing rows
3. ✅ **Cleanup DECLARE missing** - Fixed: Added `job_record RECORD` declaration

---

## 📋 Overview

**Current Problem:**
- Credits deducted BEFORE fal.ai call
- If fal.ai fails → credits lost (refund can fail too)
- If job insert fails → credits lost (refund can fail too)

**Solution:**
- Atomic stored procedure: Deduct credits + Create job in ONE transaction
- Add internal job ID for race condition protection
- Add client_request_id for webhook fallback lookup
- Automatic refunds for orphaned jobs
- All fixes included

---

## 🗂️ Implementation Steps

### Phase 1: Database Schema Changes

#### Step 1.1: Add Internal ID Column
**File:** New migration `088_add_atomic_job_creation.sql`

```sql
-- ⚠️ CRITICAL: Must drop existing PRIMARY KEY first
-- Step 1: Drop the existing PRIMARY KEY constraint on fal_job_id
ALTER TABLE job_results
DROP CONSTRAINT IF EXISTS job_results_pkey;

-- Step 2: Add internal UUID column (not primary key yet)
ALTER TABLE job_results
ADD COLUMN IF NOT EXISTS id UUID DEFAULT gen_random_uuid();

-- Step 3: Backfill id for existing rows (if any exist)
UPDATE job_results
SET id = gen_random_uuid()
WHERE id IS NULL;

-- Step 4: Make id NOT NULL and set as PRIMARY KEY
ALTER TABLE job_results
ALTER COLUMN id SET NOT NULL;

ALTER TABLE job_results
ADD CONSTRAINT job_results_pkey PRIMARY KEY (id);

-- Step 5: Make fal_job_id nullable (will be set after fal.ai call)
ALTER TABLE job_results
ALTER COLUMN fal_job_id DROP NOT NULL;

-- Step 6: Add unique index on fal_job_id (when not null) - replaces old PK
CREATE UNIQUE INDEX IF NOT EXISTS idx_job_results_fal_job_id_unique
ON job_results(fal_job_id)
WHERE fal_job_id IS NOT NULL;
```

**Why:** 
- Can't have two PRIMARY KEYs - must drop old one first
- Existing rows need `id` backfilled before making it NOT NULL
- Allows creating job BEFORE fal.ai call (with internal ID), then updating with fal_job_id later

---

#### Step 1.2: Add client_request_id Column
**File:** Same migration `088_add_atomic_job_creation.sql`

```sql
-- Add client_request_id for webhook fallback lookup
ALTER TABLE job_results
ADD COLUMN IF NOT EXISTS client_request_id TEXT;

-- Backfill client_request_id for existing rows (use fal_job_id as fallback)
-- This ensures old jobs can still be found by webhook
UPDATE job_results
SET client_request_id = fal_job_id
WHERE client_request_id IS NULL 
  AND fal_job_id IS NOT NULL;

-- Create index for fast lookup
CREATE INDEX IF NOT EXISTS idx_job_results_client_request_id
ON job_results(client_request_id)
WHERE client_request_id IS NOT NULL;

-- Add unique constraint (prevent duplicate requests)
-- Only enforce uniqueness for non-null values (old rows may have NULL)
CREATE UNIQUE INDEX IF NOT EXISTS idx_job_results_client_request_unique
ON job_results(client_request_id)
WHERE client_request_id IS NOT NULL;
```

**Why:** 
- Webhook can find job by `client_request_id` if `fal_job_id` is NULL (race condition protection)
- Existing rows get backfilled with `fal_job_id` so webhook can still find them
- New rows will have `client_request_id` set before `fal_job_id` is available

---

### Phase 2: Create Atomic Stored Procedure

#### Step 2.1: Create `submit_job_atomic()` Function
**File:** Same migration `088_add_atomic_job_creation.sql`

```sql
CREATE OR REPLACE FUNCTION submit_job_atomic(
    p_user_id UUID DEFAULT NULL,
    p_device_id TEXT DEFAULT NULL,
    p_client_request_id TEXT,
    p_idempotency_key TEXT DEFAULT NULL
)
RETURNS JSONB AS $$
DECLARE
    v_balance INTEGER;
    v_job_id UUID;
    v_result JSONB;
BEGIN
    -- Set device_id session for RLS
    IF p_device_id IS NOT NULL THEN
        PERFORM set_config('request.device_id', p_device_id, true);
    END IF;

    -- Validate inputs
    IF p_user_id IS NULL AND p_device_id IS NULL THEN
        RETURN jsonb_build_object(
            'success', FALSE,
            'error', 'Either user_id or device_id required'
        );
    END IF;

    IF p_client_request_id IS NULL THEN
        RETURN jsonb_build_object(
            'success', FALSE,
            'error', 'client_request_id is required'
        );
    END IF;

    -- ========================================
    -- IDEMPOTENCY CHECK
    -- ========================================
    IF p_idempotency_key IS NOT NULL THEN
        -- Check if already processed (by idempotency_key)
        SELECT jsonb_build_object(
            'success', TRUE,
            'credits_remaining', balance_after,
            'job_id', id::text,
            'duplicate', TRUE
        ) INTO v_result
        FROM credit_transactions
        WHERE idempotency_key = p_idempotency_key
        AND (
            (user_id IS NOT NULL AND user_id = p_user_id) OR
            (device_id IS NOT NULL AND device_id = p_device_id)
        )
        LIMIT 1;

        IF v_result IS NOT NULL THEN
            RAISE LOG '[CREDITS] Idempotent request: returning cached result for key=%', p_idempotency_key;
            RETURN v_result;
        END IF;

        -- Check if job already exists (by client_request_id)
        SELECT id INTO v_job_id
        FROM job_results
        WHERE client_request_id = p_client_request_id
        LIMIT 1;

        IF FOUND THEN
            -- Get current balance
            IF p_user_id IS NOT NULL THEN
                SELECT credits INTO v_balance FROM user_credits WHERE user_id = p_user_id;
            ELSE
                SELECT credits INTO v_balance FROM anonymous_credits WHERE device_id = p_device_id;
            END IF;

            RETURN jsonb_build_object(
                'success', TRUE,
                'credits_remaining', COALESCE(v_balance, 0),
                'job_id', v_job_id::text,
                'duplicate', TRUE
            );
        END IF;
    END IF;

    -- ========================================
    -- ATOMIC TRANSACTION: Deduct Credits + Create Job
    -- ========================================
    BEGIN
        -- For authenticated users
        IF p_user_id IS NOT NULL THEN
            -- Lock row and check credits
            SELECT credits INTO v_balance
            FROM user_credits
            WHERE user_id = p_user_id
            FOR UPDATE;

            -- Create record if doesn't exist
            IF NOT FOUND THEN
                INSERT INTO user_credits (user_id, credits)
                VALUES (p_user_id, 10)
                RETURNING credits INTO v_balance;
            END IF;

            -- Check if sufficient balance
            IF v_balance < 1 THEN
                RETURN jsonb_build_object(
                    'success', FALSE,
                    'error', 'Insufficient credits',
                    'credits_remaining', v_balance
                );
            END IF;

            -- Deduct credits
            UPDATE user_credits
            SET credits = credits - 1
            WHERE user_id = p_user_id
            RETURNING credits INTO v_balance;

            -- Create job record (fal_job_id will be NULL initially)
            INSERT INTO job_results (
                user_id,
                device_id,
                status,
                client_request_id,
                fal_job_id  -- NULL initially
            )
            VALUES (
                p_user_id,
                NULL,
                'pending',
                p_client_request_id,
                NULL
            )
            RETURNING id INTO v_job_id;

            -- Log transaction
            INSERT INTO credit_transactions (
                user_id,
                amount,
                balance_after,
                reason,
                idempotency_key,
                created_at
            ) VALUES (
                p_user_id,
                -1,
                v_balance,
                'image_processing',
                p_idempotency_key,
                NOW()
            );

        -- For anonymous users
        ELSIF p_device_id IS NOT NULL THEN
            -- Lock row and check credits
            SELECT credits INTO v_balance
            FROM anonymous_credits
            WHERE device_id = p_device_id
            FOR UPDATE;

            -- Create record if doesn't exist
            IF NOT FOUND THEN
                INSERT INTO anonymous_credits (device_id, credits)
                VALUES (p_device_id, 10)
                RETURNING credits INTO v_balance;
            END IF;

            -- Check if sufficient balance
            IF v_balance < 1 THEN
                RETURN jsonb_build_object(
                    'success', FALSE,
                    'error', 'Insufficient credits',
                    'credits_remaining', v_balance
                );
            END IF;

            -- Deduct credits
            UPDATE anonymous_credits
            SET credits = credits - 1
            WHERE device_id = p_device_id
            RETURNING credits INTO v_balance;

            -- Create job record (fal_job_id will be NULL initially)
            INSERT INTO job_results (
                user_id,
                device_id,
                status,
                client_request_id,
                fal_job_id  -- NULL initially
            )
            VALUES (
                NULL,
                p_device_id,
                'pending',
                p_client_request_id,
                NULL
            )
            RETURNING id INTO v_job_id;

            -- Log transaction
            INSERT INTO credit_transactions (
                device_id,
                amount,
                balance_after,
                reason,
                idempotency_key,
                created_at
            ) VALUES (
                p_device_id,
                -1,
                v_balance,
                'image_processing',
                p_idempotency_key,
                NOW()
            );
        END IF;

        -- Cache idempotency result
        IF p_idempotency_key IS NOT NULL THEN
            INSERT INTO idempotency_keys (user_id, device_id, idempotency_key, response_status, response_body)
            VALUES (p_user_id, p_device_id, p_idempotency_key, 200, jsonb_build_object(
                'success', TRUE,
                'credits_remaining', v_balance,
                'job_id', v_job_id::text
            ))
            ON CONFLICT (COALESCE(user_id::text, ''), COALESCE(device_id, ''), idempotency_key)
            DO UPDATE SET response_body = jsonb_build_object(
                'success', TRUE,
                'credits_remaining', v_balance,
                'job_id', v_job_id::text
            );
        END IF;

        RETURN jsonb_build_object(
            'success', TRUE,
            'credits_remaining', v_balance,
            'job_id', v_job_id::text,
            'duplicate', FALSE
        );

    EXCEPTION
        WHEN OTHERS THEN
            -- Transaction automatically rolls back
            -- Credits NOT deducted, job NOT created
            RAISE LOG '[CREDITS] Atomic transaction failed: %', SQLERRM;
            RETURN jsonb_build_object(
                'success', FALSE,
                'error', 'Transaction failed: ' || SQLERRM
            );
    END;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMENT ON FUNCTION submit_job_atomic IS 'Atomically deducts credits and creates job record. All-or-nothing transaction.';
```

**Key Features:**
- ✅ All in ONE transaction (BEGIN...EXCEPTION)
- ✅ Automatic rollback on ANY failure
- ✅ Creates job with internal `id` (fal_job_id NULL initially)
- ✅ Stores `client_request_id` for webhook lookup
- ✅ Idempotency protection

---

### Phase 3: Update Edge Function (submit-job)

#### Step 3.1: Update submit-job/index.ts Flow
**File:** `supabase/functions/submit-job/index.ts`

**Current Flow (Lines 93-120):**
```typescript
// OLD:
await consumeCredits(...)      // Step 4
await submitToFalAI(...)       // Step 5
await insertJobResult(...)      // Step 6
```

**New Flow:**
```typescript
// NEW:
// Step 4: Atomic procedure (deduct credits + create job)
const atomicResult = await supabase.rpc('submit_job_atomic', {
    p_user_id: userType === 'authenticated' ? userIdentifier : null,
    p_device_id: userType === 'anonymous' ? userIdentifier : null,
    p_client_request_id: requestId,  // Use requestId as client_request_id
    p_idempotency_key: requestId
});

if (atomicResult.error || !atomicResult.data?.success) {
    // Credits automatically NOT deducted (transaction rolled back)
    return error response;
}

const { job_id, credits_remaining } = atomicResult.data;

// Step 5: Submit to fal.ai
const falResult = await submitToFalAI(...);

if (falResult.error) {
    // Job exists, but fal.ai failed
    // Mark job as failed and refund credit
    await markJobFailedAndRefund(supabase, job_id, userType, userIdentifier, requestId);
    return error;
}

const { falJobId } = falResult.data;

// Step 6: Update job with fal_job_id
await updateJobWithFalId(supabase, job_id, falJobId);
```

**Changes Needed:**
1. Replace `consumeCredits()` call with `submit_job_atomic()`
2. Remove `insertJobResult()` call (job already created)
3. Add `updateJobWithFalId()` function
4. Add `markJobFailedAndRefund()` function for fal.ai failures
5. Remove refund logic for database failures (no longer needed)

---

#### Step 3.2: Add Helper Functions
**File:** `supabase/functions/submit-job/index.ts`

```typescript
// Update job with fal_job_id after fal.ai succeeds
async function updateJobWithFalId(
    supabase: any,
    jobId: string,
    falJobId: string,
    logger?: any
): Promise<{ error?: Response }> {
    const { error } = await supabase
        .from('job_results')
        .update({ fal_job_id: falJobId })
        .eq('id', jobId);

    if (error) {
        if (logger) logger.error('Failed to update job with fal_job_id', { error: error.message });
        // This is non-critical - job exists, webhook can still find it by client_request_id
        // But log it for monitoring
    }
    return {};
}

// Mark job as failed and refund credit (for fal.ai failures)
async function markJobFailedAndRefund(
    supabase: any,
    jobId: string,
    userType: 'authenticated' | 'anonymous',
    userIdentifier: string,
    requestId: string,
    logger?: any
): Promise<void> {
    // Mark job as failed
    await supabase
        .from('job_results')
        .update({ status: 'failed', error: 'fal.ai submission failed' })
        .eq('id', jobId);

    // Refund credit
    const refundResult = await refundCredit(supabase, userType, userIdentifier, requestId, logger);
    if (!refundResult.success) {
        if (logger) logger.error('Credit refund failed after fal.ai failure', { error: refundResult.error });
        // Critical: Log for manual intervention
    }
}
```

---

### Phase 4: Update Webhook Handler

#### Step 4.1: Update Webhook Lookup Logic
**File:** `supabase/functions/webhook-handler/index.ts`

**Current (Line 330):**
```typescript
// OLD: Only looks up by fal_job_id
.eq('fal_job_id', request_id)
```

**New:**
```typescript
// NEW: Look up by fal_job_id OR client_request_id (fallback)
const { data: existingJob, error: queryError } = await supabase
    .from('job_results')
    .select('id, fal_job_id, status, user_id, device_id, client_request_id')
    .or(`fal_job_id.eq.${request_id},client_request_id.eq.${request_id}`)
    .single();
```

**Why:** If webhook arrives before `fal_job_id` is updated, it can still find job by `client_request_id`.

---

### Phase 5: Update Cleanup Function

#### Step 5.1: Add Automatic Refund to Cleanup
**File:** New migration `089_add_refund_to_cleanup.sql`

```sql
CREATE OR REPLACE FUNCTION cleanup_job_results()
RETURNS INTEGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    deleted_count INTEGER := 0;
    temp_count INTEGER;
    refunded_count INTEGER := 0;
    job_record RECORD;  -- ⚠️ FIX: Must declare RECORD type for FOR loop
BEGIN
    -- Delete completed jobs older than 7 days
    DELETE FROM public.job_results
    WHERE status = 'completed'
      AND completed_at < now() - INTERVAL '7 days';

    GET DIAGNOSTICS temp_count = ROW_COUNT;
    deleted_count := deleted_count + temp_count;

    -- Delete failed jobs older than 7 days
    DELETE FROM public.job_results
    WHERE status = 'failed'
      AND completed_at < now() - INTERVAL '7 days';

    GET DIAGNOSTICS temp_count = ROW_COUNT;
    deleted_count := deleted_count + temp_count;

    -- Delete pending jobs older than 24 hours (stuck jobs) AND REFUND CREDITS
    FOR job_record IN (
        SELECT id, user_id, device_id, client_request_id
        FROM public.job_results
        WHERE status = 'pending'
          AND created_at < now() - INTERVAL '24 hours'
    ) LOOP
        -- Refund credit for orphaned job
        IF job_record.user_id IS NOT NULL THEN
            UPDATE user_credits
            SET credits = credits + 1
            WHERE user_id = job_record.user_id;
            
            -- Log refund transaction
            INSERT INTO credit_transactions (
                user_id,
                amount,
                balance_after,
                reason,
                idempotency_key,
                created_at
            )
            SELECT 
                job_record.user_id,
                1,
                credits,
                'orphaned_job_refund',
                'cleanup-refund-' || job_record.id::text,
                NOW()
            FROM user_credits
            WHERE user_id = job_record.user_id;
            
            refunded_count := refunded_count + 1;
            
        ELSIF job_record.device_id IS NOT NULL THEN
            UPDATE anonymous_credits
            SET credits = credits + 1
            WHERE device_id = job_record.device_id;
            
            -- Log refund transaction
            INSERT INTO credit_transactions (
                device_id,
                amount,
                balance_after,
                reason,
                idempotency_key,
                created_at
            )
            SELECT 
                job_record.device_id,
                1,
                credits,
                'orphaned_job_refund',
                'cleanup-refund-' || job_record.id::text,
                NOW()
            FROM anonymous_credits
            WHERE device_id = job_record.device_id;
            
            refunded_count := refunded_count + 1;
        END IF;
    END LOOP;

    -- Delete the orphaned jobs (after refunding)
    DELETE FROM public.job_results
    WHERE status = 'pending'
      AND created_at < now() - INTERVAL '24 hours';

    GET DIAGNOSTICS temp_count = ROW_COUNT;
    deleted_count := deleted_count + temp_count;

    RAISE LOG '[CLEANUP] Deleted % jobs, refunded % credits', deleted_count, refunded_count;

    RETURN deleted_count;
END;
$$;
```

**Why:** Orphaned jobs (stuck for 24+ hours) get automatic credit refunds.

---

### Phase 6: Add Deadlock Protection

#### Step 6.1: Use NOWAIT for Cleanup
**File:** Same migration `089_add_refund_to_cleanup.sql`

```sql
-- Update cleanup to use NOWAIT (prevent deadlocks)
-- In the refund loop, use:
UPDATE user_credits
SET credits = credits + 1
WHERE user_id = job_record.user_id
  AND NOT EXISTS (
      SELECT 1 FROM job_results
      WHERE id = job_record.id
        AND status != 'pending'  -- Job was already processed
  )
FOR UPDATE NOWAIT;  -- Fail fast if locked, don't wait
```

**Why:** Prevents cleanup from deadlocking with active transactions.

---

## 📝 Migration Files to Create

### Migration 088: Atomic Job Creation
**File:** `supabase/migrations/088_add_atomic_job_creation.sql`

Contains:
- Add `id` column (internal UUID)
- Make `fal_job_id` nullable
- Add `client_request_id` column
- Create `submit_job_atomic()` function

### Migration 089: Cleanup with Refunds
**File:** `supabase/migrations/089_add_refund_to_cleanup.sql`

Contains:
- Update `cleanup_job_results()` to refund credits
- Add deadlock protection

---

## 🔄 Edge Function Changes

### submit-job/index.ts Changes

**Remove:**
- `consumeCredits()` function call (line 95)
- `insertJobResult()` function call (line 120)
- Refund logic for database failures (lines 526-529)

**Add:**
- `submit_job_atomic()` RPC call
- `updateJobWithFalId()` helper function
- `markJobFailedAndRefund()` helper function
- Update refund logic for fal.ai failures only

**Keep:**
- `refundCredit()` function (still needed for fal.ai failures)
- `submitToFalAI()` function (unchanged)

---

### webhook-handler/index.ts Changes

**Update:**
- `validateJobExists()` function (line 319-377)
- Change lookup from `.eq('fal_job_id', ...)` to `.or('fal_job_id.eq...,client_request_id.eq...')`

---

## ✅ Testing Checklist

### Database Tests
- [ ] New job created with internal `id` and NULL `fal_job_id`
- [ ] Credits deducted atomically
- [ ] If job insert fails → credits NOT deducted (rollback)
- [ ] If credit check fails → job NOT created (rollback)
- [ ] Idempotency prevents duplicate jobs

### Edge Function Tests
- [ ] Atomic procedure succeeds → job created, credits deducted
- [ ] Atomic procedure fails → no job, no deduction
- [ ] fal.ai succeeds → job updated with `fal_job_id`
- [ ] fal.ai fails → job marked failed, credit refunded
- [ ] Duplicate request → returns cached result

### Webhook Tests
- [ ] Webhook finds job by `fal_job_id` (normal case)
- [ ] Webhook finds job by `client_request_id` (race condition)
- [ ] Webhook handles duplicate callbacks (idempotent)

### Cleanup Tests
- [ ] Orphaned jobs deleted after 24 hours
- [ ] Credits refunded for orphaned jobs
- [ ] Refund transactions logged correctly
- [ ] No deadlocks during cleanup

### Integration Tests
- [ ] Happy path: Credits deducted → fal.ai succeeds → job updated
- [ ] Failure path: Credits deducted → fal.ai fails → credit refunded
- [ ] Race condition: Webhook arrives before `fal_job_id` update → still works
- [ ] Network timeout: Job created → client timeout → cleanup refunds later

---

## 🚨 Rollback Plan

If something goes wrong:

1. **Revert Edge Function:**
   - Restore old `consumeCredits()` + `insertJobResult()` flow
   - Keep atomic procedure in database (won't break anything)

2. **Revert Database:**
   - Drop `submit_job_atomic()` function
   - Keep schema changes (backward compatible)

3. **Data Migration:**
   - No data migration needed (new columns are nullable)

---

## 📊 Success Metrics

After implementation, verify:
- ✅ Zero credit loss on database failures
- ✅ Zero credit loss on fal.ai failures (refund works)
- ✅ Zero lost webhooks (race condition handled)
- ✅ Zero orphaned credits (cleanup refunds)

---

## 🎯 Implementation Order

1. **Phase 1:** Database schema changes (migration 088)
2. **Phase 2:** Create atomic procedure (migration 088)
3. **Phase 3:** Update Edge Function (submit-job)
4. **Phase 4:** Update webhook handler
5. **Phase 5:** Update cleanup function (migration 089)
6. **Phase 6:** Testing
7. **Phase 7:** Deploy

---

## ⚠️ Important Notes

1. **Backward Compatibility:**
   - Old `consume_credits()` function still exists (not removed)
   - Can revert Edge Function without database changes
   - New columns are nullable (won't break existing code)

2. **Migration Safety:**
   - All changes are additive (no data loss)
   - Can run migrations in any order
   - Can rollback individually

3. **Performance:**
   - Atomic procedure is faster (one call vs three)
   - Webhook lookup slightly slower (OR query) but acceptable
   - Cleanup takes longer (refund loop) but runs async

---

**Ready to implement?** Start with Phase 1 (database schema changes).

