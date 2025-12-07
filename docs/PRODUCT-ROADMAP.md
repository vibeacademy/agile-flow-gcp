# Product Roadmap: Agile Flow

## Overview

This roadmap outlines the phased development of Agile Flow, a project template for bootstrapping Claude Code projects with a complete agile workflow powered by specialized AI agents.

## Roadmap Phases

### Phase 1: Foundation (COMPLETE)

**Goal**: Establish core agent architecture with safety guarantees.

| Epic | Description | Status |
|------|-------------|--------|
| #1 - Core Agent Safety Architecture | NON-NEGOTIABLE PROTOCOL, bot account separation, settings template | Done |
| #6 - PR Workflow Improvements | Rename pr-reviewer-merger to pr-reviewer, clarify approval boundaries | Done |

**Deliverables**:
- Agent policies with explicit behavioral boundaries
- Bot account documentation and setup guide
- Settings template with deny rules for sensitive operations
- Three-stage workflow (worker creates, reviewer reviews, human merges)

### Phase 2: Quality Infrastructure (IN PROGRESS)

**Goal**: Build validation and observability tooling.

| Epic | Description | Status |
|------|-------------|--------|
| #20 - CI/CD Pipeline | GitHub Actions workflow, validation scripts, policy linter | Done |
| #11 - Safety & Observability | Agent action logging, audit trails, violation detection | Ready |

**Deliverables**:
- CI pipeline validating agent policies
- Agent instruction linter
- Audit logging infrastructure
- Weekly audit workflows

### Phase 3: Integration & Extensibility

**Goal**: Enable project integration and customization.

| Epic | Description | Status |
|------|-------------|--------|
| #16 - Cloudflare Integration | DevOps engineer agent, preview environments, infrastructure cleanup | Backlog |
| Bootstrap Commands | /bootstrap-product, /bootstrap-architecture, /bootstrap-agents, /bootstrap-workflow | Backlog |

**Deliverables**:
- Infrastructure integration patterns
- Project bootstrap workflow
- Agent specialization automation
- Template placeholders for customization

### Phase 4: Documentation & Polish

**Goal**: Production-ready documentation and tooling.

| Epic | Description | Status |
|------|-------------|--------|
| #24 - Documentation | Comprehensive README, setup guide, troubleshooting FAQ | Backlog |
| Marketing Commands | Campaign planning, referral programs, GTM alignment | Backlog |

**Deliverables**:
- Complete setup documentation
- Troubleshooting guide
- Example configurations
- Marketing agent documentation

## Milestone Definitions

### M1: Safe Agent Operations (COMPLETE)

Agents cannot perform destructive actions:
- No direct commits to main
- No PR merges by agents
- No issue closure by agents
- Clear audit trail via bot accounts

### M2: Validated Workflows (IN PROGRESS)

All agent operations are validated:
- CI validates agent policies on every PR
- Policy violations detected before merge
- Audit logging captures agent actions

### M3: Production Ready

Template is ready for adoption:
- Complete documentation
- Bootstrap automation
- Integration examples
- Troubleshooting resources

## Success Criteria

| Phase | Criteria |
|-------|----------|
| Phase 1 | Zero agent policy violations possible through NON-NEGOTIABLE PROTOCOL |
| Phase 2 | CI catches 100% of policy compliance issues |
| Phase 3 | New project setup < 30 minutes |
| Phase 4 | Self-service adoption without support |

## Dependencies

```
Phase 1: Foundation
    |
    v
Phase 2: Quality Infrastructure
    |
    v
Phase 3: Integration & Extensibility
    |
    v
Phase 4: Documentation & Polish
```

Each phase builds on the previous. Phase 2 cannot validate what Phase 1 didn't define. Phase 3 cannot integrate what Phase 2 didn't validate.

## Risk Register

| Risk | Phase | Mitigation |
|------|-------|------------|
| Agent bypasses safety controls | 1 | NON-NEGOTIABLE PROTOCOL + branch protection |
| CI doesn't catch violations | 2 | Multiple validation layers + policy linter |
| Complex setup deters adoption | 3-4 | Bootstrap automation + clear docs |
| Stale documentation | 4 | CI validation of doc accuracy |

## Revision History

| Date | Change | Author |
|------|--------|--------|
| 2025-12-07 | Initial roadmap creation | Claude |
