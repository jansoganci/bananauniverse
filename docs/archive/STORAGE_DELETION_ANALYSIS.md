# Supabase Storage Image Deletion Analysis

**Date:** 2025-01-27  
**Purpose:** Comprehensive analysis before implementing automated image deletion cron job

---

## 📊 Executive Summary

**Current State:**
- **Single Bucket:** `noname-banana-images-prod`
- **Two Folder Paths:** `uploads/` (user uploads) and `processed/` (fal.ai results)
- **Database References:** `job_results` table stores signed URLs
- **Existing Cleanup:** `cleanup-images` function exists but references deprecated `jobs` table

**Recommendation:**
- Delete images older than **7 days** (completed/failed jobs)
- Delete images older than **24 hours** (pending jobs that never completed)
- Use `job_results` table as source of truth
- Implement batch deletion with audit logging
- Run weekly (Sunday 02:00 UTC) via GitHub Actions

---

## 1. Storage Buckets & Folder Paths

### Bucket Structure

```
noname-banana-images-prod/
├── uploads/
│   └── {userOrDeviceID}/
│       └── {UUID}.jpg          # User-uploaded images
└── processed/
    └── {request_id}.jpg        # fal.ai processed results
```

### Exact Paths

**User Uploads:**
- **Path Pattern:** `uploads/{userOrDeviceID}/{filename}`
- **Example:** `uploads/550e8400-e29b-41d4-a716-446655440000/abc123.jpg`
- **Source:** `BananaUniverse/Core/Services/SupabaseService.swift:70`
- **Bucket:** `noname-banana-images-prod` (from `Config.swift:34`)

**fal.ai Processed Images:**
- **Path Pattern:** `processed/{request_id}.jpg`
- **Example:** `processed/fal-abc123-def456.jpg`
- **Source:** `supabase/functions/webhook-handler/index.ts:438`
- **Bucket:** `noname-banana-images-prod`

### Code References

```70:70:BananaUniverse/Core/Services/SupabaseService.swift
let path = "uploads/\(userOrDeviceID)/\(finalFileName)"
```

```437:438:supabase/functions/webhook-handler/index.ts
const bucketName = 'noname-banana-images-prod';
const fileName = `processed/${request_id}.jpg`;
```

---

## 2. Image References & Database Links

### Database Schema

**Table:** `job_results` (from `supabase/migrations/054_create_job_results_webhook.sql`)

```sql
CREATE TABLE public.job_results (
    fal_job_id TEXT PRIMARY KEY,
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    device_id TEXT,
    status TEXT NOT NULL,  -- pending | completed | failed
    image_url TEXT,        -- Signed URL to processed image
    error TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    completed_at TIMESTAMPTZ,
    CHECK (status IN ('pending', 'completed', 'failed'))
);
```

### How Images Are Referenced

1. **User Uploads:**
   - Stored in `uploads/{userOrDeviceID}/{filename}`
   - **NOT directly referenced in database** (only via `submit-job` request)
   - Original image URL passed to fal.ai, then can be deleted after processing

2. **Processed Images:**
   - Stored in `processed/{request_id}.jpg`
   - **Referenced in `job_results.image_url`** (signed URL, 7-day expiry)
   - `fal_job_id` = `request_id` (used as filename)

### Critical Dependencies

**⚠️ IMPORTANT:**
- `job_results.image_url` contains **signed URLs** (7-day expiry from `webhook-handler/index.ts:484`)
- After 7 days, signed URLs expire, but files may still exist in storage
- **No direct path mapping** - need to reconstruct path from `fal_job_id`
- User uploads are **not tracked in database** - need to infer from `job_results` or delete orphaned files

---

## 3. Database Dependencies & Updates

### What Needs to Be Checked Before Deletion

1. **Job Status:**
   - Only delete if `status IN ('completed', 'failed')`
   - **Never delete** if `status = 'pending'` (unless older than 24 hours)

2. **Job Age:**
   - Completed/Failed: Delete if `completed_at < NOW() - INTERVAL '7 days'`
   - Pending: Delete if `created_at < NOW() - INTERVAL '24 hours'` (stuck jobs)

3. **User Uploads:**
   - **No database record** - need to check if `fal_job_id` exists in `job_results`
   - Or delete orphaned files in `uploads/` older than 7 days

