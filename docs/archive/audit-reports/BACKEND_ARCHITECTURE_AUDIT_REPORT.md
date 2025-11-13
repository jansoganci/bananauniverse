# ⚙️ Backend Architecture & Supabase System Knowledge Audit
## Safe Educational Reference Analysis

**Date**: 2025-11-02  
**Source Company**: External (BananaUniverse)  
**Target Company**: Fortunia  
**Purpose**: Safe extraction of universal backend architecture patterns and Supabase best practices

---

## 📋 Executive Summary

This audit analyzes the external source's backend architecture and Supabase integration to extract universal principles, patterns, and best practices that can be safely adapted to Fortunia's system. **No sensitive data** (API keys, database URLs, credentials, specific table names) is included in this report.

---

## 🏗️ High-Level Architecture

### Core Services

#### **1. Authentication Service Layer**
```
HybridAuthService (iOS)
  ↓
SupabaseService (Backend Communication)
  ↓
Supabase Auth (Backend)
  ↓
JWT Token Management
```

**Responsibilities**:
- User authentication (email/password, Apple Sign-In)
- Session management (token storage, refresh)
- Anonymous user support (device ID tracking)
- State synchronization (authenticated ↔ anonymous)

#### **2. Quota Management Service Layer**
```
HybridCreditManager (iOS)
  ↓
SupabaseService.consumeQuota()
  ↓
Edge Function: process-image
  ↓
Database Function: consume_quota()
  ↓
Quota Tables (with RLS)
```

**Responsibilities**:
- Daily quota tracking (authenticated + anonymous users)
- Premium status validation (server-side)
- Idempotency protection (prevent double-charging)
- Quota refresh and synchronization

#### **3. AI Processing Service Layer**
```
ChatViewModel (iOS)
  ↓
SupabaseService.processImageSteveJobsStyle()
  ↓
Edge Function: process-image
  ↓
External AI Provider (fal.ai)
  ↓
Storage Upload + Response
```

**Responsibilities**:
- Image processing orchestration
- AI model integration
- Result storage management
- Error handling and retry logic

#### **4. Subscription Management Service Layer**
```
StoreKitService (iOS)
  ↓
Adapty (Analytics)
  ↓
StoreKit 2 (Apple)
  ↓
Edge Function / Webhook
  ↓
Subscriptions Table (Supabase)
```

**Responsibilities**:
- Subscription purchase handling
- Premium status validation
- Subscription sync to backend
- Renewal date tracking

---

### Data Flow

#### **Request Flow: Image Processing**
```
1. User initiates processing (iOS)
   └──> ViewModel calls SupabaseService

2. Client-side validation (iOS)
   └──> Check local quota cache
   └──> Validate user can process

3. Edge Function call (Supabase)
   └──> POST /functions/v1/process-image
   └──> Authorization: Bearer token (JWT or anon key)
   └──> Headers: device-id (for anonymous users)

4. Authentication & User Identification (Edge Function)
   └──> Validate JWT token (if authenticated)
   └──> Extract user_id or device_id
   └──> Check premium status from subscriptions table

5. Quota Consumption (Database Function)
   └──> Call consume_quota() function
   └──> Idempotency check (request_id)
   └──> Atomic quota increment
   └──> Return quota status

6. AI Processing (External Provider)
   └──> Upload image to external AI service
   └──> Process with AI model
   └──> Wait for result

7. Storage Upload (Supabase Storage)
   └──> Upload processed image
   └──> Generate signed URL
   └──> Store job record

8. Response (Back to iOS)
   └──> Return processed image URL
   └──> Return updated quota info
   └──> Update local cache

9. UI Update (iOS)
   └──> Display processed image
   └──> Update quota display
```

---

### Integration Pattern

#### **Supabase Integration Points**

**1. Authentication**
- Supabase Auth (JWT-based)
- Anonymous sessions supported
- Token refresh automatic
- Session persistence in Keychain

**2. Database**
- PostgreSQL with RLS (Row-Level Security)
- Stored procedures for business logic
- Functions with SECURITY DEFINER
- Automatic migrations

**3. Storage**
- Supabase Storage buckets
- Signed URLs for secure access
- Organized file structure (uploads/user_id/...)
- RLS policies on storage

**4. Edge Functions**
- Deno runtime (TypeScript)
- Serverless functions
- Direct AI processing
- Background cleanup tasks

