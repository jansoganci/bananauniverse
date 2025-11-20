# Backend Architecture Documentation

This directory contains comprehensive backend documentation imported from the AI Team system.

## Overview

**Total Documentation: ~260KB of production-tested patterns and strategies**

### Backend Architecture (`backend/`)

7 comprehensive guides covering the entire Supabase backend stack:

1. **backend-INDEX.md** - Overview and navigation guide
2. **backend-1-overview-database.md** (17KB) - System architecture, database schemas, RLS policies
3. **backend-2-core-apis.md** (16KB) - API endpoints, request/response patterns
4. **backend-3-generation-workflow.md** (19KB) - Video generation, provider integration, webhooks
5. **backend-4-auth-security.md** (13KB) - Authentication flows, security best practices
6. **backend-5-credit-system.md** (13KB) - Credit management, atomic operations, audit trails
7. **backend-6-operations-testing.md** (18KB) - Monitoring, error tracking, deployment

### Implementation Guides (in `docs/`)

8 detailed strategy documents for specific backend features:

1. **IAP-IMPLEMENTATION-STRATEGY.md** (35KB) - Complete IAP guide
2. **EXTERNAL-API-STRATEGY.md** (32KB) - Multi-provider integration patterns
3. **AUTH-DECISION-FRAMEWORK.md** (18KB) - Authentication strategy guide
4. **EMAIL-PASSWORD-AUTH.md** (15KB) - Supabase Auth setup
5. **EMAIL-SERVICE-INTEGRATION.md** (9KB) - Transactional emails with Resend
6. **OPERATIONS-MONITORING-CHECKLIST.md** (20KB) - Production readiness
7. **FRONTEND-SUPABASE-INTEGRATION.md** (15KB) - Next.js + Supabase patterns
8. **FRONTEND-AUTH-PATTERNS.md** (16KB) - Frontend authentication patterns

## How to Use

### For Backend Development

1. **Start with backend-INDEX.md** to understand the architecture
2. **Follow the numbered guides** (backend-1 through backend-6) in sequence
3. **Reference implementation guides** when building specific features

### For Specific Features

- Building credit system → `backend-5-credit-system.md`
- Adding IAP verification → `IAP-IMPLEMENTATION-STRATEGY.md`
- Integrating external APIs → `EXTERNAL-API-STRATEGY.md`
- Setting up authentication → `AUTH-DECISION-FRAMEWORK.md`
- Production deployment → `OPERATIONS-MONITORING-CHECKLIST.md`

### For AI Agents

These documents are automatically referenced by the Supabase specialist agents defined in `.claude/agents/specialized/supabase/`:

- supabase-database-architect
- credit-system-architect
- supabase-edge-function-developer
- provider-integration-specialist
- auth-security-specialist
- iap-verification-specialist
- backend-operations-engineer

## Quick Reference

| Task | Primary Doc | Supporting Docs |
|------|-------------|-----------------|
| Database Design | backend-1 | - |
| API Development | backend-2 | backend-3 |
| Credit System | backend-5 | - |
| IAP Verification | IAP-IMPLEMENTATION-STRATEGY | backend-5 |
| Authentication | backend-4 | AUTH-DECISION-FRAMEWORK, EMAIL-PASSWORD-AUTH |
| External APIs | EXTERNAL-API-STRATEGY | backend-3 |
| Production Setup | backend-6 | OPERATIONS-MONITORING-CHECKLIST |

---

**Last Updated:** November 20, 2025
**Source:** AI Team of Jans - Supabase Backend Specialists
