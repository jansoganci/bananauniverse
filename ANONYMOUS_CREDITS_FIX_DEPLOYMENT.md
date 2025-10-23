# 🔧 Anonymous Credits Bug Fix - Deployment Guide

## 📋 Summary

Fixed the "Anonymous credits record not found" bug that prevented new users from generating images.

### ✅ What Was Fixed

**Backend (Supabase)**
- Added self-healing logic to `validate_user_daily_quota()` and `validate_anonymous_daily_quota()` SQL functions
- Automatically creates missing credit records instead of returning errors
- Handles race conditions gracefully with `ON CONFLICT DO NOTHING`
- Logs self-healing events for monitoring

**iOS (Swift)**
- Improved async credit loading with proper error handling
- Added `creditsLoaded` state tracking to prevent premature UI enabling
- Enhanced fallback logic for offline scenarios
- Better logging for debugging new user flows

---

## 🚀 Deployment Steps

### Phase 1: Backend Deployment (Supabase)

#### 1. Apply Database Migration

```bash
cd /Users/jans./Downloads/BananaUniverse

# Link to your Supabase project (if not already linked)
npx supabase link --project-ref YOUR_PROJECT_REF

# Apply the new migration
npx supabase db push
```

Expected output:
```
✅ Migration 016_add_self_healing_quota_validation.sql applied successfully
```

#### 2. Verify Database Functions

Run this SQL query in Supabase Dashboard → SQL Editor:

```sql
-- Test anonymous quota validation with non-existent device
SELECT validate_anonymous_daily_quota('test-device-new-user', false);

-- Expected result: Should create record and return valid=true
-- Check the anonymous_credits table
SELECT * FROM anonymous_credits WHERE device_id = 'test-device-new-user';
-- Should show new record with 10 credits

-- Clean up test data
DELETE FROM anonymous_credits WHERE device_id = 'test-device-new-user';
```

#### 3. Deploy Edge Function (if needed)

The `process-image` Edge Function only has logging improvements, so deployment is optional:

```bash
npx supabase functions deploy process-image
```

---

### Phase 2: iOS Deployment

#### 1. Build & Test Locally (Xcode Simulator)

1. Open `BananaUniverse.xcodeproj` in Xcode
2. **CRITICAL**: Delete the app from simulator to test fresh install
   - iOS Simulator → Long press app → Delete App
3. Build and Run (⌘R)
4. Check Xcode console for logs:
   ```
   ✅ New user - starting with 10 free credits
   ⚠️ Backend record will be auto-created on first Generate
   ```

#### 2. TestFlight Deployment

1. **Archive the build**:
   - Xcode → Product → Archive
   - Wait for archiving to complete

2. **Upload to TestFlight**:
   - Organizer → Distribute App → TestFlight
   - Upload and wait for processing

3. **Test with fresh TestFlight install**:
   - Install app on physical iPhone 16 (not updated, fresh install)
   - Launch app
   - Navigate to Image Upscaler
   - Upload an image
   - Click Generate
   - **Expected**: Image generation succeeds ✅
   - Check credits: Should show 9/10 remaining

---

## 🧪 Testing Checklist

### Test Case 1: Brand New Anonymous User (iPhone 16)

**Setup**: Fresh TestFlight install, never launched before

| Step | Action | Expected Result |
|------|--------|----------------|
| 1 | Launch app | App loads successfully |
| 2 | Check credit display | Shows "10 credits" |
| 3 | Navigate to Image Upscaler | UI loads |
| 4 | Upload test image | Image appears |
| 5 | Enter prompt "make it colorful" | Generate button enabled |
| 6 | Click Generate | ✅ Processing starts |
| 7 | Wait for completion | ✅ Processed image appears |
| 8 | Check credits | Shows "9 credits" |
| 9 | Check Supabase logs | See: `[STEVE-JOBS] Self-healed missing record...` |

**Success Criteria**: Image generation works without "record not found" error

---

### Test Case 2: Existing Anonymous User

**Setup**: User who already has credit record in Supabase

| Step | Action | Expected Result |
|------|--------|----------------|
| 1 | Launch app | Shows existing credit balance |
| 2 | Generate image | ✅ Works as before |
| 3 | Check Supabase logs | No self-healing messages (record exists) |

**Success Criteria**: No regression, existing users unaffected

---

### Test Case 3: New Apple Sign-In User

**Setup**: Fresh TestFlight install, sign in with Apple ID

| Step | Action | Expected Result |
|------|--------|----------------|
| 1 | Launch app | App loads |
| 2 | Sign in with Apple | Authentication succeeds |
| 3 | Check credits | Shows "10 credits" |
| 4 | Generate image | ✅ Processing succeeds |
| 5 | Check Supabase | `user_credits` record auto-created |

**Success Criteria**: Authenticated users get self-healed records

---

### Test Case 4: Offline → Online Transition

**Setup**: Fresh install, airplane mode ON

| Step | Action | Expected Result |
|------|--------|----------------|
| 1 | Launch app (offline) | Shows "10 credits" (local fallback) |
| 2 | Try to generate | ❌ Network error (expected) |
| 3 | Enable internet | Connection restored |
| 4 | Try generate again | ✅ Backend creates record, succeeds |

**Success Criteria**: Graceful offline handling, self-healing on reconnect

---

## 📊 Monitoring & Verification

### 1. Check Supabase Logs

Dashboard → Logs → Edge Functions → Filter: `process-image`

Look for these log patterns:

**✅ Successful Self-Healing**
```
[STEVE-JOBS] Quota validation passed
🔧 [STEVE-JOBS] Self-healed missing record for anonymous user: ABC123
✅ [STEVE-JOBS] Credit consumed successfully: 9 credits remaining
```

