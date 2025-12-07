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

#### Phase 5: Scope Lock (Recommended)

```bash
# Formally lock MVP scope before development begins
> /lock-scope
```

This creates `docs/SCOPE-LOCK.md` and signals that:
- MVP feature list is fixed
- All features have acceptance criteria
- Major decisions are resolved
- Changes require formal trade-off discussion

**Why lock scope?** Scope lock is the handoff point where:
- Marketing can start planning campaigns against a known target
- Engineering can commit to timelines
- Stakeholders are aligned on what "done" means

See [Scope Lock](#scope-lock) below for detailed criteria.

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
│   │   ├── pr-reviewer.md
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

#### Creating a GitHub Personal Access Token

1. Go to **GitHub Settings** → **Developer settings** → **Personal access tokens** → **Fine-grained tokens**
   - Direct link: https://github.com/settings/tokens?type=beta

2. Click **Generate new token**

3. Configure the token:
   - **Token name:** `agile-flow` (or your project name)
   - **Expiration:** Choose based on your security requirements (90 days recommended)
   - **Repository access:** Select "Only select repositories" and choose your project repo

4. Set **Repository permissions:**
   | Permission | Access Level | Why Needed |
   |------------|--------------|------------|
   | Contents | Read and write | Create branches, push commits |
   | Issues | Read and write | Create/update tickets |
   | Pull requests | Read and write | Create PRs, add comments |
   | Projects | Read and write | Manage project board columns |
   | Metadata | Read-only | Required for API access |

5. Click **Generate token** and copy the token immediately (you won't see it again)

#### Configuring the Token

**Option 1: Environment variable (recommended)**

Add to your shell profile (`~/.zshrc`, `~/.bashrc`, etc.):
```bash
export GITHUB_TOKEN="github_pat_xxxxxxxxxxxx"
```

Then reload your shell:
```bash
source ~/.zshrc  # or ~/.bashrc
```

**Option 2: Claude Code settings**

Create or edit `.claude/settings.local.json` in your project:
```json
{
  "mcpServers": {
    "github": {
      "command": "npx",
      "args": ["-y", "@anthropic/mcp-github"],
      "env": {
        "GITHUB_TOKEN": "github_pat_xxxxxxxxxxxx"
      }
    }
  }
}
```

**Important:** Add `.claude/settings.local.json` to `.gitignore` to avoid committing your token.

#### Verifying the Token

After configuring, start Claude Code and run a simple test:
```bash
claude
> Check if GitHub MCP is working by listing my repositories
```

If configured correctly, the agent should be able to access your GitHub repositories.

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

### Scope Lock

Scope lock is a formal checkpoint that signals MVP scope is finalized and development can begin with confidence.

**Criteria for Scope Lock:**

| Criteria | Locked | Not Locked |
|----------|--------|------------|
| Feature list | Fixed: "We're building A, B, C" | Fluid: "Maybe C or D" |
| Acceptance criteria | Each feature has testable conditions | Features are vague ideas |
| Open questions | Major decisions resolved | "TBD" items remain |
| Change process | Adding scope requires trade-offs | "Let's add that too" |
| Timeline | Dates based on defined scope | Dates slide with scope |

**When to Lock:**
- After PRD is complete (`/bootstrap-product`)
- After technical feasibility confirmed (`/bootstrap-architecture`)
- After backlog has tickets for all MVP features (`/groom-backlog`)
- Before significant development begins

**Why Lock Matters:**
- **Marketing** can plan campaigns against a known target
- **Engineering** can commit to realistic timelines
- **Stakeholders** are aligned on what "done" means
- **Scope creep** becomes visible (requires unlocking)

**Run `/lock-scope` to:**
1. Verify all lock criteria are met
2. Document the locked scope
3. Create `docs/SCOPE-LOCK.md` as the contract
4. Trigger `/sync-gtm` Checkpoint 2 (Scope Lock)

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

## Marketing Commands

### When to Use Marketing Commands

**Prerequisites:** Marketing commands are most effective after:
1. PRD is complete (you know WHO you're building for)
2. MVP scope is locked (you know WHAT you're launching)
3. You can articulate your value proposition in one sentence

**Don't use marketing commands:**
- Before product-market fit is validated
- When the product is still pivoting frequently
- If you can't answer "who is this for?" clearly

### Command Reference

#### `/sync-gtm` - Product-Marketing Alignment Checkpoints

**When:** At each phase transition (PRD done, scope locked, dev midpoint, pre-launch, launch, post-launch)

**Purpose:** Ensures Product and Marketing stay aligned throughout development. Prevents the "throw it over the wall" anti-pattern.

**Output:** Checkpoint artifact saved to `docs/gtm/checkpoint-{N}-{phase}.md`

**Example workflow:**
```bash
# After completing PRD
/sync-gtm
> Select: 1 (PRD Review)
# Marketing reviews personas, positioning, validates target is reachable

# After MVP scope is locked
/sync-gtm
> Select: 2 (Scope Lock)
# Marketing gets briefed, starts planning GTM strategy
```

---

#### `/plan-campaign` - Design Marketing Campaigns

**When:** You have a specific marketing goal (launch, awareness, acquisition, re-engagement)

**Purpose:** Creates a structured campaign brief with audience, channels, creative direction, budget, and timeline.

**Output:** Campaign brief saved to `docs/campaigns/{campaign-name}-brief.md`

**Best for:**
- Product launches
- Feature announcements
- Seasonal promotions
- User acquisition pushes

**Example:**
```bash
/plan-campaign
# Answer questions about goal, audience, budget, timeline, channels
# Outputs a ready-to-execute campaign brief
```

---

#### `/design-referral-program` - Create Viral/Referral Programs

**When:** You want to grow through word-of-mouth and user referrals

**Purpose:** Designs incentive structure, mechanics, tracking, and anti-fraud measures for a referral or ambassador program.

**Output:** Program design saved to `docs/REFERRAL-PROGRAM.md`

**Best for:**
- Products with network effects
- High customer lifetime value (can afford referral rewards)
- Products users naturally want to share
- Reducing customer acquisition cost (CAC)

**Not recommended if:**
- Product isn't yet delivering value (users won't refer)
- LTV is too low to support referral rewards
- Product is B2B enterprise (longer sales cycles)

**Example:**
```bash
/design-referral-program
# Answer questions about program type, incentives, user value
# Outputs referral mechanics, economics, and implementation plan
```

---

#### `/plan-ugc-campaign` - User-Generated Content Campaigns

**When:** You want to build social proof, community engagement, or authentic marketing content

**Purpose:** Designs campaigns that encourage users to create and share content about your product.

**Output:** Campaign plan saved to `docs/campaigns/ugc-{campaign-name}.md`

**Best for:**
- Visual products (food, fashion, design, travel)
- Community-driven products
- Products with passionate users
- Building social proof before paid ads

**Types of UGC campaigns:**
- Social media challenges/hashtags
- Review/testimonial collection
- Photo/video contests
- User spotlight programs
- Ambassador content programs

**Example:**
```bash
/plan-ugc-campaign
# Answer questions about content type, incentives, duration
# Outputs participation guidelines, promotion plan, success metrics
```

---

#### `/plan-local-marketing` - Local/Regional Marketing Strategy

**When:** Expanding to a new geographic market or doubling down on a specific region

**Purpose:** Creates a localized marketing plan with community partnerships, local influencers, geo-targeted campaigns, and grassroots tactics.

**Output:** Local plan saved to `docs/local-marketing/{city-region}.md`

**Best for:**
- Location-based services
- Products launching market-by-market
- Testing product-market fit in specific regions
- Building local community presence

**Tactics included:**
- Local influencer partnerships
- Community event sponsorships
- Local business partnerships
- Grassroots street teams
- Local PR/media outreach
- Geo-targeted digital ads
- Local SEO optimization

**Example:**
```bash
/plan-local-marketing
# Specify target city/region
# Answer questions about objectives, budget, resources
# Outputs comprehensive local launch playbook
```

---

#### `/audit-marketing` - Audit and Optimize Marketing

**When:** Marketing is running but you're not sure what's working, or CAC is too high

**Purpose:** Reviews current marketing efforts across all channels and provides optimization recommendations.

**Output:** Audit report saved to `docs/MARKETING-AUDIT.md`

**Best for:**
- Quarterly marketing reviews
- When CAC is rising unexpectedly
- Before scaling marketing spend
- When inheriting existing marketing efforts

**What it covers:**
- Channel-by-channel performance assessment
- Budget allocation analysis
- Quick wins (next 30 days)
- Strategic recommendations (60-90 days)
- Channels to consider adding
- Metrics to start tracking

**Example:**
```bash
/audit-marketing
# Answer questions about current channels, spend, challenges
# Outputs prioritized action plan with effort/impact ratings
```

### Marketing Outputs Summary

| Command | Output Location | Artifact |
|---------|-----------------|----------|
| `/sync-gtm` | `docs/gtm/` | Checkpoint alignment docs |
| `/plan-campaign` | `docs/campaigns/` | Campaign briefs |
| `/design-referral-program` | `docs/` | REFERRAL-PROGRAM.md |
| `/plan-ugc-campaign` | `docs/campaigns/` | UGC campaign plans |
| `/plan-local-marketing` | `docs/local-marketing/` | Local market playbooks |
| `/audit-marketing` | `docs/` | MARKETING-AUDIT.md |

### Recommended Marketing Workflow

```
1. Complete PRD
   |
   v
2. /sync-gtm (Checkpoint 1: PRD Review)
   |  - Marketing validates personas are reachable
   |  - Confirms positioning is differentiated
   v
3. Lock MVP scope
   |
   v
4. /sync-gtm (Checkpoint 2: Scope Lock)
   |  - Marketing gets full briefing
   |  - Starts planning campaigns
   v
5. /plan-campaign (if doing launch campaign)
   /design-referral-program (if using referrals)
   |
   v
6. Development reaches 50%
   |
   v
7. /sync-gtm (Checkpoint 3: Dev Midpoint)
   |  - Marketing finalizes assets
   |  - Campaigns ready to activate
   v
8. Feature complete
   |
   v
9. /sync-gtm (Checkpoint 4: Pre-Launch)
   |  - Final alignment
   |  - Soft launch to early adopters
   v
10. Launch
    |
    v
11. /sync-gtm (Checkpoint 5: Launch)
    |  - Execute campaigns
    |  - Monitor metrics
    v
12. 1-2 weeks post-launch
    |
    v
13. /sync-gtm (Checkpoint 6: Post-Launch)
    /audit-marketing
    |  - Analyze results
    |  - Iterate on what's working
```

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
