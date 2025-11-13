# Database Migration Plan: Job History Table (Optional)

**Project**: BananaUniverse iOS App
**Migration**: Add optional job_history table for async polling
**Status**: Optional Feature - Graceful Degradation
**Phase**: Phase 1 (Backend Preparation)

---

## Executive Summary

This database plan adds an **optional** `job_history` table to track async image processing jobs. The table provides:
- Job status tracking across app restarts
- Historical record for debugging
- Queue position analytics
- User activity monitoring

**IMPORTANT**: This table is **OPTIONAL**. Edge Functions will work perfectly without it using graceful degradation. If database insert fails, processing continues normally.

---

## Decision: Optional vs Required

### Why Optional?

**Pros**:
- Edge Functions already self-contained (fal.ai is source of truth)
- Reduces database load and costs
- Simpler rollback (just drop table)
- Faster deployment (skip if not needed)

**Cons**:
- No historical record after job completes
- Cannot resume polling after app restart (acceptable for MVP)
- Limited debugging visibility

**Decision**: Implement as optional with environment variable control.

---

## Migration File

**Location**: `supabase/migrations/053_create_job_history.sql`

**When to Execute**: During Phase 1 (Backend Preparation), BEFORE deploying Edge Functions.

**Execution Command**:
```bash
# Local testing
supabase db reset

# Production deployment
supabase db push
```

---

## Database Schema

### Table: job_history

**Purpose**: Track async image processing jobs for monitoring and debugging.

**Schema**:
```sql
-- =====================================================
-- Migration: 053_create_job_history.sql
-- Purpose: Optional job tracking for async polling
-- Status: OPTIONAL - graceful degradation if missing
-- =====================================================

CREATE TABLE IF NOT EXISTS public.job_history (
    -- Primary Key
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    -- User Identification (one of these will be set)
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,  -- Authenticated users
    device_id TEXT,                                            -- Anonymous users

    -- Job Identifiers
    fal_job_id TEXT NOT NULL UNIQUE,                          -- fal.ai request_id

    -- Job Status
    status TEXT NOT NULL DEFAULT 'queued',                     -- queued | processing | completed | failed

    -- Job Data
    input_url TEXT,                                            -- temp-processing/ URL (optional)
    result_url TEXT,                                           -- processed/ URL (when completed)
    prompt TEXT,                                               -- User prompt
    error TEXT,                                                -- Error message (when failed)

    -- Queue Metadata
    queue_position INTEGER,                                    -- Position in fal.ai queue

    -- Timestamps
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),            -- Job submitted
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),            -- Last status check
    completed_at TIMESTAMPTZ,                                 -- Job finished (success or failure)

    -- Constraints
    CHECK (user_id IS NOT NULL OR device_id IS NOT NULL),     -- Must have one identifier
    CHECK (status IN ('queued', 'processing', 'completed', 'failed')),
    CHECK (completed_at IS NULL OR completed_at >= created_at)
);

-- =====================================================
-- Indexes for Performance
-- =====================================================

-- Primary lookup: Find jobs by fal.ai request_id
CREATE INDEX idx_job_history_fal_job_id ON public.job_history(fal_job_id);

-- User lookup: Find all jobs for authenticated user
CREATE INDEX idx_job_history_user_id ON public.job_history(user_id) WHERE user_id IS NOT NULL;

-- Anonymous lookup: Find all jobs for device
CREATE INDEX idx_job_history_device_id ON public.job_history(device_id) WHERE device_id IS NOT NULL;

-- Status monitoring: Find all jobs in specific state
CREATE INDEX idx_job_history_status ON public.job_history(status);

-- Cleanup: Find old jobs efficiently
CREATE INDEX idx_job_history_created_at ON public.job_history(created_at);

-- Stuck job detection: Find jobs that never completed
CREATE INDEX idx_job_history_incomplete ON public.job_history(status, updated_at)
    WHERE status IN ('queued', 'processing');

-- =====================================================
-- Row-Level Security (RLS)
-- =====================================================

ALTER TABLE public.job_history ENABLE ROW LEVEL SECURITY;

-- Policy 1: Users can view their own jobs (authenticated)
CREATE POLICY "Users can view own jobs"
    ON public.job_history
    FOR SELECT
    USING (auth.uid() = user_id);

-- Policy 2: Users can insert their own jobs (authenticated)
CREATE POLICY "Users can insert own jobs"
    ON public.job_history
    FOR INSERT
    WITH CHECK (auth.uid() = user_id);

-- Policy 3: Users can update their own jobs (authenticated)
CREATE POLICY "Users can update own jobs"
    ON public.job_history
    FOR UPDATE
    USING (auth.uid() = user_id);

-- Policy 4: Anonymous users can view jobs by device_id
CREATE POLICY "Anonymous users can view own jobs"
    ON public.job_history
    FOR SELECT
    USING (device_id IS NOT NULL);

-- Policy 5: Anonymous users can insert jobs by device_id
CREATE POLICY "Anonymous users can insert own jobs"
    ON public.job_history
    FOR INSERT
    WITH CHECK (device_id IS NOT NULL);

-- Policy 6: Service role has full access (for Edge Functions)
CREATE POLICY "Service role has full access"
    ON public.job_history
    FOR ALL
    USING (auth.jwt()->>'role' = 'service_role');

-- =====================================================
-- Cleanup Function (Optional)
-- =====================================================

CREATE OR REPLACE FUNCTION cleanup_old_jobs()
RETURNS INTEGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    deleted_count INTEGER;
BEGIN
    -- Delete completed/failed jobs older than 30 days
    DELETE FROM public.job_history
    WHERE status IN ('completed', 'failed')
      AND completed_at < now() - INTERVAL '30 days';

    GET DIAGNOSTICS deleted_count = ROW_COUNT;

    -- Delete stuck jobs (processing > 24 hours)
    DELETE FROM public.job_history
    WHERE status IN ('queued', 'processing')
      AND updated_at < now() - INTERVAL '24 hours';

    GET DIAGNOSTICS deleted_count = deleted_count + ROW_COUNT;

    RETURN deleted_count;
END;
$$;

-- =====================================================
-- Scheduled Cleanup (Optional - requires pg_cron extension)
-- =====================================================

-- Uncomment if pg_cron is available:
-- SELECT cron.schedule(
--     'cleanup-old-jobs',
--     '0 2 * * *',  -- Run daily at 2 AM
--     'SELECT cleanup_old_jobs();'
-- );

-- =====================================================
-- Graceful Degradation Test
-- =====================================================

-- Verify table exists
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'job_history') THEN
        RAISE NOTICE 'WARNING: job_history table not found - Edge Functions will use graceful degradation';
    ELSE
        RAISE NOTICE 'SUCCESS: job_history table created';
    END IF;
END $$;
```