**❌ Still Failing (Should NOT see this)**
```
❌ [STEVE-JOBS] Quota validation failed: Anonymous credits record not found
```

### 2. Database Verification

Check that new records are being created:

```sql
-- Recent anonymous users (last 24 hours)
SELECT 
  device_id,
  credits,
  created_at,
  updated_at
FROM anonymous_credits
WHERE created_at > NOW() - INTERVAL '24 hours'
ORDER BY created_at DESC
LIMIT 20;

-- Recent authenticated users
SELECT 
  user_id,
  credits,
  created_at
FROM user_credits
WHERE created_at > NOW() - INTERVAL '24 hours'
ORDER BY created_at DESC
LIMIT 20;
```

### 3. iOS Console Logs (Debug Build)

Expected log sequence for new user:

```
🔍 Loading credits...
✅ New user - starting with 10 free credits
⚠️ Backend record will be auto-created on first Generate
✅ Anonymous credits loaded successfully: 10

[User clicks Generate]

🔍 canProcessImage() - Starting check
🔍 isPremiumUser: false
🔍 Non-premium user - checking credits and quota
🔍 Credits: 10, Daily quota: 0/5
🔍 Quota check result: true
```

---

## 🐛 Troubleshooting

### Issue: Migration Fails

**Symptom**: `npx supabase db push` fails

**Solution**:
```bash
# Check migration status
npx supabase migration list

# If migration is applied but erroring, check Postgres logs
npx supabase db logs
```

### Issue: Still Getting "Record Not Found"

**Check**:
1. Verify migration 016 is applied:
   ```sql
   SELECT * FROM supabase_migrations 
   WHERE name LIKE '%016%';
   ```

2. Test function directly:
   ```sql
   SELECT validate_anonymous_daily_quota('test-abc', false);
   ```
   Should return `valid: true`, not error

3. Check RLS policies:
   ```sql
   SELECT * FROM pg_policies 
   WHERE tablename IN ('anonymous_credits', 'user_credits');
   ```

### Issue: iOS Shows Wrong Credit Count

**Check**:
1. Delete app and reinstall (fresh state)
2. Check UserDefaults isn't cached:
   ```swift
   // In Xcode console
   po UserDefaults.standard.dictionaryRepresentation()
   ```
3. Verify `creditsLoaded` is true before Generate button enables

---

## 🎯 Success Metrics

After deployment, monitor these metrics for 48 hours:

| Metric | Target | How to Check |
|--------|--------|--------------|
| New user signup → first generation success rate | > 95% | Supabase logs + analytics |
| "Record not found" errors | 0 | Search Supabase logs |
| Self-healing events | > 0 | Count `Self-healed` log entries |
| Image generation errors (new users) | < 1% | Edge Function error rate |
| TestFlight crash rate | < 0.1% | App Store Connect |

---

## 📝 Rollback Plan

If critical issues arise:

### Rollback Backend

```bash
# Revert migration
npx supabase db reset --db-url YOUR_CONNECTION_STRING

# Or manually update functions to previous version
# Use migration 012_add_quota_validation_functions.sql
```

### Rollback iOS

1. Go to App Store Connect → TestFlight
2. Remove problematic build
3. Re-enable previous working build
4. Notify testers

---

## 🔐 Security Considerations

✅ **Safe**: Self-healing only creates records with default values (10 credits, quota 5/day)
✅ **Idempotent**: `ON CONFLICT DO NOTHING` prevents duplicates
✅ **Logged**: All self-healing events are logged for audit
✅ **RLS Protected**: Functions use `SECURITY DEFINER` but respect RLS
⚠️ **Monitor**: Watch for abnormal spike in credit creation (abuse detection)

---

## 📞 Support

**If deployment fails**:
1. Check this guide's Troubleshooting section
2. Review Supabase logs for error details
3. Test with fresh device install
4. Contact team if issue persists

**Post-Deployment**:
- Monitor Supabase logs for 24 hours
- Check TestFlight feedback
- Verify analytics show increased success rate

---

## ✅ Deployment Checklist

- [ ] Backend migration 016 applied successfully
- [ ] Database functions tested manually
- [ ] Edge Function deployed (optional)
- [ ] iOS app built and archived
- [ ] TestFlight build uploaded and processed
- [ ] Test Case 1 (new user) passed on iPhone 16
- [ ] Test Case 2 (existing user) passed
- [ ] Test Case 3 (Apple Sign-In) passed
- [ ] Supabase logs show self-healing events
- [ ] No "record not found" errors in logs
- [ ] Credits correctly sync between iOS and backend
- [ ] Production monitoring active

---

**Deployment Date**: _______________
**Deployed By**: _______________
**Build Number**: _______________
**Notes**: _______________

---

## 🎉 Expected Results

After successful deployment:

| User Type | Before | After |
|-----------|--------|-------|
| New anonymous user | ❌ "Record not found" error | ✅ Works, auto-creates record |
| New Apple Sign-In user | ❌ Failed | ✅ Works, auto-creates record |
| Existing user | ✅ Works | ✅ Still works |
| My device (testing) | ✅ Works | ✅ Still works |
| Fresh TestFlight install | ❌ Failed | ✅ Works perfectly |

**Backend Logs Expected**:
```
[STEVE-JOBS] Quota validation passed ✅
🔧 [STEVE-JOBS] Self-healed missing record for anonymous user: DEVICE_ID
✅ [STEVE-JOBS] Credit consumed successfully: 9 credits remaining
```

---

*End of Deployment Guide*

