# How to Find Device ID

## Current Status
❌ **Device ID is NOT logged in current logs**

## How to Find Device ID

### Method 1: Check UserDefaults (iOS Simulator/Device)
The device ID is stored in UserDefaults with key: `device_uuid_v1`

**In Xcode Console:**
```swift
// Add this to your app temporarily to print device ID
print("Device ID: \(UserDefaults.standard.string(forKey: "device_uuid_v1") ?? "NOT FOUND")")
```

### Method 2: Check Database (After Adding Logging)
After the fix I just added, logs will show:
```
📱 [CREDITS] Loading for anonymous device: <device-id-here>
```

### Method 3: Query Database Directly
If you know the device is anonymous, check:
```sql
SELECT device_id, credits, created_at, updated_at
FROM anonymous_credits
ORDER BY updated_at DESC
LIMIT 10;
```

This will show recent devices. Match by:
- `updated_at` timestamp (when credits were last updated)
- `credits` value (should match what you see in app)

### Method 4: Add Debug Print (Temporary)
Add this to `BananaUniverseApp.swift`:
```swift
.task {
    let deviceId = CreditManager.shared.getDeviceUUID()
    print("🔍 [DEBUG] Device ID: \(deviceId)")
    await CreditManager.shared.initializeNewUser()
}
```

## What I Just Fixed
✅ Added logging to show device_id/user_id when loading credits
✅ Device ID will now appear in logs like:
   - `📱 [CREDITS] Loading for anonymous device: <uuid>`
   - `👤 [CREDITS] Loading for authenticated user: <user-id>`

## Next Steps
1. Run the app again
2. Check logs for the device ID
3. Use that device ID to query `anonymous_credits` table

