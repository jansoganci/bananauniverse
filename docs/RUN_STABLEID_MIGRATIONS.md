# How to Run StableID Recovery Migrations

## ⚠️ IMPORTANT: Run in Order

These migrations MUST be run in the correct order. Do not skip any.

## Step 1: Create Device Mapping Table

**File:** `supabase/migrations/099_create_device_user_map.sql`

1. Open Supabase Dashboard → SQL Editor
2. Copy the entire contents of `099_create_device_user_map.sql`
3. Paste and click "Run"
4. You should see: `✅ Created device_user_map table for StableID tracking`

## Step 2: Create Recovery RPC

**File:** `supabase/migrations/100_create_recover_or_init_user.sql`

1. Copy the entire contents of `100_create_recover_or_init_user.sql`
2. Paste in SQL Editor and click "Run"
3. You should see: `✅ Created recover_or_init_user RPC for StableID-based credit recovery`

## Step 3: Update Auth Trigger

**File:** `supabase/migrations/101_update_auth_trigger_for_stableid.sql`

1. Copy the entire contents of `101_update_auth_trigger_for_stableid.sql`
2. Paste in SQL Editor and click "Run"
3. You should see: `✅ Updated auth trigger - credits now managed by StableID recovery system`

## Verification

After running all migrations, verify they worked:

```sql
-- Check if table exists
SELECT * FROM device_user_map LIMIT 1;

-- Check if RPC exists
SELECT proname FROM pg_proc WHERE proname = 'recover_or_init_user';

-- Check if trigger is updated
SELECT tgname FROM pg_trigger WHERE tgname = 'on_auth_user_created';
```

## Testing the System

After migrations are complete:

1. **Clean Test:** Delete the app from simulator, reinstall
2. **Launch:** Open the app and check logs for:
   ```
   🔄 [HybridAuth] Running credit recovery for device: [YOUR_STABLE_ID]
   ✅ [HybridAuth] Recovery complete: 10 credits, new device: true
   ```
3. **Spend a Credit:** Create an image (10 → 9 credits)
4. **Restart App:** Close and reopen
5. **Verify:** You should still have 9 credits (NOT 10!)

## Expected Behavior

### First Launch (New Device)
- User gets 10 credits
- `device_user_map` creates entry: `StableID → UserID`

### Subsequent Launches (Same Device)
- If session exists: Uses existing user, same credits
- If session lost: Creates new user, transfers credits from old user via StableID

### Credit Changes
- Credits only change when user spends/earns them
- Never reset to 10 on app restart

## Troubleshooting

### Issue: Still getting 10 credits on restart

**Check:**
1. Did all 3 migrations run successfully?
2. Is the iOS app using the new build? (Check build timestamp)
3. Check logs for `recover_or_init_user` being called

**Debug Query:**
```sql
-- See what's in the mapping table
SELECT * FROM device_user_map;

-- See all anonymous users
SELECT id, created_at, is_anonymous FROM auth.users WHERE is_anonymous = true;
```

### Issue: RPC fails with "function does not exist"

**Solution:**
- Re-run migration 100
- Check function permissions:
```sql
SELECT * FROM pg_proc WHERE proname = 'recover_or_init_user';
```

### Issue: Credits not transferring

**Check:**
1. Old user ID exists in `user_credits`
2. StableID is consistent (check iOS logs)
3. RPC response shows `success: true`

**Debug:**
```sql
-- Manually test the RPC (replace with your StableID)
SELECT recover_or_init_user('705048225038102432');
```

## Rollback (Emergency Only)

If you need to revert:

```sql
-- Drop new objects
DROP FUNCTION IF EXISTS recover_or_init_user(TEXT);
DROP TABLE IF EXISTS device_user_map;

-- Restore old trigger (from migration 098)
-- (Copy the old trigger code from 098_fix_auth_triggers.sql)
```

Then revert iOS code changes and rebuild.

## Support

If issues persist, check:
- `docs/STABLEID_RECOVERY_IMPLEMENTATION.md` for detailed implementation
- `docs/BUG_ANALYSIS_CREDIT_LOOP.md` for root cause analysis
- Supabase logs for RPC errors
- iOS logs for recovery flow