**5. Real-time (Optional)**
- Supabase Realtime subscriptions
- WebSocket connections
- Live updates (if needed)

---

### Security & Privacy Model

#### **1. Row-Level Security (RLS)**

**Concept**: Database-level security that restricts access to rows based on user identity.

**Implementation Pattern**:
```sql
-- Enable RLS on table
ALTER TABLE table_name ENABLE ROW LEVEL SECURITY;

-- Policy for authenticated users
CREATE POLICY "users_access_own_data"
ON table_name FOR SELECT
USING (auth.uid() = user_id);

-- Policy for anonymous users (via device_id)
CREATE POLICY "anon_access_device_data"
ON table_name FOR SELECT
USING (
    device_id IS NOT NULL 
    AND device_id = current_setting('request.device_id', true)
);

-- Service role bypass (for admin operations)
CREATE POLICY "service_role_full_access"
ON table_name FOR ALL
TO service_role
USING (true)
WITH CHECK (true);
```

**Key Principles**:
- ✅ **Never trust client**: Always validate on server
- ✅ **Default deny**: No access unless policy allows
- ✅ **Service role**: Bypass RLS for admin operations
- ✅ **Device ID**: Support anonymous users via session variables

---

#### **2. Token Management**

**JWT Token Flow**:
```
1. User authenticates → Supabase Auth returns JWT
2. JWT stored in Keychain (secure storage)
3. JWT sent in Authorization header for API calls
4. Edge Function validates JWT
5. Extract user_id from JWT payload
6. Use user_id for RLS policy evaluation
```

**Anonymous User Flow**:
```
1. No JWT token → Use device_id header
2. Edge Function sets device_id session variable
3. RLS policies check device_id
4. Quota tracked by device_id
```

**Key Principles**:
- ✅ **Secure storage**: Keychain for tokens
- ✅ **Token validation**: Always validate on server
- ✅ **Fallback support**: Device ID for anonymous users
- ✅ **Automatic refresh**: Handle token expiry

---

#### **3. Idempotency Protection**

**Pattern**: Prevent duplicate processing on network retries.

**Implementation**:
```typescript
// Client generates unique request ID
const clientRequestId = UUID().uuidString;

// Edge Function checks for duplicate
const existingRequest = await checkIdempotency(clientRequestId);

if (existingRequest) {
    // Return cached result
    return existingRequest.result;
}

// Process and store result
const result = await processImage(...);
await storeRequestResult(clientRequestId, result);
```

**Key Principles**:
- ✅ **Client-generated ID**: Unique per request
- ✅ **Server-side check**: Database lookup before processing
- ✅ **Cached results**: Return previous result if duplicate
- ✅ **Atomic operations**: Database-level idempotency

---

## 🗄️ Supabase Usage

### Auth & User Management

#### **Authentication Modes**

**1. Authenticated Users**
- Email/password authentication
- Apple Sign-In (OAuth)
- JWT token-based sessions
- User profile in database

**2. Anonymous Users**
- Device ID-based identification
- No authentication required
- Quota tracked by device_id
- Can upgrade to authenticated later

**3. Hybrid Support**
- Seamless transition (anonymous → authenticated)
- Credit migration on sign-up
- Single codebase for both modes

#### **Session Management**

**Pattern**: Automatic session restoration
```
App Launch:
1. Check Keychain for stored session
2. Validate session with Supabase
3. If valid → Restore authenticated state
4. If invalid → Fall back to anonymous
5. Update app state accordingly
```

**Session Refresh**:
- Automatic token refresh
- Background refresh before expiry
- Seamless user experience

---

### Database & RLS Policies

#### **Table Categories**

**1. User Data Tables**
- User profiles (email, subscription tier)
- User preferences
- User history (processed images, jobs)

**2. Quota Tracking Tables**
- Daily quota records (user_id/device_id, date, used, limit)
- Quota consumption log (audit trail, idempotency)
- Subscription records (premium status)

**3. Job Tracking Tables**
- Processing jobs (status, input/output URLs)
- Job history (completed jobs)
- Error logs (debugging)

**4. System Tables**
- Cleanup logs (maintenance operations)
- Performance metrics (monitoring)
- Rate limiting (abuse prevention)

#### **RLS Policy Types**

**1. User-Owned Data Policies**
```sql
-- Users can only access their own data
CREATE POLICY "users_access_own"
ON table_name FOR SELECT
USING (auth.uid() = user_id);
```

