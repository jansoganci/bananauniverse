# Operations & Monitoring Setup Checklist

**Purpose:** Step-by-step checklist for setting up error tracking, monitoring, notifications, rate limiting, and testing infrastructure for new Supabase backend projects.

**Generated:** 2025-01-15

**Target:** AI agent system templates for solo developers

---

## 🎯 Overview

This document provides **actionable checklists** for setting up production-grade operations and monitoring for your Supabase backend. Use these as copy-paste templates when starting a new project.

**NOT:** Tasks to implement right now
**YES:** Template checklists for future projects

---

## 📊 Checklist 1: Error Tracking Setup (Sentry)

### Prerequisites
- [ ] Create Sentry account at https://sentry.io (free tier: 5,000 errors/month)
- [ ] Create new Deno project in Sentry dashboard
- [ ] Copy DSN (Data Source Name)

### Implementation Checklist

#### Step 1: Add Sentry to Edge Functions
- [ ] Create `_shared/sentry.ts` file
- [ ] Import Sentry Deno SDK: `@sentry/deno@7.92.0`
- [ ] Initialize Sentry with DSN
- [ ] Set environment (production, staging, development)
- [ ] Configure trace sample rate (recommend 10%)
- [ ] Add beforeSend hook for user context anonymization

#### Step 2: Store Sentry Credentials
```bash
# Add to Supabase secrets
- [ ] supabase secrets set SENTRY_DSN="https://xxx@sentry.io/xxx"
- [ ] supabase secrets set ENVIRONMENT="production"
```

#### Step 3: Add Error Capture Helpers
- [ ] Create `captureError(error, context)` function
- [ ] Create `captureMessage(message, level)` function
- [ ] Export Sentry instance for advanced usage

#### Step 4: Integrate with Edge Functions
- [ ] Import `captureError` in all Edge Functions
- [ ] Wrap main logic in try-catch blocks
- [ ] Capture errors with relevant context (user_id, endpoint, parameters)
- [ ] Log errors to console for local debugging

#### Step 5: Configure Error Categorization
- [ ] Tag errors by component (endpoint name)
- [ ] Add user context (anonymized user_id)
- [ ] Include custom metadata (request parameters, state)
- [ ] Set error levels (error, warning, info)

#### Step 6: Setup Alert Rules
- [ ] Configure email alerts for critical errors
- [ ] Set alert threshold (e.g., >10 errors in 5 minutes)
- [ ] Configure Slack/Discord webhook for team notifications
- [ ] Test alert delivery

### Error Categorization Strategy

**Critical (Immediate Alert):**
- [ ] Payment processing failures
- [ ] Database connection failures
- [ ] Authentication system failures
- [ ] Credit system failures (negative balance, rollback errors)

**High Priority (Alert within 1 hour):**
- [ ] External API failures (provider down)
- [ ] Webhook processing failures
- [ ] Subscription renewal failures
- [ ] Refund processing errors

**Medium Priority (Daily summary):**
- [ ] Rate limit violations
- [ ] Invalid input errors (4xx)
- [ ] User-caused errors (insufficient credits)

**Low Priority (Weekly review):**
- [ ] Deprecated API warnings
- [ ] Performance degradation warnings
- [ ] Non-critical validation errors

### Testing
- [ ] Test error capture in development
- [ ] Verify errors appear in Sentry dashboard
- [ ] Test alert delivery
- [ ] Confirm user data is anonymized

---

## 📱 Checklist 2: Telegram Notifications Setup

### Prerequisites
- [ ] Install Telegram on your phone
- [ ] Have admin access to create bots

### Implementation Checklist

#### Step 1: Create Telegram Bot
- [ ] Open Telegram, search for `@BotFather`
- [ ] Send `/newbot` command
- [ ] Choose bot name (e.g., "MyApp Backend Alerts")
- [ ] Choose bot username (e.g., "myapp_backend_bot")
- [ ] Copy bot token (looks like: `123456789:ABCdefGHIjklMNOpqrsTUVwxyz`)

