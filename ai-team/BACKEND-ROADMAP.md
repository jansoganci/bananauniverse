# Backend AI Agent System: Template & Pattern Requirements

**Purpose:** Define what templates, patterns, and capabilities the AI agent system needs to build Supabase backends for solo developers

**Generated:** 2025-01-15

---

## 🎯 Goal of This Document

This document identifies what the **AI agent system** needs to successfully replicate your backend architecture for future projects.

**NOT:** A roadmap for your current app
**YES:** A requirements document for the AI agent team

---

## 📊 Pattern Analysis from Your Backend

### ✅ **Patterns Successfully Extracted** (Ready for Reuse)

These patterns are fully documented in the AI agents and ready to use in future projects:

| Pattern | Complexity | Agent Responsible | Template Status |
|---------|------------|-------------------|-----------------|
| Atomic credit operations | High | credit-system-architect | ✅ Complete |
| Stored procedures with `FOR UPDATE` | High | supabase-database-architect | ✅ Complete |
| RLS policy patterns | Medium | supabase-database-architect | ✅ Complete |
| Idempotency (HTTP + DB) | High | provider-integration-specialist | ✅ Complete |
| DeviceCheck fraud prevention | High | auth-security-specialist | ✅ Complete |
| Server-side IAP verification | High | iap-verification-specialist | ✅ Complete |
| Rollback logic patterns | High | credit-system-architect | ✅ Complete |
| Audit trail with snapshots | Medium | credit-system-architect | ✅ Complete |
| Provider abstraction | Medium | provider-integration-specialist | ✅ Complete |

---

### 🟡 **Patterns Partially Documented** (Need Enhancement)

These patterns exist but need additional templates or decision frameworks:

#### 1. **Authentication Methods & Email Integration** ✅

**Current State:**
- ✅ Apple Sign-In pattern fully documented
- ✅ Email/Password auth DOCUMENTED (using Supabase Auth)
- ✅ Email service integration DOCUMENTED (Resend + Supabase)
- ✅ Multi-provider decision framework DOCUMENTED (AUTH-DECISION-FRAMEWORK.md)
- ✅ Guest→authenticated migration DOCUMENTED

**What AI Agents Have:**

✅ Complete documentation in 3 guides:

**EMAIL-PASSWORD-AUTH.md:**
- Supabase Auth setup (built-in, no custom backend code needed)
- Password requirements configuration (8+ chars, 1 number - simple)
- Email verification setup (automatic)
- 3 essential API calls: signUp(), signIn(), resetPasswordForEmail()
- Session management (automatic JWT handling)
- Account merging with guest users
- Security features (bcrypt, rate limiting - built-in)
- Testing checklist

**EMAIL-SERVICE-INTEGRATION.md:**
- Resend + Supabase SMTP integration (5-minute setup)
- Email template customization (verification, password reset, welcome)
- Transactional email patterns (purchase confirmation, low balance warning)
- Free tier: 3,000 emails/month (generous for MVPs)
- Simple function templates for custom emails
- Security checklist
- Deliverability tips

**AUTH-DECISION-FRAMEWORK.md:**
- Authentication strategy (guest vs required login for purchases)
- Account merging patterns (device→email/password)
- DeviceCheck fraud prevention
- Security best practices

✅ Enhanced `auth-security-specialist` with:
- Email/Password authentication expertise
- Email service integration (Resend)
- Complete auth flow patterns
- References to all 3 auth documents

**Action:** ✅ COMPLETED - Email/Password auth and email service fully documented

**Note:** Google Sign-In intentionally skipped - can be added later if needed (Android/web expansion). Email/Password covers most solo developer use cases. Supabase Auth makes it simple (built-in features, no custom backend code).

---

#### 2. **IAP Products Configuration** ✅

**Current State:**
- ✅ Server-side verification pattern complete
- ✅ Products database pattern DOCUMENTED
- ✅ Migration from hardcoded to database DOCUMENTED
- ✅ Decision framework COMPLETE (`docs/IAP-IMPLEMENTATION-STRATEGY.md`)

**What AI Agents Have:**

