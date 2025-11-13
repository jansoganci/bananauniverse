# Master Migration Plan: Synchronous → Async Polling Architecture

## Executive Summary

**Project**: BananaUniverse iOS App
**Migration**: Synchronous Edge Function → Async Job + Polling
**Duration**: 3-4 days
**Risk Level**: Medium (mitigated by phased rollout)

### Current State (Problems)

```
iOS → process-image Edge Function (30-40s blocking) → fal.ai → Response
```

**Issues**:
- Edge Function holds connection for 30-40 seconds
- Wastes concurrent execution slots (limit: 10)
- iOS client timeout risk (URLSession 60s default)
- No retry without re-uploading image
- No progress feedback
- Scalability bottleneck

### Target State (Solution)

```
iOS → submit-job (< 1s) → job_id
iOS → check-status (2s polling) → status updates → completed
```

**Benefits**:
- Edge Function execution: 1-2 seconds per call
- iOS controls polling rate (exponential backoff)
- Retry without re-upload
- User sees progress
- Scales to 100+ concurrent users

---

## Migration Phases

### Phase 1: Backend Preparation (Day 1, 4-6 hours)

**Goal**: Deploy new Edge Functions without breaking existing iOS app.

**Tasks**:
1. Create `submit-job` Edge Function
2. Create `check-status` Edge Function
3. Deprecate `process-image` (keep functional)
4. Create `job_history` table (optional)
5. Deploy to production

**Deliverable**: New endpoints live, old endpoint still works.

**Risk**: Low (additive changes only)

**Go/No-Go Checkpoint**: Test new endpoints with curl. If working, proceed to Phase 2.

---

### Phase 2: iOS Client Migration (Day 2, 4-6 hours)

**Goal**: Update iOS app to use async polling pattern.

**Tasks**:
1. Update models (SubmitJobResult, JobStatusResult)
2. Update SupabaseService (submitImageJob, checkJobStatus)
3. Update ChatViewModel (polling loop with exponential backoff)
4. Test locally with Supabase
5. Deploy to TestFlight

**Deliverable**: iOS app uses new polling pattern, fallback to old endpoint.

**Risk**: Medium (user-facing changes)

**Go/No-Go Checkpoint**: TestFlight testing shows <1% error rate. If pass, submit to App Store.

---

### Phase 3: Production Monitoring (Day 3, 2-4 hours)

**Goal**: Verify new architecture performs in production.

**Tasks**:
1. Monitor Edge Function invocation counts
2. Analyze polling efficiency (avg polls per job)
3. Check error rates (target: <1%)
4. Optimize backoff parameters if needed
5. Monitor user feedback

**Deliverable**: Production metrics baseline, optimization recommendations.

**Risk**: Low (observation only)

**Go/No-Go Checkpoint**: After 7 days, if error rate <0.5% and no user complaints, proceed to Phase 4.

---

### Phase 4: Cleanup & Deprecation (Week 2, 1-2 hours)

**Goal**: Remove deprecated code, finalize migration.

**Tasks**:
1. Remove fallback code from iOS
2. Delete `process-image` Edge Function
3. Clean up unused code
4. Update documentation

**Deliverable**: Migration complete, codebase clean.

**Risk**: Low (old code proven unused)

---

## Timeline Summary

| Phase | Duration | Owner | Dependencies |
|-------|----------|-------|--------------|
| 1. Backend | 4-6 hours | Backend | None |
| 2. iOS | 4-6 hours | iOS | Phase 1 complete |
| 3. Monitoring | 2-4 hours/day × 7 days | DevOps | Phase 2 complete |
| 4. Cleanup | 1-2 hours | Full-stack | Phase 3 metrics pass |
| **Total** | **10-14 hours** over **2 weeks** | — | — |

---

## Risk Matrix

### High Risk ⚠️

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| fal.ai async API changes | Low | High | Pin API version, monitor changelog |
| iOS app rejected by App Store | Low | High | Submit early, follow guidelines |
| Edge Function cold starts cause timeouts | Medium | Medium | Monitor logs, optimize if needed |

### Medium Risk ⚡

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| Polling inefficiency (too many calls) | Medium | Medium | Tune backoff parameters based on data |
| Jobs stuck in "processing" state | Low | Medium | Add cleanup function, timeout handling |
| Database migration fails | Low | Medium | Test on staging first, backup production |

### Low Risk ✅

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| User confusion with new UI | Low | Low | Add clear "Processing..." messages |
| Old endpoint still used accidentally | Low | Low | Monitor usage, deprecate after 2 weeks |

---

## Success Criteria

### Technical Metrics

- ✅ Edge Function execution time: < 2 seconds (submit-job + check-status)
- ✅ Average polls per job: 5-10 polls
- ✅ Job completion rate: > 98%
- ✅ Timeout rate: < 1%
- ✅ Error rate: < 1%

### User Experience Metrics

- ✅ No increase in support tickets
- ✅ No negative App Store reviews mentioning "slow" or "timeout"
- ✅ User sees progress feedback (polling status)

### Business Metrics

- ✅ Concurrent capacity: 10 → 100+ users
- ✅ Edge Function costs: No increase (same total invocations)
- ✅ Credit refund rate: < 5%

---

## Go/No-Go Decision Points

### Checkpoint 1: After Phase 1 (Backend Deployment)

**Criteria**:
- ✅ `submit-job` endpoint returns job_id within 1 second
- ✅ `check-status` endpoint returns status within 2 seconds
- ✅ Old `process-image` endpoint still functional
- ✅ No errors in Supabase logs

**Decision**: If all pass → Proceed to Phase 2. If fail → Investigate and fix before continuing.

---

### Checkpoint 2: After Phase 2 (iOS Deployment)