---

## Storage Bucket Changes

### Existing Bucket: noname-banana-images-prod

**Current Structure**:
```
noname-banana-images-prod/
└── processed/
    └── {user_id}/
        └── {timestamp}-result.jpg
```

**New Structure** (Phase 1):
```
noname-banana-images-prod/
├── temp-processing/          (NEW)
│   └── {user_id}/
│       └── {timestamp}-input.jpg  (1-hour expiry)
└── processed/                (existing)
    └── {user_id}/
        └── {timestamp}-result.jpg
```

**Schema Changes Required**: ❌ **NONE**

**Policy Changes Required**: ✅ **YES** (add temp-processing/ folder access)

### Updated Storage Policies

**Location**: Add to existing migration or create `054_storage_temp_folder.sql`

```sql
-- =====================================================
-- Storage Policy: temp-processing folder
-- =====================================================

-- Policy 1: Authenticated users can upload to own temp-processing folder
CREATE POLICY "Users can upload to temp-processing"
    ON storage.objects
    FOR INSERT
    WITH CHECK (
        bucket_id = 'noname-banana-images-prod' AND
        (storage.foldername(name))[1] = 'temp-processing' AND
        (storage.foldername(name))[2] = auth.uid()::TEXT
    );

-- Policy 2: Service role can read from temp-processing (for Edge Functions)
CREATE POLICY "Service role can read temp-processing"
    ON storage.objects
    FOR SELECT
    USING (
        bucket_id = 'noname-banana-images-prod' AND
        (storage.foldername(name))[1] = 'temp-processing' AND
        auth.jwt()->>'role' = 'service_role'
    );

-- Policy 3: Service role can delete from temp-processing (cleanup)
CREATE POLICY "Service role can delete temp-processing"
    ON storage.objects
    FOR DELETE
    USING (
        bucket_id = 'noname-banana-images-prod' AND
        (storage.foldername(name))[1] = 'temp-processing' AND
        auth.jwt()->>'role' = 'service_role'
    );

-- =====================================================
-- Automatic Cleanup: Delete files older than 1 hour
-- =====================================================

CREATE OR REPLACE FUNCTION cleanup_temp_processing()
RETURNS INTEGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    deleted_count INTEGER;
BEGIN
    DELETE FROM storage.objects
    WHERE bucket_id = 'noname-banana-images-prod'
      AND (storage.foldername(name))[1] = 'temp-processing'
      AND created_at < now() - INTERVAL '1 hour';

    GET DIAGNOSTICS deleted_count = ROW_COUNT;
    RETURN deleted_count;
END;
$$;

-- Schedule cleanup (if pg_cron available)
-- SELECT cron.schedule(
--     'cleanup-temp-processing',
--     '0 * * * *',  -- Run hourly
--     'SELECT cleanup_temp_processing();'
-- );
```