**2. Device-Owned Data Policies**
```sql
-- Anonymous users access via device_id
CREATE POLICY "anon_access_device"
ON table_name FOR SELECT
USING (
    device_id = current_setting('request.device_id', true)
);
```

**3. Service Role Policies**
```sql
-- Admin operations bypass RLS
CREATE POLICY "service_role_access"
ON table_name FOR ALL
TO service_role
USING (true)
WITH CHECK (true);
```

**4. Hybrid Policies**
```sql
-- Support both authenticated and anonymous
CREATE POLICY "hybrid_access"
ON table_name FOR SELECT
USING (
    auth.uid() = user_id
    OR device_id = current_setting('request.device_id', true)
);
```

#### **Database Functions (Stored Procedures)**

**Pattern**: Business logic in database functions

**1. Quota Functions**
```sql
-- Consume quota with idempotency
CREATE FUNCTION consume_quota(
    p_user_id UUID,
    p_device_id TEXT,
    p_client_request_id UUID
) RETURNS JSONB;

-- Get current quota status
CREATE FUNCTION get_quota(
    p_user_id UUID,
    p_device_id TEXT
) RETURNS JSONB;
```

**Key Principles**:
- ✅ **SECURITY DEFINER**: Functions run with elevated privileges
- ✅ **Idempotency**: Check request_id before processing
- ✅ **Atomic operations**: UPSERT for quota increment
- ✅ **Error handling**: Comprehensive exception handling

**2. Subscription Functions**
```sql
-- Sync subscription status
CREATE FUNCTION sync_subscription(
    p_user_id UUID,
    p_transaction_id TEXT,
    p_status TEXT
) RETURNS JSONB;

-- Check premium status
CREATE FUNCTION is_premium_user(
    p_user_id UUID,
    p_device_id TEXT
) RETURNS BOOLEAN;
```

**3. Cleanup Functions**
```sql
-- Clean old quota logs
CREATE FUNCTION cleanup_quota_logs()
RETURNS TABLE(deleted_count INTEGER);

-- Clean old jobs
CREATE FUNCTION cleanup_old_jobs()
RETURNS TABLE(deleted_count INTEGER);
```

---

### Storage

#### **Storage Organization**

**File Structure Pattern**:
```
storage/
└── bucket_name/
    └── uploads/
        ├── {user_id}/
        │   └── {filename}.jpg
        └── {device_id}/
            └── {filename}.jpg
```

**Key Principles**:
- ✅ **Organized by user**: User/device ID in path
- ✅ **Unique filenames**: UUID-based naming
- ✅ **Signed URLs**: Time-limited access (30 days)
- ✅ **RLS on storage**: Access control at storage level

#### **Storage Operations**

**Upload Pattern**:
```
1. Generate unique filename (UUID)
2. Build path: uploads/{user_id}/{filename}
3. Upload to Supabase Storage
4. Get public URL or signed URL
5. Store URL in database
```

**Download Pattern**:
```
1. Get file path from database
2. Generate signed URL (if needed)
3. Download from Supabase Storage
4. Cache locally (optional)
```

---

### Edge Functions

#### **Function Structure**

**Standard Pattern**:
```typescript
Deno.serve(async (req: Request) => {
  // 1. CORS handling
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  // 2. Authentication
  const authHeader = req.headers.get('authorization');
  const user = await validateAuth(authHeader);

  // 3. Parse request
  const requestData = await req.json();

  // 4. Business logic
  const result = await processRequest(requestData, user);

  // 5. Return response
  return new Response(JSON.stringify(result), {
    headers: { ...corsHeaders, 'Content-Type': 'application/json' }
  });
});
```

#### **Function Categories**

**1. Processing Functions**
- `process-image`: Main AI processing pipeline
- Handles quota, authentication, AI calls, storage

**2. Maintenance Functions**
- `cleanup-db`: Database cleanup
- `cleanup-images`: Storage cleanup
- `cleanup-logs`: Log rotation

**3. Monitoring Functions**
- `health-check`: System health monitoring
- `log-monitor`: Error tracking
- `log-alert`: Alert notifications

#### **Edge Function Best Practices**

**1. Error Handling**
```typescript
try {
  // Process request
} catch (error) {
  console.error('Error:', error);
  return new Response(
    JSON.stringify({ success: false, error: error.message }),
    { status: 500, headers: corsHeaders }
  );
}
```