### Database Updates Required

**After deletion, update:**
```sql
UPDATE job_results 
SET image_url = NULL 
WHERE fal_job_id = $1;
```

**⚠️ RISK:** If `image_url` is NULL, iOS app may show broken image links.

**Recommendation:** Keep `image_url` in database (for audit), but mark as deleted:
```sql
ALTER TABLE job_results ADD COLUMN image_deleted_at TIMESTAMPTZ;
```

---

## 4. Deletion Strategy: Age-Based vs Complete Deletion

### Recommended Approach: **Age-Based Deletion**

**Rationale:**
- Prevents accidental deletion of active user images
- Allows users to access recent results
- Reduces storage costs while maintaining functionality

### Retention Policy

| Job Status | Retention Period | Rationale |
|------------|------------------|------------|
| `completed` | 7 days | Users may want to download/share results |
| `failed` | 7 days | Allow time for debugging/retry |
| `pending` | 24 hours | Stuck jobs should be cleaned up |

### Alternative: Complete Deletion (NOT RECOMMENDED)

**Risks:**
- Breaks active user sessions
- Removes images users may want to download
- No recovery mechanism
- Violates user expectations

**Only use if:**
- Complete system reset
- Migration to new storage
- Explicit user request

---

## 5. Authorization & Permissions

### Current Storage Policies

**From `supabase/migrations/004_fix_processed_images_policies.sql`:**

```sql
-- Service role full access to uploads directory
CREATE POLICY "Service role full access uploads"
ON storage.objects FOR ALL
TO service_role
USING (
    bucket_id = 'noname-banana-images-prod' AND
    name LIKE 'uploads/%'
);

-- Service role full access to processed directory
CREATE POLICY "Service role full access processed"
ON storage.objects FOR ALL
TO service_role
USING (
    bucket_id = 'noname-banana-images-prod' AND
    name LIKE 'processed/%'
);
```

### Required Permissions for Cron Job

**Edge Function:**
- Must use `SUPABASE_SERVICE_ROLE_KEY` (full access)
- Must authenticate with `CLEANUP_API_KEY` header

**GitHub Actions:**
- Must have `SUPABASE_SERVICE_ROLE_KEY` secret
- Must have `CLEANUP_API_KEY` secret

**✅ Current Setup:** Already configured (from `cleanup-images/index.ts:59-60`)

---

## 6. Safety Measures: Preventing Accidental Deletion

### Protection Mechanisms

1. **Age-Based Filtering:**
   ```typescript
   // Only delete jobs older than retention period
   const cutoffDate = new Date(Date.now() - 7 * 24 * 60 * 60 * 1000);
   ```

2. **Status Validation:**
   ```typescript
   // Never delete pending jobs (unless stuck > 24h)
   if (status === 'pending' && age < 24h) {
     skip();
   }
   ```

3. **Database Verification:**
   ```typescript
   // Verify job exists in database before deletion
   const job = await supabase
     .from('job_results')
     .select('fal_job_id, status, completed_at')
     .eq('fal_job_id', requestId)
     .single();
   ```

4. **Dry-Run Mode:**
   ```typescript
   // Add dry-run flag for testing
   const DRY_RUN = Deno.env.get('DRY_RUN') === 'true';
   if (DRY_RUN) {
     console.log('🔍 [DRY-RUN] Would delete:', filePath);
     return;
   }
   ```

5. **Batch Size Limits:**
   ```typescript
   // Process in small batches to avoid timeouts
   const BATCH_SIZE = 50; // Delete 50 files at a time
   ```

6. **Error Handling:**
   ```typescript
   // Stop on critical errors, continue on individual failures
   try {
     await deleteFile(filePath);
   } catch (error) {
     errors.push(`Failed to delete ${filePath}: ${error.message}`);
     // Continue with next file
   }
   ```

### Premium User Protection (DISABLED)

**Note:** User stated they removed premium features. No special handling needed.

**If premium features return:**
```typescript
// Check subscription status
const isPremium = await checkSubscriptionStatus(userId);
if (isPremium) {
  // Extended retention (30 days)
  retentionDays = 30;
}
```

---

## 7. Audit Trail & Logging

### Required Logging

**Database Table:** `cleanup_logs` (already exists from `cleanup-images`)