---

## Edge Function Integration

### Environment Variable Control

**File**: `supabase/.env` (local) or Supabase Dashboard (production)

```bash
# Enable optional job_history tracking
ENABLE_JOB_HISTORY=true   # Set to 'false' to disable database writes
```

### Graceful Degradation Pattern

**Pattern Used in Edge Functions**:

```typescript
// supabase/functions/submit-job/index.ts

const ENABLE_JOB_HISTORY = Deno.env.get('ENABLE_JOB_HISTORY') === 'true';

async function insertJobHistory(jobData: any) {
    if (!ENABLE_JOB_HISTORY) {
        console.log('Job history disabled, skipping database insert');
        return;
    }

    try {
        const { error } = await supabase
            .from('job_history')
            .insert(jobData);

        if (error) {
            console.error('Failed to insert job history (non-fatal):', error);
            // DO NOT throw - continue processing
        }
    } catch (err) {
        console.error('Job history insert failed (non-fatal):', err);
        // DO NOT throw - continue processing
    }
}

// Main handler continues even if insertJobHistory fails
```

**Key Principle**: Database failures NEVER block image processing.

---

## Testing Checklist

### Phase 1 (After Migration)

**Local Testing** (supabase start):

```bash
# 1. Verify table exists
psql postgresql://postgres:postgres@localhost:54322/postgres \
    -c "SELECT * FROM public.job_history LIMIT 1;"

# Expected: Empty result (no error)

# 2. Test insert (authenticated user)
curl -X POST http://localhost:54321/functions/v1/submit-job \
    -H "Authorization: Bearer YOUR_ANON_KEY" \
    -H "Content-Type: application/json" \
    -d '{"imageURL": "https://...", "prompt": "test"}'

# 3. Verify insert worked
psql postgresql://postgres:postgres@localhost:54322/postgres \
    -c "SELECT fal_job_id, status, created_at FROM public.job_history;"

# Expected: 1 row with status='queued'

# 4. Test graceful degradation (disable table)
# Rename table temporarily
psql postgresql://postgres:postgres@localhost:54322/postgres \
    -c "ALTER TABLE public.job_history RENAME TO job_history_backup;"

# Submit job (should still work)
curl -X POST http://localhost:54321/functions/v1/submit-job \
    -H "Authorization: Bearer YOUR_ANON_KEY" \
    -H "Content-Type: application/json" \
    -d '{"imageURL": "https://...", "prompt": "test"}'

# Expected: 200 OK (job submitted despite missing table)

# Restore table
psql postgresql://postgres:postgres@localhost:54322/postgres \
    -c "ALTER TABLE public.job_history_backup RENAME TO job_history;"
```

**Production Testing**:

```bash
# 1. Run migration
supabase db push

# 2. Verify table exists
supabase db remote-query \
    "SELECT * FROM public.job_history LIMIT 1;"

# 3. Deploy Edge Functions
supabase functions deploy submit-job
supabase functions deploy check-status

# 4. Test end-to-end
# Use iOS app to submit job, verify database insert

# 5. Monitor logs
supabase functions logs submit-job --tail
supabase functions logs check-status --tail
```

