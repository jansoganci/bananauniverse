# Credit System Migration Plan

## Context

BananaUniverse currently uses a **daily quota system** (5 requests/day free, 3/day premium temporarily) that resets every 24 hours. We are migrating to a **persistent credit-based system** where:

- Users have a **credit balance** that persists across days
- Each image processing operation costs **1 credit**
- Premium users get **unlimited credits** (bypass all checks)
- Credits are purchased via in-app purchases (future: credit packages)
- All credit operations are **idempotent** and **server-authoritative**

**Why**: Credit-based systems provide better flexibility, clearer value proposition, and align with industry standards (similar to RendioAI architecture).

---

## Migration Phases

### Phase 1: Database Foundation
**Duration**: 4-6 hours
**Owner**: Backend/Database

#### Inputs
- Current schema: `daily_quotas`, `quota_consumption_log` tables
- Existing RLS patterns from `017_create_daily_quota.sql`
- Subscription table (unchanged, reused for premium detection)

#### Tasks
1. Create migration `052_create_credit_system.sql`
2. Create `user_credits` table (balance, lifetime stats)
3. Create `credit_transactions` table (audit log + idempotency)
4. Create `credit_packages` table (optional, for future IAP)
5. Implement SQL functions:
   - `deduct_credits()` - atomic credit deduction
   - `add_credits()` - credit addition (purchase/refund)
   - `get_credits()` - fetch current balance
6. Set up RLS policies (mirror quota patterns)
7. Run migration on staging database

#### Outputs
- ✅ New tables exist with proper indexes
- ✅ RPC functions are callable from Edge Function
- ✅ RLS policies prevent unauthorized access
- ✅ Idempotency works (duplicate `request_id` returns cached result)

#### Risks & Mitigation
- **Risk**: Migration fails mid-execution → **Mitigation**: Wrap in transaction, test on staging first
- **Risk**: RLS blocks legitimate requests → **Mitigation**: Reuse exact patterns from quota system (proven)

---

### Phase 2: Edge Function Update
**Duration**: 2-3 hours
**Owner**: Backend/Serverless

#### Inputs
- New RPC functions from Phase 1
- Current `process-image/index.ts` (625 lines)
- Existing idempotency pattern (requestId generation)

#### Tasks
1. Replace `consume_quota` RPC call with `deduct_credits` (lines ~182-240)
2. Remove fallback to old system (lines ~242-365)
3. Update refund logic: `refund_quota` → `add_credits` (lines ~451-469)
4. Ensure single `requestId` is reused for deduct + refund
5. Update response payload to include `balance` instead of `quota_remaining`
6. Deploy to staging Edge Function
7. Test with curl/Postman

#### Outputs
- ✅ Edge function calls `deduct_credits` before AI processing
- ✅ Refunds work on failure using `add_credits`
- ✅ Idempotency prevents double-charging
- ✅ Premium users bypass credit checks (server-side validation)

#### Risks & Mitigation
- **Risk**: Breaking API changes affect live iOS app → **Mitigation**: Deploy backend first, then iOS with backwards compatibility check
- **Risk**: Refund logic fails, users lose credits → **Mitigation**: Add try-catch, log to monitoring, manual refund process

---

### Phase 3: iOS Core Services
**Duration**: 6-8 hours
**Owner**: iOS/SwiftUI

#### Inputs
- Current `HybridCreditManager.swift`, `QuotaService.swift`, `QuotaInfo.swift`
- New backend API from Phase 2
- Existing cache patterns (`QuotaCache`)

#### Tasks
1. Create new models:
   - `CreditBalance.swift` (balance, lifetime stats, isPremium)
   - `CreditTransaction.swift` (transaction details)
   - `CreditError.swift` (error types)
2. Create `CreditService.swift` (network layer):
   - `getCredits()` - RPC call to `get_credits`
   - `deductCredits()` - RPC call to `deduct_credits`
3. Create `CreditManager.swift` (orchestrator):
   - Replace `@Published var dailyQuotaUsed/Limit` with `creditBalance`
   - Replace `loadQuota()` with `loadCredits()`
   - Replace `consumeQuota()` with `deductCredits()`
   - Keep premium status integration with StoreKit
