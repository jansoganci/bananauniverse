# Backend Architecture: Overview & Database

**Part 1 of 6** - System architecture, database design, and infrastructure

**Related Documents:**
- [backend-INDEX.md](./backend-INDEX.md) - Complete documentation index
- [backend-2-core-apis.md](./backend-2-core-apis.md) - API endpoints
- [backend-5-credit-system.md](./backend-5-credit-system.md) - Credit stored procedures

---

## 🎯 Understanding Your Backend Architecture

### The Big Picture

Your app has **3 layers**:

```
┌─────────────────────────────────────────┐
│   iOS App (SwiftUI) - Frontend          │  ← You have this ✅
│   (Views, ViewModels, Services)         │
└──────────────┬──────────────────────────┘
               │ HTTP Requests
               ▼
┌─────────────────────────────────────────┐
│   Supabase Backend                      │  ← You need to build this ⚠️
│   ┌─────────────────────────────────┐   │
│   │  Edge Functions (API Layer)     │   │  ← API endpoints
│   │  - generate-video               │   │
│   │  - get-video-status             │   │
│   │  - get-video-jobs               │   │
│   │  - update-credits               │   │
│   │  - device/check                 │   │
│   └───────────┬─────────────────────┘   │
│               │                          │
│   ┌───────────▼─────────────────────┐   │
│   │  Database (PostgreSQL)          │   │  ← Data storage
│   │  - users                        │   │
│   │  - video_jobs                   │   │
│   │  - models                       │   │
│   │  - quota_log                    │   │
│   │  - idempotency_log              │   │  ← NEW: Prevent duplicates
│   └───────────┬─────────────────────┘   │
│               │                          │
│   ┌───────────▼─────────────────────┐   │
│   │  Storage (Supabase Storage)     │   │  ← Video files
│   │  - Generated videos             │   │
│   │  - Thumbnails                   │   │
│   └─────────────────────────────────┘   │
└──────────────┬──────────────────────────┘
               │ API Calls
               ▼
┌─────────────────────────────────────────┐
│   External AI Providers                 │  ← You connect to these
│   - FalAI (Veo 3.1, Sora 2)            │
│   - Runway (future)                     │
│   - Pika (future)                       │
└─────────────────────────────────────────┘
```

### Key Components

1. **Database (Supabase PostgreSQL)**
   - Stores: Users, video jobs, models, credit transactions
   - Security: Row-Level Security (RLS) policies
   - **NEW:** Atomic operations via stored procedures
   - Location: Supabase Cloud (or self-hosted)

2. **API Layer (Supabase Edge Functions)**
   - TypeScript/Deno functions that handle business logic
   - Act as bridge between iOS app and database/providers
   - Handle authentication, credit deduction, video generation
   - **NEW:** Idempotency protection, rollback on failure

3. **Storage (Supabase Storage)**
   - Stores generated video files
   - Stores thumbnails
   - Secure, per-user access

4. **External AI Providers**
   - FalAI, Runway, Pika (video generation APIs)
   - Your backend calls these and returns results to iOS app

---

## 🗄️ Database Schema

### Complete Table Definitions

Create migration file: `supabase/migrations/001_create_tables.sql`

#### TABLE: users

```sql
-- ==========================================
-- TABLE: users
-- ==========================================
CREATE TABLE IF NOT EXISTS public.users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    email TEXT,
    device_id TEXT UNIQUE,
    apple_sub TEXT UNIQUE,
    is_guest BOOLEAN DEFAULT true,
    tier TEXT DEFAULT 'free' CHECK (tier IN ('free', 'premium')),
    credits_remaining INTEGER DEFAULT 0,
    credits_total INTEGER DEFAULT 0,
    initial_grant_claimed BOOLEAN DEFAULT false,
    language TEXT DEFAULT 'en',
    theme_preference TEXT DEFAULT 'system',
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now(),
    
    CONSTRAINT users_identity_check CHECK (
        (email IS NOT NULL) OR (device_id IS NOT NULL)
    )
);

CREATE INDEX idx_users_device_id ON users(device_id);
CREATE INDEX idx_users_apple_sub ON users(apple_sub);
```

