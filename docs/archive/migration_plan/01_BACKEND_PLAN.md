# Backend Migration Plan: Async Polling Architecture

## Overview

This document details all backend changes required to migrate from synchronous to async polling architecture.

**Scope**: Supabase Edge Functions only
**Duration**: 4-6 hours
**Risk**: Low (additive changes, no deletions)

---

## Part 1: Files to Create

### 1.1 NEW: `submit-job` Edge Function

**File Path**: `supabase/functions/submit-job/index.ts`

**Purpose**: Accept image + prompt, submit to fal.ai async queue, return job_id immediately.

**Size Estimate**: ~300 lines

#### Responsibilities

1. **Request validation**:
   - Extract user_id (authenticated) or device_id (anonymous) from JWT
   - Validate image_url or image_data present
   - Validate prompt is non-empty (1-500 characters)
   - Generate unique request_id for idempotency

2. **Credit deduction**:
   - Call `deduct_credits` RPC with request_id
   - If insufficient credits → return 402 with credit_info
   - If premium user → skip credit check
   - Store transaction: `p_reason = 'image_processing'`

3. **Image handling**:
   - If `image_data` provided (base64): decode and upload
   - If `image_url` provided: verify it's accessible
   - Upload to: `temp-processing/{user_id}/{timestamp}-input.jpg`
   - Generate signed URL (1 hour expiry)
   - Bucket: `noname-banana-images-prod`

4. **fal.ai submission**:
   - Endpoint: `https://queue.fal.run/fal-ai/nano-banana/edit`
   - Method: POST
   - Headers:
     ```typescript
     {
       'Authorization': `Key ${FAL_API_KEY}`,
       'Content-Type': 'application/json'
     }
     ```
   - Body:
     ```typescript
     {
       prompt: string,
       image_url: string,  // Signed URL from Supabase Storage
       num_images: 1,
       output_format: 'jpeg'
     }
     ```
   - Expected response:
     ```typescript
     {
       request_id: string,  // fal.ai job ID
       status: 'IN_QUEUE' | 'IN_PROGRESS'
     }
     ```

5. **Database insert** (OPTIONAL):
   - If `job_history` table exists:
     ```sql
     INSERT INTO job_history (
       id, user_id, device_id, fal_job_id, status,
       input_url, prompt, created_at
     ) VALUES (...)
     ```
   - If table doesn't exist: skip silently (no error)

6. **Response to iOS**:
   ```typescript
   {
     success: true,
     job_id: string,         // fal.ai request_id
     status: 'queued',
     credit_info: {
       balance: number,
       is_premium: boolean
     }
   }
   ```

#### Error Handling

| Scenario | HTTP Status | Response | Action |
|----------|-------------|----------|--------|
| Invalid auth | 401 | `{ success: false, error: 'Unauthorized' }` | Return immediately |
| Insufficient credits | 402 | `{ success: false, error: 'Insufficient credits', credit_info: {...} }` | Don't call fal.ai |
| Invalid image | 400 | `{ success: false, error: 'Invalid image' }` | Return immediately |
| fal.ai error | 500 | `{ success: false, error: 'Submission failed' }` | Refund credit |
| Storage upload error | 500 | `{ success: false, error: 'Storage error' }` | Refund credit |
| Database error | 200 | Still return success (database optional) | Log warning |

#### Refund Logic

If any error occurs **after** credit deduction:
```typescript
await supabase.rpc('add_credits', {
  p_user_id: userId,
  p_device_id: deviceId,
  p_amount: 1,
  p_reason: 'submission_failed',
  p_idempotency_key: `refund-${requestId}`
});
```

---

### 1.2 NEW: `check-status` Edge Function

**File Path**: `supabase/functions/check-status/index.ts`

**Purpose**: Query fal.ai job status, download result if ready, return to iOS.

**Size Estimate**: ~250 lines

#### Responsibilities

1. **Request validation**:
   - Extract user_id or device_id from JWT
   - Validate `job_id` parameter present
   - Generate request_id for idempotency (optional caching)

2. **Query fal.ai status**:
   - Endpoint: `https://queue.fal.run/fal-ai/nano-banana/edit/{job_id}/status`
   - Method: GET
   - Headers: `Authorization: Key ${FAL_API_KEY}`
   - Possible responses:
     ```typescript
     // Queued
     { status: 'IN_QUEUE', queue_position: number }

     // Processing
     { status: 'IN_PROGRESS' }

     // Completed
     {
       status: 'COMPLETED',
       result: {
         images: [{ url: string, content_type: string }]
       }
     }

     // Failed
     { status: 'FAILED', error: string }
     ```