✅ Complete documentation in `docs/IAP-IMPLEMENTATION-STRATEGY.md`:
- Decision framework: Hardcoded vs Database products
- Complete products table schema with promotional support
- Step-by-step migration pattern (3 phases: Dual Mode → Migrate → Remove Fallback)
- Dynamic product management (promotions, A/B testing, seasonal, instant disable)
- Updated purchase flow with database lookups and validation
- Product history audit trail
- Example queries for promotions, A/B testing, seasonal products

✅ Enhanced `iap-verification-specialist` with:
- Products database management expertise
- Core principle: "USE DATABASE FOR PRODUCTS"
- Reference to comprehensive IAP strategy document

**Action:** ✅ COMPLETED - Products database patterns fully documented

---

#### 3. **Subscription & Refund Handling** ✅

**Current State:**
- ✅ One-time IAP verification complete
- ✅ Subscription handling DOCUMENTED
- ✅ Refund processing DOCUMENTED
- ✅ Complete IAP lifecycle COMPLETE (`docs/IAP-IMPLEMENTATION-STRATEGY.md`)

**What AI Agents Have:**

✅ Complete documentation in `docs/IAP-IMPLEMENTATION-STRATEGY.md`:

**Subscription Patterns:**
- Complete subscription lifecycle diagram (7 states)
- Database schemas (subscriptions + subscription_events tables)
- Webhook handlers for all App Store Server Notifications v2:
  - INITIAL_BUY (create subscription + grant credits)
  - DID_RENEW (monthly credit grants with idempotency)
  - DID_FAIL_TO_RENEW (grace period handling)
  - DID_RECOVER (exit grace period + grant credits)
  - DID_CHANGE_RENEWAL_STATUS (cancellation)
  - EXPIRED (revoke access)
- Grace period management
- Cancellation with access until expiration

**Refund Processing:**
- Refund detection (REFUND/REVOKE webhooks)
- Credit rollback with idempotency
- Edge case handling:
  - User spent refunded credits (negative balance or zero out)
  - Subscription refunds (deduct all renewal credits)
  - Partial refunds (prorated credit deduction)
- Fraud protection (3+ refunds = auto-ban)
- Refund monitoring and alerting
- Database schema (refund_log table)

**Complete 4-Phase Checklist:**
- Phase 1: Products Database Setup
- Phase 2: Subscription Implementation
- Phase 3: Refund System
- Phase 4: Testing & Validation

✅ Enhanced `iap-verification-specialist` with:
- Subscription lifecycle management
- Refund processing expertise
- Fraud detection patterns
- Core principles for database products and refund handling

**Action:** ✅ COMPLETED - IAP subscription and refund patterns fully documented

---

#### 4. **External API Retry Strategies** ✅

**Current State:**
- ✅ Retry pattern implemented and documented
- ✅ Exponential backoff with configurable options
- ✅ Decision framework COMPLETE (`docs/EXTERNAL-API-STRATEGY.md`)
- ✅ Multi-provider abstraction documented
- ✅ Health monitoring pattern documented
- ✅ Automatic failover pattern documented

**What AI Agents Have:**

✅ Complete documentation in `docs/EXTERNAL-API-STRATEGY.md`:
- Multi-provider interface pattern
- Provider registry and factory pattern
- Health monitoring with status tracking
- Automatic failover with intelligent provider selection
- Webhook vs polling decision framework
- Step-by-step guide for adding new providers

✅ Enhanced `provider-integration-specialist` with:
- Multi-provider abstraction examples (FalAI, Runway, Pika, StabilityAI)
- Health monitoring implementation
- Automatic failover logic
- Database schemas for health tracking

**Action:** ✅ COMPLETED - External API patterns fully documented

---

### ❌ **Patterns Missing from Analysis** (Need Documentation)

These patterns weren't in your backend docs, so AI agents don't know about them:

#### 1. **Email Notifications** ❌

**What's Missing:**
- Email service integration (SendGrid, Resend, AWS SES)
- Email templates
- Transactional email patterns
- Email verification flows

**What AI Agents Need:**

```markdown
Template Needed: EMAIL-SERVICE-INTEGRATION.md

Agent: backend-operations-engineer

## Email Service Options
- SendGrid (free tier: 100 emails/day)
- Resend (free tier: 100 emails/day)
- AWS SES (pay-as-you-go)

## Email Templates Needed
1. Welcome email (new user)
2. Purchase confirmation (IAP)
3. Video ready notification
4. Password reset
5. Email verification

## Implementation Pattern
- [ ] Email service setup
- [ ] Template system
- [ ] Queue for async sending
- [ ] Retry logic for failed emails
- [ ] Unsubscribe handling
```