**Log Structure:**
```typescript
interface DeletionLog {
  operation: 'cleanup_storage_images';
  details: {
    processed_deleted: number;
    uploads_deleted: number;
    orphaned_deleted: number;
    total_files_deleted: number;
    total_storage_freed_mb: number;
    errors: string[];
    execution_time_ms: number;
    deleted_files: Array<{
      path: string;
      fal_job_id: string | null;
      age_days: number;
      size_bytes: number;
    }>;
  };
  created_at: TIMESTAMPTZ;
}
```

### What to Log

1. **Per-File Deletion:**
   - File path
   - Associated `fal_job_id` (if known)
   - File size
   - Age (days)
   - Deletion timestamp

2. **Summary Statistics:**
   - Total files deleted
   - Total storage freed (MB/GB)
   - Errors encountered
   - Execution time

3. **Error Details:**
   - File path
   - Error message
   - Retry attempts

### Log Retention

- Keep logs for **90 days** (same as `cleanup_logs` retention)
- Archive old logs to cold storage (optional)

---

## 8. Edge Cases & Special Considerations

### Large Files

**Issue:** Large images may timeout during deletion

**Solution:**
```typescript
// Increase timeout for large files
const deleteOptions = {
  timeout: 30000, // 30 seconds
};

// Process large files separately
if (fileSize > 10 * 1024 * 1024) { // > 10MB
  await deleteLargeFile(filePath, deleteOptions);
}
```

### Multiple Buckets

**Current:** Single bucket `noname-banana-images-prod`

**Future-Proofing:**
```typescript
const BUCKETS = ['noname-banana-images-prod'];
// Easy to extend: const BUCKETS = ['bucket1', 'bucket2'];
```

### Non-Image Files

**Current:** Only `.jpg` files expected

**Safety Check:**
```typescript
// Only delete image files
const imageExtensions = ['.jpg', '.jpeg', '.png', '.webp'];
const isImage = imageExtensions.some(ext => 
  filePath.toLowerCase().endsWith(ext)
);

if (!isImage) {
  console.warn(`⚠️ Skipping non-image file: ${filePath}`);
  return;
}
```

### Orphaned Files

**Issue:** Files in storage without database records

**Detection:**
```typescript
// List all files in storage
const { data: allFiles } = await supabase.storage
  .from('noname-banana-images-prod')
  .list('processed', { limit: 1000 });

// Check if fal_job_id exists in job_results
for (const file of allFiles) {
  const requestId = file.name.replace('.jpg', '');
  const { data: job } = await supabase
    .from('job_results')
    .select('fal_job_id')
    .eq('fal_job_id', requestId)
    .single();
  
  if (!job) {
    // Orphaned file - delete if older than 7 days
    if (file.created_at < cutoffDate) {
      await deleteOrphanedFile(file.name);
    }
  }
}
```

### Concurrent Deletions

**Issue:** Multiple cleanup jobs running simultaneously

**Solution:**
```typescript
// Use database lock or distributed lock
const lockKey = 'storage_cleanup_lock';
const lock = await acquireLock(lockKey, 3600); // 1 hour

if (!lock) {
  console.log('⚠️ Another cleanup job is running, skipping...');
  return;
}

try {
  // Perform cleanup
} finally {
  await releaseLock(lockKey);
}
```

---

## 9. Impact on Application

### UI Impact

**iOS App (`get-result` API):**
- Returns `image_url` (signed URL) from `job_results`
- If image deleted but URL still in DB: **404 error** (broken image)
- If image deleted and URL set to NULL: **No image shown**

**Recommendation:**
```typescript
// Update job_results after deletion
UPDATE job_results 
SET image_url = NULL,
    image_deleted_at = NOW()
WHERE fal_job_id = $1;
```

**UI Handling:**
```swift
// iOS should handle NULL image_url gracefully
if let imageUrl = result.image_url {
    // Show image
} else {
    // Show "Image expired" message
}
```

### API Impact

**`get-result` Edge Function:**
- Currently returns `image_url` from database
- If deleted: Returns `image_url: null`
- **No breaking change** - client should handle null

**`webhook-handler`:**
- Uploads new images to `processed/`
- **No impact** - new uploads unaffected

### Broken Links