3. **If status = IN_QUEUE or IN_PROGRESS**:
   - Update database (optional):
     ```sql
     UPDATE job_history SET
       status = 'processing',
       updated_at = NOW()
     WHERE fal_job_id = $1
     ```
   - Return to iOS:
     ```typescript
     {
       success: true,
       status: 'processing',
       queue_position: number | null
     }
     ```

4. **If status = COMPLETED**:
   - Download image from `result.images[0].url`
   - Upload to Supabase Storage:
     - Path: `processed/{user_id}/{timestamp}-result.jpg`
     - Bucket: `noname-banana-images-prod`
   - Generate signed URL (7 days expiry)
   - Update database (optional):
     ```sql
     UPDATE job_history SET
       status = 'completed',
       result_url = $1,
       completed_at = NOW()
     WHERE fal_job_id = $2
     ```
   - Delete temp input image:
     ```typescript
     await supabase.storage
       .from('noname-banana-images-prod')
       .remove([`temp-processing/${userId}/${inputFilename}`]);
     ```
   - Return to iOS:
     ```typescript
     {
       success: true,
       status: 'completed',
       image_url: string  // Signed URL
     }
     ```

5. **If status = FAILED**:
   - Refund credit:
     ```typescript
     await supabase.rpc('add_credits', {
       p_user_id: userId,
       p_device_id: deviceId,
       p_amount: 1,
       p_reason: 'processing_failed',
       p_idempotency_key: `refund-${jobId}`
     });
     ```
   - Update database (optional):
     ```sql
     UPDATE job_history SET
       status = 'failed',
       error = $1,
       completed_at = NOW()
     WHERE fal_job_id = $2
     ```
   - Return to iOS:
     ```typescript
     {
       success: false,
       status: 'failed',
       error: string
     }
     ```

#### Idempotency (Optional)

To prevent duplicate downloads on retry:
```typescript
// Check if already completed
const cached = await db.query(
  'SELECT result_url FROM job_history WHERE fal_job_id = $1',
  [jobId]
);

if (cached?.result_url) {
  return { success: true, status: 'completed', image_url: cached.result_url };
}
```

#### Error Handling

| Scenario | HTTP Status | Response | Action |
|----------|-------------|----------|--------|
| Invalid auth | 401 | `{ success: false, error: 'Unauthorized' }` | Return immediately |
| Job not found | 404 | `{ success: false, error: 'Job not found' }` | fal.ai returned 404 |
| fal.ai API error | 500 | `{ success: false, error: 'Status check failed' }` | iOS retries |
| Download failed | 500 | `{ success: false, error: 'Download failed' }` | iOS retries |
| Storage upload error | 500 | `{ success: false, error: 'Upload failed' }` | iOS retries |

---

## Part 2: Files to Modify

### 2.1 MODIFY: `process-image` Edge Function

**File Path**: `supabase/functions/process-image/index.ts`

**Action**: Deprecate (NOT delete), add warning header.

**Current**: Synchronous processing (lines 1-625)

**Change**: Add deprecation notice at top:

```typescript
/**
 * ⚠️ DEPRECATED: This endpoint uses synchronous processing (30-40 second response time).
 *
 * For new implementations, use:
 * - POST /submit-job → returns job_id immediately
 * - POST /check-status → poll until complete
 *
 * This endpoint will be removed after 2025-12-01.
 *
 * Migration guide: docs/migration_plan/00_MASTER_MIGRATION_PLAN.md
 */
```

**Keep code unchanged**: All existing logic stays functional.

**Add response header**:
```typescript
return new Response(
  JSON.stringify(response),
  {
    status: 200,
    headers: {
      ...corsHeaders,
      'Content-Type': 'application/json',
      'X-Deprecated': 'true',
      'X-Deprecation-Date': '2025-12-01',
      'X-Migration-Guide': 'https://docs.bananauniverse.com/api/migration'
    }
  }
);
```

**Rationale**: Keep as fallback during iOS migration. Remove in Phase 4.

---

## Part 3: Files to Delete

**NONE** during Phase 1.

**Phase 4 only** (after 2 weeks):
- Delete `supabase/functions/process-image/index.ts`
- Delete `supabase/functions/process-image/deno.json` (if exists)

