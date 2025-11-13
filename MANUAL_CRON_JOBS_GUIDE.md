# Manual Cron Jobs Guide

**Purpose:** How to manually trigger all cleanup and monitoring jobs  
**Last Updated:** 2025-01-27

---

## 📋 Overview

You have **3 jobs** that can be run manually:

1. **`cleanup-db`** - Database cleanup (deletes old records)
2. **`monitoring-cron`** - Monitoring jobs (health-check, log-monitor, log-alert)
3. **`cleanup-images`** - Image cleanup (deletes old storage files)

---

## 🗄️ 1. Database Cleanup (`cleanup-db`)

### What It Does
- Deletes old job records
- Cleans up rate limiting data
- Removes old logs
- Deletes old idempotency keys

### Method 1: GitHub Actions (Recommended)

**Via GitHub UI:**
1. Go to your repository on GitHub
2. Click **Actions** tab
3. Find **"Database Cleanup (Monthly)"** workflow
4. Click **"Run workflow"** button
5. Select branch (usually `main` or `master`)
6. Click **"Run workflow"**

**Via GitHub CLI:**
```bash
gh workflow run cleanup-db.yml
```

**Via API/curl:**
```bash
curl -X POST \
  -H "Accept: application/vnd.github.v3+json" \
  -H "Authorization: token YOUR_GITHUB_TOKEN" \
  https://api.github.com/repos/YOUR_USERNAME/YOUR_REPO/actions/workflows/cleanup-db.yml/dispatches \
  -d '{"ref":"main"}'
```

### Method 2: Direct Edge Function Call

```bash
curl -X POST "https://jiorfutbmahpfgplkats.supabase.co/functions/v1/cleanup-db" \
  -H "Authorization: Bearer YOUR_SERVICE_ROLE_KEY" \
  -H "x-api-key: YOUR_CLEANUP_API_KEY" \
  -H "Content-Type: application/json"
```

**Response:**
```json
{
  "jobsDeleted": 150,
  "rateLimitDeleted": 200,
  "logsDeleted": 500,
  "quotaLogsDeleted": 100,
  "quotaRecordsDeleted": 50,
  "idempotencyKeysDeleted": 1000,
  "errors": [],
  "executionTime": 5000
}
```

---

## 📊 2. Monitoring Jobs (`monitoring-cron`)

### What It Does
- **health-check** - Checks system health
- **log-monitor** - Monitors log files
- **log-alert** - Sends alerts for errors

### Method 1: GitHub Actions (Recommended)

**Via GitHub UI:**
1. Go to **Actions** tab
2. Find **"Monitoring Cron Jobs"** workflow
3. Click **"Run workflow"** button
4. Select **job_type**:
   - `all` - Run all monitoring jobs
   - `health-check` - Only health check
   - `log-monitor` - Only log monitor
   - `log-alert` - Only log alert
5. Click **"Run workflow"**

**Via GitHub CLI:**
```bash
# Run all jobs
gh workflow run monitoring-cron.yml -f job_type=all

# Run only health-check
gh workflow run monitoring-cron.yml -f job_type=health-check

# Run only log-monitor
gh workflow run monitoring-cron.yml -f job_type=log-monitor

# Run only log-alert
gh workflow run monitoring-cron.yml -f job_type=log-alert
```

**Via API/curl:**
```bash
# Run all jobs
curl -X POST \
  -H "Accept: application/vnd.github.v3+json" \
  -H "Authorization: token YOUR_GITHUB_TOKEN" \
  https://api.github.com/repos/YOUR_USERNAME/YOUR_REPO/actions/workflows/monitoring-cron.yml/dispatches \
  -d '{"ref":"main","inputs":{"job_type":"all"}}'
```

### Method 2: Direct Edge Function Calls

**Health Check:**
```bash
curl -X POST "https://jiorfutbmahpfgplkats.supabase.co/functions/v1/health-check" \
  -H "Authorization: Bearer YOUR_ANON_KEY" \
  -H "x-api-key: YOUR_CLEANUP_API_KEY" \
  -H "Content-Type: application/json"
```

**Log Monitor:**
```bash
curl -X POST "https://jiorfutbmahpfgplkats.supabase.co/functions/v1/log-monitor" \
  -H "Authorization: Bearer YOUR_ANON_KEY" \
  -H "x-api-key: YOUR_CLEANUP_API_KEY" \
  -H "Content-Type: application/json"
```

**Log Alert:**
```bash
curl -X POST "https://jiorfutbmahpfgplkats.supabase.co/functions/v1/log-alert" \
  -H "Authorization: Bearer YOUR_ANON_KEY" \
  -H "x-api-key: YOUR_CLEANUP_API_KEY" \
  -H "Content-Type: application/json"
```

---

## 🖼️ 3. Image Cleanup (`cleanup-images`)

