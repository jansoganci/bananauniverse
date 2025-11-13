# Database Schema Reference

Complete documentation of database tables, relationships, RLS policies, and functions.

## Tables

### `daily_quota`

Tracks daily quota usage for both authenticated and anonymous users.

```sql
CREATE TABLE daily_quota (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    device_id TEXT,                    -- For anonymous users
    date DATE NOT NULL,
    requests_made INTEGER DEFAULT 0 CHECK (requests_made >= 0),
    is_premium BOOLEAN DEFAULT false,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    
    -- Constraints
    UNIQUE(user_id, date),             -- One record per user per day
    UNIQUE(device_id, date),           -- One record per device per day
    CHECK ((user_id IS NOT NULL) OR (device_id IS NOT NULL))  -- Must have identifier
);
```

**Indexes:**
```sql
CREATE INDEX idx_daily_quota_user_date 
ON daily_quota(user_id, date) 
WHERE user_id IS NOT NULL;

CREATE INDEX idx_daily_quota_device_date 
ON daily_quota(device_id, date) 
WHERE device_id IS NOT NULL;
```

**RLS Policies:**
- Users can view their own quota records
- Users can update their own quota records
- Service role has full access

**Quota Limits:**
- Free users: 5 requests/day
- Premium users: 3 requests/day (temporary)
- Reset: Automatic at midnight UTC

---

### `processed_images`

Stores history of all processed images.

```sql
CREATE TABLE processed_images (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    device_id TEXT,                    -- For anonymous users
    tool_id TEXT NOT NULL,
    original_image_url TEXT NOT NULL,
    processed_image_url TEXT NOT NULL,
    prompt TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    
    CHECK ((user_id IS NOT NULL) OR (device_id IS NOT NULL))
);
```

**Indexes:**
```sql
CREATE INDEX idx_processed_images_user 
ON processed_images(user_id, created_at DESC) 
WHERE user_id IS NOT NULL;

CREATE INDEX idx_processed_images_device 
ON processed_images(device_id, created_at DESC) 
WHERE device_id IS NOT NULL;
```

**RLS Policies:**
- Users can view their own processed images
- Users can delete their own processed images
- Service role has full access

---

### `subscriptions`

Server-side subscription validation (prevents client manipulation).

```sql
CREATE TABLE subscriptions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    device_id TEXT,                    -- For anonymous premium users
    status TEXT NOT NULL CHECK (status IN ('active', 'expired', 'cancelled', 'grace_period')),
    product_id TEXT NOT NULL,          -- 'weekly_pro' or 'yearly_pro'
    expires_at TIMESTAMPTZ NOT NULL,
    original_transaction_id TEXT UNIQUE NOT NULL,  -- Apple StoreKit ID
    platform TEXT DEFAULT 'ios' CHECK (platform IN ('ios', 'android', 'web')),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    
    CHECK ((user_id IS NOT NULL) OR (device_id IS NOT NULL))
);
```

**Indexes:**
```sql
CREATE INDEX idx_subscriptions_active
ON subscriptions(user_id, status, expires_at)
WHERE status = 'active';

CREATE INDEX idx_subscriptions_device_active
ON subscriptions(device_id, status, expires_at)
WHERE device_id IS NOT NULL AND status = 'active';

CREATE INDEX idx_subscriptions_transaction
ON subscriptions(original_transaction_id);
```

**RLS Policies:**
- Users can view their own subscriptions
- Service role has full access (for webhooks)

**Status Values:**
- `active`: Subscription is active
- `expired`: Subscription has expired
- `cancelled`: User cancelled subscription
- `grace_period`: In grace period (still has access)

---

### `refunds`

Tracks refund requests for quota refunds.

```sql
CREATE TABLE refunds (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    device_id TEXT,
    request_id TEXT UNIQUE NOT NULL,   -- For idempotency
    processed_image_id UUID REFERENCES processed_images(id) ON DELETE SET NULL,
    reason TEXT,
    status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'rejected')),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    processed_at TIMESTAMPTZ,
    
    CHECK ((user_id IS NOT NULL) OR (device_id IS NOT NULL))
);
```

**Indexes:**
```sql
CREATE INDEX idx_refunds_user 
ON refunds(user_id, created_at DESC);

CREATE INDEX idx_refunds_request_id 
ON refunds(request_id);
```

**RLS Policies:**
- Users can view their own refund requests
- Service role has full access

---

## Functions

### `get_quota(user_id_param UUID, device_id_param TEXT)`

Gets current quota information for a user.

**Parameters:**
- `user_id_param`: User ID (if authenticated)
- `device_id_param`: Device ID (if anonymous)

**Returns:**
```sql
TABLE (
    quota_used INTEGER,
    quota_limit INTEGER,
    quota_remaining INTEGER,
    is_premium BOOLEAN
)
```

**Usage:**
```sql
SELECT * FROM get_quota(user_id_param := 'user-123', device_id_param := NULL);
```

---

### `consume_quota(user_id_param UUID, device_id_param TEXT, request_id TEXT)`

Consumes one quota unit for a user.

**Parameters:**
- `user_id_param`: User ID (if authenticated)
- `device_id_param`: Device ID (if anonymous)
- `request_id`: Unique request ID for idempotency