**Fields:**
- `id`: Primary key (UUID)
- `email`: Optional email for authenticated users
- `device_id`: Unique device identifier for guest users
- `apple_sub`: Apple Sign-In subject identifier
- `is_guest`: Whether user is a guest (not signed in)
- `tier`: User tier ('free' or 'premium')
- `credits_remaining`: Current credit balance
- `credits_total`: Lifetime credits earned
- `initial_grant_claimed`: Whether user claimed initial 10 credits
- `language`: User's preferred language ('en', 'es', 'tr')
- `theme_preference`: UI theme preference ('light', 'dark', 'system')

#### TABLE: models

```sql
-- ==========================================
-- TABLE: models
-- ==========================================
CREATE TABLE IF NOT EXISTS public.models (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    category TEXT NOT NULL,
    description TEXT,
    cost_per_generation INTEGER NOT NULL DEFAULT 4,
    provider TEXT NOT NULL,
    provider_model_id TEXT, -- e.g., "fal-ai/veo3.1"
    is_featured BOOLEAN DEFAULT false,
    is_available BOOLEAN DEFAULT true,
    thumbnail_url TEXT,
    created_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX idx_models_provider ON models(provider);
CREATE INDEX idx_models_featured ON models(is_featured) WHERE is_featured = true;
```

**Fields:**
- `id`: Primary key (UUID)
- `name`: Display name (e.g., "Cinematic")
- `category`: Model category
- `description`: Model description
- `cost_per_generation`: Credits required per generation
- `provider`: Provider name ('fal', 'runway', 'pika')
- `provider_model_id`: Provider-specific model identifier
- `is_featured`: Whether to show in featured section
- `is_available`: Whether model is currently available
- `thumbnail_url`: Thumbnail image URL

#### TABLE: video_jobs

```sql
-- ==========================================
-- TABLE: video_jobs
-- ==========================================
CREATE TABLE IF NOT EXISTS public.video_jobs (
    job_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    model_id UUID NOT NULL REFERENCES models(id),
    prompt TEXT NOT NULL,
    settings JSONB DEFAULT '{}',
    status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'processing', 'completed', 'failed')),
    video_url TEXT,
    thumbnail_url TEXT,
    credits_used INTEGER NOT NULL,
    error_message TEXT,
    provider_job_id TEXT, -- Track provider's job ID
    created_at TIMESTAMPTZ DEFAULT now(),
    completed_at TIMESTAMPTZ
);

CREATE INDEX idx_video_jobs_user ON video_jobs(user_id, created_at DESC);
CREATE INDEX idx_video_jobs_status ON video_jobs(status);
CREATE INDEX idx_video_jobs_provider ON video_jobs(provider_job_id);
```

**Fields:**
- `job_id`: Primary key (UUID)
- `user_id`: Foreign key to users table
- `model_id`: Foreign key to models table
- `prompt`: User's video generation prompt
- `settings`: JSONB with video settings (resolution, duration, etc.)
- `status`: Job status ('pending', 'processing', 'completed', 'failed')
- `video_url`: URL to generated video (when completed)
- `thumbnail_url`: URL to video thumbnail
- `credits_used`: Credits deducted for this generation
- `error_message`: Error message if generation failed
- `provider_job_id`: Provider's job identifier for tracking
- `created_at`: When job was created
- `completed_at`: When job completed (or failed)

#### TABLE: quota_log

```sql
-- ==========================================
-- TABLE: quota_log (Credit transactions)
-- ==========================================
CREATE TABLE IF NOT EXISTS public.quota_log (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    job_id UUID REFERENCES video_jobs(job_id) ON DELETE SET NULL,
    change INTEGER NOT NULL,
    reason TEXT NOT NULL,
    transaction_id TEXT UNIQUE, -- For IAP purchases
    balance_after INTEGER, -- Credit balance after transaction
    created_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX idx_quota_log_user ON quota_log(user_id, created_at DESC);
CREATE INDEX idx_quota_log_transaction ON quota_log(transaction_id);
```