**2. Authentication**
```typescript
// Validate JWT token
const authHeader = req.headers.get('authorization');
if (authHeader?.startsWith('Bearer ')) {
  const token = authHeader.split(' ')[1];
  const { data: { user }, error } = await supabase.auth.getUser(token);
  // Use user.id for RLS policies
}
```

**3. Idempotency**
```typescript
// Check for duplicate request
const requestId = requestData.client_request_id;
const existing = await checkIdempotency(requestId);
if (existing) {
  return existing.result; // Return cached result
}
```

**4. Quota Management**
```typescript
// Consume quota before processing
const quotaResult = await supabase.rpc('consume_quota', {
  p_user_id: user?.id,
  p_device_id: deviceId,
  p_client_request_id: requestId
});

if (!quotaResult.success) {
  return new Response(
    JSON.stringify({ success: false, error: 'Quota exceeded' }),
    { status: 429 }
  );
}
```

---

### Error Handling

#### **Error Hierarchy**

**1. Client Errors (4xx)**
- 400: Bad Request (missing parameters)
- 401: Unauthorized (invalid token)
- 429: Too Many Requests (quota exceeded)

**2. Server Errors (5xx)**
- 500: Internal Server Error
- 502: Bad Gateway (external service error)
- 503: Service Unavailable

**3. Custom Error Types**
```typescript
enum SupabaseError {
  notAuthenticated
  insufficientCredits
  quotaExceeded
  processingFailed
  timeout
  rateLimitExceeded
}
```

#### **Error Response Pattern**

```typescript
{
  success: false,
  error: "User-friendly error message",
  details?: "Technical details (optional)",
  quota_info?: {
    quota_used: number,
    quota_limit: number,
    quota_remaining: number
  }
}
```

---

## 🔄 Reusable Architectural Patterns

### **1. Hybrid User Support Pattern**

**Concept**: Support both authenticated and anonymous users seamlessly.

**Implementation**:
```typescript
// Edge Function
let userIdentifier: string;
let userType: 'authenticated' | 'anonymous';

if (authHeader && authHeader.startsWith('Bearer ')) {
  // Authenticated user
  const { user } = await validateJWT(authHeader);
  userIdentifier = user.id;
  userType = 'authenticated';
} else if (deviceId) {
  // Anonymous user
  userIdentifier = deviceId;
  userType = 'anonymous';
} else {
  return 401; // Unauthorized
}
```

**Benefits**:
- ✅ No friction for new users
- ✅ Seamless upgrade path
- ✅ Single codebase for both modes
- ✅ Data migration handled automatically

---

### **2. Server-Side Premium Validation Pattern**

**Concept**: Never trust client for premium status - always validate on server.

**Implementation**:
```sql
-- Check subscriptions table (not client-provided flag)
CREATE FUNCTION is_premium_user(p_user_id UUID) RETURNS BOOLEAN AS $$
  SELECT EXISTS(
    SELECT 1 FROM subscriptions
    WHERE user_id = p_user_id
    AND status = 'active'
    AND expires_at > NOW()
  );
$$;
```

**Benefits**:
- ✅ Prevents client manipulation
- ✅ Single source of truth (database)
- ✅ Real-time premium status
- ✅ Secure subscription validation

---

### **3. Idempotency Pattern**

**Concept**: Prevent duplicate processing on retries.

**Implementation**:
```sql
-- Check for duplicate request
CREATE FUNCTION consume_quota(
    p_client_request_id UUID,
    ...
) RETURNS JSONB AS $$
  -- Check if already processed
  IF EXISTS(
    SELECT 1 FROM quota_consumption_log
    WHERE request_id = p_client_request_id
  ) THEN
    -- Return cached result
    RETURN (SELECT result FROM quota_consumption_log WHERE ...);
  END IF;
  
  -- Process and store result
  ...
$$;
```

**Benefits**:
- ✅ Prevents double-charging
- ✅ Handles network retries gracefully
- ✅ Atomic operations
- ✅ Audit trail

---

### **4. Atomic Quota Management Pattern**

**Concept**: Use database-level atomic operations for quota.

**Implementation**:
```sql
-- Atomic UPSERT with quota check
INSERT INTO daily_quotas (user_id, date, used, limit_value)
VALUES (p_user_id, CURRENT_DATE, 1, 5)
ON CONFLICT (user_id, date)
DO UPDATE SET
    used = daily_quotas.used + 1,
    updated_at = NOW()
WHERE daily_quotas.used < daily_quotas.limit_value
RETURNING used, limit_value;
```

