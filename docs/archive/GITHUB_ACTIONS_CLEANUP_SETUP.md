# GitHub Actions Cleanup-DB Setup Guide

**Purpose:** Automated monthly database cleanup via GitHub Actions  
**Schedule:** 1st of every month at 03:00 UTC  
**Retry:** One automatic retry on failure

---

## 📋 Setup Instructions

### Step 1: Add Required Secrets

Go to your GitHub repository:
1. **Settings** → **Secrets and variables** → **Actions**
2. Click **New repository secret**
3. Add these three secrets:

**Secret 1: `SUPABASE_URL`**
```
Name: SUPABASE_URL
Value: https://jiorfutbmahpfgplkats.supabase.co
```

**Secret 2: `SUPABASE_SERVICE_ROLE_KEY`**
```
Name: SUPABASE_SERVICE_ROLE_KEY
Value: [Your service role key from Supabase Dashboard]
```
*Find it in: Supabase Dashboard → Settings → API → service_role key*

**Secret 3: `CLEANUP_API_KEY`**
```
Name: CLEANUP_API_KEY
Value: [Your cleanup API key]
```
*This is the API key you use for cleanup-db authentication*

---

### Step 2: Verify Workflow File

The workflow file is located at:
```
.github/workflows/cleanup-db.yml
```

**Verify it exists and has correct content.**

---

### Step 3: Test Manual Trigger (Optional)

1. Go to **Actions** tab in GitHub
2. Select **Database Cleanup (Monthly)** workflow
3. Click **Run workflow**
4. Select branch (usually `main` or `master`)
5. Click **Run workflow** button

**Expected:**
- Workflow runs immediately
- Shows "Run Cleanup-DB (Attempt 1)" step
- If successful, shows summary
- If failed, shows retry attempt

---

## 📊 How to Check Workflow Results

### View Workflow Runs

1. Go to **Actions** tab in GitHub
2. Click on **Database Cleanup (Monthly)** workflow
3. See list of all runs (scheduled and manual)

### Check Individual Run

1. Click on a specific run
2. Expand **Run Cleanup-DB (Attempt 1)** step
3. See logs:
   - HTTP status code
   - Response body (JSON with deletion counts)
   - Success/failure status

### Check Retry (if needed)

1. If first attempt failed, expand **Run Cleanup-DB (Attempt 2 - Retry)**
2. See retry logs
3. Check if retry succeeded or failed

### View Summary

1. Expand **Summary** step
2. See:
   - Attempt 1 status
   - Attempt 2 status (if retried)
   - Final status (SUCCESS or FAILED)

---

## 🔍 Understanding the Output

### Successful Run

```
✅ [ATTEMPT 1] Cleanup completed successfully
HTTP Status Code: 200
Response Body:
{
  "jobsDeleted": 0,
  "rateLimitDeleted": 0,
  "logsDeleted": 5,
  "quotaLogsDeleted": 0,
  "quotaRecordsDeleted": 0,
  "idempotencyKeysDeleted": 123,
  "errors": [],
  "executionTime": 150
}
```

### Failed Run (with Retry)

```
❌ [ATTEMPT 1] Cleanup failed with status 500
🔄 [ATTEMPT 2] Retrying database cleanup...
✅ [ATTEMPT 2] Cleanup completed successfully (retry succeeded)
```

### Failed Run (both attempts failed)

```
❌ [ATTEMPT 1] Cleanup failed with status 500
🔄 [ATTEMPT 2] Retrying database cleanup...
❌ [ATTEMPT 2] Cleanup failed with status 500 (retry failed)
❌ FINAL STATUS: FAILED (both attempts failed)
```

---

## ⚙️ Configuration

### Change Schedule

Edit `.github/workflows/cleanup-db.yml`:

```yaml
schedule:
  - cron: '0 3 1 * *'  # 1st of month at 03:00 UTC
```

**Cron format:** `minute hour day month weekday`

**Examples:**
- `'0 3 1 * *'` - 1st of month at 03:00 UTC (current)
- `'0 2 * * 0'` - Every Sunday at 02:00 UTC
- `'0 4 15 * *'` - 15th of month at 04:00 UTC

### Disable Retry

Remove the retry step or set `continue-on-error: false`:

```yaml
- name: Run Cleanup-DB (Attempt 1)
  continue-on-error: false  # Fail immediately, no retry
```

---

## 🚨 Troubleshooting

### Workflow Not Running

**Check:**
1. Secrets are set correctly
2. Workflow file is in `.github/workflows/` directory
3. File has correct YAML syntax
4. Branch is `main` or `master` (default branch)

### Authentication Errors

**Error:** `401 Unauthorized`

**Fix:**
- Verify `SUPABASE_SERVICE_ROLE_KEY` secret is correct
- Verify `CLEANUP_API_KEY` secret is correct
- Check keys in Supabase Dashboard

### Timeout Errors

**Error:** `timeout` or `max-time exceeded`

**Fix:**
- Increase timeout in workflow:
  ```yaml
  timeout-minutes: 20  # Increase from 10
  ```

### Function Not Found

**Error:** `404 Not Found`

**Fix:**
- Verify `cleanup-db` function is deployed
- Check `SUPABASE_URL` secret is correct
- Verify function name in URL

---

## 📅 Schedule Details

**Current Schedule:**
- **Frequency:** Monthly
- **Day:** 1st of every month
- **Time:** 03:00 UTC
- **Timezone:** UTC

**What Gets Cleaned:**
- Old job records
- Rate limiting data
- Cleanup logs
- Quota consumption logs
- Daily quota records
- **Idempotency keys (older than 90 days)**

---

## ✅ Verification Checklist

- [ ] Secrets added to GitHub repository
- [ ] Workflow file exists at `.github/workflows/cleanup-db.yml`
- [ ] Manual test run succeeded
- [ ] Schedule is correct (1st of month at 03:00 UTC)
- [ ] Retry logic works (test by temporarily breaking function)
- [ ] Logs show deletion counts
- [ ] Summary step shows correct status

---

## 🔗 Related Files

- **Workflow:** `.github/workflows/cleanup-db.yml`
- **Edge Function:** `supabase/functions/cleanup-db/index.ts`
- **Migration:** `supabase/migrations/066_add_idempotency_cleanup.sql`

---

**Status:** ✅ **READY TO USE**

Once secrets are added, the workflow will run automatically on the 1st of every month.

