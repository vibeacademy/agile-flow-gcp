# Agile Flow - Claude Code Project Template

This is a template project for bootstrapping Claude-based coding projects with a full agile workflow powered by specialized AI agents.

## Critical Requirements

### Trunk-Based Development (REQUIRED)

**This project template assumes trunk-based development. It will not work without it.**

- `main` branch is protected - no direct commits
- All work happens on short-lived feature branches
- Branch naming: `feature/issue-{number}-short-description`
- All changes go through pull requests
- PRs require review before merge
- Keep branches short-lived (ideally < 1 day)

The agent workflow depends on this:
1. `github-ticket-worker` creates feature branches and PRs
2. `pr-reviewer-merger` reviews PRs (cannot merge - human does)
3. Human performs final review and merge

**Without trunk-based development, the agent handoff workflow breaks.**

### Quality-Driven Development

**The assumption of this pattern is that the quality of internal deliverables drives final product quality.**

This means:
- Ticket quality determines implementation quality
- Code review quality determines merge quality
- Test quality determines release confidence
- Documentation quality determines maintainability

Each agent is responsible for the quality of their deliverables:
- Product Manager: Quality of strategic decisions and feature evaluations
- Product Owner: Quality of tickets (clear, complete, actionable)
- Ticket Worker: Quality of implementation (clean, tested, documented)
- PR Reviewer: Quality of reviews (thorough, constructive, actionable)
- Quality Engineer: Quality of test plans and validation
- System Architect: Quality of design decisions and guidance

## Project Configuration

### Required Files

Before using this template, create these files:

```
docs/
  PRODUCT-REQUIREMENTS.md    # Product vision, features, target audience
  PRODUCT-ROADMAP.md         # Phases, milestones, timeline
```

### GitHub Project Board Setup

Create a GitHub Project board with these columns:
- **Icebox** - Ideas not yet prioritized
- **Backlog** - Prioritized but not ready for work
- **Ready** - Well-defined, ready to pick up (2-5 items)
- **In Progress** - Currently being worked on (1 item per developer)
- **In Review** - PR created, awaiting review
- **Done** - Merged and complete

### Repository Settings

Configure branch protection on `main`:
- Require pull request reviews before merging
- Require status checks to pass (CI/CD)
- Do not allow bypassing the above settings

## Agent Configuration

### Agent Roles and Boundaries

| Agent | Role | Owns | Cannot Do |
|-------|------|------|-----------|
| Product Manager | Strategy | Vision, go/no-go, feature eval | Backlog management |
| Product Owner | Tactics | Backlog, tickets, priorities | Strategic decisions |
| Ticket Worker | Implementation | Code, tests, PRs | Merge PRs |
| PR Reviewer | Quality Gate | Code review, recommendations | Merge PRs |
| Quality Engineer | Validation | Test plans, reports | Implementation |
| System Architect | Design | Architecture, patterns | Implementation |

### Agent Handoff Protocol

```
Feature Request
    |
    v
[Product Manager] -- evaluate-feature --> BUILD/DEFER/DECLINE
    |
    | (if BUILD)
    v
[Product Owner] -- groom-backlog --> Ticket in Ready column
    |
    v
[Ticket Worker] -- work-ticket --> PR created, ticket In Review
    |
    v
[PR Reviewer] -- review-pr --> GO/NO-GO recommendation
    |
    v
[Human] -- final review --> Merge PR, move to Done
```

### Memory MCP Configuration

Agents use Memory MCP for cross-session context. Configure in `.claude/settings.local.json`:

```json
{
  "mcpServers": {
    "memory": {
      "command": "npx",
      "args": ["-y", "@anthropic/mcp-memory"]
    }
  }
}
```

Agents store:
- Strategic decisions and rationale
- Prioritization history
- Architecture decisions (ADRs)
- Test patterns and results
- Cross-agent context

### GitHub MCP Configuration

Agents use GitHub MCP for project board operations:

```json
{
  "mcpServers": {
    "github": {
      "command": "npx",
      "args": ["-y", "@anthropic/mcp-github"],
      "env": {
        "GITHUB_TOKEN": "${GITHUB_TOKEN}"
      }
    }
  }
}
```

## Formatting Standards

### No Emojis in ASCII Tables

Do not use emojis inside ASCII tables - they break column alignment.

**Bad:**
```
| Status | Count |
|--------|-------|
| ✅ Done | 5 |
| ❌ Failed | 2 |
```

**Good:**
```
| Status | Count |
|--------|-------|
| Done | 5 |
| Failed | 2 |
```

Emojis are acceptable in:
- Headings
- Bullet points
- Prose text
- Status indicators outside tables

### Markdown Standards

- Use GitHub-flavored markdown
- Code blocks with language specifiers
- Tables for structured data (without emojis)
- Clear heading hierarchy

## Project-Specific Configuration