**Fields:**
- `id`: Primary key (UUID)
- `user_id`: Foreign key to users table
- `job_id`: Optional foreign key to video_jobs (if related to generation)
- `change`: Credit change amount (positive for additions, negative for deductions)
- `reason`: Reason for change ('initial_grant', 'video_generation', 'iap_purchase', 'generation_failed_refund', etc.)
- `transaction_id`: Unique transaction ID for IAP purchases (prevents duplicates)
- `balance_after`: Credit balance after this transaction (for audit trail)
- `created_at`: When transaction occurred

#### TABLE: idempotency_log

```sql
-- ==========================================
-- TABLE: idempotency_log (Prevent duplicates)
-- ==========================================
CREATE TABLE IF NOT EXISTS public.idempotency_log (
    idempotency_key UUID PRIMARY KEY,
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    job_id UUID REFERENCES video_jobs(job_id) ON DELETE SET NULL,
    operation_type TEXT NOT NULL,
    response_data JSONB,
    status_code INTEGER,
    created_at TIMESTAMPTZ DEFAULT now(),
    expires_at TIMESTAMPTZ DEFAULT now() + INTERVAL '24 hours'
);

CREATE INDEX idx_idempotency_user ON idempotency_log(user_id, created_at);
CREATE INDEX idx_idempotency_expires ON idempotency_log(expires_at);
```

**Fields:**
- `idempotency_key`: Primary key (UUID from client)
- `user_id`: Foreign key to users table
- `job_id`: Optional foreign key to video_jobs (if operation created a job)
- `operation_type`: Type of operation ('video_generation', 'credit_purchase', etc.)
- `response_data`: Cached response to return on duplicate requests
- `status_code`: HTTP status code of original response
- `created_at`: When idempotency key was first used
- `expires_at`: When key expires (24 hours default)

**Purpose:** Prevents duplicate processing if client retries a request. See [backend-3-generation-workflow.md](./backend-3-generation-workflow.md) for details.

---

## 🔒 Row-Level Security (RLS) Policies

### Enable RLS on All Tables

```sql
-- ==========================================
-- RLS POLICIES
-- ==========================================

-- Users table
ALTER TABLE users ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view own profile"
ON users FOR SELECT
USING (auth.uid() = id);

CREATE POLICY "Users can update own profile"
ON users FOR UPDATE
USING (auth.uid() = id);

-- Video jobs table
ALTER TABLE video_jobs ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view own jobs"
ON video_jobs FOR SELECT
USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own jobs"
ON video_jobs FOR INSERT
WITH CHECK (auth.uid() = user_id);

-- Quota log table
ALTER TABLE quota_log ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view own transactions"
ON quota_log FOR SELECT
USING (auth.uid() = user_id);

-- Models table (public read-only)
ALTER TABLE models ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Anyone can view available models"
ON models FOR SELECT
USING (is_available = true);
```

**Security Model:**
- Users can only view/update their own data
- Models are publicly readable (when available)
- All operations use `auth.uid()` to identify the current user
- Guest users get anonymous JWT tokens (see [backend-4-auth-security.md](./backend-4-auth-security.md))

---

## 📦 Storage Buckets

### Configure Supabase Storage

Create the following buckets:

1. **`videos`** bucket
   - Purpose: Store generated video files
   - Access: Public with RLS policies
   - Policy: Users can only access their own videos

2. **`thumbnails`** bucket
   - Purpose: Store video thumbnail images
   - Access: Public with RLS policies
   - Policy: Users can only access their own thumbnails

3. **`user_uploads`** bucket (optional)
   - Purpose: Store user-uploaded images for image-to-video
   - Access: Private with RLS policies
   - Policy: Users can only upload/access their own files

**Storage Policies Example:**

```sql
-- Allow users to upload videos
CREATE POLICY "Users can upload own videos"
ON storage.objects FOR INSERT
WITH CHECK (
    bucket_id = 'videos' AND
    auth.uid()::text = (storage.foldername(name))[1]
);

-- Allow users to read own videos
CREATE POLICY "Users can read own videos"
ON storage.objects FOR SELECT
USING (
    bucket_id = 'videos' AND
    auth.uid()::text = (storage.foldername(name))[1]
);
```

