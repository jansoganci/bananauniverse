# 🔐 Authentication 401 Error Fix - Summary

## 📋 Problem Description

**Issue**: Authenticated users (Apple Sign-In) getting **401 Unauthorized** when trying to generate images.

**Error in Supabase Logs**:
```
POST | 401 | https://...supabase.co/functions/v1/process-image
```

**Affected Users**: 
- ✅ Works: Users on devices where it worked before
- ❌ Fails: Fresh TestFlight installs with Apple Sign-In
- ❌ Fails: Users who logout → login again

---

## 🔍 Root Cause

The iOS app was sending the **anon key** instead of the user's **actual JWT token** in the Authorization header.

### What Was Happening:

**iOS Side** (SupabaseService.swift:158):
```swift
// ❌ WRONG - Always sending anon key
request.setValue("Bearer \(Config.supabaseAnonKey)", forHTTPHeaderField: "Authorization")
```

**Backend Side** (process-image/index.ts:84-95):
```typescript
const { data: { user }, error } = await supabase.auth.getUser(token);

if (error || !user) {
  // ❌ This fails because anon key is not a valid user JWT
  throw new Error('Invalid token');
}
```

**Result**: 
- Backend tries to validate anon key as user token → fails
- Falls back to check for `device_id` in request body
- No `device_id` provided → returns **401 Unauthorized**

---

## ✅ Solution Implemented

### 1. **Backend Fix** - Better Error Logging

Added comprehensive logging to `process-image/index.ts`:

```typescript
// Before
catch (error) {
  if (!device_id) {
    return new Response(
      JSON.stringify({ success: false, error: 'Authentication required' }),
      { status: 401 }
    );
  }
}

// After
catch (error: any) {
  console.log('⚠️ [STEVE-JOBS] JWT auth failed, checking for device_id fallback...');
  console.error('⚠️ [STEVE-JOBS] Auth error details:', error.message || error);
  
  if (!device_id) {
    console.error('❌ [STEVE-JOBS] No device_id provided for fallback - returning 401');
    return new Response(
      JSON.stringify({ 
        success: false, 
        error: 'Authentication failed and no device_id provided',
        details: error.message || 'Invalid or expired token'
      }),
      { status: 401 }
    );
  }
  
  console.log('🔓 [STEVE-JOBS] Falling back to anonymous user:', device_id);
}
```

**Benefits**:
- ✅ See exactly WHY authentication is failing
- ✅ Better error messages for debugging
- ✅ Clear logs when fallback to anonymous mode occurs

---

### 2. **iOS Fix** - Use Actual User Token

Updated `SupabaseService.swift` to send the correct token:

```swift
// CRITICAL FIX: Use actual user session token for authenticated users
if userState.isAuthenticated {
    // Get the user's session token
    if let session = try? await client.auth.session {
        request.setValue("Bearer \(session.accessToken)", forHTTPHeaderField: "Authorization")
        #if DEBUG
        print("🔑 Using authenticated user token for API call")
        #endif
    } else {
        // Fallback to anon key if session retrieval fails
        request.setValue("Bearer \(Config.supabaseAnonKey)", forHTTPHeaderField: "Authorization")
        #if DEBUG
        print("⚠️ Failed to get session, using anon key")
        #endif
    }
} else {
    // Anonymous users use anon key
    request.setValue("Bearer \(Config.supabaseAnonKey)", forHTTPHeaderField: "Authorization")
    #if DEBUG
    print("🔓 Using anon key for anonymous user")
    #endif
}
```

**Benefits**:
- ✅ Authenticated users send their real JWT token
- ✅ Backend can properly validate the user
- ✅ Falls back to anon key if session retrieval fails
- ✅ Debug logging shows which path is taken

---

### 3. **iOS Fix** - Add device_id Fallback for Everyone

Also updated the request body to ALWAYS include `device_id`:

```swift
// Add user identification and premium status
if userState.isAuthenticated {
    body["user_id"] = userState.identifier
    // ✅ NEW: Also add device_id as fallback for authenticated users
    body["device_id"] = await HybridCreditManager.shared.getDeviceUUID()
} else {
    body["device_id"] = userState.identifier
}
```