#### Step 2: Get Chat ID
- [ ] Send a message to your bot (e.g., "Hello")
- [ ] Get chat ID using this command:
```bash
- [ ] curl https://api.telegram.org/bot<YOUR_BOT_TOKEN>/getUpdates
```
- [ ] Copy chat ID from response (number in `"chat":{"id":123456789}`)

#### Step 3: Store Telegram Credentials
```bash
# Add to Supabase secrets
- [ ] supabase secrets set TELEGRAM_BOT_TOKEN="your-bot-token"
- [ ] supabase secrets set TELEGRAM_CHAT_ID="your-chat-id"
```

#### Step 4: Create Telegram Helper Functions
- [ ] Create `_shared/telegram.ts` file
- [ ] Implement `sendTelegramAlert(alert)` function
- [ ] Add emoji mapping (ℹ️ info, ⚠️ warning, 🚨 error)
- [ ] Add metadata formatting
- [ ] Add timestamp to messages

#### Step 5: Create Convenience Functions
- [ ] `alertPurchase(userId, productName, credits)` - Purchase notifications
- [ ] `alertError(endpoint, error, userId)` - Error notifications
- [ ] `alertHighUsage(userId, action, count)` - Usage spike alerts
- [ ] `alertRefund(userId, transactionId, credits)` - Refund alerts
- [ ] `alertProviderDown(providerName, failures)` - Provider health alerts

#### Step 6: Integrate with Key Events
- [ ] Call on successful purchases (IAP)
- [ ] Call on errors (caught in try-catch)
- [ ] Call on high usage detection (>100 requests/hour)
- [ ] Call on refund processing
- [ ] Call on provider health failures

### Notification Event Types

**Always Send:**
- [ ] Purchases (IAP, subscriptions)
- [ ] Refunds (all amounts)
- [ ] Critical errors (database, auth, payment)
- [ ] Provider down alerts

**Configurable Threshold:**
- [ ] High usage (>100 requests/hour per user)
- [ ] Rate limit violations (>10/hour)
- [ ] Failed API calls (>5 in a row)
- [ ] Slow response times (>5 seconds)

**Daily Summary Only:**
- [ ] Total revenue
- [ ] Active users
- [ ] Error count by type
- [ ] Provider health status

### Testing
- [ ] Test sending message via curl:
```bash
- [ ] curl -X POST "https://api.telegram.org/bot<TOKEN>/sendMessage" \
     -H "Content-Type: application/json" \
     -d '{"chat_id":"<CHAT_ID>","text":"Test message"}'
```
- [ ] Verify message appears in Telegram
- [ ] Test emoji rendering
- [ ] Test markdown formatting

---

## 🚦 Checklist 3: Rate Limiting Implementation

### Rate Limiting Strategy

#### Determine Limits by Endpoint

**Authentication Endpoints:**
- [ ] `/auth/login` - 5 requests per 15 minutes per IP
- [ ] `/auth/register` - 3 requests per 15 minutes per IP
- [ ] `/auth/password-reset` - 3 requests per hour per email

**IAP Endpoints:**
- [ ] `/update-credits` - 10 requests per minute per user (prevent duplicate processing)
- [ ] `/verify-purchase` - 10 requests per minute per user

**Video Generation Endpoints:**
- [ ] `/generate-video` - Based on user tier (see below)
- [ ] `/check-status` - 60 requests per minute per user

**Query Endpoints:**
- [ ] `/get-user-credits` - 100 requests per minute per user
- [ ] `/get-video-history` - 60 requests per minute per user

#### User Tier-Based Limits

**Free Tier:**
- [ ] 10 video generations per day
- [ ] 5 concurrent jobs
- [ ] 100 API requests per hour

**Paid Tier:**
- [ ] Unlimited generations (credit-based)
- [ ] 20 concurrent jobs
- [ ] 1000 API requests per hour

