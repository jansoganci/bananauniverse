# Backend Architecture: Authentication & Security

**Part 4 of 6** - Apple Sign-In, DeviceCheck, JWT tokens, and IAP verification

**Related Documents:**
- [backend-INDEX.md](./backend-INDEX.md) - Complete documentation index
- [backend-2-core-apis.md](./backend-2-core-apis.md) - API authentication flow
- [backend-5-credit-system.md](./backend-5-credit-system.md) - IAP purchase handling

---

## 🍎 Apple Sign-In Flow

### Overview

Users can sign in with Apple to:
- Migrate from guest to authenticated account
- Sync data across devices
- Access premium features (future)

### Flow Diagram

```
iOS App → Apple Sign-In → Supabase Auth → Database
   │           │              │              │
   │           │              │              │
   1. Request  2. Authenticate 3. Verify     4. Create/Merge
   Sign-In     User           Token          User Account
```

### Implementation

**iOS Side (Swift):**

```swift
import AuthenticationServices

func signInWithApple() async throws -> Session {
    let appleIDProvider = ASAuthorizationAppleIDProvider()
    let request = appleIDProvider.createRequest()
    request.requestedScopes = [.fullName, .email]
    
    let authorizationController = ASAuthorizationController(authorizationRequests: [request])
    
    // Handle authorization result
    // Send ID token to Supabase Auth
    let session = try await supabaseClient.auth.signInWithIdToken(
        credentials: .init(
            provider: .apple,
            idToken: idToken,
            nonce: nonce
        )
    )
    
    return session
}
```

**Backend Side:**

Supabase Auth handles Apple Sign-In automatically. The backend needs to:
1. Verify the token (handled by Supabase)
2. Check if user exists (by `apple_sub`)
3. Merge guest account if exists
4. Create new user or return existing

---

## 👤 Anonymous User Handling

### Guest User Creation

When a new device is onboarded:

1. **iOS generates device_id** (UUID)
2. **iOS requests DeviceCheck token** from Apple
3. **iOS calls `/device-check`** endpoint
4. **Backend verifies DeviceCheck token**
5. **Backend creates anonymous auth session**
6. **Backend creates user record** with `auth.uid()`

### Anonymous Auth Session

File: `supabase/functions/device-check/index.ts`

```typescript
// 3. Create anonymous auth session for new guest
const { data: authData, error: authError } = await supabaseClient.auth.signInAnonymously()

if (authError) throw authError

// 4. Create user record with auth.uid
const { data: newUser, error: userError } = await supabaseClient
  .from('users')
  .insert({
    id: authData.user.id, // Use auth user ID
    device_id: device_id,
    is_guest: true,
    tier: 'free',
    credits_remaining: 10,
    credits_total: 10,
    initial_grant_claimed: true
  })
  .select()
  .single()
```

### Benefits of Anonymous Auth

- **RLS works** - Users can query their own data
- **Realtime works** - Can subscribe to database changes
- **Secure** - Token-based authentication
- **Upgradeable** - Can merge with Apple Sign-In account

---

## 🛡️ DeviceCheck Verification

### Purpose

Prevents credit farming by:
- Verifying device is legitimate (not emulator)
- Tracking if device already claimed initial grant
- Preventing duplicate initial credit grants

### Implementation

File: `supabase/functions/_shared/device-check.ts`