4. Create `CreditCache.swift` (local storage)
5. Update `StoreKitService.swift`:
   - Add credit sync after purchase (optional: grant bonus credits)
6. Test locally with `supabase start`

#### Outputs
- ✅ `CreditManager.shared.creditBalance` returns current balance
- ✅ `CreditManager.shared.canProcessImage()` checks credits
- ✅ Premium users see unlimited credits
- ✅ Cache persists across app launches

#### Risks & Mitigation
- **Risk**: Cache corruption causes incorrect balance display → **Mitigation**: Cache is read-only display, always fetch from server on critical operations
- **Risk**: Concurrent credit operations cause race conditions → **Mitigation**: Use `actor` for CreditService (already planned)

---

### Phase 4: ViewModels Update
**Duration**: 2-3 hours
**Owner**: iOS/MVVM

#### Inputs
- Updated `CreditManager` from Phase 3
- Current ViewModels: `ChatViewModel`, `LibraryViewModel`, `ProfileView`

#### Tasks
1. Update `ChatViewModel.swift`:
   - Replace `dailyQuotaUsed`/`dailyQuotaLimit` computed properties with `creditBalance`
   - Update quota check: `if dailyQuotaUsed >= dailyQuotaLimit` → `if !creditManager.canProcessImage()`
   - Update error messages: "Daily limit reached" → "Insufficient credits"
2. Update `LibraryViewModel.swift`:
   - Replace quota references with credit references (if any)
3. Update any other ViewModels that reference quota

#### Outputs
- ✅ ViewModels read from `CreditManager.creditBalance`
- ✅ Image processing gates on credit availability
- ✅ Error messages reference "credits" not "quota"

#### Risks & Mitigation
- **Risk**: Missed ViewModel references cause crashes → **Mitigation**: Global search for `dailyQuota`, `remainingQuota`, `QuotaInfo` before QA

---

### Phase 5: UI Components Update
**Duration**: 2-3 hours
**Owner**: iOS/SwiftUI

#### Inputs
- Updated ViewModels from Phase 4
- Current UI: `QuotaDisplayView`, `UnifiedHeaderBar`, paywall screens

#### Tasks
1. Rename `QuotaDisplayView.swift` → `CreditDisplayView.swift`:
   - Change text: "Daily Credits" → "Credits"
   - Update formatting: "X / Y" → "X credits" or "Unlimited"
   - Update icon logic (keep star for free, infinity for premium)
2. Update `UnifiedHeaderBar.swift`:
   - Replace `QuotaDisplayView` with `CreditDisplayView`
3. Update paywall messaging:
   - "Upgrade for unlimited daily generations" → "Upgrade for unlimited credits"
4. Update any banners/alerts that mention "daily quota"
5. Add low credit warning (if balance < 5 credits)

#### Outputs
- ✅ All UI shows "Credits" instead of "Daily Quota"
- ✅ Premium users see "Unlimited" or "∞"
- ✅ Low credit warnings appear before running out

#### Risks & Mitigation
- **Risk**: Inconsistent terminology confuses users → **Mitigation**: Global text audit, update all strings in single commit

---

### Phase 6: Testing & Validation
**Duration**: 4-6 hours
**Owner**: QA / Full-stack

#### Tasks
1. **Idempotency tests**:
   - Call `deduct_credits` with same `request_id` twice → should return cached result
   - Verify no double-charging in `credit_transactions` table
2. **Insufficient credits**:
   - Set balance to 0 → attempt image processing → should show paywall
3. **Premium bypass**:
   - Active subscription → should bypass credit checks entirely
4. **Refund on failure**:
   - Simulate AI failure → verify credit refund via `add_credits`
5. **Edge cases**:
   - Negative balance (should be prevented by CHECK constraint)
   - Concurrent requests (test race conditions)
6. **End-to-end flow**:
   - New user signup → gets 10 free credits
   - Process 10 images → balance reaches 0
   - Purchase credits → balance increases
   - Premium subscription → unlimited credits

#### Outputs
- ✅ All test scenarios pass
- ✅ No double-charging bugs
- ✅ Refunds work correctly
- ✅ Premium users unaffected

#### Risks & Mitigation
- **Risk**: Edge cases missed in testing → **Mitigation**: Run automated test suite, monitor Sentry/logs post-launch