**Premium Tier:**
- [ ] Unlimited generations
- [ ] 100 concurrent jobs
- [ ] 10,000 API requests per hour

### Implementation Checklist

#### Step 1: Create Rate Limiting Database Tables
```sql
- [ ] Create rate_limits table (user_id, action, window_start, request_count)
- [ ] Add indexes for fast lookups
- [ ] Create check_rate_limit() stored procedure
- [ ] Test stored procedure with sample data
```

#### Step 2: Implement Rate Limiting Middleware
- [ ] Create `_shared/rate-limit.ts` file
- [ ] Implement `checkRateLimit(userId, action, maxRequests, windowMinutes)`
- [ ] Return allowed boolean + remaining count
- [ ] Return retry_after seconds if rate limited

#### Step 3: Add Rate Limiting to Edge Functions
- [ ] Add rate limit check at start of function
- [ ] Return 429 Too Many Requests if exceeded
- [ ] Include `Retry-After` header in response
- [ ] Include `X-RateLimit-Limit` header (max requests)
- [ ] Include `X-RateLimit-Remaining` header (requests left)
- [ ] Include `X-RateLimit-Reset` header (when window resets)

#### Step 4: Implement IP-Based Rate Limiting (Optional)
- [ ] Extract IP from request headers (`X-Forwarded-For`)
- [ ] Create ip_rate_limits table
- [ ] Apply stricter limits for unauthenticated requests
- [ ] Use for authentication endpoints (prevent brute force)

#### Step 5: Configure Abuse Prevention
- [ ] Auto-block IPs with >100 failed auth attempts
- [ ] Temporary ban (1 hour) after 5 rate limit violations
- [ ] Permanent ban after 10 rate limit violations
- [ ] Alert admin on suspicious activity

### Abuse Prevention Patterns

**Detect:**
- [ ] Multiple accounts from same IP
- [ ] Unusual usage patterns (100+ requests in 1 minute)
- [ ] Repeated rate limit violations
- [ ] Scraping behavior (sequential ID access)

**Prevent:**
- [ ] CAPTCHA after 5 failed login attempts
- [ ] IP rate limiting on auth endpoints
- [ ] DeviceCheck for iOS fraud prevention
- [ ] Webhook signature validation (prevent replay attacks)

**Response:**
- [ ] Log suspicious activity to database
- [ ] Send Telegram alert on detected abuse
- [ ] Temporary ban (1-24 hours)
- [ ] Require manual review for permanent ban

### Testing
- [ ] Test rate limiting with curl scripts
- [ ] Verify 429 response and headers
- [ ] Test rate limit reset after window expires
- [ ] Verify different limits for different tiers

---

## 🧪 Checklist 4: Testing Infrastructure

### API Testing Script Templates

#### Prerequisites
- [ ] Install `jq` for JSON parsing: `brew install jq` (macOS) or `apt install jq` (Linux)
- [ ] Have test user credentials ready
- [ ] Have test JWT token ready

#### Create Test Script Directory
```bash
- [ ] mkdir -p tests/api
- [ ] mkdir -p tests/database
- [ ] mkdir -p tests/load
```

### Test Script 1: Credit System
- [ ] Create `tests/api/test-credit-system.sh`
- [ ] Test: Check initial balance
- [ ] Test: Purchase credits (mock IAP transaction)
- [ ] Test: Verify idempotency (duplicate transaction)
- [ ] Test: Deduct credits (video generation)
- [ ] Test: View transaction history
- [ ] Assert: All tests pass

**Template:**
```bash
#!/bin/bash
set -e
BASE_URL="https://your-project.supabase.co/functions/v1"
USER_ID="test-user-uuid"
JWT="your-jwt-token"

# Test 1: Check balance
# Test 2: Purchase credits
# Test 3: Duplicate purchase (idempotency)
# Test 4: Generate video (deduct)
# Test 5: View history
```

