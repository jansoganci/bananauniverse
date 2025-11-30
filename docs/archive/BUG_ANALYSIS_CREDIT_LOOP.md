# Credit Reset Loop Analysis

## The Issue
Every time the app restarts or authentication happens, the user is getting reset to **10 credits**, effectively granting free credits repeatedly or failing to persist their spent credits.

## Root Cause Analysis

### 1. The "Infinite New User" Loop
The core problem is likely that the **Anonymous User is being recreated** on every launch (or frequently), rather than being persisted.

**Evidence:**
*   Log: `User state transition: anonymous(...) → authenticated(...)`
*   The `authenticated` user ID (`CF3FCD90...`) has a `createdAt` timestamp of `2025-11-30 20:58:16`. This is extremely recent.
*   If the user ID changes on every launch, the Database Trigger (`handle_new_user_consolidated`) runs every time.
*   **Trigger Logic:** `INSERT INTO user_credits ... VALUES (NEW.id, 10)`.
*   **Result:** Every new anonymous user ID gets a fresh 10 credits.

### 2. Why is the User ID changing?
Supabase Anonymous Auth relies on a JWT stored in the Keychain.
*   If `Supabase.auth.signInAnonymously()` is called *without* a valid existing session, it creates a **new** user.
*   The logs show `Initial session emitted...` followed by `Attempting Supabase Anonymous Sign-In...`.
*   If the app calls `signInAnonymously()` *aggressively* even when a session might exist (or if session restoration fails), it generates a new user.

### 3. The Migration "Bonus"
*   You have a Stable ID (`7050...`). This is constant.
*   You have "legacy" credits attached to this Stable ID (let's say 9 credits).
*   **Step A:** App launches, creates NEW anonymous user (User X).
*   **Step B:** Trigger gives User X **10 credits**.
*   **Step C:** App calls `migrate_device_data`.
*   **Step D (The Merge Logic):** The RPC logic says:
    ```sql
    UPDATE user_credits SET credits = credits + (SELECT credits FROM old_device_record)
    ```
    It adds the old device credits (9) to the new user credits (10) = 19?
    *Wait*, usually the migration deletes the old record:
    ```sql
    DELETE FROM user_credits WHERE device_id = p_device_id;
    ```
    If the old record was deleted in a previous run, `SELECT credits` returns NULL/0.
    So the user just gets the 10 from the new account trigger.

**Scenario:**
1.  User spends 1 credit. Balance = 9.
2.  App restarts.
3.  New User Y created. Trigger gives 10 credits.
4.  App tries to migrate. Old device record is gone (migrated to User X).
5.  User Y has 10 credits. **User effectively reset to 10.**

### 4. Why is Session Persistence Failing?
*   **Log:** `Initial session emitted after attempting to refresh the local stored session... This is incorrect behavior...`
*   This suggests the Supabase Swift SDK is struggling with session persistence or the implementation in `HybridAuthService` is overriding it.
*   **Code in `HybridAuthService.checkCurrentUser()`:**
    ```swift
    if let session = try? await supabase.getCurrentSession() {
        // ...
    } else {
        try await signInAnonymously() // Creates NEW user
    }
    ```
    If `getCurrentSession()` throws or returns nil (which it might if the token is expired or storage is flaky), it creates a new user.

## Conclusion
The system is failing to persist the **Supabase User Session**. It treats every launch as a new user sign-up, granting the default 10 credits. The "StableID" is persisting, but since we migrated away from StableID-based credits to UserID-based credits, the StableID no longer holds the "truth" of the balance after the first migration.

## Recommended Fix Strategy (Do Not Implement Yet)
1.  **Trust the Session:** Ensure `HybridAuthService` doesn't aggressively create new users if a session exists.
2.  **Stop the Giveaway:** The Database Trigger grants 10 credits to *every* new anonymous user. If we can't guarantee session persistence, this model is flawed for anonymous apps.
    *   *Alternative:* Only grant credits if `is_anonymous` is FALSE? No, we want anon users to have credits.
    *   *Better:* We must fix the iOS session persistence.
3.  **Link StableID to UserID:** We need a way to say "This StableID (`7050...`) belongs to User ID (`CF3F...`)."
    *   If a new User ID is created for the same StableID, we should **link** it or **restore** the old User ID (impossible without auth).
    *   Actually, if the keychain is wiped, the User ID is lost forever for an anonymous user. That is the nature of anonymous auth.
    *   **BUT**, we have `StableID`. We should use `StableID` to look up the *existing* User ID if possible? No, we can't log in with just a UUID.

**The fundamental flaw:**
We moved from "Device ID = Identity" (Persistent) to "Anonymous JWT = Identity" (Fragile).
When the JWT is lost (app reinstall/session error), the identity is lost, and a new one (with fresh credits) is born.

**Solution:**
We need to rely on **StableID** as the source of truth for *existence*.
1.  When a new Anonymous User is created:
    *   Check if `StableID` already has a credit record (or a link to an old user).
    *   If yes, DO NOT give 10 free credits. Recover the old balance.
    *   If no, give 10 credits.

**Implementation Detail:**
*   Modify the `handle_new_user_consolidated` trigger or the migration logic.
*   Actually, simpler: The migration RPC should handle this.
    *   If `migrate_device_data` finds that this Device ID was *already migrated* (we need to track this), it should... do what?
    *   We need a table `device_user_map` (DeviceID -> UserID).
    *   If User X is lost, and User Y is created with DeviceID `7050...`:
        *   Look up `7050...` -> It maps to User X.
        *   Transfer credits from User X to User Y?
        *   This allows "Account Recovery" via StableID!

**Analysis Complete.** The problem is session loss + default credit grant on new user creation.