```typescript
import * as jose from 'https://deno.land/x/jose@v4.14.4/index.ts'

interface DeviceCheckResult {
  valid: boolean
  is_first_time: boolean
}

export async function verifyDeviceToken(
  deviceToken: string,
  deviceId: string
): Promise<DeviceCheckResult> {
  
  // 1. Create JWT for DeviceCheck API
  const privateKey = Deno.env.get('APPLE_DEVICECHECK_PRIVATE_KEY')!
    .replace(/\\n/g, '\n')
  
  const algorithm = 'ES256'
  const key = await jose.importPKCS8(privateKey, algorithm)
  
  const jwt = await new jose.SignJWT({})
    .setProtectedHeader({ 
      alg: algorithm,
      kid: Deno.env.get('APPLE_DEVICECHECK_KEY_ID')!
    })
    .setIssuer(Deno.env.get('APPLE_TEAM_ID')!)
    .setIssuedAt()
    .setExpirationTime('1h')
    .sign(key)
  
  // 2. Query DeviceCheck API
  const queryResponse = await fetch(
    'https://api.devicecheck.apple.com/v1/query_two_bits',
    {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${jwt}`,
        'Content-Type': 'application/json'
      },
      body: JSON.stringify({
        device_token: deviceToken,
        transaction_id: deviceId,
        timestamp: Date.now()
      })
    }
  )
  
  if (!queryResponse.ok) {
    throw new Error('DeviceCheck verification failed')
  }
  
  const data = await queryResponse.json()
  
  // bit0 = false means device hasn't claimed initial grant yet
  const isFirstTime = data.bit0 === false
  
  // 3. If first time, mark bit0 as true
  if (isFirstTime) {
    await fetch(
      'https://api.devicecheck.apple.com/v1/update_two_bits',
      {
        method: 'POST',
        headers: {
          'Authorization': `Bearer ${jwt}`,
          'Content-Type': 'application/json'
        },
        body: JSON.stringify({
          device_token: deviceToken,
          transaction_id: deviceId,
          timestamp: Date.now(),
          bit0: true // Mark as used
        })
      }
    )
  }
  
  return {
    valid: true,
    is_first_time: isFirstTime
  }
}
```

### DeviceCheck Setup

1. **Create DeviceCheck key** in Apple Developer Portal
2. **Download private key** (.p8 file)
3. **Store in environment variables:**
   - `APPLE_DEVICECHECK_KEY_ID`
   - `APPLE_DEVICECHECK_PRIVATE_KEY`

---

## 🔑 JWT Token Management

### Token Types

1. **Access Token** - Short-lived (1 hour), used for API requests
2. **Refresh Token** - Long-lived (30 days), used to get new access tokens
3. **Anonymous Token** - Same structure, but for guest users

### Token Refresh

**Backend Helper:**

File: `supabase/functions/_shared/auth-helper.ts`

```typescript
import { SupabaseClient } from 'https://esm.sh/@supabase/supabase-js@2'

export async function getAuthenticatedUser(
  req: Request,
  supabaseClient: SupabaseClient
) {
  const authHeader = req.headers.get('Authorization')
  
  if (!authHeader) {
    throw new Error('Missing Authorization header')
  }
  
  const token = authHeader.replace('Bearer ', '')
  
  // Get user from token
  const { data: { user }, error } = await supabaseClient.auth.getUser(token)
  
  if (error || !user) {
    throw new Error('Invalid or expired token')
  }
  
  return user
}
```

**iOS Auto-Refresh:**

```swift
actor AuthService {
    static let shared = AuthService()
    private let supabaseClient: SupabaseClient
    
    private var refreshTask: Task<Session, Error>?
    
    func refreshTokenIfNeeded() async throws -> Bool {
        // Prevent concurrent refresh attempts
        if let existingTask = refreshTask {
            _ = try? await existingTask.value
            return true
        }
        
        guard let session = try? await supabaseClient.auth.session else {
            return false
        }
        
        // Check if token expires in < 5 minutes
        let expiresAt = session.expiresAt
        let now = Date().timeIntervalSince1970
        
        if expiresAt - now < 300 {
            let task = Task {
                try await supabaseClient.auth.refreshSession()
            }
            refreshTask = task
            defer { refreshTask = nil }
            
            do {
                _ = try await task.value
                return true
            } catch {
                return false
            }
        }
        
        return true
    }
}
```

**API Client Auto-Retry:**

```swift
private func executeWithRetry<T: Decodable>(
    request: URLRequest,
    attempt: Int = 1
) async throws -> T {
    do {
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AppError.invalidResponse
        }
        
        // Handle 401 Unauthorized
        if httpResponse.statusCode == 401 && attempt == 1 {
            // Try to refresh token
            if await AuthService.shared.refreshTokenIfNeeded() {
                // Retry request with new token
                return try await executeWithRetry(request: request, attempt: attempt + 1)
            }
        }
        
        try handleHTTPStatus(httpResponse.statusCode, data: data)
        return try decoder.decode(T.self, from: data)
        
    } catch {
        // ... existing retry logic ...
    }
}
```

### Token Revocation

When user signs out:

```swift
func signOut() async throws {
    try await supabaseClient.auth.signOut()
    // Clear local storage
    UserDefaultsManager.shared.currentUserId = nil
}
```

---

## 💳 In-App Purchase (IAP) Verification

### Purpose

Verify Apple IAP transactions server-side to prevent:
- Fake credit purchases
- Revenue loss from fraudulent transactions
- Duplicate credit grants

### Implementation

File: `supabase/functions/_shared/apple-iap.ts`

```typescript
import * as jose from 'https://deno.land/x/jose@v4.14.4/index.ts'