**Benefits**:
- ✅ Thread-safe (no race conditions)
- ✅ Atomic operation (all-or-nothing)
- ✅ Database-level validation
- ✅ No application-level locking needed

---

### **5. RLS with Session Variables Pattern**

**Concept**: Use session variables for anonymous user RLS.

**Implementation**:
```typescript
// Edge Function sets device_id
await supabase.rpc('set_device_id_session', { 
  p_device_id: device_id 
});

// RLS policy checks session variable
CREATE POLICY "anon_access_device"
ON table_name FOR SELECT
USING (
  device_id = current_setting('request.device_id', true)
);
```

**Benefits**:
- ✅ Secure anonymous user support
- ✅ Database-level access control
- ✅ No client manipulation
- ✅ Works with RLS policies

---

### **6. Function-Based Business Logic Pattern**

**Concept**: Put business logic in database functions, not application code.

**Implementation**:
```sql
-- Business logic in database
CREATE FUNCTION process_quota_consumption(...) RETURNS JSONB AS $$
  -- Complex logic here
  -- Atomic operations
  -- Error handling
  -- Return structured result
$$ LANGUAGE plpgsql SECURITY DEFINER;
```

**Benefits**:
- ✅ Single source of truth
- ✅ Atomic operations
- ✅ Reduced network calls
- ✅ Database-level validation

---

### **7. Cleanup & Maintenance Pattern**

**Concept**: Automated cleanup of old data.

**Implementation**:
```typescript
// Scheduled edge function
Deno.serve(async (req: Request) => {
  // Clean old jobs (90 days)
  await cleanupOldJobs();
  
  // Clean old quota logs (90 days)
  await cleanupQuotaLogs();
  
  // Clean old quota records (1 year)
  await cleanupOldQuotas();
  
  return { success: true };
});
```

**Benefits**:
- ✅ Automatic maintenance
- ✅ Database size management
- ✅ Performance optimization
- ✅ Compliance (GDPR, data retention)

---

### **8. Health Check Pattern**

**Concept**: Monitor system health and alert on issues.

**Implementation**:
```typescript
interface HealthCheck {
  status: 'healthy' | 'degraded' | 'unhealthy';
  database: 'connected' | 'error';
  last_cleanup: string | null;
  errors_24h: number;
}

// Check various components
const health = {
  database: await checkDatabase(),
  storage: await checkStorage(),
  edgeFunctions: await checkEdgeFunctions(),
  cleanup: await checkLastCleanup()
};
```

**Benefits**:
- ✅ Proactive monitoring
- ✅ Early issue detection
- ✅ Automated alerts
- ✅ System reliability

---

## 📊 Database Structure (Logical Level)

### **Core Tables (Conceptual)**

**1. User Management**
- User profiles (email, subscription tier, preferences)
- User authentication (handled by Supabase Auth)
- User state (authenticated vs anonymous)

**2. Quota Management**
- Daily quota tracking (user_id/device_id, date, usage, limit)
- Quota consumption log (audit trail, idempotency)
- Subscription records (premium status, expiry)

**3. Job Processing**
- Processing jobs (status, input/output, metadata)
- Job history (completed jobs for library)
- Error logs (debugging and monitoring)

**4. Storage Management**
- File references (paths, URLs, signed URLs)
- Storage metadata (size, type, upload date)

**5. System Operations**
- Cleanup logs (maintenance operations)
- Performance metrics (monitoring)
- Error tracking (alerting)

### **Table Relationships (Conceptual)**

```
users (Supabase Auth)
  ├── profiles (user profile data)
  ├── subscriptions (premium status)
  ├── daily_quotas (quota tracking)
  ├── jobs (processing history)
  └── quota_consumption_log (audit trail)

device_id (Anonymous)
  ├── daily_quotas (quota tracking)
  ├── jobs (processing history)
  └── quota_consumption_log (audit trail)
```

### **Indexing Strategy**

**Principles**:
- ✅ **User-based queries**: Index on user_id
- ✅ **Device-based queries**: Index on device_id
- ✅ **Date-based queries**: Index on date columns
- ✅ **Status-based queries**: Partial indexes (WHERE status = 'active')
- ✅ **Composite indexes**: For common query patterns

---

