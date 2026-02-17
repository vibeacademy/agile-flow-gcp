# Workshop Guide (Instructor)

This guide prepares instructors to run a 3-day Agile Flow workshop where
participants build a product from idea to deployed application using
AI-assisted development.

## Pre-Workshop Checklist

### Per Participant

- [ ] GitHub account with personal access token (fine-grained, repo + project scope)
- [ ] Worker bot account (`{org}-worker`) with PAT
- [ ] Reviewer bot account (`{org}-reviewer`) with PAT
- [ ] Fork of `agile-flow` repository
- [ ] GitHub Project board created (Backlog, Ready, In Progress, In Review, Done)
- [ ] Branch protection rule on `main` (require PR, require status checks)
- [ ] Claude Code CLI installed and authenticated

### Per Participant (Optional, Enable When Ready)

- [ ] Render account with service created
- [ ] `RENDER_API_KEY` and `RENDER_SERVICE_ID` added to repo secrets
- [ ] Sentry project created with DSN
- [ ] `SENTRY_DSN` added to Render environment variables

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

For each bot account, create a fine-grained personal access token:

1. Go to **Settings > Developer settings > Personal access tokens > Fine-grained**
2. Token name: `agile-flow-workshop`
3. Repository access: Select the participant's fork
4. Permissions:

| Permission | Worker Bot | Reviewer Bot |
|-----------|-----------|-------------|
| Contents | Read and write | Read only |
| Issues | Read and write | Read only |
| Pull requests | Read and write | Read and write |
| Projects | Read and write | Read only |
| Metadata | Read only | Read only |

### Configuring Account Switching

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

1. Create a Sentry organization (free tier is sufficient)
2. Create a project: **Python > FastAPI**
3. Copy the DSN from **Settings > Client Keys**
4. Add `SENTRY_DSN` to Render environment variables
5. Test: Visit `/error` endpoint to trigger a deliberate error
6. Verify: Error appears in Sentry dashboard within 30 seconds

## Render Setup

1. Create a Render account at render.com
2. Connect GitHub repository
3. Create a new **Web Service** from the repo
4. Configure:
   - Runtime: Python
   - Build command: `pip install .`
   - Start command: `uvicorn app.main:app --host 0.0.0.0 --port $PORT`
5. Add environment variables: `SENTRY_DSN`, `PYTHON_VERSION=3.11`
6. Enable preview environments in service settings
7. Copy API key and service ID for GitHub secrets

## Session Plans

### Day 1: Foundation (4 hours)

| Time | Activity | Commands Used |
|------|----------|---------------|
| 0:00-0:30 | Introduction and setup verification | `gh auth status` |
| 0:30-1:00 | Product definition | `/bootstrap-product` |
| 1:00-1:30 | Technical architecture | `/bootstrap-architecture` |
| 1:30-2:00 | Agent specialization | `/bootstrap-agents` |
| 2:00-2:30 | Break | - |
| 2:30-3:00 | Workflow activation | `/bootstrap-workflow` |
| 3:00-3:30 | First ticket: deploy and verify | `/work-ticket` |
| 3:30-4:00 | Trigger deliberate error, verify Sentry | Visit `/error` |

**Day 1 Success Criteria:**
- App deployed to Render
- Health check endpoint returns `{"status": "ok"}`
- Sentry receives the deliberate error
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
  |      --> Run: uv run ruff check . --fix
  |      --> Stage, commit, push
  |
  +--> Test failure?
  |      --> Run: uv run pytest --tb=short
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
uv run ruff check . --fix

# Stage and amend:
git add -A && git commit --amend --no-edit

# Push again:
git push origin <branch> --force-with-lease
```

## If Someone Is Stuck

```text
Participant is stuck
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
  |      --> Check: PAT has project scope
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
