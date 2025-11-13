# AI Team of Jans - Supabase Backend Specialists 🚀

**A specialized AI agent team for building production-ready Supabase backends** with credit systems, IAP verification, authentication, and external API integrations.

## 🎯 What This Is

This is a **focused collection of 8 specialized AI agents** designed to help solo developers build robust Supabase backends. The agents work together as a coordinated team, with each agent handling specific aspects of backend development:

- **Database architecture** (PostgreSQL, RLS, stored procedures)
- **Edge Functions** (Deno-based REST APIs)
- **Credit systems** (atomic operations, audit trails)
- **IAP verification** (Apple App Store Server API)
- **Authentication** (Apple Sign-In, DeviceCheck, email/password)
- **External API integration** (video generation, AI providers)
- **Operations** (monitoring, error tracking, testing)

## ⚠️ Important Notice

**This project is focused on Supabase backends**, specifically optimized for applications with:
- Credit/quota management systems
- In-App Purchase (IAP) verification
- Video generation or AI provider integrations
- Guest-to-authenticated user flows
- Atomic financial operations

If you're building a different type of backend or using a different stack, these agents may not be suitable.

## 📦 Repository Structure

```
awesome-claude-agents/
├── supabase-specialists/          # Supabase backend agents & resources
│   ├── agents/                    # 8 specialized agents
│   │   ├── orchestrators/
│   │   │   └── backend-tech-lead-orchestrator.md
│   │   └── specialized/
│   │       └── supabase/
│   │           ├── supabase-database-architect.md
│   │           ├── credit-system-architect.md
│   │           ├── supabase-edge-function-developer.md
│   │           ├── provider-integration-specialist.md
│   │           ├── auth-security-specialist.md
│   │           ├── iap-verification-specialist.md
│   │           └── backend-operations-engineer.md
│   ├── docs/                      # Backend documentation (100KB+)
│   ├── templates/                 # Code templates (iOS, Next.js, Supabase)
│   └── CLAUDE.md                  # Project instructions for Claude Code
│
├── framework-agents/              # Optional: Generic Claude Code agents
│   └── .claude/
│       └── agents/                # 45 framework agents (Python, Rails, React, etc.)
│
├── install-supabase.sh           # 🚀 Smart installer script
├── README.md                     # This file
└── CONTRIBUTING.md               # Contribution guidelines
```

## 🚀 Quick Start

### Prerequisites
- **Claude Code CLI** installed and authenticated
- **Claude subscription** - required for agent workflows
- Active project directory (your Supabase project)
- Basic understanding of Supabase (Edge Functions, PostgreSQL)

### Installation (Recommended Method)

Use the smart installer to add Supabase specialists to your project:

```bash
# 1. Clone this repository
git clone https://github.com/your-username/awesome-claude-agents.git
cd awesome-claude-agents

# 2. Run installer on your project
./install-supabase.sh ~/path/to/your-project

# Or install to current directory
./install-supabase.sh .
```

The installer will:
- ✅ Install 8 Supabase specialist agents to `.claude/agents/`
- ✅ Copy backend documentation to `docs/backend-architecture/`
- ✅ Copy code templates to `templates/supabase-backend/`
- ✅ Add or append to your `CLAUDE.md` file
- ✅ Prompt before overwriting existing files
- ✅ Update `.gitignore` with optional entries

### Manual Installation (Alternative)

If you prefer manual control:

```bash
# 1. Navigate to your project
cd ~/your-project

# 2. Copy agents
mkdir -p .claude/agents
cp -r /path/to/awesome-claude-agents/supabase-specialists/agents/* .claude/agents/

# 3. Copy documentation
mkdir -p docs
cp -r /path/to/awesome-claude-agents/supabase-specialists/docs docs/backend-architecture

# 4. Copy templates
mkdir -p templates
cp -r /path/to/awesome-claude-agents/supabase-specialists/templates templates/supabase-backend

# 5. Copy CLAUDE.md
cp /path/to/awesome-claude-agents/supabase-specialists/CLAUDE.md .
```

### Verify Installation

```bash
# Check that agents are installed
claude /agents

# You should see:
# - backend-tech-lead-orchestrator
# - supabase-database-architect
# - credit-system-architect
# - supabase-edge-function-developer
# - provider-integration-specialist
# - auth-security-specialist
# - iap-verification-specialist
# - backend-operations-engineer
```