## 🔐 Security Best Practices

### **1. RLS First Approach**

**Principle**: Enable RLS on all user-accessible tables.

**Implementation**:
```sql
-- Enable RLS
ALTER TABLE table_name ENABLE ROW LEVEL SECURITY;

-- Create policies BEFORE allowing access
CREATE POLICY "secure_access" ON table_name ...;

-- Grant permissions
GRANT SELECT, INSERT, UPDATE ON table_name TO authenticated, anon;
```

**Benefits**:
- ✅ Defense in depth
- ✅ Database-level security
- ✅ Prevents data leaks
- ✅ Works even if application has bugs

---

### **2. Server-Side Validation**

**Principle**: Never trust client data - always validate on server.

**Implementation**:
```typescript
// Edge Function validates premium status
const isPremium = await checkPremiumStatus(userId);
// NOT: const isPremium = requestData.is_premium; ❌
```

**Benefits**:
- ✅ Prevents client manipulation
- ✅ Single source of truth
- ✅ Secure validation
- ✅ Real-time status

---

### **3. Service Role Usage**

**Principle**: Use service role only for admin operations.

**Implementation**:
```typescript
// Service role for admin operations
const supabase = createClient(
  supabaseUrl,
  serviceRoleKey // Only in edge functions
);

// Regular operations use anon key
const supabase = createClient(
  supabaseUrl,
  anonKey // In iOS app
);
```

**Benefits**:
- ✅ Least privilege principle
- ✅ Separation of concerns
- ✅ Secure admin operations
- ✅ Regular users can't bypass RLS

---

### **4. Idempotency Everywhere**

**Principle**: Make all state-changing operations idempotent.

**Implementation**:
```sql
-- Check for duplicate before processing
IF EXISTS(SELECT 1 FROM log WHERE request_id = p_request_id) THEN
  RETURN cached_result;
END IF;

-- Process and log
INSERT INTO log (request_id, result) VALUES (...);
```

**Benefits**:
- ✅ Prevents duplicate processing
- ✅ Handles network retries
- ✅ Atomic operations
- ✅ Audit trail

---

### **5. Signed URLs for Storage**

**Principle**: Use time-limited signed URLs for file access.

**Implementation**:
```typescript
// Generate signed URL (30 days expiry)
const signedURL = await supabase.storage
  .from('bucket_name')
  .createSignedURL(path, expiresIn: 2592000); // 30 days
```

**Benefits**:
- ✅ Time-limited access
- ✅ No permanent public URLs
- ✅ Revocable access
- ✅ Security best practice

---

## 🔄 Data Flow Patterns

### **1. Quota Consumption Flow**

```
Client Request
  ↓
Edge Function: process-image
  ↓
Validate Auth (JWT or device_id)
  ↓
Database Function: consume_quota()
  ├── Check idempotency
  ├── Check premium status (from subscriptions table)
  ├── Atomic UPSERT quota
  └── Return quota status
  ↓
If quota OK → Process image
If quota exceeded → Return 429
```

### **2. Premium Status Validation Flow**

```
Client Request
  ↓
Edge Function receives request
  ↓
Extract user_id or device_id
  ↓
Check subscriptions table
  ├── Query: SELECT * FROM subscriptions
  │   WHERE user_id = ? AND status = 'active'
  │   AND expires_at > NOW()
  └── Return is_premium boolean
  ↓
Use is_premium for quota bypass
```

### **3. Image Processing Flow**

```
Client uploads image
  ↓
Supabase Storage
  ↓
Get signed URL
  ↓
Edge Function: process-image
  ├── Consume quota
  ├── Call external AI service
  ├── Wait for result
  ├── Upload result to storage
  └── Store job record
  ↓
Return processed image URL
```

### **4. Subscription Sync Flow**

```
StoreKit purchase
  ↓
StoreKitService (iOS)
  ↓
Sync to Supabase
  ├── Edge Function or Webhook
  ├── Insert/update subscriptions table
  └── Update premium status
  ↓
Quota system checks subscriptions table
```

---

## 🎯 Reusable Patterns Summary

### **Backend Patterns**

1. ✅ **Hybrid User Support**: Anonymous + Authenticated
2. ✅ **Server-Side Premium Validation**: Database lookup, not client flag
3. ✅ **Idempotency Protection**: Request ID tracking
4. ✅ **Atomic Quota Management**: Database-level UPSERT
5. ✅ **RLS with Session Variables**: Device ID for anonymous users
6. ✅ **Function-Based Business Logic**: Stored procedures
7. ✅ **Cleanup & Maintenance**: Automated data cleanup
8. ✅ **Health Check**: System monitoring