---

## 🔧 Database Design Patterns

### 1. Atomic Operations

All credit operations use stored procedures to prevent race conditions. See [backend-5-credit-system.md](./backend-5-credit-system.md) for stored procedure implementations.

### 2. Soft Deletes

Consider adding `deleted_at` columns for soft deletes instead of hard deletes:

```sql
ALTER TABLE video_jobs ADD COLUMN deleted_at TIMESTAMPTZ;
CREATE INDEX idx_video_jobs_deleted ON video_jobs(deleted_at) WHERE deleted_at IS NULL;
```

### 3. Audit Trail

The `quota_log` table provides a complete audit trail:
- Every credit change is logged
- `balance_after` field tracks balance at time of transaction
- `transaction_id` prevents duplicate IAP purchases

### 4. Indexing Strategy

**High-frequency queries:**
- User's video jobs: `idx_video_jobs_user` (user_id, created_at DESC)
- Job status checks: `idx_video_jobs_status`
- User's credit history: `idx_quota_log_user` (user_id, created_at DESC)

**Lookup queries:**
- Device ID lookup: `idx_users_device_id`
- Apple Sign-In lookup: `idx_users_apple_sub`
- Transaction ID lookup: `idx_quota_log_transaction`

**Partial indexes:**
- Featured models: `idx_models_featured` (only indexes where is_featured = true)

---

## 🌍 Environment Variables

### Required Environment Variables

Create `.env.example`:

```bash
# Supabase
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_ANON_KEY=your-anon-key
SUPABASE_SERVICE_ROLE_KEY=your-service-role-key

# External AI Providers
FALAI_API_KEY=your-falai-key
RUNWAY_API_KEY=your-runway-key (future)
PIKA_API_KEY=your-pika-key (future)

# Apple IAP & DeviceCheck
APPLE_BUNDLE_ID=com.yourdomain.rendio
APPLE_TEAM_ID=YOUR_TEAM_ID
APPLE_KEY_ID=YOUR_KEY_ID
APPLE_ISSUER_ID=YOUR_ISSUER_ID
APPLE_PRIVATE_KEY="-----BEGIN PRIVATE KEY-----\n...\n-----END PRIVATE KEY-----"
APPLE_DEVICECHECK_KEY_ID=YOUR_DEVICECHECK_KEY_ID
APPLE_DEVICECHECK_PRIVATE_KEY="-----BEGIN PRIVATE KEY-----\n...\n-----END PRIVATE KEY-----"

# Environment
ENVIRONMENT=production # or development, staging
```

**Security Notes:**
- Never commit `.env` files to version control
- Use Supabase Secrets for Edge Functions
- Rotate keys regularly
- Use different keys for development/staging/production

---

## 📊 Database Performance Considerations

### Query Optimization

1. **Use indexes** for all foreign keys and frequently queried columns
2. **Partial indexes** for filtered queries (e.g., featured models)
3. **Composite indexes** for multi-column queries (e.g., user_id + created_at)

### Connection Pooling

Supabase handles connection pooling automatically, but for high-traffic scenarios:
- Consider using Supavisor (Supabase's connection pooler)
- Monitor connection count in Supabase dashboard
- Set appropriate connection limits

### Maintenance Tasks

1. **Vacuum and analyze** tables regularly (Supabase handles this automatically)
2. **Clean up expired idempotency keys** (add cron job after Phase 4)
3. **Archive old video_jobs** (optional: move to archive table after 90 days)

---

## 🚀 Next Steps

After setting up the database:

1. **Create stored procedures** - See [backend-5-credit-system.md](./backend-5-credit-system.md)
2. **Set up API endpoints** - See [backend-2-core-apis.md](./backend-2-core-apis.md)
3. **Configure authentication** - See [backend-4-auth-security.md](./backend-4-auth-security.md)

---

**Related Documentation:**
- [backend-INDEX.md](./backend-INDEX.md) - Complete documentation index
- [backend-2-core-apis.md](./backend-2-core-apis.md) - API endpoints
- [backend-5-credit-system.md](./backend-5-credit-system.md) - Credit stored procedures