### Test Script 2: Idempotency
- [ ] Create `tests/api/test-idempotency.sh`
- [ ] Test: First request creates job
- [ ] Test: Second request (same key) returns cached result
- [ ] Test: Verify `X-Idempotent-Replay: true` header
- [ ] Assert: Job ID matches for both requests

### Test Script 3: Rate Limiting
- [ ] Create `tests/api/test-rate-limiting.sh`
- [ ] Test: Send requests within limit (should succeed)
- [ ] Test: Exceed rate limit (should get 429)
- [ ] Test: Verify `Retry-After` header
- [ ] Test: Wait and retry (should succeed)
- [ ] Assert: Rate limiting enforced correctly

### Test Script 4: Authentication
- [ ] Create `tests/api/test-auth.sh`
- [ ] Test: Login with valid credentials
- [ ] Test: Login with invalid credentials (should fail)
- [ ] Test: Access protected endpoint without token (should fail)
- [ ] Test: Access protected endpoint with valid token
- [ ] Test: Refresh token
- [ ] Assert: Auth flow works end-to-end

### Load Testing Approach

#### Simple Load Test (Bash)
- [ ] Create `tests/load/simple-load-test.sh`
- [ ] Run 10 concurrent requests
- [ ] Measure response times
- [ ] Check for errors
- [ ] Report success/failure rate

**Template:**
```bash
#!/bin/bash
for i in {1..10}; do
  curl -s -X POST "$BASE_URL/endpoint" \
    -H "Authorization: Bearer $JWT" \
    -d '{"test":"data"}' &
done
wait
echo "Load test completed"
```

#### Advanced Load Test (Optional)
- [ ] Install k6: `brew install k6`
- [ ] Create `tests/load/k6-load-test.js`
- [ ] Define scenarios (10 users, 100 users, 1000 users)
- [ ] Set duration (30s, 5min, 30min)
- [ ] Measure response times (p95, p99)
- [ ] Set failure thresholds

### Manual Testing Checklist

#### Pre-Deployment Testing
- [ ] Test all auth flows (login, register, logout)
- [ ] Test IAP purchase (sandbox)
- [ ] Test video generation (all models)
- [ ] Test credit deduction and refund
- [ ] Test subscription renewal (if applicable)
- [ ] Test refund processing
- [ ] Test rate limiting (hit limit, verify 429)
- [ ] Test error handling (simulate failures)

#### Post-Deployment Smoke Tests
- [ ] Health check endpoint returns 200
- [ ] Can authenticate successfully
- [ ] Can make API request
- [ ] Logs appear in Supabase dashboard
- [ ] Errors appear in Sentry
- [ ] Telegram alerts working

#### Database Testing
- [ ] Create `tests/database/test-stored-procedures.sql`
- [ ] Test: `deduct_credits()` with sufficient balance
- [ ] Test: `deduct_credits()` with insufficient balance (should fail)
- [ ] Test: `add_credits()` with duplicate transaction_id (idempotency)
- [ ] Test: `merge_guest_account()` credits transfer
- [ ] Test: Concurrent credit deductions (race condition)
- [ ] Assert: All stored procedures work correctly

### Continuous Testing Strategy

**On Every Deploy:**
- [ ] Run smoke tests (health, auth, basic API call)
- [ ] Check error logs for new errors
- [ ] Verify Sentry integration
- [ ] Confirm Telegram alerts working

**Daily:**
- [ ] Run full API test suite
- [ ] Check rate limiting effectiveness
- [ ] Review error trends in Sentry
- [ ] Check for new security vulnerabilities

**Weekly:**
- [ ] Run load tests
- [ ] Review database performance (slow queries)
- [ ] Audit RLS policies
- [ ] Review user abuse reports

**Monthly:**
- [ ] Full security audit
- [ ] Dependency updates (Deno, Supabase, packages)
- [ ] Performance optimization review
- [ ] Cost analysis (API calls, storage, bandwidth)