**Risk:** Signed URLs expire after 7 days, but files may exist longer

**Mitigation:**
- Delete files when signed URLs expire (7 days)
- Or delete files when `completed_at` is older than 7 days

---

## 10. Best Practices & Recommendations

### Deletion Strategy

1. **Batch Processing:**
   ```typescript
   const BATCH_SIZE = 50; // Delete 50 files per batch
   const BATCH_DELAY = 1000; // 1 second between batches
   ```

2. **Error Handling:**
   ```typescript
   // Continue on individual failures, stop on critical errors
   const errors: string[] = [];
   for (const file of files) {
     try {
       await deleteFile(file);
     } catch (error) {
       errors.push(`${file}: ${error.message}`);
       // Continue with next file
     }
   }
   ```

3. **Retry Logic:**
   ```typescript
   const MAX_RETRIES = 3;
   for (let attempt = 1; attempt <= MAX_RETRIES; attempt++) {
     try {
       await deleteFile(file);
       break; // Success
     } catch (error) {
       if (attempt === MAX_RETRIES) throw error;
       await sleep(1000 * attempt); // Exponential backoff
     }
   }
   ```

4. **Notifications:**
   ```typescript
   // Send summary to Telegram/Slack
   const summary = {
     files_deleted: count,
     storage_freed_mb: freedMB,
     errors: errors.length,
   };
   await sendNotification(summary);
   ```

### Performance Optimization

1. **Parallel Deletions:**
   ```typescript
   // Delete multiple files in parallel (with limit)
   const CONCURRENT_DELETIONS = 10;
   const chunks = chunkArray(files, CONCURRENT_DELETIONS);
   for (const chunk of chunks) {
     await Promise.all(chunk.map(file => deleteFile(file)));
   }
   ```

2. **Database Query Optimization:**
   ```sql
   -- Use indexed columns for fast lookups
   SELECT fal_job_id, status, completed_at
   FROM job_results
   WHERE status IN ('completed', 'failed')
     AND completed_at < NOW() - INTERVAL '7 days'
   ORDER BY completed_at ASC
   LIMIT 1000;
   ```

3. **Storage List Optimization:**
   ```typescript
   // List files in batches to avoid memory issues
   const listOptions = {
     limit: 1000,
     offset: 0,
     sortBy: { column: 'created_at', order: 'asc' }
   };
   ```

---

## 11. Recommended Cron Schedule

### Frequency & Timing

**Recommended:** **Weekly (Sunday 02:00 UTC)**

**Rationale:**
- Low traffic time (Sunday morning)
- Weekly cleanup sufficient for 7-day retention
- Avoids peak usage hours
- Allows manual intervention if needed

### Alternative Schedules

| Frequency | Time | Pros | Cons |
|-----------|------|------|------|
| Daily | 02:00 UTC | More frequent cleanup | Higher cost, more load |
| Weekly | Sunday 02:00 UTC | Balanced | May accumulate more files |
| Monthly | 1st 02:00 UTC | Lowest cost | Long retention needed |

### GitHub Actions Schedule

```yaml
on:
  schedule:
    - cron: '0 2 * * 0'  # Every Sunday at 02:00 UTC
  workflow_dispatch:      # Manual trigger
```

---

## 12. Implementation Outline

### Edge Function: `cleanup-storage-images`

**Location:** `supabase/functions/cleanup-storage-images/index.ts`

**Flow:**
1. Authenticate request (service role + API key)
2. Fetch eligible jobs from `job_results`:
   - Completed/Failed: `completed_at < NOW() - 7 days`
   - Pending: `created_at < NOW() - 24 hours`
3. Extract file paths:
   - Processed: `processed/{fal_job_id}.jpg`
   - Uploads: Need to infer from job history (or delete orphaned)
4. Delete files in batches (50 files/batch)
5. Update database:
   - Set `image_url = NULL` (optional)
   - Set `image_deleted_at = NOW()` (if column exists)
6. Log results to `cleanup_logs`
7. Send notification (Telegram/Slack)

**Helper Functions:**
- `fetchEligibleJobs()` - Query `job_results` for old jobs
- `extractStoragePaths()` - Convert `fal_job_id` to file paths
- `deleteFilesInBatches()` - Batch deletion with retry
- `updateJobResults()` - Mark images as deleted in DB
- `logDeletionResults()` - Audit logging
- `sendNotification()` - Alert on completion

