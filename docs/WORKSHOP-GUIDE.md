# Workshop Guide (Instructor)

This guide prepares instructors to run a 3-day Agile Flow workshop where
participants build a product from idea to deployed application using
AI-assisted development.

## Pre-Workshop Checklist

Send participants the [PRE-WORK-CHECKLIST.md](./PRE-WORK-CHECKLIST.md) at
least one week before the workshop. It covers account creation, PAT
generation, tool installation, and Supabase/Render setup with verification
steps.

### Per Participant (Required)

- [ ] GitHub organization created
- [ ] GitHub account with personal access token (classic: repo + project + workflow scope)
- [ ] Worker bot account (`{org}-worker`) with PAT, invited to org
- [ ] Reviewer bot account (`{org}-reviewer`) with PAT, invited to org
- [ ] Claude Code CLI installed and authenticated
- [ ] Supabase account with project created
- [ ] Supabase access token generated
- [ ] Supabase GitHub integration enabled for their org
- [ ] Git and Node.js 20+ installed (Python 3.11+ and uv only if using FastAPI starter)

### Instructor Setup (Repository)

- [ ] Verify `agile-flow` repo has **template repository** enabled
      (Settings > General > Template repository checkbox)

### Per Participant (During Workshop)

- [ ] Own copy of `agile-flow` created via **"Use this template"** (not fork)
- [ ] `SUPABASE_ACCESS_TOKEN` and `SUPABASE_PROJECT_REF` added to repo secrets
- [ ] Render account with service created
- [ ] `RENDER_API_KEY` and `RENDER_SERVICE_ID` added to repo secrets
- [ ] GitHub Project board created (Backlog, Ready, In Progress, In Review, Done)
- [ ] Branch protection rule on `main` (require PR, require status checks)
- [ ] (Optional) Sentry project created with DSN — not required for zero-config error flow
- [ ] (Optional) `SENTRY_DSN` added to Render environment variables

### Instructor Setup

- [ ] Demo repository with completed bootstrap (for reference)
- [ ] Slide deck covering Agile Flow concepts
- [ ] Printed quick-reference cards (slash commands, workflow diagram)
- [ ] Backup PATs in case participants lose theirs
- [ ] Test all workflows on the demo repo before the workshop

## Three-Account Setup

Each participant needs three GitHub accounts to maintain separation of
duties in the agent workflow.

### Account Purposes

| Account | Role | Creates | Reviews | Merges |
|---------|------|---------|---------|--------|
| Personal | Human | - | Final review | Yes |
| Worker bot | Agent | PRs | - | - |
| Reviewer bot | Agent | - | Reviews | - |

### PAT Generation

For each bot account, create a classic personal access token:

1. Go to **Settings > Developer settings > Personal access tokens > Tokens (classic)**
2. Token name: `agile-flow-workshop`
3. Select scopes: `repo`, `project`, `workflow`, `read:org`, `gist`

> The `workflow` scope is required by GitHub for any token that pushes
> changes to `.github/workflows/` files.

If you prefer fine-grained tokens, enable these permissions:

| Permission | Worker Bot | Reviewer Bot |
|-----------|-----------|-------------|
| Contents | Read and write | Read only |
| Issues | Read and write | Read only |
| Pull requests | Read and write | Read and write |
| Projects | Read and write | Read only |
| Workflows | Read and write | Read and write |
| Metadata | Read only | Read only |

### Configuring Account Switching

**Recommended**: Run `bash scripts/setup-accounts.sh` which handles
login, environment variables, and verification in one step. The manual
commands below are an alternative if the script isn't available.

Add bot accounts to `gh auth`:

```bash
# Login as worker bot
gh auth login --with-token < worker-token.txt

# Login as reviewer bot
gh auth login --with-token < reviewer-token.txt

# Verify all accounts
gh auth status
```

Set environment variables in shell profile:

```bash
export AGILE_FLOW_WORKER_ACCOUNT="{org}-worker"
export AGILE_FLOW_REVIEWER_ACCOUNT="{org}-reviewer"
```

## Sentry Setup

Note: Sentry SaaS is optional. The app ships with zero-config error telemetry that creates GitHub issues automatically. The steps below are only needed if you want an external error monitoring dashboard.

1. Create a Sentry organization (free tier is sufficient)
2. Create a project: **JavaScript > Next.js**
3. Copy the DSN from **Settings > Client Keys**
4. Add `SENTRY_DSN` to Render environment variables
5. Test: Visit `/api/error` endpoint to trigger a deliberate error
6. Verify: Error appears in Sentry dashboard within 30 seconds

## Render Setup

1. Create a Render account at render.com
2. Connect GitHub repository
3. Create a new **Web Service** from the repo
4. Configure:
   - Runtime: Node
   - Build command: `npm install && npm run build`
   - Start command: `node .next/standalone/server.js`
5. Add environment variables: `SENTRY_DSN`, `NODE_VERSION=20`, `GITHUB_TOKEN`, `GITHUB_REPOSITORY`
6. Enable preview environments in service settings
7. Copy API key and service ID for GitHub secrets

## Session Plans

### Day 1: Foundation (4.5 hours)

| Time | Activity | Commands Used |
|------|----------|---------------|
| 0:00-0:15 | Introduction, setup verification | `/doctor`, `gh auth status` |
| 0:15-0:30 | Deploy to Render (deploy-first) | Render dashboard |
| 0:30-0:45 | Market research | `/research` |
| 0:45-0:55 | Jobs-to-be-Done analysis | `/jtbd` |
| 0:55-1:05 | Positioning analysis | `/positioning` |
| 1:05-1:30 | Product definition (pre-populated) | `/bootstrap-product` |
| 1:30-2:00 | Technical architecture (stack selection) | `/bootstrap-architecture` |
| 2:00-2:30 | Agent specialization | `/bootstrap-agents` |
| 2:30-3:00 | Break | - |
| 3:00-3:30 | Workflow activation | `/bootstrap-workflow` |
| 3:30-4:00 | First ticket: implement and create PR | `/work-ticket` |
| 4:00-4:30 | Trigger deliberate error, verify auto-created issue | `curl /error`, `gh issue list` |

**Day 1 Success Criteria:**
- `/doctor` reports zero FAILs
- App deployed to Render
- Research artifacts generated (market research, JTBD, positioning)
- Health check endpoint returns `{"status": "ok"}`
- Stack swap completed (if non-Next.js chosen)
- Deliberate error auto-creates a GitHub issue
- First PR created and merged

### Day 2: Development Workflow (4 hours)

| Time | Activity | Commands Used |
|------|----------|---------------|
| 0:00-0:30 | Review Day 1, check board health | `/sprint-status` |
| 0:30-1:00 | Backlog grooming | `/groom-backlog` |
| 1:00-2:00 | Work on 2-3 tickets | `/work-ticket` |
| 2:00-2:30 | Break | - |
| 2:30-3:00 | PR review practice | `/review-pr` |
| 3:00-3:30 | Handle CI failures and fixes | - |
| 3:30-4:00 | Session logging | `/log-session` |

**Day 2 Success Criteria:**
- 2-3 tickets completed through full workflow
- At least one PR reviewed by agent, merged by human
- Preview environment tested for at least one PR
- Session log posted

### Day 3: Iteration and Independence (4 hours)

| Time | Activity | Commands Used |
|------|----------|---------------|
| 0:00-0:30 | Review Day 2 session log | - |
| 0:30-1:00 | Create tickets from user feedback | `/create-ticket` |
| 1:00-2:00 | Independent development cycle | `/work-ticket` |
| 2:00-2:30 | Break | - |
| 2:30-3:00 | Milestone check and scope review | `/check-milestone` |
| 3:00-3:30 | Release decision practice | `/release-decision` |
| 3:30-4:00 | Retrospective and next steps | `/log-session` |