**Benefits**:
- ✅ If JWT validation fails, backend can fall back to device_id
- ✅ More resilient to token expiration issues
- ✅ Graceful degradation to anonymous mode

---

## 📊 Before vs After

### Before Fix

| User Type | Authorization Header | device_id in Body | Result |
|-----------|---------------------|-------------------|--------|
| Anonymous | `Bearer <anon-key>` | ✅ Yes | ✅ Works |
| Authenticated | `Bearer <anon-key>` ❌ | ❌ No | ❌ 401 Error |

### After Fix

| User Type | Authorization Header | device_id in Body | Result |
|-----------|---------------------|-------------------|--------|
| Anonymous | `Bearer <anon-key>` | ✅ Yes | ✅ Works |
| Authenticated | `Bearer <user-jwt>` ✅ | ✅ Yes (fallback) | ✅ Works |

---

## 🚀 Deployment Steps

### Phase 1: Deploy Backend (5 min)

```bash
cd /Users/jans./Downloads/BananaUniverse

# Deploy updated Edge Function with better logging
npx supabase functions deploy process-image
```

**Verify**:
- Check Supabase dashboard → Edge Functions → process-image
- Should show deployment version 14 (or latest)

---

### Phase 2: Deploy iOS (30 min)

1. **Build new version**:
   ```bash
   # Open Xcode
   xcodebuild -scheme BananaUniverse -project BananaUniverse.xcodeproj archive
   ```

2. **Upload to TestFlight**:
   - Xcode → Organizer → Distribute App
   - Upload build to App Store Connect
   - Wait for processing (~10 minutes)

3. **Test**:
   - Install from TestFlight on iPhone 16
   - Login with Apple Sign-In
   - Generate an image
   - **Expected**: ✅ Should work without 401 error

---

## 🧪 Testing Checklist