---

## Part 4: Environment Variables

### Required Variables

Add to Supabase Dashboard → Settings → Edge Functions → Environment Variables:

| Variable | Value | Purpose | Required |
|----------|-------|---------|----------|
| `FAL_API_KEY` | `your-fal-api-key` | Authenticate with fal.ai | ✅ Yes |
| `FAL_BASE_URL` | `https://queue.fal.run` | fal.ai async API base | ✅ Yes |
| `TEMP_STORAGE_BUCKET` | `noname-banana-images-prod` | Temp image storage | ✅ Yes |
| `RESULT_STORAGE_BUCKET` | `noname-banana-images-prod` | Final image storage | ✅ Yes |
| `ENABLE_JOB_HISTORY` | `true` | Enable database tracking | ❌ Optional |

### Existing Variables (Already Set)

| Variable | Current Value | Usage |
|----------|---------------|-------|
| `SUPABASE_URL` | `https://xxx.supabase.co` | Already exists |
| `SUPABASE_SERVICE_ROLE_KEY` | `eyJ...` | Already exists |

### Local Development

**File**: `supabase/.env.local`

```bash
FAL_API_KEY=your-fal-api-key
FAL_BASE_URL=https://queue.fal.run
TEMP_STORAGE_BUCKET=noname-banana-images-prod
RESULT_STORAGE_BUCKET=noname-banana-images-prod
ENABLE_JOB_HISTORY=true
```

**Note**: Do NOT commit `.env.local` to git.

---

## Part 5: Storage Bucket Structure

### Current Structure

```
noname-banana-images-prod/
└── processed/
    └── {user_id}/
        └── {timestamp}-result.jpg
```

### New Structure (After Migration)

```
noname-banana-images-prod/
├── temp-processing/              ← NEW
│   └── {user_id}/
│       └── {timestamp}-input.jpg  (auto-delete after 1 hour)
└── processed/
    └── {user_id}/
        └── {timestamp}-result.jpg
```

### Changes Required

**Action**: Create `temp-processing/` folder structure dynamically (no manual setup).

**Cleanup**: Delete temp files in `check-status` after processing:
```typescript
// After successful upload of result
await supabase.storage
  .from('noname-banana-images-prod')
  .remove([tempFilePath]);
```

**Optional**: Add Supabase Storage lifecycle policy (if supported):
- Auto-delete files in `temp-processing/` older than 1 hour
- Check Supabase docs for TTL support

---

## Part 6: Deployment Steps

### Step 1: Create Edge Functions Locally

```bash
cd supabase/functions

# Create submit-job
supabase functions new submit-job

# Create check-status
supabase functions new check-status
```

### Step 2: Implement Functions

(Code implementation happens after plan approval)

### Step 3: Test Locally

```bash
# Start local Supabase
supabase start

# Serve functions locally
supabase functions serve

# Test submit-job
curl -X POST http://localhost:54321/functions/v1/submit-job \
  -H "Authorization: Bearer YOUR_ANON_KEY" \
  -H "Content-Type: application/json" \
  -d '{"image_url":"https://example.com/test.jpg","prompt":"test"}'

# Test check-status
curl -X POST http://localhost:54321/functions/v1/check-status \
  -H "Authorization: Bearer YOUR_ANON_KEY" \
  -H "Content-Type: application/json" \
  -d '{"job_id":"abc-123"}'
```

### Step 4: Deploy to Production

```bash
# Deploy submit-job
supabase functions deploy submit-job

# Deploy check-status
supabase functions deploy check-status

# Update process-image (add deprecation header)
supabase functions deploy process-image
```

### Step 5: Verify Deployment

```bash
# Test submit-job in production
curl -X POST https://YOUR_PROJECT.supabase.co/functions/v1/submit-job \
  -H "Authorization: Bearer YOUR_ANON_KEY" \
  -H "Content-Type: application/json" \
  -d '{"image_url":"https://example.com/test.jpg","prompt":"test"}'

# Check logs
supabase functions logs submit-job --follow
supabase functions logs check-status --follow
```

### Step 6: Monitor for 24 Hours

- Check error rate in Supabase Dashboard
- Verify Edge Function invocations
- Check for any crashes or timeouts
- Confirm old `process-image` still works (iOS not broken)

---

## Part 7: Error Handling Patterns

