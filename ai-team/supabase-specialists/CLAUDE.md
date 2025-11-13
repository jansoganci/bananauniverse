# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is the **AI Team of Jans - Supabase Backend Specialists** repository. It contains a specialized collection of 8 AI agents focused exclusively on building production-ready Supabase backends with:

- **Credit/Quota Systems** - Atomic operations, audit trails, rollback logic
- **In-App Purchase (IAP) Verification** - Apple App Store Server API, subscriptions, refunds
- **Authentication** - Apple Sign-In, DeviceCheck, Email/Password, guest accounts
- **External API Integration** - Video generation (FalAI, Runway, Pika), retry logic, webhooks
- **Operations** - Error tracking (Sentry), Telegram alerts, rate limiting, testing

**Important**: This is NOT a multi-framework agent collection. These agents are **laser-focused on Supabase backends** using PostgreSQL, Edge Functions (Deno), and Row-Level Security.

## When to Use This Project

**✅ Use these agents if you're building:**
- Video generation apps with credit-based systems
- AI-powered applications with quota management
- Mobile apps with IAP verification (Apple)
- SaaS products with Supabase backends
- Apps requiring atomic financial operations

**❌ Do NOT use these agents if you're building:**
- Django/Rails/Laravel backends (different stack)
- Non-Supabase backends
- Apps without credit/payment systems
- General web development projects

## Orchestration Pattern

Since sub-agents in Claude Code cannot directly invoke other sub-agents, orchestration follows this strict pattern:

### CRITICAL: Agent Routing Protocol

**When handling Supabase backend tasks, you MUST:**

1. **ALWAYS start with backend-tech-lead-orchestrator** for any multi-step backend task
2. **FOLLOW the agent routing map** returned by tech-lead EXACTLY
3. **USE ONLY the Supabase specialists** explicitly recommended by tech-lead
4. **NEVER select agents independently** - tech-lead knows which specialists exist

### Example: Building a Credit System with IAP

```
User: "Build a credit system with Apple IAP verification"

Main Claude Agent:
1. First, I'll use the backend-tech-lead-orchestrator to analyze and get routing
   → Tech lead returns Agent Routing Map with SPECIFIC Supabase agents

2. I MUST use ONLY the agents listed in the routing map:
   - If tech-lead says "use credit-system-architect" → Use that EXACT agent
   - If tech-lead says "use iap-verification-specialist" → Use that EXACT agent
   - DO NOT substitute with generic agents unless specified as fallback

3. Execute tasks in the order specified by tech-lead using TodoWrite
```

### Key Orchestration Rules

1. **Backend Tech-Lead is Routing Authority**: Tech-lead determines which Supabase specialist handles each task
2. **Strict Agent Selection**: Use ONLY agents from tech-lead's "Available Agents" list
3. **No Improvisation**: Do NOT select agents based on your own judgment
4. **Maximum 2 Parallel Agents**: Control context usage by limiting parallel execution
5. **Structured Handoffs**: Extract and pass information between specialist invocations

### Agent Selection Flow

```
CORRECT FLOW:
User Request → Backend Tech-Lead Analysis → Agent Routing Map → Execute with Supabase Specialists

INCORRECT FLOW:
User Request → Main Agent Guesses → Wrong Agent Selected → Task Fails
```

### Example Tech-Lead Response You Must Follow

When backend-tech-lead returns:
```
## Available Agents for This Project
- supabase-database-architect: PostgreSQL schemas, RLS, stored procedures
- credit-system-architect: Atomic credit operations
- iap-verification-specialist: Apple IAP verification
- auth-security-specialist: Apple Sign-In, DeviceCheck
```

You MUST use these specific Supabase specialists, NOT generic alternatives like "backend-developer"

## Agent Organization

### 1. Orchestrator (`agents/orchestrators/`)

**backend-tech-lead-orchestrator** (uses Opus model)
- Analyzes Supabase backend requirements
- Coordinates all 7 Supabase specialists
- Returns structured Agent Routing Map
- Ensures proper layer separation (Database → API → Security → Operations)

