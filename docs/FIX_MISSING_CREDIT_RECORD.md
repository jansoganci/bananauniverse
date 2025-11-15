# Fix Missing Credit Record

## Problem
Device ID `E2B177B4-B4F9-4738-9629-7D4CB46869DC` doesn't exist in database because:
1. Network call failed before `get_credits` could auto-create the record
2. `get_credits` only creates records when it successfully runs

## Solution: Manually Create Record

### Step 1: Create Record in Database

Run this SQL in your Supabase SQL Editor:

```sql
-- Insert record for your device with 10 credits
INSERT INTO anonymous_credits (device_id, credits)
VALUES ('E2B177B4-B4F9-4738-9629-7D4CB46869DC', 10)
ON CONFLICT (device_id) 
DO UPDATE SET 
    credits = 10,
    updated_at = NOW();
```

This will:
- Create the record if it doesn't exist
- Set credits to 10
- Update if record already exists

### Step 2: Verify Record Created

```sql
-- Check if record exists
SELECT device_id, credits, created_at, updated_at
FROM anonymous_credits
WHERE device_id = 'E2B177B4-B4F9-4738-9629-7D4CB46869DC';
```

### Step 3: Test App Again

1. Close and reopen the app
2. Check logs - should see successful credit load
3. Credits should show 10

## Alternative: Fix Network Issue First

If network keeps failing, check:
1. Supabase URL is correct
2. Network connectivity
3. Supabase service is running

Once network works, `get_credits` will auto-create the record.

## Why This Happened

The `get_credits` function has this logic:
```sql
IF NOT FOUND THEN
    INSERT INTO anonymous_credits (device_id, credits)
    VALUES (p_device_id, 10)
    RETURNING credits INTO v_balance;
END IF;
```

But this only runs if the function executes successfully. Since the network call failed, the function never ran, so no record was created.

