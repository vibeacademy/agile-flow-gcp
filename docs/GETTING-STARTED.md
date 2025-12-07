# Getting Started with Agile Flow

Step-by-step instructions for using this template to bootstrap a new project.

## Prerequisites

Before you begin, ensure you have:

- [ ] [Claude Code CLI](https://claude.ai/code) installed
- [ ] Git installed
- [ ] Node.js 18+ installed
- [ ] A GitHub account with permission to create repositories
- [ ] GitHub personal access token with `repo` and `project` scopes

## Step 1: Create Your Project Repository

```bash
# Create a new directory for your project
mkdir my-project
cd my-project

# Clone the Agile Flow template (replace with your fork URL)
git clone https://github.com/your-org/agile-flow.git .

# Remove the template's git history and start fresh
rm -rf .git
git init

# Create your GitHub repository, then connect it
git remote add origin git@github.com:your-org/your-project.git
```

## Step 2: Configure GitHub Access

Set up your GitHub token for the MCP server:

```bash
# Option 1: Environment variable
export GITHUB_TOKEN=your_github_token_here

# Option 2: Add to your shell profile (~/.zshrc or ~/.bashrc)
echo 'export GITHUB_TOKEN=your_github_token_here' >> ~/.zshrc
source ~/.zshrc
```

## Step 3: Run the Bootstrap Wizard

The bootstrap wizard guides you through 4 phases of progressive refinement:

```bash
./bootstrap.sh
```

This will show:
```
╔════════════════════════════════════════════════════════════╗
║              Agile Flow Bootstrap Wizard                   ║
╚════════════════════════════════════════════════════════════╝

Progress:
  [ ] Phase 1: Product Definition
  [ ] Phase 2: Technical Architecture
  [ ] Phase 3: Agent Specialization
  [ ] Phase 4: Workflow Activation
```

### Phase 1: Product Definition

**What happens**: The Product Manager agent interviews you about your product.

**You provide**:
- What problem you're solving
- Who your users are
- What features you need
- How you'll measure success

**Output created**:
- `docs/PRODUCT-REQUIREMENTS.md` - Your PRD
- `docs/PRODUCT-ROADMAP.md` - Your roadmap

**How to run**:
```bash
# When prompted by bootstrap.sh, open Claude Code
claude

# Run the bootstrap command
/bootstrap-product
```

Answer the Product Manager's questions. When done, the agent creates your PRD and roadmap.

### Phase 2: Technical Architecture

**What happens**: The System Architect reads your PRD and helps define technical decisions.

**You provide**:
- Technology preferences/constraints
- Scale requirements
- Team expertise
- Infrastructure preferences

**Output created**:
- `docs/TECHNICAL-ARCHITECTURE.md` - Your architecture document

**How to run**:
```bash
# In Claude Code
/bootstrap-architecture
```

Review the architect's recommendations and iterate until satisfied.

### Phase 3: Agent Specialization

**What happens**: All agents are updated with your project-specific context.

**What gets updated**:
- Agent configurations with your tech stack
- CLAUDE.md with your project details
- Quality standards specific to your stack

**How to run**:
```bash
# In Claude Code
/bootstrap-agents
```

Review the changes to ensure agents understand your project.

### Phase 4: Workflow Activation

**What happens**: GitHub project board and initial backlog are set up.

**You provide**:
- GitHub organization name
- Repository name
- Project board name

**Output created**:
- GitHub project board with columns
- Initial backlog issues from PRD features
- Branch protection configuration

**How to run**:
```bash
# In Claude Code
/bootstrap-workflow
```

## Step 4: Set Up GitHub Project Board

If not done automatically, create a GitHub Project board with these columns:

| Column | Purpose |
|--------|---------|
| Icebox | Ideas not yet prioritized |
| Backlog | Prioritized but not ready |
| Ready | Well-defined, ready to work (2-5 items) |
| In Progress | Currently being worked on |
| In Review | PR created, awaiting review |
| Done | Merged and complete |

## Step 5: Configure Branch Protection

In your GitHub repository settings:

1. Go to **Settings** → **Branches**
2. Add rule for `main` branch
3. Enable:
   - [x] Require pull request reviews before merging
   - [x] Require status checks to pass (if you have CI)
   - [x] Do not allow bypassing the above settings

## Step 6: Make Initial Commit

```bash
git add -A
git commit -m "Initialize project with Agile Flow template

- Created PRD and roadmap
- Defined technical architecture
- Configured specialized agents
- Set up project workflow"

git push -u origin main
```

## Step 7: Start Development

Your project is now ready! Use these commands:

### Daily Workflow

```bash
# Start Claude Code
claude

# Morning: Check board status
/sprint-status

# Pick up next ticket
/work-ticket

# Review pending PRs
/review-pr
```

### Weekly Planning

```bash
# Check milestone progress
/check-milestone "MVP"

# Groom the backlog
/groom-backlog
```

### Feature Decisions

```bash
# Evaluate a new feature request
/evaluate-feature "Add dark mode support"

# Get architecture guidance
/architect-review "How should we implement caching?"
```

### Release Process

```bash
# Make go/no-go decision
/release-decision v1.0
```

## Command Reference

| Command | When to Use |
|---------|-------------|
| `/sprint-status` | Daily standup, quick health check |
| `/work-ticket` | Ready to implement next feature |
| `/review-pr` | PRs waiting for review |
| `/groom-backlog` | Ready column empty, weekly planning |
| `/check-milestone` | Track progress toward deadline |
| `/evaluate-feature` | New feature request received |
| `/release-decision` | Preparing to ship |
| `/test-feature` | Need test plan or validation |
| `/architect-review` | Design decision needed |

## Agent Roles

| Agent | Responsibility | Invoke When |
|-------|---------------|-------------|
| Product Manager | Strategy, vision, go/no-go | Feature evaluation, release decisions |
| Product Owner | Backlog, tickets, priorities | Grooming, sprint planning |
| Ticket Worker | Implementation, PRs | `/work-ticket` |
| PR Reviewer | Code review | `/review-pr` |
| Quality Engineer | Test plans, validation | `/test-feature` |
| System Architect | Design guidance | `/architect-review` |

## Workflow Diagram

```
┌─────────────────┐
│ Feature Request │
└────────┬────────┘
         │
         v
┌─────────────────┐     ┌─────────┐
│ Product Manager │────>│ DECLINE │
│ /evaluate-feature│     └─────────┘
└────────┬────────┘
         │ BUILD
         v
┌─────────────────┐
│  Product Owner  │
│ /groom-backlog  │
└────────┬────────┘
         │
         v
┌─────────────────┐
│  Ready Column   │
│   (2-5 items)   │
└────────┬────────┘
         │
         v
┌─────────────────┐
│  Ticket Worker  │
│  /work-ticket   │
└────────┬────────┘
         │ Creates PR
         v
┌─────────────────┐
│   PR Reviewer   │
│   /review-pr    │
└────────┬────────┘
         │ GO recommendation
         v
┌─────────────────┐
│     Human       │
│  Final Review   │
│     & Merge     │
└────────┬────────┘
         │
         v
┌─────────────────┐
│      Done       │
└─────────────────┘
```

## Troubleshooting

### "Ready column is empty"
```bash
/groom-backlog
```

### "Bootstrap phase failed"
- Check that previous phases completed
- Look for missing files in `docs/`
- Re-run the failed phase

### "GitHub token not working"
- Verify token has `repo` and `project` scopes
- Check token isn't expired
- Ensure `GITHUB_TOKEN` env var is set

### "Agent gives generic advice"
- Ensure Phase 3 completed
- Check agent files for project context
- Re-run `/bootstrap-agents`

### "PR reviewer can't find PRs"
- Ensure tickets are in "In Review" column
- Verify PRs are linked to issues
- Check project board URL in CLAUDE.md

## Next Steps

After setup:

1. **Populate your backlog** - `/groom-backlog`
2. **Start your first ticket** - `/work-ticket`
3. **Set up CI/CD** - Add GitHub Actions for tests
4. **Invite team members** - Share repo access
5. **Schedule standups** - Daily `/sprint-status`

## Getting Help

- Check `CLAUDE.md` for project configuration
- Review agent files in `.claude/agents/` for behavior
- See command files in `.claude/commands/` for usage

---

Happy building!