### 2. Supabase Backend Specialists (`agents/specialized/supabase/`)

The 7 specialized agents that execute backend tasks:

**Database Layer:**
1. **supabase-database-architect**
   - PostgreSQL schemas, RLS policies, indexes
   - Database migrations
   - Stored procedures design
   - Query optimization

2. **credit-system-architect**
   - Atomic credit operations with `FOR UPDATE` locking
   - Stored procedures: `add_credits()`, `deduct_credits()`
   - Audit trails with balance snapshots
   - Rollback logic for failed operations
   - Prevents race conditions and duplicate charges

**API Layer:**
3. **supabase-edge-function-developer**
   - Deno Edge Functions
   - REST API endpoints
   - Error handling
   - Request validation

4. **provider-integration-specialist**
   - External API integration (FalAI, Runway, Pika, StabilityAI)
   - Idempotency patterns (HTTP + database)
   - Webhook systems
   - Retry logic with exponential backoff
   - Multi-provider abstraction with health monitoring

**Security Layer:**
5. **auth-security-specialist**
   - Apple Sign-In + DeviceCheck
   - Email/Password authentication (Supabase Auth)
   - JWT token management
   - Guest account patterns
   - Account merging (guest → authenticated)

6. **iap-verification-specialist**
   - Server-side Apple IAP verification
   - App Store Server API integration
   - Subscription lifecycle (7 states: active → grace → expired)
   - Refund processing with fraud detection
   - Products database patterns

**Operations Layer:**
7. **backend-operations-engineer**
   - Sentry error tracking setup
   - Telegram alert configuration
   - Rate limiting implementation
   - Testing infrastructure (API tests, load tests)
   - Metrics collection and monitoring

## Orchestration Workflow

The main Claude agent implements this workflow using the backend-tech-lead-orchestrator:

1. **Analysis Phase**: Backend tech-lead analyzes Supabase requirements and returns routing map
2. **Planning Phase**: Main agent creates tasks with TodoWrite based on tech-lead's recommendations
3. **Execution Phase**: Main agent invokes Supabase specialists sequentially (max 2 in parallel)
4. **Coordination**: Main agent extracts findings and passes context between specialists

### Agent Communication Protocol

Since sub-agents cannot directly communicate:
- **Structured Returns**: Each specialist returns findings in parseable format
- **Context Passing**: Main agent extracts relevant information from returns
- **Sequential Coordination**: Main agent manages execution flow
- **Handoff Information**: Specialists include what next specialist needs

Example return format:
```
## Task Completed: Credit System Database Schema

### Created Tables
- users (credits_remaining, credits_total)
- quota_log (audit trail with balance snapshots)
- products (IAP product configurations)

### Created Stored Procedures
- add_credits(user_id, amount, reason, transaction_id)
- deduct_credits(user_id, amount, reason)

### Next Specialist Needs
- Table names: users, quota_log, products
- Stored procedure signatures for Edge Function calls
- RLS policies are configured (authenticated users can read their own data)

Handoff to: credit-system-architect for atomic credit operations implementation
```

## Complete Orchestration Example

Here's a full example showing proper Supabase backend orchestration:

### User Request:
"Build a credit-based video generation backend with Apple IAP"

### Step 1: Backend Tech-Lead Analysis
```
Main Agent: "I'll use the backend-tech-lead-orchestrator to analyze this Supabase backend requirement."

[Invokes backend-tech-lead-orchestrator]
```