---

### Phase 7: Cleanup & Deprecation
**Duration**: 2-3 hours
**Owner**: Backend + iOS

#### Tasks
1. **Database cleanup**:
   - Drop old tables: `daily_quotas`, `quota_consumption_log`
   - Drop old functions: `consume_quota`, `get_quota`, `refund_quota`
   - Remove old migrations: `017_create_daily_quota.sql`, `018_create_quota_functions.sql`
2. **iOS cleanup**:
   - Delete `HybridCreditManager.swift` (replaced by `CreditManager.swift`)
   - Delete `QuotaService.swift` (replaced by `CreditService.swift`)
   - Delete `QuotaInfo.swift` (replaced by `CreditBalance.swift`)
   - Delete `QuotaCache.swift` (replaced by `CreditCache.swift`)
   - Delete `QuotaError.swift` (replaced by `CreditError.swift`)
3. **Documentation updates**:
   - Update `DATABASE_SCHEMA.md` (remove quota tables, add credit tables)
   - Update `API_REFERENCE.md` (remove quota RPCs, add credit RPCs)
   - Update `PROJECT_OVERVIEW.md` (quota → credit terminology)

#### Outputs
- ✅ No dead code remains
- ✅ Documentation reflects new credit system
- ✅ Codebase is clean for future development

#### Risks & Mitigation
- **Risk**: Accidentally delete code still in use → **Mitigation**: Run full test suite after cleanup, check for compile errors

---

## Deployment Strategy

### Pre-Deployment Checklist
- [ ] All Phase 1-6 tasks completed
- [ ] Staging environment fully tested
- [ ] Rollback plan documented (restore old quota tables from backup)
- [ ] Low-traffic deployment window scheduled
- [ ] Team on standby for monitoring

### Deployment Order
1. **Database migration** (Phase 1) → Run `052_create_credit_system.sql` on production
2. **Edge Function update** (Phase 2) → Deploy `process-image` function
3. **iOS app update** (Phase 3-5) → Submit to App Store, force update recommended
4. **Monitor for 24-48 hours** → Watch error rates, Sentry alerts, user feedback
5. **Cleanup** (Phase 7) → After confidence period, remove old tables/code

### Rollback Plan
If critical issues arise within 24 hours:
1. Redeploy old `process-image` Edge Function (git revert)
2. Restore old quota tables from database backup
3. Force old iOS app version (or hotfix release)
4. Investigate root cause before retry

---

## Success Metrics

### Technical Metrics
- ✅ Zero credit double-charges (idempotency working)
- ✅ Refund rate < 5% (AI processing reliability)
- ✅ Credit balance sync accuracy > 99%
- ✅ Premium bypass working 100% of time

### User Metrics
- ✅ No increase in support tickets about "lost credits"
- ✅ Paywall conversion rate maintained or improved
- ✅ User retention unaffected by migration
- ✅ Positive sentiment on credit system (App Store reviews)

---

## Timeline Summary

| Phase | Duration | Dependencies | Owner |
|-------|----------|--------------|-------|
| 1. Database | 4-6 hours | None | Backend |
| 2. Edge Function | 2-3 hours | Phase 1 | Backend |
| 3. iOS Services | 6-8 hours | Phase 2 | iOS |
| 4. ViewModels | 2-3 hours | Phase 3 | iOS |
| 5. UI Components | 2-3 hours | Phase 4 | iOS |
| 6. Testing | 4-6 hours | Phase 5 | QA |
| 7. Cleanup | 2-3 hours | Phase 6 | Full-stack |
| **TOTAL** | **22-32 hours** | — | **3-4 days** |

---

## Next Steps

1. **Review this plan** with team/stakeholders
2. **Create tickets** for each phase in project management tool
3. **Set up staging environment** for isolated testing
4. **Schedule deployment window** (weekend or low-traffic period)
5. **Begin Phase 1** (database migration)

**Questions?** Refer to:
- `FRONTEND_CREDIT_CHANGES.md` for iOS implementation details
- `BACKEND_CREDIT_CHANGES.md` for Edge Function changes
- `DATABASE_CREDIT_CHANGES.md` for SQL migration specifics