**Criteria**:
- ✅ TestFlight build shows <1% error rate (24 hour window)
- ✅ Polling completes successfully in 15-30 seconds
- ✅ Timeout handling works (120s limit)
- ✅ Network retry works (resume polling after disconnect)

**Decision**: If all pass → Submit to App Store. If fail → Rollback iOS to old endpoint, investigate.

---

### Checkpoint 3: After Phase 3 (Production Monitoring)

**Criteria**:
- ✅ Error rate < 0.5% over 7 days
- ✅ No user-reported issues
- ✅ Average polls per job: 5-10 (efficient)
- ✅ No jobs stuck in "processing" > 5 minutes

**Decision**: If all pass → Proceed to Phase 4 (cleanup). If fail → Keep old endpoint active, optimize new one.

---

## Rollback Procedures

### Rollback Phase 2 (iOS Emergency)

**Trigger**: iOS error rate > 5% or critical user-facing bug.

**Steps**:
1. Re-enable `processImageSteveJobsStyle()` call in ChatViewModel
2. Comment out `submitImageJob()` + `pollJobStatus()`
3. Build hotfix release
4. Submit to App Store (expedited review)
5. Notify users via in-app banner

**Time to rollback**: 2-4 hours (build + App Store approval)

---

### Rollback Phase 4 (Cleanup Reversal)

**Trigger**: Discover critical bug after removing old endpoint.

**Steps**:
1. Re-deploy `process-image` Edge Function from git history
2. iOS already has fallback code (if Phase 4 done correctly)
3. Monitor for 24 hours
4. Investigate root cause

**Time to rollback**: 15 minutes (Edge Function deployment)

---

## Communication Plan

### Stakeholders

- **iOS Team**: Daily updates during Phase 1-2, weekly during Phase 3
- **Backend Team**: Real-time during deployment, daily during monitoring
- **QA Team**: Test plan before Phase 2, regression testing before Phase 4
- **Users**: In-app changelog after Phase 2 (optional)

### Status Updates

**Daily** (Phase 1-2):
- Morning: Plan for the day
- Evening: Progress report, blockers

**Weekly** (Phase 3):
- Monday: Metrics summary (error rate, polling efficiency)
- Friday: Decision on Phase 4 readiness

---

## Dependencies

### External

- **fal.ai Async API**: Must be stable (check status page)
- **Supabase Platform**: No scheduled maintenance during deployment
- **Apple App Store**: Review time 1-2 days (plan accordingly)

### Internal

- **Credit system**: Must be deployed (from previous credit migration)
- **Supabase Storage**: Must have available space (check quota)
- **iOS URLSession**: Timeout configured > 120 seconds

---

## Documentation Updates

### Before Migration

- [x] Read existing architecture docs
- [x] Review fal.ai async API docs
- [x] Review Supabase Edge Function docs

### After Phase 1

- [ ] Update `API_REFERENCE.md` with new endpoints
- [ ] Update `BACKEND_ARCHITECTURE.md` with polling pattern

### After Phase 2

- [ ] Update `IOS_ARCHITECTURE.md` with polling logic
- [ ] Update `TROUBLESHOOTING.md` with new error cases

### After Phase 4

- [ ] Archive `MIGRATION_PLAN.md` (this document)
- [ ] Update `PROJECT_OVERVIEW.md` (remove "synchronous" references)

---

## Testing Checklist

### Phase 1 (Backend)

**submit-job**:
- [ ] Valid request → returns job_id within 1s
- [ ] Invalid auth → returns 401
- [ ] Insufficient credits → returns 402, refunds not applied
- [ ] Premium user → bypasses credit check
- [ ] fal.ai error → returns 500, refunds credit

**check-status**:
- [ ] Job queued → returns "queued"
- [ ] Job processing → returns "processing"
- [ ] Job completed → returns "completed" + image_url
- [ ] Job failed → returns "failed" + error, refunds credit
- [ ] Invalid job_id → returns 404

---

### Phase 2 (iOS)

**Happy Path**:
- [ ] Submit job → poll → display result

**Error Handling**:
- [ ] Timeout after 120s → shows error
- [ ] Network drop → reconnects, resumes polling
- [ ] fal.ai failure → shows error, credit refunded

**Edge Cases**:
- [ ] Kill app mid-polling → resume on relaunch (optional)
- [ ] Switch screens mid-polling → polling continues
- [ ] Submit 3 jobs simultaneously → all complete

---

### Phase 3 (Production)

**Monitoring**:
- [ ] Average polls per job: 5-10
- [ ] Error rate: < 1%
- [ ] No jobs stuck > 5 minutes
- [ ] Edge Function costs: No increase

---

## File Structure

```
docs/migration_plan/
├── 00_MASTER_MIGRATION_PLAN.md       (this file)
├── 01_BACKEND_PLAN.md                (Edge Functions)
├── 02_IOS_PLAN.md                    (Swift code)
└── 03_DATABASE_PLAN.md               (Optional job_history)
```

---

## Next Steps

1. **Review this master plan** with team
2. **Read detailed plans**:
   - Backend: `01_BACKEND_PLAN.md`
   - iOS: `02_IOS_PLAN.md`
   - Database: `03_DATABASE_PLAN.md`
3. **Schedule Phase 1 deployment** (low-traffic window)
4. **Begin implementation** after approval

---

## Approval Sign-Off

| Role | Name | Date | Approved |
|------|------|------|----------|
| Backend Lead | — | — | [ ] |
| iOS Lead | — | — | [ ] |
| DevOps | — | — | [ ] |
| Product Owner | — | — | [ ] |

---

**Last Updated**: 2025-11-13
**Document Owner**: Backend Team
**Status**: Draft - Awaiting Approval