<!--
TEMPLATE: Fill in project-specific details below when using this template.
-->

### Project Information

- **Project Name**: [Your project name]
- **Repository**: [GitHub repo URL]
- **Project Board**: [GitHub project board URL]
- **Tech Stack**: [Languages, frameworks, tools]

### Team Configuration

- **Organization**: [GitHub org name]
- **Reviewers**: [Who can merge PRs]

### Technology Stack

<!--
Fill in your project's tech stack:

- **Language**: [e.g., TypeScript 5.x]
- **Framework**: [e.g., React 18+, Node.js 20+]
- **Build Tool**: [e.g., Vite, esbuild]
- **Testing**: [e.g., Vitest, Jest]
- **Styling**: [e.g., Tailwind, CSS Modules]
- **Database**: [e.g., PostgreSQL, MongoDB]
- **Infrastructure**: [e.g., AWS, Cloudflare]
-->

### Code Standards

<!--
Fill in your project's code standards:

- **Type Safety**: [e.g., TypeScript strict mode, no `any`]
- **Linting**: [e.g., ESLint config]
- **Formatting**: [e.g., Prettier config]
- **Testing**: [e.g., 80% coverage threshold]
- **Documentation**: [e.g., JSDoc for public APIs]
-->

### Build & Test Commands

<!--
Fill in your project's commands:

```bash
# Install dependencies
npm install

# Run development server
npm run dev

# Run tests
npm test

# Run tests with coverage
npm run test:coverage

# Lint code
npm run lint

# Build for production
npm run build
```
-->

### Definition of Ready

A ticket is ready for development when it has:
- [ ] Clear, specific title
- [ ] Detailed description with context
- [ ] Acceptance criteria (specific, testable)
- [ ] Effort estimate
- [ ] Priority label (P0/P1/P2/P3)
- [ ] No unresolved blockers
- [ ] Technical guidance (if needed)

### Definition of Done

A ticket is done when:
- [ ] All acceptance criteria met
- [ ] Code reviewed and approved
- [ ] All tests passing
- [ ] Coverage meets threshold
- [ ] No linting errors
- [ ] Documentation updated (if needed)
- [ ] PR merged to main
- [ ] Deployed to target environment (if applicable)

## Slash Commands

| Command | Description |
|---------|-------------|
| `/groom-backlog` | Groom backlog, prioritize tickets, populate Ready |
| `/work-ticket` | Pick up next ticket from Ready and implement |
| `/review-pr` | Review PRs in In Review column |
| `/check-milestone` | Check progress toward a roadmap milestone |
| `/evaluate-feature` | Evaluate feature request for strategic fit |
| `/release-decision` | Make go/no-go decision for a release |
| `/sprint-status` | Quick status overview of board and sprint |
| `/test-feature` | Create test plan and validate a feature |
| `/architect-review` | Get architectural guidance or design review |
| `/plan-campaign` | Design a marketing campaign with channels and budget |
| `/design-referral-program` | Create a viral referral or ambassador program |
| `/plan-ugc-campaign` | Design a user-generated content campaign |
| `/plan-local-marketing` | Create a local/regional marketing strategy |
| `/audit-marketing` | Audit marketing efforts and get recommendations |
| `/sync-gtm` | Checkpoint sync between Product and Marketing |

## Workflow Quick Reference

### Daily Development

1. `/sprint-status` - Check board health
2. `/work-ticket` - Pick up next ticket (if Ready has items)
3. `/groom-backlog` - Replenish Ready (if empty)
4. `/review-pr` - Review pending PRs

### Weekly Planning

1. `/check-milestone` - Assess milestone progress
2. `/groom-backlog` - Full backlog grooming session

### Feature Decisions

1. `/evaluate-feature` - Assess new feature request
2. `/architect-review` - Get design guidance (if needed)

### Release Process

1. `/check-milestone` - Verify milestone completion
2. `/release-decision` - Go/no-go decision
3. Human executes release (if GO)

## Troubleshooting

### Ready Column Empty

Run `/groom-backlog` to move prioritized tickets to Ready.

### PRs Piling Up in Review

Run `/review-pr` to process pending reviews. Check if human reviewers are bottleneck.

### Tickets Stuck in Progress

Check `/sprint-status` for stale items. May indicate blockers or scope issues.

### Agent Handoff Failures

Ensure:
1. Trunk-based development is configured
2. Branch protection is enabled
3. GitHub MCP has proper token
4. Memory MCP is running for context sharing

---

## Getting Started

1. Copy this template to your new project
2. Fill in the project-specific sections above
3. Create `docs/PRODUCT-REQUIREMENTS.md` and `docs/PRODUCT-ROADMAP.md`
4. Set up GitHub project board with required columns
5. Configure branch protection on `main`
6. Configure MCP servers (Memory, GitHub)
7. Start with `/groom-backlog` to populate Ready column
8. Use `/work-ticket` to begin development