---

## 📋 Checklist 5: Structured Logging

### Implementation Checklist

#### Step 1: Create Logging Helper
- [ ] Create `_shared/logger.ts` file
- [ ] Define LogLevel type (debug, info, warn, error)
- [ ] Define LogEntry interface
- [ ] Implement `logEvent(event, data, level)` function
- [ ] Output structured JSON logs

#### Step 2: Add Convenience Functions
- [ ] `logInfo(event, data)` - Log informational events
- [ ] `logError(event, data)` - Log errors
- [ ] `logWarning(event, data)` - Log warnings
- [ ] `logDebug(event, data)` - Log debug info (development only)

#### Step 3: Integrate with Monitoring
- [ ] Send errors to Sentry automatically
- [ ] Send high-priority events to Telegram
- [ ] Include trace IDs for request tracking
- [ ] Add user context (anonymized)

#### Step 4: Define Standard Events
**User Events:**
- [ ] `user.registered` - New user signup
- [ ] `user.login` - User login
- [ ] `user.logout` - User logout
- [ ] `user.deleted` - Account deletion

**Purchase Events:**
- [ ] `iap.purchase.success` - Purchase completed
- [ ] `iap.purchase.failed` - Purchase failed
- [ ] `iap.refund.processed` - Refund completed
- [ ] `subscription.renewed` - Subscription renewed

**Generation Events:**
- [ ] `video.generation.started` - Video generation started
- [ ] `video.generation.completed` - Video completed
- [ ] `video.generation.failed` - Generation failed

**System Events:**
- [ ] `provider.health.degraded` - Provider slow
- [ ] `provider.health.down` - Provider down
- [ ] `rate_limit.exceeded` - User hit rate limit
- [ ] `credits.depleted` - User ran out of credits

### Log Querying Examples

**Find recent errors:**
```sql
- [ ] SELECT * FROM logs WHERE level = 'error' ORDER BY created_at DESC LIMIT 10;
```

**Track user activity:**
```sql
- [ ] SELECT event, created_at FROM logs WHERE user_id = 'uuid' ORDER BY created_at DESC;
```

**Revenue tracking:**
```sql
- [ ] SELECT COUNT(*), SUM((data->>'credits')::int) FROM logs WHERE event = 'iap.purchase.success';
```

---

## 📊 Checklist 6: Health Check Endpoints

### Implementation Checklist

#### Step 1: Create Health Check Function
- [ ] Create `supabase/functions/health/index.ts`
- [ ] Check database connection
- [ ] Check external API availability (optional)
- [ ] Return status: `healthy` / `degraded` / `down`
- [ ] Include response time metrics

#### Step 2: Health Check Response
```typescript
- [ ] Return 200 OK if healthy
- [ ] Return 503 Service Unavailable if down
- [ ] Include version number
- [ ] Include uptime
- [ ] Include last deployment time
```

**Example Response:**
```json
{
  "status": "healthy",
  "version": "1.2.3",
  "uptime": 86400,
  "database": "healthy",
  "providers": {
    "fal": "healthy",
    "runway": "degraded"
  }
}
```

#### Step 3: Setup Uptime Monitoring
- [ ] Use external service (UptimeRobot, Pingdom, Better Uptime)
- [ ] Monitor `/health` endpoint every 5 minutes
- [ ] Alert if endpoint returns 5xx or times out
- [ ] Alert if response time >5 seconds

#### Step 4: Internal Health Checks
- [ ] Check database connection on startup
- [ ] Check provider health every 5 minutes (cron job)
- [ ] Store health metrics in database
- [ ] Alert on health degradation

---

## 📈 Checklist 7: Metrics Collection

### Key Metrics to Track

