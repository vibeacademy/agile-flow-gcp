---
description: "Phase 2: Define Technical Architecture based on PRD"
---

Launch the system-architect agent to define the technical architecture based on your Product Requirements Document.

## Bootstrap Phase 2: Technical Architecture

**Prerequisite**: Phase 1 (Product Definition) must be complete.

The System Architect will read your PRD and help you define:

1. **Technology Stack** - Languages, frameworks, tools
2. **System Design** - Components, services, boundaries
3. **Data Models** - Entities, relationships, storage
4. **API Contracts** - Interfaces, protocols, patterns
5. **Infrastructure** - Hosting, deployment, scaling
6. **Development Standards** - Coding conventions, testing requirements

## Process

### 0. Platform Selection

Before diving into architecture, ask the user about their deployment platform:

```
What platform will you deploy to?

1. Render (Recommended for this template)
2. Cloudflare (Workers/Pages)
3. Vercel
4. Railway
5. Fly.io
6. Other (please specify)

Enter a number (1-6):
```

Write the platform choice to `.claude/PROJECT.md`:

```markdown
## Platform
- **Hosting**: [selected platform]
- **Selected**: [date]
```

This file is read by the `devops-engineer` and `system-architect` agents
to provide platform-specific guidance.

### 1. PRD Analysis
The architect first analyzes your Product Requirements:
- What features need to be built?
- What scale do we need to support?
- What are the technical constraints?
- What integrations are required?

### 2. Technology Selection
For each layer of the stack:
- Present 2-3 options with trade-offs
- Recommend based on requirements
- Document the decision rationale

### 3. System Design
Define the high-level architecture:
- Component boundaries
- Data flow
- Integration points
- Security boundaries

### 4. Standards Definition
Establish development standards:
- Coding conventions
- Testing requirements
- Documentation standards
- Review criteria

## Output

This phase creates:

### docs/TECHNICAL-ARCHITECTURE.md
```markdown
# Technical Architecture

## Overview
[High-level system description]

## Technology Stack

### Frontend
- Framework: [e.g., React 18+]
- Language: [e.g., TypeScript 5.x]
- Styling: [e.g., Tailwind CSS]
- Build: [e.g., Vite]
- Testing: [e.g., Vitest + Testing Library]

### Backend
- Runtime: [e.g., Node.js 20+]
- Framework: [e.g., Express/Fastify]
- Language: [e.g., TypeScript]
- Testing: [e.g., Jest]

### Database
- Primary: [e.g., PostgreSQL 15]
- Cache: [e.g., Redis]
- Search: [e.g., Elasticsearch] (if needed)

### Infrastructure
- Hosting: [e.g., Render/Cloudflare/Vercel/Railway/Fly.io]
- CI/CD: [e.g., GitHub Actions]
- Monitoring: [e.g., DataDog]

## System Design

### Component Diagram
[ASCII or description of components]

### Data Flow
[How data moves through the system]

### API Design
[REST/GraphQL/gRPC patterns]

## Data Models

### Core Entities
[Entity definitions and relationships]

### Database Schema
[Key tables/collections]

## Development Standards

### Code Style
- [Linting rules]
- [Formatting rules]
- [Naming conventions]

### Testing Requirements
- Unit test coverage: [e.g., 80%]
- Integration tests: [requirements]
- E2E tests: [requirements]

### Documentation
- [What needs documentation]
- [Documentation format]

### Code Review
- [Review checklist]
- [Approval requirements]

## Security

### Authentication
[Auth approach]

### Authorization
[Permissions model]

### Data Protection
[Encryption, PII handling]

## Scalability

### Current Targets
[Expected load]

### Scaling Strategy
[How we'll scale]

## Architecture Decision Records

### ADR-001: [First Decision]
- Status: Accepted
- Context: [Why this decision]
- Decision: [What we decided]
- Consequences: [Impact]
```

## CLAUDE.md Updates

This phase also updates CLAUDE.md with project-specific configuration:
- Technology stack details
- Code standards
- Build and test commands
- Definition of Ready/Done refinements

## What Gets Unlocked

After Phase 2 is complete:
- **Ticket Worker** knows the tech stack and coding standards
- **PR Reviewer** knows what to check for
- **Quality Engineer** knows testing requirements
- **All agents** can give project-specific guidance

## Architecture Patterns

The architect will recommend patterns based on your needs:

| Pattern | Best For |
|---------|----------|
| Monolith | Small team, early stage, simple domain |
| Modular Monolith | Growing team, need boundaries |
| Microservices | Large scale, independent deployment |
| Serverless | Event-driven, variable load |
| JAMstack | Content sites, static-first |

## Tips for Success

1. **Start simple** - You can always add complexity later
2. **Optimize for change** - Requirements will evolve
3. **Document decisions** - Future you will thank present you
4. **Consider the team** - Pick tech your team can maintain
5. **Plan for testing** - Testability is an architecture concern

## Running This Command

1. Ensure Phase 1 is complete (PRD exists)
2. Type `/bootstrap-architecture`
3. Answer the architect's questions about constraints and preferences
4. Review the proposed architecture
5. Iterate until satisfied

When complete, run `./bootstrap.sh` to continue to Phase 3.