### Pattern 1: Credit Refund on Failure

**Use cases**:
- fal.ai submission fails
- Storage upload fails
- AI processing fails

**Implementation**:
```typescript
try {
  // Deduct credit
  await deductCredits();

  // Risky operation
  await submitToFalAI();

} catch (error) {
  // Refund credit
  await supabase.rpc('add_credits', {
    p_user_id: userId,
    p_device_id: deviceId,
    p_amount: 1,
    p_reason: 'submission_failed',
    p_idempotency_key: `refund-${requestId}`
  });

  throw error;
}
```

### Pattern 2: Graceful Degradation (Database Optional)

**Use case**: `job_history` table doesn't exist yet.

**Implementation**:
```typescript
try {
  await supabase.from('job_history').insert({ ... });
} catch (error) {
  // Log warning, but don't fail request
  console.warn('[DATABASE] job_history insert failed (optional):', error);
}
```

### Pattern 3: Idempotency

**Use case**: iOS retries same request after network error.

**Implementation**:
```typescript
// Generate or receive request_id
const requestId = body.request_id || crypto.randomUUID();

// Check if already processed
const existing = await db.query('SELECT * FROM credit_transactions WHERE idempotency_key = $1', [requestId]);
if (existing) {
  return { success: true, idempotent: true, ...existing };
}

// Process request...
```

### Pattern 4: Timeout Handling

**Use case**: fal.ai takes too long to respond.

**Implementation**:
```typescript
const controller = new AbortController();
const timeout = setTimeout(() => controller.abort(), 10000); // 10s

try {
  const response = await fetch(url, {
    signal: controller.signal,
    headers: { ... }
  });
  clearTimeout(timeout);
  return response;
} catch (error) {
  if (error.name === 'AbortError') {
    throw new Error('fal.ai request timeout');
  }
  throw error;
}
```

---

## Part 8: Monitoring & Logging

### Metrics to Track

**submit-job**:
- Invocation count (per hour)
- Error rate (%)
- Average execution time (ms)
- Credit deduction failures (count)
- fal.ai submission failures (count)

**check-status**:
- Invocation count (per hour)
- Error rate (%)
- Average execution time (ms)
- Jobs completed (count)
- Jobs failed (count)
- Average polls per job (number)

### Logging Standards

**Format**: Structured JSON with prefixes

```typescript
console.log('[SUBMIT-JOB] Job submitted:', { jobId, userId });
console.error('[SUBMIT-JOB] ERROR:', { error: error.message, userId });
console.warn('[SUBMIT-JOB] WARNING: Database unavailable');
```

**Prefix conventions**:
- `[SUBMIT-JOB]` - submit-job function
- `[CHECK-STATUS]` - check-status function
- `[CREDIT]` - credit operations
- `[FAL-AI]` - fal.ai API calls
- `[STORAGE]` - Supabase Storage operations
- `[DATABASE]` - Database operations (optional)

---

## Part 9: Rollback Procedure

### Scenario: Phase 1 deployment fails

**Symptoms**:
- New endpoints return 500 errors
- Credit deduction fails
- fal.ai submission fails

**Rollback steps**:

1. **Disable new endpoints** (via Supabase Dashboard):
   - Pause `submit-job` function
   - Pause `check-status` function

2. **Verify old endpoint works**:
   ```bash
   curl -X POST https://YOUR_PROJECT.supabase.co/functions/v1/process-image \
     -H "Authorization: Bearer YOUR_ANON_KEY" \
     -d '{"image_url":"...","prompt":"..."}'
   ```

3. **Investigate logs**:
   ```bash
   supabase functions logs submit-job --tail 100
   supabase functions logs check-status --tail 100
   ```

4. **Fix issues locally**:
   - Test with `supabase functions serve`
   - Verify fix works

5. **Re-deploy**:
   ```bash
   supabase functions deploy submit-job
   supabase functions deploy check-status
   ```

**Time to rollback**: 5-10 minutes

**Impact**: None (iOS still uses old endpoint)

---

## Part 10: Testing Checklist

### Local Testing (Before Deployment)

**submit-job**:
- [ ] Valid request returns job_id within 1 second
- [ ] Invalid auth returns 401
- [ ] Insufficient credits returns 402 with credit_info
- [ ] Invalid image returns 400
- [ ] fal.ai error refunds credit
- [ ] Premium user bypasses credit check