**Action:** Add email integration guide to `backend-operations-engineer`

---

#### 2. **Operations & Monitoring Infrastructure** ✅

**Current State:**
- ✅ Error tracking patterns (Sentry) DOCUMENTED
- ✅ Notification system (Telegram) DOCUMENTED
- ✅ Rate limiting patterns DOCUMENTED
- ✅ Testing infrastructure DOCUMENTED
- ✅ Structured logging DOCUMENTED
- ✅ Health checks DOCUMENTED
- ✅ Metrics collection DOCUMENTED

**What AI Agents Have:**

✅ Complete documentation in `docs/OPERATIONS-MONITORING-CHECKLIST.md`:

**7 Complete Checklists:**
1. **Error Tracking Setup (Sentry)**
   - Step-by-step Sentry integration
   - Error categorization strategy (critical/high/medium/low)
   - Alert rule configuration
   - Testing procedures

2. **Telegram Notifications Setup**
   - Bot creation with @BotFather
   - Chat ID retrieval
   - Convenience functions (alertPurchase, alertError, alertRefund)
   - Event routing logic

3. **Rate Limiting Implementation**
   - Endpoint-specific limits
   - User tier-based limits (free/paid/premium)
   - Abuse prevention patterns
   - Database schemas and stored procedures

4. **Testing Infrastructure**
   - API test script templates (credit system, idempotency, rate limiting)
   - Database testing (stored procedures)
   - Load testing approach (bash + k6)
   - Manual testing checklists

5. **Structured Logging**
   - Log helper functions
   - Standard event definitions
   - Integration with Sentry and Telegram
   - Log querying examples

6. **Health Check Endpoints**
   - Health check implementation
   - Uptime monitoring setup
   - Status response format
   - Internal health checks

7. **Metrics Collection**
   - Business metrics (revenue, DAU, MAU, conversion)
   - Technical metrics (response times, error rates)
   - Implementation options (database vs external service)
   - SQL query examples

**Deployment Checklist:**
- Pre-deployment verification
- Post-deployment smoke tests
- Continuous monitoring strategy

✅ Enhanced `backend-operations-engineer` with:
- Reference to comprehensive checklist document
- Rate limiting expertise
- Testing infrastructure patterns
- Complete operational setup guide

**Action:** ✅ COMPLETED - Operations & monitoring patterns fully documented

---

#### 3. **Push Notifications (APNs)** ❌

**What's Missing:**
- APNs setup and configuration
- Push notification patterns
- Device token management
- Notification payload templates

**What AI Agents Need:**

```markdown
Template Needed: PUSH-NOTIFICATIONS-GUIDE.md

Agent: backend-operations-engineer

## When to Send Push Notifications
- Video generation completed
- Credits purchased
- Low balance warning
- Promotional messages

## APNs Setup Checklist
- [ ] APNs certificate from Apple
- [ ] Device token storage table
- [ ] Push notification service
- [ ] Notification payload templates
- [ ] Badge count management
- [ ] Silent notifications for data sync

## Implementation Pattern
CREATE TABLE device_tokens (
    user_id UUID REFERENCES users(id),
    token TEXT NOT NULL,
    platform TEXT CHECK (platform IN ('ios', 'android')),
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT now()
);
```

**Action:** Add push notification patterns to `backend-operations-engineer`

---

## 🤖 AI Agent Enhancement Requirements

### What Each Agent Currently Knows vs. Needs to Know

#### 1. **auth-security-specialist**

**Currently Knows:**
- ✅ Apple Sign-In
- ✅ DeviceCheck
- ✅ JWT token management
- ✅ Guest account patterns
- ✅ Rate limiting

**Needs to Learn:**
- ❌ Google Sign-In integration
- ❌ Email/Password auth
- ❌ Password reset flows
- ❌ Email verification
- ❌ Multi-provider account linking
- ❌ OAuth 2.0 general patterns

