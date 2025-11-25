# Agile Flow

A Claude Code project template that bootstraps a complete agile development workflow with specialized AI agents.

## What This Is

Agile Flow provides a team of AI agents that work together to manage your software project:

| Agent | Role |
|-------|------|
| Product Manager | Strategy, vision, go/no-go decisions |
| Product Owner | Backlog management, ticket quality |
| Ticket Worker | Implementation, PRs |
| PR Reviewer | Code review, quality gate |
| Quality Engineer | Test planning, validation |
| System Architect | Design guidance, patterns |
| Growth Marketing Strategist | Campaigns, GTM, user acquisition |

The agents hand off work to each other through a structured workflow, with humans making final merge decisions.

## Prerequisites

- [Claude Code](https://claude.ai/code) CLI installed
- GitHub repository with project board
- Node.js 18+ (for MCP servers)

## Quick Start

```bash
# 1. Copy this template to your project
cp -r agile-flow/ your-project/
cd your-project

# 2. Initialize git (if not already)
git init

# 3. Run the bootstrap wizard
./bootstrap.sh
```

## How It Works: Progressive Refinement

Agile Flow uses **progressive refinement** - each phase builds context that makes subsequent phases more focused and effective.

```
Phase 1: Product Definition
    |
    | Creates: PRODUCT-REQUIREMENTS.md
    | Unlocks: Product context for all agents
    v
Phase 2: Technical Architecture
    |
    | Creates: TECHNICAL-ARCHITECTURE.md
    | Unlocks: Tech stack context, coding standards
    v
Phase 3: Agent Specialization
    |
    | Updates: Agent configs with project context
    | Unlocks: Project-specific agent behavior
    v
Phase 4: Workflow Activation
    |
    | Creates: GitHub board, branch protection
    | Unlocks: Full agent workflow
    v
Ready for Development
```

### Why Progressive Refinement?

Generic agents produce generic results. By building context progressively:

1. **Product Manager** creates PRD → agents understand *what* we're building
2. **System Architect** creates tech architecture → agents understand *how* we're building
3. **Agents get specialized** → agents give project-specific guidance
4. **Workflow activates** → agents can execute with full context

## Bootstrap Process

### Option 1: Interactive Wizard (Recommended)

```bash
./bootstrap.sh
```

The wizard guides you through each phase, invoking the right agents at the right time.

### Option 2: Manual Phase-by-Phase

#### Phase 1: Product Definition

```bash
# Start Claude Code
claude

# Invoke the product manager to create your PRD
> /bootstrap-product
```

This creates `docs/PRODUCT-REQUIREMENTS.md` with:
- Product vision and goals
- Target audience
- Core features
- Success metrics
- Competitive landscape

#### Phase 2: Technical Architecture

```bash
# With PRD complete, define technical architecture
> /bootstrap-architecture
```

This creates `docs/TECHNICAL-ARCHITECTURE.md` with:
- Technology stack decisions
- System design
- Data models
- API contracts
- Infrastructure approach

#### Phase 3: Agent Specialization

```bash
# Refine agents with project context
> /bootstrap-agents
```

This updates agent configurations with:
- Project-specific tech stack
- Coding standards
- Testing requirements
- Architecture patterns

#### Phase 4: Workflow Activation

```bash
# Set up GitHub and activate workflow
> /bootstrap-workflow
```

This configures:
- GitHub project board columns
- Branch protection rules
- Initial backlog from PRD features
- First tickets in Ready column

## After Bootstrap

Once bootstrap is complete, use the standard workflow:

```bash
# Daily development
/sprint-status          # Check board health
/work-ticket            # Pick up next ticket
/review-pr              # Review pending PRs

# Planning
/groom-backlog          # Manage backlog
/check-milestone        # Track progress

# Decisions
/evaluate-feature       # Assess feature requests
/release-decision       # Go/no-go for releases
/architect-review       # Design guidance

# Marketing & GTM
/sync-gtm               # Product-Marketing alignment checkpoints
/plan-campaign          # Design marketing campaigns
/design-referral-program # Create viral/referral programs
/plan-ugc-campaign      # User-generated content campaigns
/plan-local-marketing   # Local/regional marketing
/audit-marketing        # Audit and optimize marketing
```

## Project Structure

```
your-project/
├── .claude/
│   ├── agents/                 # Agent definitions
│   │   ├── agile-product-manager.md
│   │   ├── agile-backlog-prioritizer.md
│   │   ├── github-ticket-worker.md
│   │   ├── pr-reviewer-merger.md
│   │   ├── quality-engineer.md
│   │   ├── system-architect.md
│   │   └── growth-marketing-strategist.md
│   ├── commands/               # Slash commands
│   │   ├── bootstrap-product.md
│   │   ├── bootstrap-architecture.md
│   │   ├── bootstrap-agents.md
│   │   ├── bootstrap-workflow.md
│   │   ├── groom-backlog.md
│   │   ├── work-ticket.md
│   │   └── ... (other commands)
│   └── settings.local.json     # MCP configuration
├── docs/
│   ├── PRODUCT-REQUIREMENTS.md # Created in Phase 1
│   ├── PRODUCT-ROADMAP.md      # Created in Phase 1
│   └── TECHNICAL-ARCHITECTURE.md # Created in Phase 2
├── CLAUDE.md                   # Project configuration
├── bootstrap.sh                # Bootstrap wizard
└── README.md                   # This file
```

## Requirements

### Trunk-Based Development (Required)

This template **requires** trunk-based development:
- `main` branch is protected
- All work on feature branches
- All changes via pull requests
- Human performs final merge

The agent workflow depends on this structure. See [CLAUDE.md](./CLAUDE.md) for details.

### GitHub Configuration

You'll need:
- A GitHub repository
- Permission to create project boards
- Permission to configure branch protection
- A GitHub personal access token (for MCP)

## Customization

### Adding Project-Specific Context

After bootstrap, you can further refine agents by editing their definitions in `.claude/agents/`. Look for `<!-- TEMPLATE: ... -->` comments indicating where to add project-specific context.

### Adding Custom Commands

Create new `.md` files in `.claude/commands/` following the existing patterns.

### Extending the Workflow

The agent workflow can be extended by:
1. Adding new agents in `.claude/agents/`
2. Creating commands that invoke them
3. Updating CLAUDE.md with new handoff protocols

## Philosophy

### Quality of Internal Deliverables

The core assumption is: **quality of internal deliverables drives final product quality**.

- Good PRD → Good architecture decisions
- Good tickets → Good implementations
- Good reviews → Good merges
- Good tests → Confident releases

Each agent is accountable for the quality of their outputs.

### Agents as Team Members

Treat agents as team members with specific roles:
- They have expertise (defined in their config)
- They have boundaries (what they can/cannot do)
- They hand off work (via project board)
- They need context (provided progressively)

### Human in the Loop

Humans remain in control of:
- Final merge decisions
- Release approvals
- Strategic pivots
- Conflict resolution

Agents provide recommendations; humans make decisions.

### Product-Marketing Alignment

Marketing often gets "thrown over the wall" after product is built. Agile Flow solves this with **GTM checkpoints** that bring marketing into the loop at key phases:

| Checkpoint | When | Purpose |
|------------|------|---------|
| PRD Review | After PRD draft | Marketing validates personas & positioning |
| Scope Lock | MVP finalized | Marketing gets briefed, starts GTM planning |
| Dev Midpoint | ~50% complete | Marketing finalizes assets |
| Pre-Launch | Feature complete | Final alignment, soft launch |
| Launch | Go-live | Execute and monitor |
| Post-Launch | 1-2 weeks after | Analyze, iterate, feedback loop |

Run `/sync-gtm` at each phase to ensure alignment. Each checkpoint produces an artifact in `docs/gtm/` that serves as the contract between Product and Marketing.

## Troubleshooting

### Bootstrap Issues

**"Phase X requires Phase Y to be complete"**
- Run phases in order: Product → Architecture → Agents → Workflow

**"GitHub token not configured"**
- Set `GITHUB_TOKEN` environment variable
- Or configure in `.claude/settings.local.json`

### Workflow Issues

**"Ready column is empty"**
- Run `/groom-backlog` to populate from backlog

**"Agent doesn't have project context"**
- Ensure you completed Phase 3 (Agent Specialization)
- Check agent configs for project-specific sections

**"PR reviewer can't find PRs"**
- Ensure tickets are moved to "In Review" column
- Check that PRs are linked to issues

## Contributing

This is a template project. To contribute:
1. Fork the repository
2. Make improvements to agent definitions or commands
3. Submit PR with clear description of changes

## License

MIT License - Use freely for any project.