### Start Building

Navigate to your project and use the orchestrator:

```bash
cd ~/your-project

# Build a credit system
claude "use @backend-tech-lead-orchestrator and help me build a credit system with IAP verification"

# Add authentication
claude "use @backend-tech-lead-orchestrator and set up Apple Sign-In with DeviceCheck fraud prevention"

# Integrate external API
claude "use @backend-tech-lead-orchestrator and integrate FalAI video generation with idempotency"
```

## 👥 Meet Your AI Backend Team

### 🎭 Orchestrator (1 agent)

- **[Backend Tech Lead Orchestrator](supabase-specialists/agents/orchestrators/backend-tech-lead-orchestrator.md)** - Senior backend architect who analyzes requirements and coordinates the specialist team. Always start here for multi-step backend tasks.

### 🔧 Supabase Specialists (7 agents)

1. **[Supabase Database Architect](supabase-specialists/agents/specialized/supabase/supabase-database-architect.md)** - PostgreSQL schemas, RLS policies, indexes, migrations, and database optimization

2. **[Supabase Edge Function Developer](supabase-specialists/agents/specialized/supabase/supabase-edge-function-developer.md)** - Deno Edge Functions, REST APIs, error handling, and API design

3. **[Credit System Architect](supabase-specialists/agents/specialized/supabase/credit-system-architect.md)** - Atomic credit operations, stored procedures, audit trails, and transaction safety

4. **[IAP Verification Specialist](supabase-specialists/agents/specialized/supabase/iap-verification-specialist.md)** - Apple App Store Server API, receipt verification, subscription handling, and refund processing

5. **[Auth Security Specialist](supabase-specialists/agents/specialized/supabase/auth-security-specialist.md)** - Apple Sign-In, DeviceCheck, email/password auth, JWT management, and security best practices

6. **[Provider Integration Specialist](supabase-specialists/agents/specialized/supabase/provider-integration-specialist.md)** - External API integration, idempotency, webhooks, retry logic, and multi-provider abstraction

7. **[Backend Operations Engineer](supabase-specialists/agents/specialized/supabase/backend-operations-engineer.md)** - Error tracking (Sentry), monitoring, Telegram alerts, rate limiting, and testing infrastructure

**Total: 8 specialized agents** working together to build your Supabase backend!

## 📚 Documentation

Comprehensive backend documentation is included in `supabase-specialists/docs/`:

### Backend Architecture Guides
- **[Backend Index](supabase-specialists/docs/backend/backend-INDEX.md)** - Overview of all backend documentation
- **[Overview & Database](supabase-specialists/docs/backend/backend-1-overview-database.md)** - System architecture, database design, RLS policies
- **[Core APIs](supabase-specialists/docs/backend/backend-2-core-apis.md)** - API endpoints, request/response patterns, authentication
- **[Generation Workflow](supabase-specialists/docs/backend/backend-3-generation-workflow.md)** - Video generation, provider integration, webhooks
- **[Auth & Security](supabase-specialists/docs/backend/backend-4-auth-security.md)** - Authentication flows, security best practices
- **[Credit System](supabase-specialists/docs/backend/backend-5-credit-system.md)** - Credit management, atomic operations, transactions
- **[Operations & Testing](supabase-specialists/docs/backend/backend-6-operations-testing.md)** - Monitoring, error tracking, deployment

### Implementation Guides
- **[Auth Decision Framework](supabase-specialists/docs/AUTH-DECISION-FRAMEWORK.md)** - Choosing authentication methods
- **[Email/Password Auth](supabase-specialists/docs/EMAIL-PASSWORD-AUTH.md)** - Supabase Auth setup
- **[Email Service Integration](supabase-specialists/docs/EMAIL-SERVICE-INTEGRATION.md)** - Transactional emails with Resend
- **[IAP Implementation Strategy](supabase-specialists/docs/IAP-IMPLEMENTATION-STRATEGY.md)** - Complete IAP guide (products, subscriptions, refunds)
- **[External API Strategy](supabase-specialists/docs/EXTERNAL-API-STRATEGY.md)** - Multi-provider integration, retry logic, failover
- **[Operations Checklist](supabase-specialists/docs/OPERATIONS-MONITORING-CHECKLIST.md)** - Production readiness guide
- **[Frontend Integration](supabase-specialists/docs/FRONTEND-SUPABASE-INTEGRATION.md)** - Client-side patterns

