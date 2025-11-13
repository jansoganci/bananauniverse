# Phase 1 Deployment Guide

**Date**: 2025-11-13
**Phase**: 1 - Backend Preparation
**Project ID**: jiorfutbmahpfgplkats

---

## Pre-Deployment Checklist

### 1. Environment Variables (Critical!)

You must set these environment variables in the Supabase Dashboard before deploying:

**Navigate to**: Supabase Dashboard → Settings → Edge Functions → Add secret

| Variable Name | Value | Required For |
|---------------|-------|--------------|
| `FAL_AI_API_KEY` | Your fal.ai API key | submit-job, check-status |
| `ENABLE_JOB_HISTORY` | `true` or `false` | Optional job tracking |

**How to get FAL_AI_API_KEY**:
- Visit: https://fal.ai/dashboard
- Generate API key
- Copy to Supabase secrets

---

## Deployment Steps

### Step 1: Verify You're Logged In

```bash
supabase login
```

If not logged in, follow the OAuth flow.

---

### Step 2: Link to Production Project

```bash
cd /Users/jans./Downloads/banana.universe
supabase link --project-ref jiorfutbmahpfgplkats
```

This connects your local environment to production.

---

### Step 3: Deploy Database Migration (Optional)

```bash
# Push migration to production
supabase db push
```

This will apply migration `053_create_job_history.sql` to create the optional `job_history` table.

**Expected Output**:
```
✓ Applying migration 053_create_job_history.sql...
SUCCESS: job_history table created successfully
```

**If it fails**: Check error message. Most likely RLS or constraint issues.

---

### Step 4: Deploy Edge Functions

Deploy all three Edge Functions:

```bash
# Deploy submit-job
supabase functions deploy submit-job

# Deploy check-status
supabase functions deploy check-status

# Deploy updated process-image (with deprecation notice)
supabase functions deploy process-image
```

**Expected Output for each**:
```
Deploying Function (project-ref: jiorfutbmahpfgplkats)...
Function URL: https://jiorfutbmahpfgplkats.supabase.co/functions/v1/submit-job
Completed in 5s.
```

---

### Step 5: Verify Deployment

Test each endpoint using curl:

#### Test submit-job

```bash
# Set your environment variables
export SUPABASE_URL="https://jiorfutbmahpfgplkats.supabase.co"
export ANON_KEY="your-anon-key-from-dashboard"
export DEVICE_ID="test-device-$(date +%s)"

# Test submit-job
curl -X POST $SUPABASE_URL/functions/v1/submit-job \
  -H "Authorization: Bearer $ANON_KEY" \
  -H "Content-Type: application/json" \
  -H "device-id: $DEVICE_ID" \
  -d '{
    "image_url": "https://example.com/test.jpg",
    "prompt": "test prompt",
    "device_id": "'"$DEVICE_ID"'"
  }'
```

**Expected Response** (success):
```json
{
  "success": true,
  "job_id": "abc-123-def-456",
  "status": "queued",
  "quota_info": {
    "credits": 2,
    "quota_used": 1,
    "quota_limit": 3,
    "quota_remaining": 2,
    "is_premium": false
  }
}
```

**Expected Response** (quota exceeded):
```json
{
  "success": false,
  "error": "Daily limit reached. Please try again tomorrow or upgrade to Premium.",
  "quota_info": {
    "credits": 0,
    "quota_used": 3,
    "quota_limit": 3,
    "quota_remaining": 0,
    "is_premium": false
  }
}
```

#### Test check-status

```bash
# Use job_id from submit-job response
export JOB_ID="abc-123-def-456"

curl -X POST $SUPABASE_URL/functions/v1/check-status \
  -H "Authorization: Bearer $ANON_KEY" \
  -H "Content-Type: application/json" \
  -H "device-id: $DEVICE_ID" \
  -d '{
    "job_id": "'"$JOB_ID"'",
    "device_id": "'"$DEVICE_ID"'"
  }'
```

**Expected Response** (queued):
```json
{
  "success": true,
  "status": "queued",
  "queue_position": 5
}
```

**Expected Response** (processing):
```json
{
  "success": true,
  "status": "processing"
}
```

**Expected Response** (completed):
```json
{
  "success": true,
  "status": "completed",
  "image_url": "https://jiorfutbmahpfgplkats.supabase.co/storage/v1/object/sign/..."
}
```

---

### Step 6: Monitor Logs

```bash
# Monitor submit-job logs
supabase functions logs submit-job --tail

# Monitor check-status logs (in separate terminal)
supabase functions logs check-status --tail

# Monitor deprecated process-image logs
supabase functions logs process-image --tail
```

**Watch for**:
- ✅ Successful job submissions
- ✅ Quota consumption working
- ✅ fal.ai queue responses
- ❌ Any error messages
- ⚠️ Deprecation warnings from process-image

---

## Post-Deployment Verification

### 1. Check Function Status

Visit Supabase Dashboard → Edge Functions → Verify all three functions are deployed:
- ✅ submit-job
- ✅ check-status
- ✅ process-image

### 2. Test End-to-End Flow

Run this complete test:

```bash
#!/bin/bash
set -e

export SUPABASE_URL="https://jiorfutbmahpfgplkats.supabase.co"
export ANON_KEY="your-anon-key"
export DEVICE_ID="test-device-$(date +%s)"

echo "1. Submitting job..."
RESPONSE=$(curl -s -X POST $SUPABASE_URL/functions/v1/submit-job \
  -H "Authorization: Bearer $ANON_KEY" \
  -H "Content-Type: application/json" \
  -H "device-id: $DEVICE_ID" \
  -d '{
    "image_url": "https://example.com/test.jpg",
    "prompt": "make it blue",
    "device_id": "'"$DEVICE_ID"'"
  }')

echo $RESPONSE | jq .

JOB_ID=$(echo $RESPONSE | jq -r .job_id)
echo "Job ID: $JOB_ID"

echo ""
echo "2. Polling for status (10 times, 3 second intervals)..."
for i in {1..10}; do
  echo "Poll #$i..."
  STATUS=$(curl -s -X POST $SUPABASE_URL/functions/v1/check-status \
    -H "Authorization: Bearer $ANON_KEY" \
    -H "Content-Type: application/json" \
    -H "device-id: $DEVICE_ID" \
    -d '{
      "job_id": "'"$JOB_ID"'",
      "device_id": "'"$DEVICE_ID"'"
    }')

  echo $STATUS | jq .

  # Check if completed
  if echo $STATUS | jq -e '.status == "completed"' > /dev/null; then
    echo "✅ Job completed!"
    exit 0
  fi

  sleep 3
done

echo "⚠️ Job still processing after 30 seconds"
```

Save this as `test-polling.sh` and run:
```bash
chmod +x test-polling.sh
./test-polling.sh
```

### 3. Check Database (Optional)

If `ENABLE_JOB_HISTORY=true`:

```bash
# Connect to production database
supabase db remote-query "
  SELECT
    fal_job_id,
    status,
    created_at,
    updated_at
  FROM job_history
  ORDER BY created_at DESC
  LIMIT 5;
"
```

Expected: See your test jobs recorded.

---

## Rollback Procedure (If Needed)

If deployment fails or causes issues:

### Option 1: Rollback Database Migration

```bash
# Create rollback migration
cat > supabase/migrations/054_rollback_job_history.sql << 'EOF'
DROP TABLE IF EXISTS public.job_history CASCADE;
DROP FUNCTION IF EXISTS public.cleanup_job_history() CASCADE;
EOF

# Apply rollback
supabase db push
```

### Option 2: Delete Edge Functions

```bash
# This will remove the functions from production
supabase functions delete submit-job
supabase functions delete check-status

# Old process-image will continue working
```

### Option 3: Disable Job History

In Supabase Dashboard → Settings → Edge Functions → Secrets:
- Set `ENABLE_JOB_HISTORY=false`

Functions will continue working without database writes.

---

## Troubleshooting

### Error: "FAL_AI_API_KEY not configured"

**Solution**: Set the environment variable in Supabase Dashboard → Settings → Edge Functions → Add secret

---

### Error: "Quota validation failed"

**Possible Causes**:
1. `consume_quota` RPC function doesn't exist
2. Database migration not applied
3. RLS policies blocking access

**Solution**:
```bash
# Check if RPC exists
supabase db remote-query "
  SELECT proname
  FROM pg_proc
  WHERE proname IN ('consume_quota', 'add_credits', 'refund_quota');
"
```

---

### Error: "Job not found" (404 from fal.ai)

**Possible Causes**:
1. Invalid FAL_AI_API_KEY
2. Job ID doesn't exist in fal.ai queue
3. Job expired (fal.ai retention period)

**Solution**: Check fal.ai dashboard for API key validity.

---

### Error: "Failed to save image to storage"

**Possible Causes**:
1. Storage bucket doesn't exist
2. RLS policies blocking upload
3. Disk quota exceeded

**Solution**:
```bash
# Check bucket exists
supabase storage list

# Check RLS policies on storage.objects
supabase db remote-query "
  SELECT policyname, tablename
  FROM pg_policies
  WHERE tablename = 'objects';
"
```

---

## Success Criteria

✅ All three Edge Functions deployed without errors
✅ `submit-job` returns valid job_id
✅ `check-status` returns status updates
✅ `process-image` shows deprecation headers
✅ Database migration applied (if ENABLE_JOB_HISTORY=true)
✅ No errors in function logs
✅ End-to-end test completes successfully

---

## Next Steps

After successful deployment:

1. **Wait 24 hours** - Monitor for any production issues
2. **Check metrics**:
   - Function invocation counts (should see submit-job + check-status usage)
   - Error rates (target: < 1%)
   - Average execution time (submit-job: < 2s, check-status: < 2s)
3. **Proceed to Phase 2** - iOS client migration
   - Update iOS app to use new endpoints
   - Deploy to TestFlight
   - Monitor for issues

---

**Deployment Date**: _________
**Deployed By**: _________
**Status**: ☐ Success  ☐ Rollback  ☐ Partial

---

## Notes

_Add any deployment-specific notes here_