**Action Items:**
```markdown
1. Add Google Sign-In template to agent
2. Add Email/Password template to agent
3. Create multi-provider decision framework
4. Add account linking stored procedure template
```

---

#### 2. **iap-verification-specialist**

**Currently Knows:**
- ✅ Apple IAP verification
- ✅ Transaction verification
- ✅ Duplicate prevention
- ✅ Basic purchase flow

**Needs to Learn:**
- ❌ Subscription renewal handling
- ❌ Subscription status checking
- ❌ Refund webhook handling
- ❌ App Store Server Notifications (v2)
- ❌ Products table patterns
- ❌ Grace period handling
- ❌ Cancellation handling

**Action Items:**
```markdown
1. Add subscription patterns to agent
2. Add refund handling template
3. Add products table decision framework
4. Add App Store Server Notifications v2 guide
```

---

#### 3. **provider-integration-specialist**

**Currently Knows:**
- ✅ Provider abstraction
- ✅ Idempotency patterns
- ✅ Rollback logic
- ✅ Basic webhook patterns

**Needs to Learn:**
- ❌ Retry with exponential backoff (documented but needs decision framework)
- ❌ Circuit breaker pattern
- ❌ Provider health monitoring
- ❌ Webhook retry logic
- ❌ Fallback provider patterns

**Action Items:**
```markdown
1. Add retry decision framework
2. Add circuit breaker pattern
3. Add provider health check template
4. Add fallback/redundancy patterns
```

---

#### 4. **backend-operations-engineer**

**Currently Knows:**
- ✅ Sentry setup
- ✅ Telegram alerts
- ✅ Structured logging
- ✅ curl test scripts

**Needs to Learn:**
- ❌ Email service integration
- ❌ Push notifications (APNs)
- ❌ Testing infrastructure templates
- ❌ Metrics collection (beyond logs)
- ❌ Health check endpoint patterns
- ❌ Admin panel basics

**Action Items:**
```markdown
1. Add email service integration guide
2. Add push notification setup guide
3. Create comprehensive testing templates
4. Add health check endpoint template
5. Add metrics collection patterns
```

---

#### 5. **credit-system-architect**

**Currently Knows:**
- ✅ Atomic operations
- ✅ Stored procedures
- ✅ Audit trails
- ✅ Rollback patterns
- ✅ Idempotency

**Needs to Learn:**
- ❌ Products table patterns (vs hardcoded)
- ❌ Promotional credits handling
- ❌ Credit expiration patterns
- ❌ Negative balance handling
- ❌ Credit transfer between users

**Action Items:**
```markdown
1. Add products table template
2. Add promotional credits patterns
3. Add credit expiration handling
4. Add negative balance recovery
```

---

## 📋 Template Checklist for AI Agent System

### **Templates We Need to Create**

#### Authentication Templates
- [x] `AUTH-DECISION-FRAMEWORK.md` - ✅ COMPLETE (Auth strategy, guest→authenticated, account merging)
- [x] `EMAIL-PASSWORD-AUTH.md` - ✅ COMPLETE (Supabase Auth setup, password requirements, verification)
- [x] `EMAIL-SERVICE-INTEGRATION.md` - ✅ COMPLETE (Resend + Supabase, transactional emails)
- [ ] `GOOGLE-SIGNIN-TEMPLATE.md` - Google Sign-In setup (optional, for Android/web expansion)
- [ ] `ACCOUNT-LINKING-TEMPLATE.md` - Multi-provider linking (optional, add when needed)

#### IAP Templates
- [x] `IAP-IMPLEMENTATION-STRATEGY.md` - ✅ COMPLETE (All-in-one comprehensive guide)
  - [x] Database-driven products (decision framework + migration)
  - [x] Subscription implementation (complete lifecycle + webhooks)
  - [x] Refund webhook handling (edge cases + fraud detection)
  - [x] App Store Server Notifications v2 (all event handlers)
  - [x] 4-phase implementation checklist

#### External API Templates
- [x] `EXTERNAL-API-STRATEGY.md` - ✅ COMPLETE (All-in-one comprehensive guide)
  - [x] Retry strategy decision framework
  - [x] Multi-provider abstraction pattern
  - [x] Provider health check implementation
  - [x] Automatic failover logic
  - [x] Webhook vs polling decision framework