---

## Monitoring Queries

### Check Job Status Distribution

```sql
SELECT
    status,
    COUNT(*) as count,
    AVG(EXTRACT(EPOCH FROM (completed_at - created_at))) as avg_duration_seconds
FROM public.job_history
WHERE created_at > now() - INTERVAL '7 days'
GROUP BY status
ORDER BY count DESC;
```

### Find Stuck Jobs

```sql
SELECT
    fal_job_id,
    status,
    created_at,
    updated_at,
    now() - updated_at as time_since_update
FROM public.job_history
WHERE status IN ('queued', 'processing')
  AND updated_at < now() - INTERVAL '5 minutes'
ORDER BY updated_at ASC
LIMIT 10;
```

### User Activity Report

```sql
SELECT
    COALESCE(user_id::TEXT, device_id) as identifier,
    COUNT(*) as total_jobs,
    COUNT(*) FILTER (WHERE status = 'completed') as completed,
    COUNT(*) FILTER (WHERE status = 'failed') as failed,
    AVG(EXTRACT(EPOCH FROM (completed_at - created_at))) as avg_duration
FROM public.job_history
WHERE created_at > now() - INTERVAL '30 days'
GROUP BY identifier
ORDER BY total_jobs DESC
LIMIT 20;
```

### Cleanup Old Jobs (Manual)

```sql
-- Run cleanup function
SELECT cleanup_old_jobs();

-- Check result
-- Returns number of deleted rows
```

---

## Rollback Procedures

### Rollback Phase 1 (Drop Table)

**Trigger**: Migration caused issues, table not needed.

**Steps**:

```bash
# 1. Disable job history in Edge Functions
# Set ENABLE_JOB_HISTORY=false in Supabase Dashboard

# 2. Wait 5 minutes (let active requests finish)

# 3. Drop table
supabase db remote-query "DROP TABLE IF EXISTS public.job_history CASCADE;"

# 4. Verify Edge Functions still work
curl -X POST https://YOUR_PROJECT.supabase.co/functions/v1/submit-job \
    -H "Authorization: Bearer YOUR_ANON_KEY" \
    -H "Content-Type: application/json" \
    -d '{"imageURL": "https://...", "prompt": "test"}'

# Expected: 200 OK (graceful degradation)
```

**Time to Rollback**: 5 minutes

**Risk**: ✅ **LOW** (table is optional, no data loss)

---

### Rollback Phase 1 (Storage Policies)

**Trigger**: Storage policies causing upload failures.

**Steps**:

```bash
# 1. Drop new policies
supabase db remote-query "
    DROP POLICY IF EXISTS \"Users can upload to temp-processing\" ON storage.objects;
    DROP POLICY IF EXISTS \"Service role can read temp-processing\" ON storage.objects;
    DROP POLICY IF EXISTS \"Service role can delete temp-processing\" ON storage.objects;
"

# 2. Verify old endpoint still works
# (Phase 1 keeps process-image functional)
```

**Time to Rollback**: 2 minutes

---

## Performance Considerations

### Write Load

**Current**: ~0 writes/second (no job history)
**After Migration**:
- submit-job: 1 INSERT per job
- check-status: 1 UPDATE per poll (5-10 polls per job)
- Total: ~11 writes per job

**Impact**: Negligible at BananaUniverse scale (<100 jobs/day)

### Read Load

**Expected**: Minimal (only for debugging queries, no user-facing reads)

### Index Maintenance

**Automatic**: PostgreSQL handles index updates
**Manual**: Run `VACUUM ANALYZE public.job_history;` monthly if needed

### Storage Size

**Estimate**: ~1 KB per job
**100 jobs/day × 30 days = 3,000 jobs = ~3 MB**
**Negligible impact on database size**

---

## Security Considerations

### RLS Policies

✅ **Implemented**: Users can only view/modify own jobs
✅ **Tested**: Anonymous users isolated by device_id
✅ **Service Role**: Full access for Edge Functions

### Data Exposure

**Sensitive Data in Table**:
- `prompt`: User input (PII risk)
- `input_url`: Signed URL (expires in 1 hour)
- `result_url`: Signed URL (persistent)