**check-status**:
- [ ] Job queued returns "queued" status
- [ ] Job processing returns "processing" status
- [ ] Job completed downloads + uploads + returns image_url
- [ ] Job failed refunds credit
- [ ] Invalid job_id returns 404

### Production Testing (After Deployment)

**Smoke tests**:
- [ ] Call submit-job → receives job_id
- [ ] Call check-status with job_id → receives status
- [ ] Wait 30 seconds → call check-status again → receives "completed"
- [ ] Verify image uploaded to Storage
- [ ] Verify credit balance decreased by 1
- [ ] Old process-image endpoint still works

**Load testing** (optional):
- [ ] Submit 10 jobs simultaneously → all succeed
- [ ] Submit 100 jobs over 5 minutes → all succeed

---

## Part 11: Security Considerations

### API Key Protection

**FAL_API_KEY must NEVER**:
- Be committed to git
- Be exposed in client-side code
- Be logged in console.log
- Be included in error messages

**Verify**:
```bash
# Check git history (should return nothing)
git log --all --full-history --source -- '*fal*api*key*'

# Check codebase (should return nothing)
grep -r "fal-ai-key-" supabase/functions/
```

### Input Validation

**Prompt validation**:
```typescript
if (!prompt || prompt.length < 1 || prompt.length > 500) {
  return new Response(
    JSON.stringify({ success: false, error: 'Invalid prompt length' }),
    { status: 400 }
  );
}
```

**Image URL validation**:
```typescript
try {
  new URL(imageUrl);
} catch {
  return new Response(
    JSON.stringify({ success: false, error: 'Invalid image URL' }),
    { status: 400 }
  );
}
```

### Rate Limiting

**Supabase Edge Functions**: Built-in rate limiting (no action needed)

**fal.ai API**: 100 requests/minute (per their docs)
- If exceeded: iOS will get 429 error
- iOS should retry with exponential backoff

---

## Part 12: Performance Optimization

### Image Compression (Optional)

Before uploading to temp storage:
```typescript
// Compress image if > 5MB
if (imageData.length > 5_000_000) {
  imageData = await compressImage(imageData, { quality: 0.8 });
}
```

### Parallel Operations

In `check-status`, after job completes:
```typescript
// Download + Upload + Delete in parallel
const [downloadedImage] = await Promise.all([
  fetchImage(falImageUrl),
  // Don't wait for delete
  deleteOldTempImage(tempPath).catch(err => console.warn(err))
]);
```

### Caching (Optional)

Cache `check-status` responses for 30 seconds:
```typescript
const cacheKey = `status-${jobId}`;
const cached = await redis.get(cacheKey);
if (cached) return JSON.parse(cached);

// ... fetch from fal.ai ...

await redis.set(cacheKey, JSON.stringify(result), { ex: 30 });
```

**Note**: Requires Redis setup (may be overkill for BananaUniverse).

---

## Part 13: Documentation Updates

After Phase 1 completion, update:

### API_REFERENCE.md

Add new endpoints:

**POST /functions/v1/submit-job**
```
Request:
{
  "image_url": "string",
  "prompt": "string",
  "device_id": "string" (optional)
}

Response:
{
  "success": true,
  "job_id": "string",
  "status": "queued",
  "credit_info": { ... }
}
```

**POST /functions/v1/check-status**
```
Request:
{
  "job_id": "string"
}

Response (processing):
{
  "success": true,
  "status": "processing",
  "queue_position": number | null
}

Response (completed):
{
  "success": true,
  "status": "completed",
  "image_url": "string"
}
```

### BACKEND_ARCHITECTURE.md

Add section:
```markdown
## Async Job Processing

BananaUniverse uses a two-step polling architecture:

1. Submit job → fal.ai async queue → return job_id
2. Poll status → check fal.ai → download result when ready

Benefits:
- Fast response times (< 2s per request)
- Scales to 100+ concurrent users
- iOS controls retry logic
```

---

## Summary

**Phase 1 Deliverables**:
- ✅ `submit-job` Edge Function deployed
- ✅ `check-status` Edge Function deployed
- ✅ `process-image` deprecated (functional)
- ✅ Environment variables configured
- ✅ Storage bucket structure defined
- ✅ Monitoring dashboards set up

**Ready for Phase 2**: iOS client migration.

---

**Document Version**: 1.0
**Last Updated**: 2025-11-13
**Owner**: Backend Team
