# Manual Storage Cleanup Guide

**Edge Function:** `cleanup-images`  
**Purpose:** Delete all images older than 24 hours from Supabase Storage  
**Trigger:** Manual only (no scheduling)

---

## 🎯 Overview

This Edge Function deletes **ALL images** from both `uploads/` and `processed/` folders that are older than **24 hours**, regardless of job status.

**Key Features:**
- ✅ Simple 24-hour rule (no complex status logic)
- ✅ Manual trigger only (no cron/scheduling)
- ✅ Dry-run mode for preview
- ✅ Database audit logging
- ✅ Handles both folders automatically

---

## ⚠️ Safety Considerations

### Potential Issues

1. **Active User Sessions:**
   - Users may lose access to images they uploaded < 24 hours ago
   - Signed URLs expire after 7 days, but files may be deleted earlier

2. **Recent Job Results:**
   - Completed jobs < 24 hours old will have their images deleted
   - iOS app may show broken image links if `image_url` still in database

3. **No Recovery:**
   - Deleted files cannot be recovered
   - No backup mechanism

### Safer Alternatives

If you want to avoid breaking active sessions:

1. **Increase retention to 7 days:**
   ```typescript
   const retentionHours = 168; // 7 days
   ```

2. **Check job status before deletion:**
   ```typescript
   // Only delete if job is completed/failed AND older than 24h
   if (job.status === 'pending') {
     skip(); // Keep pending jobs
   }
   ```

3. **Keep recent user uploads:**
   ```typescript
   // Don't delete uploads/ folder, only processed/
   const folders = ['processed']; // Skip uploads/
   ```

**Current Implementation:** Deletes everything > 24 hours (as requested)

---

## 🚀 Usage

### 1. Deploy the Edge Function

```bash
cd supabase/functions
supabase functions deploy cleanup-images
```

### 2. Run Dry-Run (Preview)

**Test what would be deleted without actually deleting:**

```bash
curl -X POST "https://jiorfutbmahpfgplkats.supabase.co/functions/v1/cleanup-images?dry_run=true" \
  -H "Authorization: Bearer YOUR_SERVICE_ROLE_KEY" \
  -H "x-api-key: YOUR_CLEANUP_API_KEY" \
  -H "Content-Type: application/json"
```

**Response:**
```json
{
  "files_deleted": 0,
  "files_skipped": 5,
  "total_storage_freed_mb": 0,
  "errors": [],
  "deleted_files": [
    {
      "path": "processed/fal-abc123.jpg",
      "folder": "processed",
      "age_hours": 25.3,
      "size_bytes": 1048576,
      "deleted_at": "2025-01-27T10:00:00Z"
    }
  ],
  "skipped_files": [
    {
      "path": "uploads/user123/image.jpg",
      "folder": "uploads",
      "age_hours": 12.5,
      "reason": "File is less than 24 hours old"
    }
  ],
  "execution_time_ms": 1234,
  "dry_run": true
}
```

### 3. Run Actual Deletion

**Remove `?dry_run=true` to actually delete files:**

```bash
curl -X POST "https://jiorfutbmahpfgplkats.supabase.co/functions/v1/cleanup-images" \
  -H "Authorization: Bearer YOUR_SERVICE_ROLE_KEY" \
  -H "x-api-key: YOUR_CLEANUP_API_KEY" \
  -H "Content-Type: application/json"
```

**Response:**
```json
{
  "files_deleted": 15,
  "files_skipped": 5,
  "total_storage_freed_mb": 45.67,
  "errors": [],
  "deleted_files": [...],
  "skipped_files": [...],
  "execution_time_ms": 5678,
  "dry_run": false
}
```

---

## 📊 Database Logging

All cleanup operations are logged to `cleanup_logs` table:

```sql
SELECT 
  operation,
  details->>'files_deleted' as files_deleted,
  details->>'total_storage_freed_mb' as storage_freed_mb,
  details->>'dry_run' as was_dry_run,
  created_at
FROM cleanup_logs
WHERE operation = 'cleanup_images'
ORDER BY created_at DESC
LIMIT 10;
```

**View deleted files:**
```sql
SELECT 
  details->'deleted_files' as deleted_files
FROM cleanup_logs
WHERE operation = 'cleanup_images'
  AND created_at > NOW() - INTERVAL '1 day'
ORDER BY created_at DESC
LIMIT 1;
```

---

## 🔧 Configuration

### Environment Variables

Required in Supabase Dashboard → Edge Functions → `cleanup-images`:

- `SUPABASE_URL` - Your Supabase project URL
- `SUPABASE_SERVICE_ROLE_KEY` - Service role key (for storage access)
- `CLEANUP_API_KEY` - Custom API key for authentication (optional but recommended)