**Mitigation**:
- RLS prevents cross-user access
- Cleanup function removes old jobs (30 days)
- URLs are signed (require auth to access)

### SQL Injection

✅ **Protected**: All queries use parameterized statements
✅ **Validated**: Edge Functions validate input before insert

---

## Migration Timeline

### Phase 1: Database Preparation (Day 1, 30 minutes)

| Step | Duration | Action |
|------|----------|--------|
| 1 | 5 min | Create migration file 053_create_job_history.sql |
| 2 | 2 min | Test locally (supabase db reset) |
| 3 | 5 min | Verify inserts/updates work |
| 4 | 3 min | Deploy to production (supabase db push) |
| 5 | 10 min | Verify production table exists |
| 6 | 5 min | Test graceful degradation (disable table) |

**Total**: 30 minutes

**Go/No-Go Checkpoint**:
- ✅ Migration applied without errors
- ✅ Table visible in Supabase Dashboard
- ✅ RLS policies active
- ✅ Edge Functions work with and without table

---

## Dependencies

### Required Before Database Migration

- ✅ Credit system deployed (from previous migration)
- ✅ Storage bucket exists (noname-banana-images-prod)
- ✅ Supabase project active (no maintenance window)

### Required After Database Migration

- ✅ Edge Functions deployed (submit-job, check-status)
- ✅ Environment variable ENABLE_JOB_HISTORY set
- ✅ Storage policies updated (temp-processing/ folder)

---

## Success Criteria

### Technical Metrics

- ✅ Migration completes in <5 minutes
- ✅ No errors in Supabase logs
- ✅ Table visible in Dashboard
- ✅ RLS policies prevent unauthorized access
- ✅ Edge Functions work with graceful degradation

### Functional Metrics

- ✅ Jobs inserted successfully (100% success rate)
- ✅ Status updates tracked correctly
- ✅ Cleanup function removes old jobs
- ✅ Queries return results in <100ms

---

## Documentation Updates

### After Phase 1 (Database Deployment)

- [ ] Update `DATABASE_SCHEMA.md` with job_history table
- [ ] Update `API_REFERENCE.md` with ENABLE_JOB_HISTORY flag
- [ ] Update `TROUBLESHOOTING.md` with "stuck job" debugging queries

### After Phase 4 (Cleanup)

- [ ] Archive this migration plan
- [ ] Update `PROJECT_OVERVIEW.md` (add async polling architecture diagram)

---

## FAQ

### Q: What happens if the database insert fails?

**A**: Edge Functions continue processing. The insert is wrapped in try/catch with no throw. Logs will show warning but job completes normally.

---

### Q: Can I disable job_history after enabling it?

**A**: Yes. Set `ENABLE_JOB_HISTORY=false` and redeploy Edge Functions. Existing data remains in table but no new inserts.

---

### Q: How do I resume polling after app restart?

**A**: Not supported in MVP. Job history only tracks active sessions. If app closes mid-polling, user must re-submit (credit already deducted, so user loses 1 credit). Future enhancement could query `job_history` on app launch.

---

### Q: What if I want to remove the table completely?

**A**:
1. Set `ENABLE_JOB_HISTORY=false`
2. Wait 24 hours (verify no errors)
3. Run `DROP TABLE public.job_history CASCADE;`
4. Remove references from Edge Functions (optional)

---

### Q: Does this table affect performance?

**A**: No measurable impact at BananaUniverse scale (<100 jobs/day). Database writes are async and non-blocking.

---

## Approval Sign-Off

| Role | Name | Date | Approved |
|------|------|------|----------|
| Database Admin | — | — | [ ] |
| Backend Lead | — | — | [ ] |
| DevOps | — | — | [ ] |

---

**Last Updated**: 2025-11-13
**Document Owner**: Database Team
**Status**: Draft - Awaiting Approval
**Priority**: Optional (can skip if not needed)

---

## Next Steps

1. **Review this database plan** with team
2. **Decide if job_history is needed** (MVP can skip)
3. **If approved**: Create migration file, test locally, deploy
4. **If skipped**: Set `ENABLE_JOB_HISTORY=false`, skip to Phase 2 (iOS)

---

**End of Database Migration Plan**