### **Security Patterns**

1. ✅ **RLS First**: Enable RLS on all tables
2. ✅ **Server-Side Validation**: Never trust client
3. ✅ **Service Role Usage**: Admin operations only
4. ✅ **Idempotency Everywhere**: Prevent duplicates
5. ✅ **Signed URLs**: Time-limited storage access

### **Data Flow Patterns**

1. ✅ **Quota Consumption**: Atomic database operations
2. ✅ **Premium Validation**: Database lookup
3. ✅ **Image Processing**: Edge Function orchestration
4. ✅ **Subscription Sync**: Webhook or edge function

---

## 🔄 Adaptation Notes

### **Safe for Reuse Across Projects**

✅ **Universal Patterns**:
- Hybrid user support (anonymous + authenticated)
- Server-side premium validation
- Idempotency protection
- Atomic quota management
- RLS with session variables
- Function-based business logic
- Cleanup & maintenance
- Health check monitoring

✅ **Security Principles**:
- RLS first approach
- Server-side validation
- Service role usage
- Idempotency everywhere
- Signed URLs for storage

✅ **Architecture Patterns**:
- Edge Function structure
- Database function pattern
- Storage organization
- Error handling hierarchy
- CORS handling

### **Customization Needed**

⚠️ **Project-Specific**:
- Table names (adapt to Fortunia's schema)
- Function names (adapt to Fortunia's conventions)
- Edge Function endpoints (adapt to Fortunia's URLs)
- Storage bucket names (adapt to Fortunia's buckets)
- Error message format (adapt to Fortunia's style)

### **Implementation Priority**

**High Priority**:
1. ✅ RLS policy implementation
2. ✅ Idempotency protection
3. ✅ Server-side premium validation
4. ✅ Atomic quota management

**Medium Priority**:
5. ✅ Edge Function structure
6. ✅ Database function pattern
7. ✅ Storage organization
8. ✅ Error handling

**Low Priority**:
9. ✅ Cleanup functions
10. ✅ Health check monitoring
11. ✅ Analytics tracking

---

## 📊 Summary

### **Architecture Highlights**
- **4 core services**: Auth, Quota, AI Processing, Subscriptions
- **Hybrid user support**: Anonymous + Authenticated seamlessly
- **Server-side validation**: Premium status from database
- **RLS everywhere**: Database-level security
- **Edge Functions**: Serverless processing

### **Security Highlights**
- **RLS policies**: User/device-based access control
- **Idempotency**: Prevent duplicate processing
- **Server validation**: Never trust client
- **Signed URLs**: Secure storage access
- **Service role**: Admin operations only

### **Data Flow Highlights**
- **4 main flows**: Quota, Premium, Processing, Subscription
- **Atomic operations**: Database-level consistency
- **Error handling**: Comprehensive error management
- **Monitoring**: Health checks and alerts

### **Reusable Patterns**
- **8 backend patterns**: Hybrid support, validation, idempotency, etc.
- **5 security patterns**: RLS, validation, service role, etc.
- **4 data flow patterns**: Quota, premium, processing, subscription

---

## 🎯 Recommendations for Fortunia

### **Immediate Actions**
1. **Implement RLS policies** - Database-level security
2. **Set up idempotency** - Prevent duplicate processing
3. **Server-side premium validation** - Database lookup
4. **Atomic quota management** - Database-level UPSERT
5. **Edge Function structure** - Serverless processing

### **Short-Term Goals**
1. **Hybrid user support** - Anonymous + Authenticated
2. **Storage organization** - User/device-based paths
3. **Error handling** - Comprehensive error management
4. **Health check monitoring** - System reliability
5. **Cleanup functions** - Automated maintenance

### **Long-Term Vision**
1. **Expand edge functions** - More serverless operations
2. **Advanced monitoring** - Analytics and alerting
3. **Performance optimization** - Database indexing, caching
4. **Security hardening** - Advanced RLS policies
5. **Scalability** - Handle increased load

---

**End of Audit Report**

*This report contains only universal backend architecture patterns and Supabase best practices. No sensitive data, API keys, database URLs, credentials, or project-specific implementation details are included.*