### Step 2: Backend Tech-Lead Returns Routing Map
```
## Task Analysis
- Need video generation API with credit system
- Supabase backend: PostgreSQL + Edge Functions (Deno)
- Apple Sign-In, IAP for credits, FalAI for video generation
- Key patterns: atomic credit deduction, idempotency, rollback on failure

## SubAgent Assignments
Task 1: Design database schema (users, models, video_jobs, quota_log) → AGENT: supabase-database-architect
Task 2: Create RLS policies for data isolation → AGENT: supabase-database-architect
Task 3: Build credit system stored procedures (deduct/add credits atomically) → AGENT: credit-system-architect
Task 4: Create device-check endpoint (guest onboarding) → AGENT: supabase-edge-function-developer
Task 5: Build generate-video endpoint with idempotency → AGENT: supabase-edge-function-developer
Task 6: Integrate FalAI provider with rollback logic → AGENT: provider-integration-specialist
Task 7: Add Apple Sign-In and DeviceCheck verification → AGENT: auth-security-specialist
Task 8: Implement IAP verification for credit purchases → AGENT: iap-verification-specialist
Task 9: Set up Sentry error tracking and Telegram alerts → AGENT: backend-operations-engineer

## Execution Order
- **Sequential**: Task 1 → Task 2 → Task 3 (database foundation)
- **Parallel**: Tasks 4, 5 after Task 3 (Edge Functions)
- **Sequential**: Task 6 after Task 5 (provider integration)
- **Parallel**: Tasks 7, 8 after Task 6 (security layer)
- **Sequential**: Task 9 after all (operations last)

## Available Agents for This Project
- supabase-database-architect: PostgreSQL schema, RLS, indexes
- credit-system-architect: Atomic credit operations with stored procedures
- supabase-edge-function-developer: Deno Edge Functions, REST APIs
- provider-integration-specialist: FalAI integration, idempotency, webhooks
- auth-security-specialist: Apple Sign-In, DeviceCheck, JWT
- iap-verification-specialist: Server-side IAP verification
- backend-operations-engineer: Sentry, Telegram alerts, monitoring

## Instructions to Main Agent
- Delegate task 1 to supabase-database-architect (database schema)
- After task 1, delegate task 2 to supabase-database-architect (RLS)
- After task 2, delegate task 3 to credit-system-architect (stored procedures)
- After task 3, run tasks 4 and 5 in parallel using supabase-edge-function-developer
- After task 5, delegate task 6 to provider-integration-specialist
- After task 6, run tasks 7 and 8 in parallel (auth and IAP)
- After all tasks complete, delegate task 9 to backend-operations-engineer
```

### Step 3: Main Agent Executes Plan
```
Main Agent: "Based on the backend tech-lead's routing, I'll coordinate the Supabase backend implementation:"

1. ✓ Using supabase-database-architect for database schema
2. ✓ Using supabase-database-architect for RLS policies
3. ✓ Using credit-system-architect for atomic stored procedures
4. ✓ Using supabase-edge-function-developer for Edge Functions (parallel)
5. ✓ Using provider-integration-specialist for FalAI integration
6. ✓ Using auth-security-specialist for Apple Sign-In (parallel with IAP)
7. ✓ Using iap-verification-specialist for IAP verification (parallel with auth)
8. ✓ Using backend-operations-engineer for monitoring setup

[Executes each step with the EXACT Supabase specialists specified]
```

### What NOT to Do:
```
❌ "I'll use backend-developer" (when tech-lead specified supabase-database-architect)
❌ "I'll use django-api-developer" (wrong stack - this is Supabase/Deno, not Django)
❌ "I'll skip the tech-lead and choose agents myself" (bypasses routing)
❌ "I'll run all tasks in parallel" (violates max 2 parallel rule)
```

## Key Backend Principles

These Supabase specialists follow strict principles:

1. **Database First**: Always start with schema, RLS policies, and stored procedures
2. **Atomic Operations**: Use stored procedures with `FOR UPDATE` for financial operations
3. **Idempotency**: All state-changing operations must be idempotent (HTTP + DB level)
4. **Rollback Logic**: Every credit deduction must have a refund path
5. **Security by Default**: RLS policies, server-side verification, never trust client
6. **Audit Trail**: Log all transactions with balance snapshots
7. **Error Tracking**: Set up Sentry and Telegram alerts before launching

## Documentation Reference

Comprehensive backend documentation is available:

### Backend Architecture (`docs/backend/`)
- `backend-INDEX.md` - Overview of all backend docs
- `backend-1-overview-database.md` - System architecture, database schemas, RLS
- `backend-2-core-apis.md` - API endpoints, request/response patterns
- `backend-3-generation-workflow.md` - Video generation, provider integration, webhooks
- `backend-4-auth-security.md` - Authentication flows, security best practices
- `backend-5-credit-system.md` - Credit management, atomic operations, transactions
- `backend-6-operations-testing.md` - Monitoring, error tracking, deployment

### Implementation Guides (`docs/`)
- `IAP-IMPLEMENTATION-STRATEGY.md` - Complete IAP guide (products, subscriptions, refunds)
- `EXTERNAL-API-STRATEGY.md` - Multi-provider integration, retry logic, failover
- `AUTH-DECISION-FRAMEWORK.md` - Authentication strategy decision framework
- `EMAIL-PASSWORD-AUTH.md` - Supabase Auth setup
- `EMAIL-SERVICE-INTEGRATION.md` - Resend + Supabase for transactional emails
- `OPERATIONS-MONITORING-CHECKLIST.md` - Production readiness (7 checklists)
- `FRONTEND-SUPABASE-INTEGRATION.md` - Next.js + Supabase client patterns

### Templates (`templates/`)
- `ios/Services/` - Swift services (SupabaseAuth, CreditSystem, IAPManager)
- `nextjs/` - Next.js auth pages, components, middleware
- `supabase/functions/` - Edge Function examples
- `supabase/migrations/` - Database migration templates

## Agent Definition Format

```yaml
---
name: agent-name
description: |
  Supabase-specific expertise description
  Examples:
  - <example>
    Context: Supabase backend scenario
    user: "Build credit system"
    assistant: "I'll use credit-system-architect"
    <commentary>Atomic operations required</commentary>
  </example>
# tools: omit for all tools (recommended for Supabase specialists)
model: opus  # backend-tech-lead-orchestrator uses opus for complex reasoning
---

# Agent Name - Supabase Specialist

System prompt focused on Supabase/PostgreSQL/Edge Functions...
```

## Development Guidelines

1. **Creating New Supabase Specialists**:
   - Focus on single Supabase domain (database, API, auth, IAP, provider, operations)
   - Include 2-3 XML examples with Supabase scenarios
   - Define structured return format with handoff information
   - Reference relevant documentation in `docs/backend/`

2. **Agent Return Patterns**:
   - Always return findings in structured format
   - Include "Next Specialist Needs" section
   - List created resources (tables, functions, endpoints)
   - Specify handoff to next Supabase specialist

3. **Testing Agents**:
   - Test with real Supabase backend scenarios
   - Verify atomic operations work correctly
   - Ensure RLS policies are properly configured
   - Test idempotency patterns

## Critical Reminders

- **ALWAYS use backend-tech-lead-orchestrator** for multi-step Supabase backend tasks
- **FOLLOW the agent routing map exactly** - use only listed Supabase specialists
- **MAXIMUM 2 agents in parallel** - control context usage
- **Database layer first** - schema, RLS, stored procedures before APIs
- **Never trust client** - all financial operations server-side
- **Atomic operations** - use stored procedures with `FOR UPDATE`
- **Idempotency everywhere** - both HTTP and database level
- **Audit trails** - log every credit transaction with balance snapshots
- **Rollback logic** - every deduction needs a refund path
- **Error tracking** - Sentry + Telegram alerts are mandatory

## Anti-Patterns to Avoid

❌ Building API before database schema
❌ Trusting client-sent credit amounts
❌ Skipping idempotency for payment operations
❌ Forgetting rollback logic on failures
❌ Missing RLS policies on tables
❌ No error tracking in production
❌ Hardcoding product configurations (use products database)
❌ Using generic "backend-developer" instead of Supabase specialists
❌ Running more than 2 agents in parallel

---

**This project is specialized for Supabase backends with credit systems, IAP verification, and external API integration. For other backend stacks (Django, Rails, Laravel), use different agent collections.**