#### Operations Templates
- [x] `OPERATIONS-MONITORING-CHECKLIST.md` - ✅ COMPLETE (All-in-one comprehensive guide)
  - [x] Error tracking setup (Sentry integration + categorization)
  - [x] Telegram notifications (bot setup + alert routing)
  - [x] Rate limiting (endpoint limits + abuse prevention)
  - [x] Testing infrastructure (API tests + database tests + load tests)
  - [x] Structured logging (event definitions + querying)
  - [x] Health check endpoints (monitoring + uptime)
  - [x] Metrics collection (business + technical metrics)
  - [x] Deployment checklist (pre/post deployment)
- [ ] `EMAIL-SERVICE-SETUP.md` - Email integration guide
- [ ] `PUSH-NOTIFICATIONS-GUIDE.md` - APNs setup

#### Credit System Templates
- [ ] `PRODUCTS-TABLE-PATTERN.md` - Database products vs hardcoded
- [ ] `PROMOTIONAL-CREDITS.md` - Limited-time offers
- [ ] `CREDIT-EXPIRATION.md` - Time-based credits
- [ ] `NEGATIVE-BALANCE.md` - Recovery patterns

---

## 🎯 Decision Frameworks Needed

### **Framework 1: Auth Provider Selection**

```markdown
# When to Support Which Auth Methods

## Inputs
- Platform: iOS only? Android? Web?
- User base: Technical? General public?
- Friction tolerance: High (fewer options) vs Low (more options)

## Outputs
- Required auth methods
- Implementation order
- Migration strategy

## Decision Tree
1. iOS-only → Start with Apple Sign-In
2. + Android → Add Google Sign-In
3. + Web users → Add Email/Password
4. + Enterprise → Add SSO/SAML

## Template Usage
For each method, use corresponding agent template:
- Apple: auth-security-specialist (existing)
- Google: auth-security-specialist (needs template)
- Email: auth-security-specialist (needs template)
```

---

### **Framework 2: IAP vs Subscription** ✅ COMPLETED

**Status:** ✅ Documented in `docs/IAP-IMPLEMENTATION-STRATEGY.md`

**Includes:**
- Decision framework for choosing IAP model (one-time vs subscription vs hybrid)
- Complete subscription lifecycle (7 states: initial → renewal → grace period → recovery/expiration)
- Products database pattern (hardcoded vs database decision framework)
- Subscription webhook handlers for all App Store Server Notifications v2
- Refund processing for both one-time and subscription purchases
- 4-phase implementation checklist

---

### **Framework 3: Retry Strategy** ✅ COMPLETED

**Status:** ✅ Documented in `docs/EXTERNAL-API-STRATEGY.md`

**Includes:**
- Complete retry decision framework (when to retry, when not to retry)
- Exponential backoff implementation with configurable options
- Multi-provider abstraction for automatic failover
- Health monitoring with status tracking (healthy/degraded/down)
- Circuit breaker pattern (provider goes down after 3 consecutive failures)
- Webhook vs polling decision framework

---

## 🚀 Action Plan for AI Agent System

### **Phase 1: Document Missing Patterns** (Priority: HIGH)

**Goal:** Fill gaps in agent knowledge

| Task | Agent | Estimated Effort | Status |
|------|-------|------------------|--------|
| ~~Add Email/Password template~~ | auth-security-specialist | 4 hours | ✅ DONE |
| ~~Add email service integration~~ | auth-security-specialist | 3 hours | ✅ DONE |
| ~~Add subscription patterns~~ | iap-verification-specialist | 4 hours | ✅ DONE |
| ~~Add products table template~~ | credit-system-architect | 2 hours | ✅ DONE |
| ~~Add retry decision framework~~ | provider-integration-specialist | 2 hours | ✅ DONE |
| ~~Add testing templates~~ | backend-operations-engineer | 6 hours | ✅ DONE |

**Progress: 21 hours completed / 21 hours total (100% complete!)** 🎉

