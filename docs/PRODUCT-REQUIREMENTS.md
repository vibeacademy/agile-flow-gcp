# Product Requirements Document: Agile Flow

## Executive Summary

Agile Flow is a project template for bootstrapping Claude Code projects with a complete agile workflow powered by specialized AI agents. It provides the configuration, policies, and commands needed to safely integrate AI agents into a trunk-based development workflow.

## Problem Statement

Development teams adopting Claude Code face several challenges:

1. **Safety Concerns**: AI agents can perform destructive actions (force push, merge, delete) without proper guardrails
2. **Workflow Integration**: No clear pattern for integrating AI agents into existing agile workflows
3. **Audit Trail**: Difficulty tracking which agent performed which action
4. **Quality Control**: AI-generated code bypassing human review
5. **Configuration Complexity**: Each project reinvents agent policies and permissions

## Target Audience

### Primary Users

**Development Teams** adopting Claude Code for AI-assisted development:
- Teams practicing trunk-based development
- Organizations requiring human oversight of AI actions
- Projects needing clear separation of duties between agents and humans

### Secondary Users

**Platform Engineers** setting up AI development infrastructure:
- Creating standardized agent configurations across projects
- Establishing security policies for AI-assisted workflows
- Building observability into agent actions

## Product Vision

Enable safe, auditable, and productive AI-assisted development by providing:

1. **Pre-configured agent policies** with explicit behavioral boundaries
2. **Three-stage workflow** ensuring human control over code merging
3. **Slash commands** for common agile operations
4. **CI/CD integration** validating agent policy compliance
5. **Observability tools** for monitoring agent actions

## Core Value Propositions

### 1. Safety by Default

- NON-NEGOTIABLE PROTOCOL blocks prevent destructive actions
- Agents cannot merge PRs, push to main, or close issues
- Explicit deny rules for sensitive operations

### 2. Clear Separation of Duties

| Role | Creates | Reviews | Merges |
|------|---------|---------|--------|
| github-ticket-worker | PRs | - | - |
| pr-reviewer | - | Reviews | - |
| Human | - | Final review | Merges |

### 3. Audit Trail

- Dedicated bot accounts for worker and reviewer roles
- All agent actions attributed to specific accounts
- Clear distinction between AI and human actions

### 4. Agile Integration

- Project board integration (Ready → In Progress → In Review → Done)
- Backlog prioritization with CD3 methodology
- Sprint status and milestone tracking

## Functional Requirements

### FR-1: Agent Policies

| ID | Requirement | Priority |
|----|-------------|----------|
| FR-1.1 | NON-NEGOTIABLE PROTOCOL blocks in all workflow agents | P0 |
| FR-1.2 | GitHub account identity switching instructions | P0 |
| FR-1.3 | Explicit "cannot do" boundaries for each agent | P0 |
| FR-1.4 | Settings template with deny rules | P1 |

### FR-2: Slash Commands

| ID | Requirement | Priority |
|----|-------------|----------|
| FR-2.1 | /work-ticket - Pick up next ticket from Ready | P0 |
| FR-2.2 | /review-pr - Review PRs in In Review column | P0 |
| FR-2.3 | /groom-backlog - Prioritize and populate Ready | P0 |
| FR-2.4 | /sprint-status - Board health overview | P1 |
| FR-2.5 | /check-milestone - Milestone progress | P1 |

### FR-3: CI/CD Integration

| ID | Requirement | Priority |
|----|-------------|----------|
| FR-3.1 | Validate agent policy files have required sections | P0 |
| FR-3.2 | Lint agent instructions for safety compliance | P1 |
| FR-3.3 | Verify settings.template.json deny rules | P1 |

### FR-4: Observability

| ID | Requirement | Priority |
|----|-------------|----------|
| FR-4.1 | Agent action logging | P1 |
| FR-4.2 | Policy violation detection | P1 |
| FR-4.3 | Weekly audit workflows | P2 |

## Non-Functional Requirements

### NFR-1: Security

- No hardcoded secrets in agent policies
- PAT storage guidance for bot accounts
- Explicit deny rules for sensitive file access

### NFR-2: Extensibility

- Template placeholders for project-specific customization
- Clear separation between framework and project code
- Documentation for adding new agents

### NFR-3: Usability

- Clear setup instructions in .claude/README.md
- Settings template with explanatory comments
- Troubleshooting FAQ

## Success Metrics

| Metric | Target |
|--------|--------|
| Agent policy violations | 0 per sprint |
| PRs merged by agents | 0 (human-only) |
| Setup time for new project | < 30 minutes |
| Agent configuration reuse | > 90% across projects |

## Out of Scope

- Application-specific code (this is a template, not an app)
- Runtime agent execution (handled by Claude Code)
- GitHub account creation (manual setup required)
- CI/CD pipeline execution (GitHub Actions handles this)

## Dependencies

- Claude Code CLI
- GitHub repository with project board
- GitHub Actions for CI/CD
- MCP servers (GitHub, Memory)

## Risks and Mitigations

| Risk | Impact | Mitigation |
|------|--------|------------|
| Agent bypasses NON-NEGOTIABLE PROTOCOL | High | Branch protection + policy linter |
| Bot account credentials leaked | High | PAT rotation + security docs |
| Stale agent policies | Medium | CI validation + audit workflows |

## Glossary

| Term | Definition |
|------|------------|
| NON-NEGOTIABLE PROTOCOL | Override rules that agents must follow regardless of other instructions |
| Three-stage workflow | Worker creates → Reviewer reviews → Human merges |
| CD3 | Cost of Delay Divided by Duration - prioritization methodology |
| Definition of Ready | Criteria a ticket must meet before development starts |
