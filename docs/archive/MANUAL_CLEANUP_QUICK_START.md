# Manual Storage Cleanup - Quick Start

**Edge Function:** `cleanup-images`  
**Deletes:** All images older than 24 hours  
**Trigger:** Manual only (no scheduling)

---

## 🚀 Quick Commands

### 1. Deploy Function

```bash
cd supabase/functions
supabase functions deploy cleanup-images
```

### 2. Test (Dry-Run)

```bash
curl -X POST "https://jiorfutbmahpfgplkats.supabase.co/functions/v1/cleanup-images?dry_run=true" \
  -H "Authorization: Bearer YOUR_SERVICE_ROLE_KEY" \
  -H "x-api-key: YOUR_CLEANUP_API_KEY"
```

### 3. Run Actual Deletion

```bash
curl -X POST "https://jiorfutbmahpfgplkats.supabase.co/functions/v1/cleanup-images" \
  -H "Authorization: Bearer YOUR_SERVICE_ROLE_KEY" \
  -H "x-api-key: YOUR_CLEANUP_API_KEY"
```

---

## 📋 What It Does

- ✅ Lists all files in `uploads/` and `processed/` folders
- ✅ Deletes files older than 24 hours
- ✅ Skips files < 24 hours old
- ✅ Logs all deletions to `cleanup_logs` table
- ✅ Supports dry-run mode (`?dry_run=true`)

---

## ⚠️ Safety Warning

**This will delete ALL images older than 24 hours, including:**
- Recent user uploads
- Completed job results
- Failed job results

**Impact:**
- Users may lose access to images they uploaded recently
- iOS app may show broken image links if `image_url` still in database

**Recommendation:** Always run dry-run first to preview what will be deleted.

---

## 📊 Check Results

```sql
-- View latest cleanup log
SELECT 
  details->>'files_deleted' as deleted,
  details->>'files_skipped' as skipped,
  details->>'total_storage_freed_mb' as freed_mb,
  details->>'dry_run' as was_dry_run,
  created_at
FROM cleanup_logs
WHERE operation = 'cleanup_images'
ORDER BY created_at DESC
LIMIT 1;
```

---

**Full Guide:** See `docs/MANUAL_STORAGE_CLEANUP_GUIDE.md`