**Day 3 Success Criteria:**
- Participants can run the full workflow independently
- At least one self-created ticket completed end-to-end
- Release decision documented
- Clear next steps for continued development

## Common Failure Modes

### Account Switching Errors

**Symptom:** PR created by wrong account, or permission denied.

**Fix:**
```bash
# Check which account is active
gh auth status

# Switch to correct account
gh auth switch --user {worker-bot}
```

**Prevention:** The `ensure-github-account.sh` hook handles this
automatically. Verify it is configured:
```bash
ls .claude/hooks/ensure-github-account.sh
```

### CI Failures

**Symptom:** PR checks fail after push.

**Diagnostic flowchart:**

```text
CI Failed
  |
  +--> Lint error?
  |      --> Run: npx eslint . --fix (or uv run ruff check . --fix for FastAPI)
  |      --> Stage, commit, push
  |
  +--> Test failure?
  |      --> Run: npm test (or uv run pytest --tb=short for FastAPI)
  |      --> Fix the failing test or code
  |      --> Stage, commit, push
  |
  +--> Agent policy lint?
  |      --> Run: ./scripts/lint-agent-policies.sh
  |      --> Fix the flagged agent file
  |
  +--> Workflow file error?
         --> Check YAML syntax
         --> Verify no non-ASCII characters in workflow files
```

### Render Deploy Issues

**Symptom:** Deploy fails or preview not available.

**Diagnostic steps:**
1. Check Render dashboard for build logs
2. Verify `render.yaml` is valid
3. Verify `RENDER_API_KEY` and `RENDER_SERVICE_ID` secrets exist
4. Check if the service is within free tier limits
5. Try manual deploy from Render dashboard

### Pre-Push Hook Failures

**Symptom:** `git push` rejected by pre-push hook.

**Fix:**
```bash
# Read the error output
# Fix the issue (often auto-fixable):
npx eslint . --fix              # Next.js (default)
# uv run ruff check . --fix     # FastAPI starter

# Stage and amend:
git add -A && git commit --amend --no-edit

# Push again:
git push origin <branch> --force-with-lease
```

## If Someone Is Stuck

```text
Participant is stuck
  |
  +--> Run /doctor (or bash scripts/doctor.sh) first
  |      --> Fixes most setup issues with actionable instructions
  |
  +--> Can't push code?
  |      --> Check: git status, git remote -v
  |      --> Check: gh auth status (correct account?)
  |      --> Check: branch protection (on feature branch?)
  |
  +--> Agent not responding?
  |      --> Check: Claude Code authenticated?
  |      --> Check: MCP servers configured?
  |      --> Try: restart Claude Code
  |
  +--> Board not updating?
  |      --> Check: correct project board URL in commands
  |      --> Check: PAT has project + workflow scopes
  |      --> Try: gh project item-list <project-number>
  |
  +--> Deploy not working?
  |      --> Check: Render secrets configured?
  |      --> Check: render.yaml valid?
  |      --> Try: manual deploy from Render dashboard
  |
  +--> Everything else?
         --> Check the error message carefully
         --> Search GitHub Issues for the error
         --> Ask the instructor
```

## Materials Checklist

### To Project/Share on Screen

- [ ] Agile Flow workflow diagram (3-stage: worker, reviewer, human)
- [ ] Slash command quick reference
- [ ] GitHub Project board (demo)
- [ ] Render dashboard (demo)
- [ ] Sentry dashboard (demo)

### To Hand Out

- [ ] Quick-reference card: slash commands and their purposes
- [ ] Account setup checklist (3 accounts, PATs, env vars)
- [ ] Troubleshooting flowchart (printed from this guide)

### To Have Ready

- [ ] Backup PATs for bot accounts
- [ ] Pre-configured demo repo (completed bootstrap)
- [ ] Wi-Fi credentials and network requirements
- [ ] Power strips and adapters