**Completed Documents:**
- ✅ `docs/EXTERNAL-API-STRATEGY.md` (External API patterns + retry logic)
- ✅ `docs/IAP-IMPLEMENTATION-STRATEGY.md` (Products database + subscriptions + refunds)
- ✅ `docs/AUTH-DECISION-FRAMEWORK.md` (Authentication decision framework)
- ✅ `docs/OPERATIONS-MONITORING-CHECKLIST.md` (Error tracking + testing + rate limiting)
- ✅ `docs/EMAIL-PASSWORD-AUTH.md` (Supabase Auth setup, simple and secure)
- ✅ `docs/EMAIL-SERVICE-INTEGRATION.md` (Resend + Supabase, transactional emails)

**Note:** Google Sign-In intentionally not included - can be added later if needed for Android/web. Email/Password covers 95% of solo developer needs.

---

### **Phase 2: Create Decision Frameworks** (Priority: MEDIUM)

**Goal:** Help solo developers make architecture decisions

| Framework | Estimated Effort | Status |
|-----------|------------------|--------|
| ~~Auth provider selection~~ | 2 hours | ✅ DONE (AUTH-DECISION-FRAMEWORK.md) |
| ~~IAP vs Subscription~~ | 2 hours | ✅ DONE (IAP-IMPLEMENTATION-STRATEGY.md) |
| ~~Retry strategy~~ | 2 hours | ✅ DONE (EXTERNAL-API-STRATEGY.md) |
| Email vs Push notifications | 2 hours | 🟡 TODO |
| ~~Hardcoded vs Database config~~ | 1 hour | ✅ DONE (IAP-IMPLEMENTATION-STRATEGY.md) |

**Progress: 7 hours completed / 9 hours total (~78% complete)**

---

### **Phase 3: Enhance Agent Capabilities** (Priority: MEDIUM)

**Goal:** Make agents more autonomous

| Enhancement | Agent | Effort | Priority |
|-------------|-------|--------|----------|
| Auto-detect auth requirements | backend-tech-lead | 3 hours | 🟡 MEDIUM |
| Generate curl test scripts | backend-operations-engineer | 2 hours | 🟡 MEDIUM |
| Create schema migration scripts | supabase-database-architect | 2 hours | 🟡 MEDIUM |
| Suggest products table structure | credit-system-architect | 1 hour | 🟢 LOW |

**Total: ~8 hours of agent enhancements**

---

### **Phase 4: Create Checklists** (Priority: LOW)

**Goal:** Ensure nothing is forgotten

| Checklist | Purpose | Effort |
|-----------|---------|--------|
| Backend Launch Checklist | Pre-launch verification | 2 hours |
| Security Audit Checklist | Pre-production security | 2 hours |
| IAP Setup Checklist | Ensure revenue protection | 1 hour |
| Monitoring Setup Checklist | Operational readiness | 1 hour |

**Total: ~6 hours of checklist creation**

---

## 📊 Summary: What the AI Agent System Needs

### **Immediate Needs (Next 2 Weeks)**

1. **Multi-Provider Auth Templates** (7 hours)
   - Google Sign-In
   - Email/Password
   - Account linking

2. **IAP Enhancement Templates** (6 hours)
   - Subscriptions
   - Refunds
   - Products table

3. **Retry & Reliability Templates** (4 hours)
   - Retry decision framework
   - Circuit breaker pattern

**Total: 17 hours to make AI agents production-ready**

---

### **Secondary Needs (Month 2)**

4. **Testing Infrastructure** (6 hours)
5. **Email & Push Notifications** (4 hours)
6. **Decision Frameworks** (9 hours)
7. **Enhanced Checklists** (6 hours)

**Total: 25 hours for comprehensive coverage**

---

## 🎯 Success Criteria

**The AI agent system is ready when:**

✅ A solo developer can describe their app idea
✅ Tech lead routes to appropriate specialists
✅ Each agent has templates for common patterns
✅ Decision frameworks help choose between options
✅ Agents generate production-ready code (not just examples)
✅ Checklists ensure nothing is missed
✅ Agents can explain trade-offs (not just implement)

---

## 📝 Next Steps for AI Agent Team

1. **Review this document** - Understand what's missing
2. **Prioritize templates** - Focus on HIGH priority items first
3. **Create templates** - Start with auth and IAP
4. **Test with new project** - Try building a backend from scratch
5. **Iterate** - Improve templates based on results

---

**This document is the blueprint for completing the AI agent system. Focus on filling the gaps identified here, not on implementing features in your current app.**