### Retention Period

**Current:** 24 hours (hardcoded)

**To change:** Edit `supabase/functions/cleanup-images/index.ts`:

```typescript
const retentionHours = 24; // Change this value
```

### Folders Processed

**Current:** `uploads/` and `processed/`

**To change:** Edit the `folders` array:

```typescript
const folders = ['uploads', 'processed']; // Add/remove folders
```

---

## 📝 How It Works

### 1. Authentication
- Checks `Authorization: Bearer` header (service role key)
- Checks `x-api-key` header (optional `CLEANUP_API_KEY`)

### 2. Dry-Run Check
- Checks `?dry_run=true` query parameter
- Or `DRY_RUN=true` environment variable

### 3. File Listing
- Recursively lists all files in `uploads/` and `processed/`
- Gets file metadata (created_at, updated_at, size)

### 4. Age Check
- Calculates file age: `(now - file.updated_at) / (1000 * 60 * 60)` hours
- If age > 24 hours: Delete (or log in dry-run)
- If age < 24 hours: Skip

### 5. Deletion
- Uses `supabase.storage.from(bucket).remove([path])`
- Logs each deletion to result array

### 6. Database Logging
- Inserts summary to `cleanup_logs` table
- Includes all deleted files, skipped files, errors

---

## 🧪 Testing

### Step 1: Dry-Run Test

```bash
# Preview what would be deleted
curl -X POST "YOUR_URL/functions/v1/cleanup-images?dry_run=true" \
  -H "Authorization: Bearer $SERVICE_ROLE_KEY" \
  -H "x-api-key: $CLEANUP_API_KEY"
```

**Check output:**
- `deleted_files` array shows what would be deleted
- `skipped_files` array shows what would be kept
- `dry_run: true` confirms no actual deletion

### Step 2: Verify Files in Storage

```sql
-- Check how many files exist in storage (approximate)
SELECT COUNT(*) 
FROM storage.objects 
WHERE bucket_id = 'noname-banana-images-prod';
```

### Step 3: Run Actual Deletion

```bash
# Remove ?dry_run=true to actually delete
curl -X POST "YOUR_URL/functions/v1/cleanup-images" \
  -H "Authorization: Bearer $SERVICE_ROLE_KEY" \
  -H "x-api-key: $CLEANUP_API_KEY"
```

### Step 4: Verify Deletion

```sql
-- Check cleanup log
SELECT 
  details->>'files_deleted' as deleted,
  details->>'files_skipped' as skipped,
  created_at
FROM cleanup_logs
WHERE operation = 'cleanup_images'
ORDER BY created_at DESC
LIMIT 1;
```

---

## ⚡ Performance

**Expected Performance:**
- **Small bucket (< 100 files):** ~1-2 seconds
- **Medium bucket (100-1000 files):** ~5-10 seconds
- **Large bucket (1000+ files):** ~30-60 seconds

**Limitations:**
- Supabase Storage `list()` returns max 1000 items per call
- Large folders may need pagination (not implemented)
- Deletion is sequential (not parallel) to avoid rate limits

**Optimization Tips:**
- Run during low-traffic hours
- Use dry-run first to estimate time
- Monitor execution time in logs

---

## 🚨 Error Handling

**Common Errors:**

1. **"Missing authorization header"**
   - Solution: Add `Authorization: Bearer YOUR_KEY` header

2. **"Unauthorized - Invalid API key"**
   - Solution: Set `CLEANUP_API_KEY` env var or provide `x-api-key` header

3. **"Failed to delete {path}"**
   - Solution: File may not exist or permission issue
   - Check storage policies in Supabase Dashboard

4. **"Error listing {folder}"**
   - Solution: Folder may not exist or permission issue
   - Check bucket name and folder paths

**Error Recovery:**
- Individual file errors don't stop the cleanup
- All errors are logged in `errors` array
- Check `cleanup_logs` table for details

---

## 📋 Summary

**What it does:**
- ✅ Lists all files in `uploads/` and `processed/`
- ✅ Deletes files older than 24 hours
- ✅ Skips files < 24 hours old
- ✅ Logs all deletions to database
- ✅ Supports dry-run mode

**What it doesn't do:**
- ❌ No scheduled automation (manual only)
- ❌ No job status checking (deletes everything > 24h)
- ❌ No recovery mechanism (deleted files are gone)
- ❌ No backup before deletion

**Use when:**
- You want to free up storage space quickly
- You don't need to preserve recent images
- You can accept breaking some active user sessions

**Don't use when:**
- Users are actively viewing recent images
- You need to preserve images for > 24 hours
- You want to keep pending job images

---

**Last Updated:** 2025-01-27

