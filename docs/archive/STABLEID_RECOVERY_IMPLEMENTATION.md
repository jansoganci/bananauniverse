# StableID Credit Recovery System - Implementation Summary

## Problem Solved
The app was creating a new anonymous user on every launch, granting 10 fresh credits each time. This caused credit inflation (10 → 19 → 27) as the migration system accumulated credits from abandoned users. The root cause was Supabase session persistence failure, but StableID remained constant.

## Solution Implemented
Made StableID the master key for credit persistence. When a new anonymous user is created, the system checks if this StableID already exists. If it does, all data is transferred from the old user to the new user, then the old user is deleted.

## Files Created

### Backend (SQL Migrations)

#### 1. `supabase/migrations/099_create_device_user_map.sql`
- Created `device_user_map` table to track StableID → UserID mapping
- Stores current user ID and array of previous user IDs (audit trail)
- Indexed for fast lookups

#### 2. `supabase/migrations/100_create_recover_or_init_user.sql`
- Created `recover_or_init_user(p_device_id TEXT)` RPC function
- Logic:
  - **New Device:** Initialize with 10 credits, create mapping
  - **Same User:** Return current credits (no action needed)
  - **Existing Device, New User:** Transfer all data from old user to new user, delete old user
- Returns: credits_remaining, credits_total, jobs_moved, transactions_moved

#### 3. `supabase/migrations/101_update_auth_trigger_for_stableid.sql`
- Modified `handle_new_user_consolidated` trigger
- **Removed:** Automatic 10 credit grant on user creation
- Now only creates profile, credits are handled by iOS app via RPC

### iOS (Swift)

#### 1. `BananaUniverse/Core/Services/HybridAuthService.swift`
**Modified `checkAndMigrateLegacyData()`:**
- Removed UserDefaults migration check (runs every time now)
- Calls `recover_or_init_user` RPC instead of `migrate_device_data`
- Parses response and updates CreditManager with recovered balance
- Falls back to normal credit loading if RPC fails

#### 2. `BananaUniverse/Core/Services/CreditManager.swift`
**Added `updateFromRecovery(credits: Int)`:**
- Bypasses normal `loadQuota()` flow
- Directly sets recovered credit balance
- Called by HybridAuthService after successful recovery

## How It Works

### Flow Diagram
```
App Launch
    ↓
HybridAuthService.checkCurrentUser()
    ↓
Try to restore session
    ↓
If no session → signInAnonymously() (creates new user)
    ↓
checkAndMigrateLegacyData()
    ↓
Call recover_or_init_user(StableID)
    ↓
Database checks device_user_map:
    ├─ New Device → Initialize 10 credits
    ├─ Same User → Return current credits
    └─ Existing Device, New User → Transfer & Delete old user
    ↓
Return recovered credits to iOS
    ↓
CreditManager.updateFromRecovery(credits)
    ↓
User sees correct balance
```

## Key Benefits

1. **StableID is Master:** Credits tied to device, not fragile JWT session
2. **No Credit Inflation:** Old users deleted after transfer, preventing accumulation
3. **Seamless Recovery:** Users never lose credits, even if session is lost
4. **Backward Compatible:** Existing users will have credits recovered on next launch
5. **Audit Trail:** Previous user IDs tracked in `device_user_map`

## Testing Scenarios

### Scenario 1: Fresh Install (New Device)
- **Expected:** User gets 10 credits
- **Verification:** Check `device_user_map` has new entry

### Scenario 2: App Restart (Same Session)
- **Expected:** User keeps same credits (e.g., 9 after spending 1)
- **Verification:** Credits should not change

### Scenario 3: Session Loss (New User Created)
- **Expected:** Credits recovered from old user via StableID
- **Verification:** Old user deleted, credits transferred to new user

### Scenario 4: Multiple Restarts
- **Expected:** Credits never increase unexpectedly
- **Verification:** Balance should only change when user spends/earns credits

## SQL Migrations to Run

Run these in Supabase SQL Editor in order:

1. `supabase/migrations/099_create_device_user_map.sql`
2. `supabase/migrations/100_create_recover_or_init_user.sql`
3. `supabase/migrations/101_update_auth_trigger_for_stableid.sql`

## Verification Queries

```sql
-- Check device mapping
SELECT * FROM device_user_map WHERE device_id = 'YOUR_STABLE_ID';

-- Check user credits
SELECT * FROM user_credits WHERE user_id = 'YOUR_USER_ID';

-- Check if old users are being deleted
SELECT COUNT(*) FROM auth.users WHERE is_anonymous = true;
```

## Logs to Monitor

### iOS Logs
```
🔄 [HybridAuth] Running credit recovery for device: 705048225038102432
✅ [HybridAuth] Recovery complete: 9 credits, new device: false, jobs moved: 0
💾 [CREDITS] Recovered from StableID: 9 credits
```

### Database Logs
```
[RECOVERY] New device detected: 705048225038102432
[RECOVERY] Initialized new device with 10 credits

OR

[RECOVERY] Transferring from old user ABC to new user XYZ
[RECOVERY] Transfer complete: 9 credits, 5 jobs, 3 transactions
```

## Rollback Plan

If issues occur, you can temporarily revert by:

1. Restore old `handle_new_user_consolidated` trigger (from migration 098)
2. Update iOS to call old `migrate_device_data` RPC
3. Add back UserDefaults check in `checkAndMigrateLegacyData`

However, this will bring back the credit inflation bug.

## Date Implemented
2025-11-30

## Status
✅ **COMPLETE** - All migrations created, iOS code updated, build successful