**Returns:**
- `quota_remaining`: Remaining quota after consumption
- `quota_exceeded`: Boolean indicating if quota was exceeded

**Idempotency:**
- Same `request_id` returns cached result without consuming quota
- Prevents duplicate quota consumption

**Usage:**
```sql
SELECT * FROM consume_quota(
    user_id_param := 'user-123',
    device_id_param := NULL,
    request_id := 'unique-request-id'
);
```

---

### `refund_quota(user_id_param UUID, device_id_param TEXT, request_id TEXT)`

Refunds one quota unit to a user.

**Parameters:**
- `user_id_param`: User ID (if authenticated)
- `device_id_param`: Device ID (if anonymous)
- `request_id`: Unique request ID for idempotency

**Returns:**
- `quota_remaining`: Remaining quota after refund
- `refund_applied`: Boolean indicating if refund was applied

**Limits:**
- Maximum 5 refunds per day per user
- Idempotent (same request_id won't refund twice)

**Usage:**
```sql
SELECT * FROM refund_quota(
    user_id_param := 'user-123',
    device_id_param := NULL,
    request_id := 'unique-refund-id'
);
```

---

### `sync_subscription(user_id_param UUID, device_id_param TEXT, transaction_data JSONB)`

Syncs subscription status from Adapty webhook.

**Parameters:**
- `user_id_param`: User ID (if authenticated)
- `device_id_param`: Device ID (if anonymous)
- `transaction_data`: JSON with subscription details

**Transaction Data Format:**
```json
{
    "status": "active",
    "product_id": "weekly_pro",
    "expires_at": "2024-12-31T23:59:59Z",
    "original_transaction_id": "apple_transaction_id"
}
```

**Usage:**
```sql
SELECT * FROM sync_subscription(
    user_id_param := 'user-123',
    device_id_param := NULL,
    transaction_data := '{"status": "active", ...}'::jsonb
);
```

---

## Triggers

### Auto-refund on Processing Failure

Automatically refunds quota if image processing fails.

```sql
CREATE TRIGGER auto_refund_on_failure
AFTER INSERT ON processed_images
WHEN (processed_image_url IS NULL OR processed_image_url = '')
FOR EACH ROW
EXECUTE FUNCTION refund_quota_trigger();
```

---

## Row Level Security (RLS)

### Policy Patterns

**User Can View Own Records:**
```sql
CREATE POLICY "Users can view own records"
ON table_name FOR SELECT
USING (auth.uid() = user_id);
```

**User Can Update Own Records:**
```sql
CREATE POLICY "Users can update own records"
ON table_name FOR UPDATE
USING (auth.uid() = user_id);
```

**Anonymous Users (Device ID):**
```sql
CREATE POLICY "Users can view own device records"
ON table_name FOR SELECT
USING (
    auth.uid() = user_id 
    OR device_id = current_setting('request.device_id', true)
);
```

---

## Queries

### Get Current Quota

```sql
SELECT 
    requests_made as quota_used,
    CASE 
        WHEN is_premium THEN 3 
        ELSE 5 
    END as quota_limit,
    CASE 
        WHEN is_premium THEN 3 - requests_made 
        ELSE 5 - requests_made 
    END as quota_remaining,
    is_premium
FROM daily_quota
WHERE user_id = auth.uid() 
    AND date = CURRENT_DATE;
```

### Get Processed Images (Recent)

```sql
SELECT *
FROM processed_images
WHERE user_id = auth.uid()
ORDER BY created_at DESC
LIMIT 50;
```

### Check Active Subscription

```sql
SELECT *
FROM subscriptions
WHERE user_id = auth.uid()
    AND status = 'active'
    AND expires_at > NOW()
ORDER BY expires_at DESC
LIMIT 1;
```

---

## Migrations

### Migration History

All migrations are in `supabase/migrations/` directory:

- `001_create_database_schema.sql`: Initial schema
- `017_create_daily_quota.sql`: Daily quota system
- `034_create_subscriptions.sql`: Subscription table
- `036_add_refund_tracking.sql`: Refund system
- `047_update_quota_limit_to_3.sql`: Updated premium quota

### Running Migrations

```bash
# Apply all migrations
supabase db reset

# Apply specific migration
supabase migration up <version>

# Rollback migration
supabase migration down
```

---

## Security Considerations

### RLS Enforcement

- All tables have RLS enabled
- Users can only access their own data
- Service role bypasses RLS for admin operations

### Data Validation

- Check constraints on status fields
- Foreign key constraints enforce referential integrity
- Unique constraints prevent duplicate records

### Idempotency

- Request IDs prevent duplicate quota consumption
- Transaction IDs prevent duplicate subscriptions
- Refund IDs prevent duplicate refunds

---

## Performance Optimization

### Indexes

- All foreign keys are indexed
- Date columns are indexed for time-based queries
- Status columns are indexed for filtering

### Query Optimization

- Use `LIMIT` for pagination
- Use `WHERE` clauses to filter early
- Use `ORDER BY` with indexed columns

### Connection Pooling

- Supabase handles connection pooling automatically
- Edge Functions use service role for admin operations
- Client uses anon key with RLS policies