#### Business Metrics
- [ ] Daily revenue (from IAP purchases)
- [ ] Daily active users (DAU)
- [ ] Monthly active users (MAU)
- [ ] Conversion rate (sign up → purchase)
- [ ] Average revenue per user (ARPU)
- [ ] Churn rate (for subscriptions)
- [ ] Refund rate

#### Technical Metrics
- [ ] API response times (p50, p95, p99)
- [ ] Error rate (errors per 1000 requests)
- [ ] Database query times
- [ ] Provider response times
- [ ] Credit system balance integrity
- [ ] Rate limit violations

#### Operational Metrics
- [ ] Disk usage (storage)
- [ ] Bandwidth usage
- [ ] Function execution count
- [ ] Database connections
- [ ] Failed jobs count
- [ ] Queued jobs count

### Implementation Options

**Option A: Database-Based Metrics**
- [ ] Create metrics table
- [ ] Insert metrics on key events
- [ ] Query for analytics
- [ ] Build dashboard with SQL queries

**Option B: External Analytics Service**
- [ ] Use PostHog (free tier: 1M events/month)
- [ ] Use Mixpanel (free tier: 100K MAU)
- [ ] Use Google Analytics
- [ ] Use custom solution

**Option C: Hybrid Approach** (Recommended)
- [ ] Store critical metrics in database
- [ ] Send events to external analytics
- [ ] Use database for revenue tracking
- [ ] Use analytics for user behavior

### SQL Queries for Metrics

```sql
-- Daily revenue
- [ ] SELECT DATE(created_at), SUM(change) FROM quota_log
      WHERE reason = 'iap_purchase' GROUP BY DATE(created_at);

-- Error rate
- [ ] SELECT COUNT(*) FILTER (WHERE status = 'failed') / COUNT(*)::float * 100
      FROM video_jobs;

-- Active users
- [ ] SELECT COUNT(DISTINCT user_id) FROM quota_log
      WHERE created_at > NOW() - INTERVAL '24 hours';
```

---

## 🚀 Deployment Checklist

### Pre-Deployment
- [ ] All tests passing (API, database, integration)
- [ ] Sentry configured and tested
- [ ] Telegram alerts configured and tested
- [ ] Rate limiting implemented and tested
- [ ] Health check endpoint working
- [ ] Secrets configured (Sentry DSN, Telegram tokens, API keys)
- [ ] Environment variables set correctly
- [ ] Database migrations applied
- [ ] RLS policies tested

### Deployment
- [ ] Deploy Edge Functions: `supabase functions deploy`
- [ ] Run smoke tests on production
- [ ] Verify health check returns 200
- [ ] Test authentication flow
- [ ] Make test API request
- [ ] Verify error appears in Sentry
- [ ] Verify alert appears in Telegram

### Post-Deployment
- [ ] Monitor error logs for 1 hour
- [ ] Check Sentry for new errors
- [ ] Verify all functions deployed successfully
- [ ] Test all critical endpoints
- [ ] Update monitoring dashboard
- [ ] Notify team of deployment

---

## 📋 Summary: Backend Template Setup Guide

Use this checklist when starting a new Supabase backend project:

### Phase 1: Core Operations (Day 1)
- [x] Checklist 1: Error Tracking (Sentry) - 2 hours
- [x] Checklist 2: Telegram Notifications - 1 hour
- [x] Checklist 6: Health Check Endpoint - 1 hour

### Phase 2: Security & Testing (Week 1)
- [x] Checklist 3: Rate Limiting - 3 hours
- [x] Checklist 4: Testing Infrastructure - 4 hours
- [x] Checklist 5: Structured Logging - 2 hours

### Phase 3: Monitoring & Analytics (Week 2)
- [x] Checklist 7: Metrics Collection - 3 hours
- [x] Setup uptime monitoring - 1 hour
- [x] Create operations dashboard - 2 hours

**Total Setup Time: ~19 hours**

---

**This document provides complete operational checklists for the AI agent system to set up production-grade monitoring, error tracking, and testing infrastructure for Supabase backends.**