### Test Case 1: Fresh Anonymous User
- [ ] Install app (don't login)
- [ ] Generate image
- [ ] **Expected**: ✅ Works (uses anon key + device_id)

### Test Case 2: Fresh Apple Sign-In User
- [ ] Fresh TestFlight install
- [ ] Login with Apple Sign-In
- [ ] Generate image
- [ ] **Expected**: ✅ Works (uses user JWT token)
- [ ] Check Supabase logs: Should see `✅ Authenticated user: <user_id>`

### Test Case 3: Logout → Login Again
- [ ] Existing user logs out
- [ ] Login again with Apple Sign-In
- [ ] Generate image
- [ ] **Expected**: ✅ Works (new JWT token retrieved)

### Test Case 4: Token Expiration Fallback
- [ ] User logged in for several hours
- [ ] JWT might expire
- [ ] Generate image
- [ ] **Expected**: ✅ Still works (falls back to device_id)
- [ ] Check logs: Should see "Falling back to anonymous user"

---

## 📝 Expected Supabase Logs (After Fix)

### Successful Authenticated User:
```
🍎 [STEVE-JOBS] Process Image Request Started
🔍 [STEVE-JOBS] Processing request: {...}
🔑 [STEVE-JOBS] Attempting to validate JWT token...
✅ [STEVE-JOBS] Authenticated user: abc-123-def Premium: false
💳 [STEVE-JOBS] Validating credits and quota...
✅ [STEVE-JOBS] Quota validation passed: 10 credits, 0/5 quota
```

### Successful Anonymous User:
```
🍎 [STEVE-JOBS] Process Image Request Started
🔍 [STEVE-JOBS] Processing request: {...}
🔓 [STEVE-JOBS] No auth header provided, checking for device_id...
🔓 [STEVE-JOBS] Anonymous user: device-abc-123 Premium: false
💳 [STEVE-JOBS] Validating credits and quota...
🔧 [STEVE-JOBS] Self-healed missing record for anonymous user: device-abc-123
✅ [STEVE-JOBS] Quota validation passed: 10 credits, 0/5 quota
```

### Auth Failed → Fallback:
```
🍎 [STEVE-JOBS] Process Image Request Started
🔍 [STEVE-JOBS] Processing request: {...}
🔑 [STEVE-JOBS] Attempting to validate JWT token...
❌ [STEVE-JOBS] JWT validation error: Token expired
⚠️ [STEVE-JOBS] JWT auth failed, checking for device_id fallback...
🔓 [STEVE-JOBS] Falling back to anonymous user: device-abc-123
💳 [STEVE-JOBS] Validating credits and quota...
✅ [STEVE-JOBS] Quota validation passed: 9 credits, 1/5 quota
```

---

## 🔍 Debugging Commands

### Check Supabase Edge Function Logs:
```sql
-- Recent 401 errors
SELECT * FROM edge_function_logs
WHERE status_code = 401
AND created_at > NOW() - INTERVAL '1 hour'
ORDER BY created_at DESC;

-- Authentication attempts
SELECT * FROM edge_function_logs
WHERE event_message LIKE '%JWT%' OR event_message LIKE '%Authenticated%'
ORDER BY created_at DESC
LIMIT 20;
```

### Check iOS Console:
```swift
// In Xcode console, filter for:
🔑 Using authenticated user token for API call
🔓 Using anon key for anonymous user
⚠️ Failed to get session, using anon key
```

---

## 🐛 Troubleshooting

### Issue: Still Getting 401

**Check**:
1. **Is Edge Function deployed?**
   ```bash
   npx supabase functions list
   ```
   Should show `process-image` with latest version

2. **Is iOS app updated?**
   - Check build number in TestFlight
   - Verify you downloaded latest build

3. **Check Supabase logs** for the actual error:
   ```
   ❌ [STEVE-JOBS] JWT validation error: <error message>
   ```

4. **Is user actually logged in?**
   ```swift
   // In iOS app, check:
   print(HybridAuthService.shared.isAuthenticated)
   print(try? await supabase.auth.session)
   ```

---

### Issue: "Failed to get session"

**Possible Causes**:
- User logged out but app state not updated
- Session expired and refresh token invalid
- Network issue preventing token refresh

**Solution**:
- App will fallback to device_id (anonymous mode)
- User should logout and login again
- Or just continue as anonymous user

---

## 📊 Success Metrics

After deployment, monitor:

| Metric | Target | How to Check |
|--------|--------|--------------|
| 401 errors | 0 | Supabase Edge Function logs |
| Authenticated image generations | > 0 | Count of "Authenticated user" logs |
| Fallback to anonymous | < 5% | Count of "Falling back to anonymous" |
| User complaints about auth | 0 | Support tickets |

---

## 🔗 Files Modified

1. **supabase/functions/process-image/index.ts**
   - Lines 79-144: Enhanced authentication error logging
   - Added detailed error messages for debugging

2. **BananaUniverse/Core/Services/SupabaseService.swift**
   - Lines 125-186: Fixed to use actual user JWT token
   - Lines 139-145: Added device_id fallback for authenticated users
   - Added debug logging

---

## 🎯 Impact

### Before Fix:
- ❌ Authenticated users: **100% failure** rate on fresh installs
- ❌ Logout/login: **Always fails**
- ❌ No error logs to debug
- ✅ Anonymous users: Working

### After Fix:
- ✅ Authenticated users: **Should work** with proper JWT
- ✅ Logout/login: **Should work** (gets new JWT)
- ✅ Better logs: **Easy to debug** auth issues
- ✅ Graceful fallback: **Falls back to anonymous** if JWT fails
- ✅ Anonymous users: **Still working**

---

## 📚 Related Issues

- **Anonymous Credits Bug**: Fixed in migration `016_add_self_healing_quota_validation.sql`
- **This Fix**: Addresses authentication flow for Apple Sign-In users
- **Both Required**: For complete functionality

---

**Status**: Ready for Deployment ✅  
**Priority**: HIGH (blocks authenticated users)  
**Deployment Date**: _______________  
**Tested By**: _______________  
**Deployed By**: _______________  

---

*End of Fix Summary*