interface AppleVerificationResult {
  valid: boolean
  product_id: string
  original_transaction_id: string
  purchase_date: number
}

export async function verifyAppleTransaction(
  transactionId: string
): Promise<AppleVerificationResult> {
  
  // 1. Create JWT for Apple API authentication
  const privateKey = Deno.env.get('APPLE_PRIVATE_KEY')!
    .replace(/\\n/g, '\n')
  
  const algorithm = 'ES256'
  const key = await jose.importPKCS8(privateKey, algorithm)
  
  const jwt = await new jose.SignJWT({})
    .setProtectedHeader({ 
      alg: algorithm,
      kid: Deno.env.get('APPLE_KEY_ID')!
    })
    .setIssuer(Deno.env.get('APPLE_ISSUER_ID')!)
    .setAudience('appstoreconnect-v1')
    .setIssuedAt()
    .setExpirationTime('1h')
    .sign(key)
  
  // 2. Call Apple's App Store Server API
  const response = await fetch(
    `https://api.storekit.itunes.apple.com/inApps/v1/transactions/${transactionId}`,
    {
      headers: {
        'Authorization': `Bearer ${jwt}`,
        'Content-Type': 'application/json'
      }
    }
  )
  
  if (!response.ok) {
    const error = await response.text()
    throw new Error(`Apple verification failed: ${error}`)
  }
  
  // 3. Parse and validate response
  const data = await response.json()
  
  // Decode the signed transaction (JWS format)
  const { payload } = await jose.jwtVerify(
    data.signedTransaction,
    // Apple's public key verification (simplified - in production use Apple's certs)
    key
  )
  
  return {
    valid: true,
    product_id: payload.productId as string,
    original_transaction_id: payload.originalTransactionId as string,
    purchase_date: payload.purchaseDate as number
  }
}
```

### IAP Setup

1. **Create App Store Connect API key**
2. **Download private key** (.p8 file)
3. **Store in environment variables:**
   - `APPLE_KEY_ID`
   - `APPLE_ISSUER_ID`
   - `APPLE_PRIVATE_KEY`

### Usage in Credit Purchase Endpoint

See [backend-5-credit-system.md](./backend-5-credit-system.md) for complete IAP purchase flow.

---

## 🔒 Security Best Practices

### 1. Never Trust Client Data

- **Always verify IAP transactions** server-side
- **Never trust client-sent credit amounts** - look up in database
- **Validate all inputs** before processing

### 2. Use Row-Level Security (RLS)

- All tables have RLS enabled
- Users can only access their own data
- See [backend-1-overview-database.md](./backend-1-overview-database.md)

### 3. Secure Environment Variables

- Never commit `.env` files
- Use Supabase Secrets for Edge Functions
- Rotate keys regularly
- Use different keys for dev/staging/prod

### 4. Token Security

- Store tokens in iOS Keychain (not UserDefaults)
- Auto-refresh before expiration
- Revoke on sign-out
- Validate tokens on every request

### 5. Rate Limiting

- Implement IP-based rate limiting (Phase 8)
- Prevent abuse and credit farming
- See [backend-6-operations-testing.md](./backend-6-operations-testing.md)

---

## ⚠️ Authentication Edge Cases

### 1. Token Expiration During Request

**Solution:** Auto-refresh on 401, retry request

### 2. Guest User Signs In

**Solution:** Merge guest account with authenticated account:
- Transfer credits
- Transfer video history
- Update `is_guest` flag

### 3. DeviceCheck Fails

**Solution:** Fallback to UUID-based device_id (less secure, but app still works)

### 4. IAP Verification Fails

**Solution:** Return error, don't grant credits. User can retry.

### 5. Concurrent Token Refresh

**Solution:** Use actor/singleton pattern to prevent concurrent refresh attempts

---

## 🚀 Next Steps

1. **Implement IAP purchase flow** - See [backend-5-credit-system.md](./backend-5-credit-system.md)
2. **Add rate limiting** - See [backend-6-operations-testing.md](./backend-6-operations-testing.md)
3. **Set up monitoring** - Track auth failures, token refresh rates

---

**Related Documentation:**
- [backend-INDEX.md](./backend-INDEX.md) - Complete documentation index
- [backend-2-core-apis.md](./backend-2-core-apis.md) - API authentication flow
- [backend-5-credit-system.md](./backend-5-credit-system.md) - IAP purchase handling