## 🎯 How It Works

### Orchestration Pattern

1. **Start with the Orchestrator**: Use `@backend-tech-lead-orchestrator` for any multi-step backend task
2. **Get Routing Plan**: The orchestrator analyzes your requirements and creates a task plan
3. **Specialists Execute**: Each specialist handles their domain (database, APIs, auth, etc.)
4. **Coordinated Delivery**: Agents work together, sharing context and ensuring consistency

### Example Workflow

```
User: "Build a credit system with IAP verification"

1. Orchestrator analyzes → Creates task plan
2. Database Architect → Designs schema and stored procedures
3. Edge Function Developer → Builds API endpoints
4. Credit System Architect → Implements atomic operations
5. IAP Specialist → Adds purchase verification
6. Operations Engineer → Sets up monitoring
```

## 🛠️ Templates

Ready-to-use code templates are included in `supabase-specialists/templates/`:

### iOS (Swift)
- `ios/Services/` - CreditSystem, IAPManager, SupabaseAuth
- `ios-testing-suite/` - Complete testing framework with mocks

### Next.js (TypeScript)
- `nextjs/` - Auth pages, components, Supabase client setup

### Supabase
- `supabase/functions/` - Edge Function examples
- `supabase/migrations/` - Database migration templates

## 🔥 Key Features

- **Specialized Expertise**: Each agent masters their Supabase domain
- **Production-Ready Patterns**: Atomic operations, idempotency, rollback logic
- **Security First**: RLS policies, server-side verification, fraud prevention
- **Complete Documentation**: Step-by-step guides for every backend component
- **Real-World Tested**: Patterns extracted from production applications
- **Easy Installation**: Smart installer handles setup and conflicts

## 📈 What You Can Build

With these agents, you can build backends for:

- **Video Generation Apps** - Credit-based generation with provider integration
- **AI-Powered Applications** - Quota management for AI API usage
- **SaaS Products** - User management, subscriptions, usage tracking
- **Mobile Apps** - IAP verification, guest accounts, credit systems

## 🤝 Contributing

Contributions are welcome! Whether it's:
- 🐛 Bug reports and fixes
- 💡 New agent ideas or improvements
- 📝 Documentation improvements
- 🎨 Pattern enhancements

Please see [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

## 📄 License

Proprietary - All rights reserved. AI Team of Jans © 2025

---

## 🎓 Learning Resources

### For Beginners
1. Start with [Backend Index](supabase-specialists/docs/backend/backend-INDEX.md) to understand the architecture
2. Read [Overview & Database](supabase-specialists/docs/backend/backend-1-overview-database.md) for database fundamentals
3. Follow the implementation guides step-by-step

### For Experienced Developers
1. Review the [Backend Roadmap](BACKEND-ROADMAP.md) for pattern analysis
2. Check [IAP Implementation Strategy](supabase-specialists/docs/IAP-IMPLEMENTATION-STRATEGY.md) for advanced patterns
3. Use templates as starting points for your projects

## 🚨 Common Use Cases

### Building a Credit System
```bash
claude "use @backend-tech-lead-orchestrator and design a credit system with atomic operations"
```

### Adding IAP Verification
```bash
claude "use @backend-tech-lead-orchestrator and implement Apple IAP verification with subscription support"
```

### Setting Up Authentication
```bash
claude "use @backend-tech-lead-orchestrator and set up Apple Sign-In with DeviceCheck fraud prevention"
```

### Integrating External APIs
```bash
claude "use @backend-tech-lead-orchestrator and integrate FalAI video generation with idempotency and retry logic"
```

---

## 🔧 Advanced: Framework Agents (Optional)

The `framework-agents/` directory contains 45 additional agents for other frameworks (Django, Rails, Laravel, React, Vue, etc.). These are optional and independent from the Supabase specialists.

To use framework agents:
```bash
# Copy to global Claude Code directory
cp -r framework-agents/.claude ~/.claude-framework-agents

# Or symlink
ln -sf "$(pwd)/framework-agents/.claude" ~/.claude-framework-agents
```

**Note**: The Supabase specialists are completely independent and don't require framework agents.

---

<p align="center">
  <strong>AI Team of Jans - Build production-ready Supabase backends with an AI team of specialists</strong><br>
  <em>Focused. Expert. Production-tested.</em>
</p>