### What It Does
- Deletes all images older than 24 hours from storage
- Processes `uploads/` and `processed/` folders
- Supports dry-run mode for preview

### Method: Direct Edge Function Call

**Dry-Run (Preview - Recommended First):**
```bash
curl -X POST "https://jiorfutbmahpfgplkats.supabase.co/functions/v1/cleanup-images?dry_run=true" \
  -H "Authorization: Bearer YOUR_SERVICE_ROLE_KEY" \
  -H "x-api-key: YOUR_CLEANUP_API_KEY" \
  -H "Content-Type: application/json"
```

**Actual Deletion:**
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

## 🔑 Required Credentials

### For GitHub Actions
- **GitHub Token** - Personal access token with `repo` scope
- Or use GitHub UI (no token needed)

### For Direct Edge Function Calls
- **SUPABASE_URL** - `https://jiorfutbmahpfgplkats.supabase.co`
- **SERVICE_ROLE_KEY** - From Supabase Dashboard → Settings → API
- **ANON_KEY** - From Supabase Dashboard → Settings → API (for monitoring jobs)
- **CLEANUP_API_KEY** - Custom API key (set in Edge Function env vars)

---

## 📝 Quick Reference

### All Jobs at Once (Bash Script)

Create `run-all-cleanup.sh`:

```bash
#!/bin/bash

# Set your credentials
SUPABASE_URL="https://jiorfutbmahpfgplkats.supabase.co"
SERVICE_ROLE_KEY="your-service-role-key"
ANON_KEY="your-anon-key"
CLEANUP_API_KEY="your-cleanup-api-key"

echo "🧹 Running Database Cleanup..."
curl -X POST "$SUPABASE_URL/functions/v1/cleanup-db" \
  -H "Authorization: Bearer $SERVICE_ROLE_KEY" \
  -H "x-api-key: $CLEANUP_API_KEY" \
  -H "Content-Type: application/json"

echo ""
echo "📊 Running Health Check..."
curl -X POST "$SUPABASE_URL/functions/v1/health-check" \
  -H "Authorization: Bearer $ANON_KEY" \
  -H "x-api-key: $CLEANUP_API_KEY" \
  -H "Content-Type: application/json"

echo ""
echo "🖼️ Running Image Cleanup (Dry-Run)..."
curl -X POST "$SUPABASE_URL/functions/v1/cleanup-images?dry_run=true" \
  -H "Authorization: Bearer $SERVICE_ROLE_KEY" \
  -H "x-api-key: $CLEANUP_API_KEY" \
  -H "Content-Type: application/json"
```

**Make it executable:**
```bash
chmod +x run-all-cleanup.sh
./run-all-cleanup.sh
```

---

## ⚠️ Important Notes

### Database Cleanup (`cleanup-db`)
- ✅ Safe to run manually anytime
- ✅ Runs automatically on 1st of every month
- ⚠️ Deletes old records (not recoverable)

### Monitoring Jobs (`monitoring-cron`)
- ✅ Safe to run manually anytime
- ❌ Currently disabled (no automatic runs)
- ℹ️ Can run individual jobs or all at once

### Image Cleanup (`cleanup-images`)
- ⚠️ **Always run dry-run first** to preview
- ⚠️ Deletes files permanently (not recoverable)
- ✅ Manual trigger only (no automatic schedule)

---

## 🔍 Verify Results

### Check Database Cleanup Logs
```sql
SELECT 
  operation,
  details->>'jobsDeleted' as jobs_deleted,
  details->>'idempotencyKeysDeleted' as keys_deleted,
  created_at
FROM cleanup_logs
WHERE operation = 'cleanup_db'
ORDER BY created_at DESC
LIMIT 5;
```

### Check Image Cleanup Logs
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
LIMIT 5;
```

### Check Monitoring Job Results
- Health check: Returns system status JSON
- Log monitor: Returns log analysis JSON
- Log alert: Returns alert status JSON

---

## 🚨 Troubleshooting

### "401 Unauthorized"
- Check your `SERVICE_ROLE_KEY` or `ANON_KEY`
- Verify the key is correct in Supabase Dashboard

### "Invalid API key"
- Check `CLEANUP_API_KEY` matches Edge Function env var
- Verify `x-api-key` header is set correctly

### "Workflow not found" (GitHub Actions)
- Check workflow file exists in `.github/workflows/`
- Verify you're using the correct workflow filename
- Ensure you have permission to run workflows

### "Function not found" (Edge Function)
- Verify function is deployed: `supabase functions list`
- Check function name matches exactly (case-sensitive)
- Ensure function is not disabled in Supabase Dashboard

---

## 📚 Related Documentation

- **Database Cleanup:** See `cleanup-db` Edge Function
- **Image Cleanup:** See `docs/MANUAL_CLEANUP_QUICK_START.md` (if exists)
- **Monitoring:** See `monitoring-cron.yml` workflow

---

**Last Updated:** 2025-01-27

