# Backend Architecture Documentation Index

**Version:** 3.0 - MVP + Production Features Edition  
**Date:** 2025-11-05  
**Status:** Comprehensive implementation plan split into focused documents

---

## 📚 Documentation Structure

This backend architecture documentation has been split into 6 focused files for easier navigation and analysis. Each file covers a specific domain of the backend system.

### 1. [backend-1-overview-database.md](./backend-1-overview-database.md)
**Size:** ~15-20KB  
**Focus:** System architecture, database design, and infrastructure

**Contents:**
- Overall architecture overview (3-layer system)
- Technology stack (Supabase, PostgreSQL, Edge Functions)
- Complete database schema (all CREATE TABLE statements)
- Database indexes and performance optimization
- Row-Level Security (RLS) policies
- Storage buckets configuration
- Database design patterns and best practices
- Environment variables setup

**Use when:** Setting up the database, understanding the data model, or configuring security policies.

---

### 2. [backend-2-core-apis.md](./backend-2-core-apis.md)
**Size:** ~20-25KB  
**Focus:** Core API endpoints and request/response patterns

**Contents:**
- Core API endpoints:
  - `device-check` - Guest user onboarding
  - `get-user-credits` - Credit balance queries
  - `get-models` - Available video generation models
  - `get-user-profile` - User profile data
  - `get-video-jobs` - Generation history
- Request/response formats
- API authentication flow
- Rate limiting implementation
- API versioning strategy
- Error response patterns

**Use when:** Implementing client-side API integration, understanding endpoint contracts, or debugging API calls.

---

### 3. [backend-3-generation-workflow.md](./backend-3-generation-workflow.md)
**Size:** ~20-25KB  
**Focus:** Video generation workflow and provider integration

**Contents:**
- `generate-video` endpoint (with idempotency)
- `get-video-status` / `check-video-job-status` endpoint
- Provider integration (FalAI, Runway, Pika adapters)
- Idempotency logic and duplicate prevention
- Webhook system (replacing polling)
- Credit deduction and rollback mechanisms
- Error handling for generation failures
- Status polling patterns (before webhooks)

**Use when:** Implementing video generation features, integrating with AI providers, or handling generation errors.

---

### 4. [backend-4-auth-security.md](./backend-4-auth-security.md)
**Size:** ~15-20KB  
**Focus:** Authentication, authorization, and security

**Contents:**
- Apple Sign-In flow and integration
- Anonymous user handling (guest accounts)
- DeviceCheck verification (preventing credit farming)
- JWT token management (issue, refresh, revoke)
- In-App Purchase (IAP) verification (App Store Server API)
- Security best practices
- Authentication edge cases
- Token refresh logic

**Use when:** Implementing authentication, securing endpoints, or handling user sessions.

---

### 5. [backend-5-credit-system.md](./backend-5-credit-system.md)
**Size:** ~15-20KB  
**Focus:** Credit management and transaction handling

**Contents:**
- Credit management logic
- Quota tracking (`quota_log` table)
- Stored procedures:
  - `deduct_credits()` - Atomic credit deduction
  - `add_credits()` - Atomic credit addition
- Transaction handling
- Purchase flow (IAP integration)
- Credit history and audit trail
- Atomic operations (preventing race conditions)
- Duplicate transaction prevention

**Use when:** Implementing credit operations, handling purchases, or debugging credit balance issues.

---

### 6. [backend-6-operations-testing.md](./backend-6-operations-testing.md)
**Size:** ~15-20KB  
**Focus:** Operations, monitoring, and testing

**Contents:**
- Error handling with internationalization (i18n error codes)
- Logging and monitoring strategies
- Admin functions and tools
- Deployment phases (Phases 0-9)
- Testing checklist
- Performance considerations
- Maintenance tasks
- Production readiness checklist
- Known limitations and trade-offs

**Use when:** Deploying to production, setting up monitoring, or running tests.

---

## 🔗 Cross-References

When reading these documents, you'll find cross-references like:
- "See [backend-4-auth-security.md](./backend-4-auth-security.md) for JWT token details"
- "See [backend-5-credit-system.md](./backend-5-credit-system.md) for credit deduction logic"

These help you navigate between related topics across files.

---

## 📊 Implementation Phases Overview

The backend is built in phases:

**MVP Phases (0-4):** 16-20 days
- Phase 0: Setup & Infrastructure
- Phase 0.5: Security Essentials
- Phase 1: Core Database & API Setup
- Phase 2: Video Generation API
- Phase 3: History & User Management
- Phase 4: Integration & Testing

**Production Features (5-9):** 12-16 days
- Phase 5: Webhook System
- Phase 6: Retry Logic for External APIs
- Phase 7: Error Handling with i18n
- Phase 8: IP-Based Rate Limiting
- Phase 9: Admin Tools

**Total:** 28-36 days for production-ready backend

---

## 🎯 Quick Navigation

**Starting a new project?**
1. Read [backend-1-overview-database.md](./backend-1-overview-database.md) for architecture
2. Follow Phase 0 setup instructions

**Implementing authentication?**
→ See [backend-4-auth-security.md](./backend-4-auth-security.md)

**Building video generation?**
→ See [backend-3-generation-workflow.md](./backend-3-generation-workflow.md)

**Handling credits/purchases?**
→ See [backend-5-credit-system.md](./backend-5-credit-system.md)

**Deploying to production?**
→ See [backend-6-operations-testing.md](./backend-6-operations-testing.md)

---

## 📝 Document Status

All documents are up-to-date as of 2025-11-05 and reflect the complete MVP + Production Features implementation plan.

**Original Source:** `backend-architecture.txt` (122KB)  
**Split into:** 6 focused files for better maintainability and analysis

---

**Questions?** Each file includes detailed implementation examples and code snippets. Start with the overview file and navigate to specific topics as needed.