### GitHub Actions Workflow

**Location:** `.github/workflows/cleanup-storage.yml`

**Configuration:**
```yaml
name: Storage Image Cleanup (Weekly)

on:
  schedule:
    - cron: '0 2 * * 0'  # Sunday 02:00 UTC
  workflow_dispatch:

env:
  SUPABASE_URL: ${{ secrets.SUPABASE_URL }}
  SUPABASE_SERVICE_ROLE_KEY: ${{ secrets.SUPABASE_SERVICE_ROLE_KEY }}
  CLEANUP_API_KEY: ${{ secrets.CLEANUP_API_KEY }}

jobs:
  cleanup:
    runs-on: ubuntu-latest
    steps:
      - name: Run Storage Cleanup
        run: |
          curl -X POST "${{ env.SUPABASE_URL }}/functions/v1/cleanup-storage-images" \
            -H "Authorization: Bearer ${{ env.SUPABASE_SERVICE_ROLE_KEY }}" \
            -H "x-api-key: ${{ env.CLEANUP_API_KEY }}" \
            -H "Content-Type: application/json" \
            --max-time 600
```

---

## 13. Risk Assessment

### High Risk

1. **Accidental Deletion of Active Images**
   - **Mitigation:** Age-based filtering (7 days), status validation
   - **Impact:** Users lose access to recent results

2. **Database-Storage Mismatch**
   - **Mitigation:** Verify job exists before deletion, update DB after deletion
   - **Impact:** Orphaned files or broken links

### Medium Risk

1. **Large File Timeouts**
   - **Mitigation:** Increase timeout, process large files separately
   - **Impact:** Some files not deleted, requires manual cleanup

2. **Concurrent Execution**
   - **Mitigation:** Distributed lock, skip if another job running
   - **Impact:** Duplicate deletions, wasted resources

### Low Risk

1. **Non-Image Files**
   - **Mitigation:** File extension validation
   - **Impact:** Unnecessary files remain in storage

2. **Notification Failures**
   - **Mitigation:** Log to database, continue on notification error
   - **Impact:** No visibility into cleanup results

---

## 14. Testing Strategy

### Pre-Production Testing

1. **Dry-Run Mode:**
   ```typescript
   const DRY_RUN = true;
   // Log what would be deleted without actually deleting
   ```

2. **Small Batch Test:**
   ```typescript
   // Test with 10 files first
   const TEST_BATCH_SIZE = 10;
   ```

3. **Manual Verification:**
   ```sql
   -- Check which files would be deleted
   SELECT fal_job_id, status, completed_at,
          NOW() - completed_at as age
   FROM job_results
   WHERE status IN ('completed', 'failed')
     AND completed_at < NOW() - INTERVAL '7 days'
   LIMIT 10;
   ```

### Production Rollout

1. **Phase 1:** Dry-run for 1 week (log only)
2. **Phase 2:** Delete 10 files per run (manual verification)
3. **Phase 3:** Full batch deletion (50 files/batch)
4. **Phase 4:** Increase batch size if stable (100 files/batch)

---

## 15. Summary & Next Steps

### Key Findings

✅ **Single bucket:** `noname-banana-images-prod`  
✅ **Two folders:** `uploads/` and `processed/`  
✅ **Database tracking:** `job_results` table  
✅ **Existing cleanup:** Function exists but needs update  
✅ **Permissions:** Service role access configured  

### Recommended Approach

1. **Create new Edge Function:** `cleanup-storage-images`
2. **Update to use `job_results` table** (not deprecated `jobs` table)
3. **Implement age-based deletion:** 7 days (completed/failed), 24 hours (pending)
4. **Add audit logging:** Log all deletions to `cleanup_logs`
5. **Schedule weekly:** Sunday 02:00 UTC via GitHub Actions
6. **Test thoroughly:** Dry-run mode, small batches, manual verification

### Implementation Priority

1. **High:** Core deletion logic, database updates, error handling
2. **Medium:** Audit logging, notifications, batch processing
3. **Low:** Orphaned file detection, premium user handling (if needed)

---

**Next Step:** Review this analysis and approve implementation approach.

