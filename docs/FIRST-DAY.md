# Day 1 Walkthrough: Template to Production Bug Ticket

This is a step-by-step guide for workshop participants. It assumes you have
already completed the bootstrap wizard (`bash bootstrap.sh`, Phases 0-3) and
that your instructor has walked through the three-account setup. If you are
an instructor, see [WORKSHOP-GUIDE.md](./WORKSHOP-GUIDE.md) for session
plans and troubleshooting flowcharts.

By the end of Day 1, you will have:

- Your own repo (from the template) with a live project board
- A deployed app on Render with a working health check
- A pull request created by an agent, reviewed by an agent, merged by you
- A deliberate error captured with a bug ticket auto-created on your board

---

## Prerequisites

Before you start, confirm:

- Phase 0-3 of `bash bootstrap.sh` completed (product, architecture, agents)
- Three GitHub accounts ready (personal, `{org}-worker`, `{org}-reviewer`)
- Claude Code CLI installed and authenticated
- MCP servers working — run `claude` and verify `github` and `memory` servers connect
- `GITHUB_PERSONAL_ACCESS_TOKEN` exported with `repo` + `project` scopes
- Render account created, service connected to your repo
- Run `/doctor` in Claude Code (or `bash scripts/doctor.sh`) to verify your setup

---

## Step 1: Create Your Repo from the Template

Go to the template repository on GitHub and click **Use this template >
Create a new repository**. Choose your organization as the owner and give
it a name (e.g., `agile-flow`).

> **Why "Use this template" instead of Fork?** A template creates a fresh
> repo with no upstream link, its own issue tracker, and its own project
> board — exactly what you need for the workshop.

You should see: Your own repo at
`https://github.com/{your-org}/agile-flow`.

---

## Step 2: Clone and Verify Local Setup

> **Important:** `cd` to the directory where you want your project *before*
> cloning. A common mistake is cloning inside another repo.

```bash
cd ~/projects   # or wherever you keep repos
git clone https://github.com/{your-org}/agile-flow.git
cd agile-flow
```

You should see:

```
Cloning into 'agile-flow'...
remote: Enumerating objects: ...
```

Enable the pre-push hook:

```bash
git config core.hooksPath scripts/hooks
```

You should see: No output (silence means success).

Run the diagnostic to verify your local setup:

```bash
bash scripts/doctor.sh
```

You should see: A list of `[PASS]` checks with a summary at the end. Fix
any `[FAIL]` items before continuing.

---

## Step 3: Verify Three Accounts Work

All three accounts must be logged into the GitHub CLI. Run:

```bash
gh auth status
```

You should see output listing all three accounts:

```
github.com
  Logged in to github.com account {your-personal-account} (keyring)
    - Active account: true
    ...
  Logged in to github.com account {org}-worker (keyring)
    - Active account: false
    ...
  Logged in to github.com account {org}-reviewer (keyring)
    - Active account: false
    ...
```

If any account is missing, log it in now:

```bash
gh auth login --with-token < worker-token.txt
gh auth login --with-token < reviewer-token.txt
```

> **PAT scopes**: Each bot account's PAT needs **`repo`** + **`project`**
> scopes (classic PAT) so the agent can manage issues, PRs, and move
> tickets on the project board. If you used fine-grained PATs, enable
> `Contents`, `Issues`, `Pull requests`, `Metadata` (read), and
> `Projects` permissions.

Verify the environment variables are set:

```bash
echo $AGILE_FLOW_WORKER_ACCOUNT
echo $AGILE_FLOW_REVIEWER_ACCOUNT
```

You should see:

```
{org}-worker
{org}-reviewer
```

If blank, add them to your shell profile:

```bash
export AGILE_FLOW_WORKER_ACCOUNT="{org}-worker"
export AGILE_FLOW_REVIEWER_ACCOUNT="{org}-reviewer"
```

---

## Step 4: Understand the Safety Layers

Before you start using agents, understand why they cannot merge your code or
push to main. The system has 8 layers of protection, described in full in
[AGENTIC-CONTROLS.md](./AGENTIC-CONTROLS.md). Here is the short version:

| Layer | What It Does |
|-------|-------------|
| 1. Platform | Branch protection blocks direct pushes to `main` |
| 2. MCP Deny | Agents cannot read `.env` files or call the merge API |
| 3. Agent Policy | NON-NEGOTIABLE PROTOCOL blocks in agent definitions |
| 4. CI/CD | Policy linter fails the build if safety phrases are removed |
| 5. Pre-Push | Local hook runs lint and tests before code reaches GitHub |
| 6. Audit | Weekly reports detect any restricted action attempts |
| 7. Runtime | Application-level input/output guards (as you build them) |
| 8. Observability | Sentry catches errors, alerts create tickets |

The three-stage workflow enforces separation of duties:

```
Worker (bot)            Reviewer (bot)          Human (you)
  Implements              Reviews code            Final review
  Creates PR              GO / NO-GO              Approve
  Moves to In Review      Requests changes        Merge
  ---                     ---                     ---
  Cannot review           Cannot merge            Does not write code
  Cannot merge            Cannot move board
  Cannot mark Done        Cannot deploy
```

No single actor can take a change from ticket to production alone.

You should see: Nothing to run here. Read through the table and the
three-stage diagram. Ask your instructor if any layer is unclear.

---

## Step 5: Activate the Workflow -- `/bootstrap-workflow`

Open Claude Code and run the final bootstrap phase:

```bash
claude
```

Inside the Claude Code session:

```
/bootstrap-workflow
```

The agent will ask you for:

```
GitHub Organization: {your-org}
Repository Name: agile-flow
Project Board Name: Agile Flow
```

Provide these values. The agent will:

1. Create the project board with columns (Icebox, Backlog, Ready, In
   Progress, In Review, Done)
2. Configure branch protection on `main`
3. Create initial backlog issues from your PRD
4. Move the highest-priority tickets to Ready
5. Update `CLAUDE.md` with your project board URL

You should see:

- A GitHub Project board at your repo with columns populated
- 3-5 tickets in the Ready column
- Branch protection active on `main` (verify at Settings > Branches)

Verify the board is live:

```bash
gh project list --owner {your-org}
```

You should see:

```
NUMBER  TITLE        STATE
1       Agile Flow   open
```

Verify CI is green by checking the Actions tab on your repo. If Phases 1-3
were committed properly, the CI workflow should show a passing run.

You should see: A green checkmark on the latest CI run at
`https://github.com/{your-org}/agile-flow/actions`.

---

## Step 6: Create a Ticket, Work It, and Get a PR

### 6a. Create a ticket

In your Claude Code session:

```
/create-ticket Add a /ping endpoint that returns {"ping": "pong"}
```

The agent will:

1. Search existing issues for duplicates
2. Draft a ticket with acceptance criteria
3. Ask you to confirm
4. Create the GitHub issue and add it to the board in Backlog

You should see: A new issue on your GitHub board. The agent will show you
the issue number (e.g., `#7`).

Move the ticket to Ready on the board (or ask the agent to do it during
creation).

### 6b. Work the ticket

```
/work-ticket
```

The agent (using the `{org}-worker` account) will:

1. Pick the top ticket from the Ready column
2. Move it to In Progress
3. Create a branch: `feature/issue-7-ping-endpoint` (number will vary)
4. Implement the `/ping` endpoint in `app/main.py`
5. Write a test
6. Run lint and tests locally
7. Push the branch
8. Create a pull request
9. Watch CI checks
10. Move the ticket to In Review when CI passes

You should see:

```
Created branch: feature/issue-7-ping-endpoint
Moved #7 to In Progress
...
Created PR #8: Add /ping endpoint
CI checks passing
Moved #7 to In Review
```

Verify the PR exists:

```bash
gh pr list
```

You should see:

```
#8  Add /ping endpoint  feature/issue-7-ping-endpoint  OPEN
```

### 6c. Preview URL

If Render secrets are configured (`RENDER_API_KEY` and `RENDER_SERVICE_ID`
in your repo's GitHub Secrets), the preview deploy workflow triggers
automatically when the PR is created.

You should see: A comment on the PR from the preview deploy workflow with a
URL like:

```
Preview deployed: https://agile-flow-starter-pr-8.onrender.com
```

Visit the preview URL and hit the new endpoint:

```bash
curl https://agile-flow-starter-pr-8.onrender.com/ping
```

You should see:

```json
{"ping": "pong"}
```

If Render secrets are not yet configured, skip the preview check. You will
verify the endpoint after merging to production.

---

## Step 7: Review the PR, Merge, and Deploy to Production

### 7a. Agent review

In your Claude Code session:

```
/review-pr
```

The agent (using the `{org}-reviewer` account) will:

1. Find the PR in the In Review column
2. Read the diff and analyze code quality
3. Check that tests exist and CI is green
4. Post a structured review comment with a GO or NO-GO recommendation

You should see: A review comment on the PR that looks like:

```
## PR Review -- #8

### Requirements
- [x] Acceptance criteria from linked issue are met
- [x] Feature works end-to-end as described

### Code Quality
- [x] Follows existing patterns and conventions

### Testing
- [x] Tests cover acceptance criteria
- [x] All tests pass in CI

### Recommendation
**GO**

The /ping endpoint is implemented correctly and follows the
existing pattern from the /health endpoint.
```

### 7b. Human review and merge

This is your job. The agent cannot merge -- only you can.

1. Go to the PR on GitHub
2. If a preview URL exists, test the endpoint in your browser
3. Click **Files changed** and read the diff yourself
4. Click **Review changes > Approve**
5. Click **Squash and merge**
6. Delete the branch when prompted

You should see: The PR status changes to "Merged" with a purple icon.

### 7c. Production deployment

If Render secrets are configured, the deploy workflow
(`.github/workflows/deploy.yml`) triggers automatically on merge to `main`.

Watch the deployment:

```bash
gh run list --workflow=deploy.yml --limit 1
```

You should see:

```
STATUS  TITLE                WORKFLOW  BRANCH  ...
*       Deploy to production Deploy    main    ...
```

Wait for it to complete (1-3 minutes for Render free tier). Then verify:

```bash
curl https://agile-flow-starter.onrender.com/health
```

You should see:

```json
{"status": "ok"}
```

And your new endpoint:

```bash
curl https://agile-flow-starter.onrender.com/ping
```

You should see:

```json
{"ping": "pong"}
```

### 7d. Close the ticket

Move ticket `#7` to the Done column on your project board. Only you (the
human) do this -- agents are not allowed to mark tickets as Done.

---

## Step 8: Trigger a Bug -- Error to GitHub Issue to Agent Fix

The starter app has a deliberate `/error` endpoint that raises a
`RuntimeError`. When no external Sentry account is configured, the app
captures errors itself and creates GitHub issues automatically.

### 8a. Hit the error endpoint

```bash
curl https://agile-flow-starter.onrender.com/error
```

You should see: An HTTP 500 response.

### 8b. Check for the auto-created issue

Wait 10-30 seconds, then check your repository for new issues:

```bash
gh issue list --label bug:auto
```

You should see:

```
#N  bug: RuntimeError: Deliberate error for Day 1 workshop exercise...  bug:auto, P1
```

Open the issue on GitHub. The body contains the error type, message, and
stack trace — everything the agent needs to fix it.

### 8c. Auto-triage comment

The auto-triage workflow fires automatically when the `bug:auto` label is
applied. Check the issue for a comment that says:

```
## Auto-Triage

This bug was automatically detected from a production error.

To fix it, run:

/work-ticket #N
```

### 8d. Agent fixes the bug

Run the command from the triage comment:

```
/work-ticket #N
```

The agent will read the error details, create a branch, write a fix, and
open a pull request.

You should see: A new PR linked to the bug issue.

### 8e. Review and merge

Follow the same review process from Step 7 — run `/review-pr`, check the
diff, and merge.

You should see: The bug fix deployed to production. The `/error` endpoint
behavior is unchanged (it is deliberately broken for demo purposes), but
you have now experienced the full loop:

```
Error in production → Auto-detected → GitHub issue → Agent fix → PR → Human merge
```

No Sentry account required. If you want a full error monitoring dashboard
with history and alerts, see the upgrade options in
[SENTRY-SETUP.md](./SENTRY-SETUP.md).

---

## Day 1 Checklist

Verify you have completed each item:

- [ ] Created repo from template and cloned it locally
- [ ] All three accounts show up in `gh auth status`
- [ ] Environment variables `AGILE_FLOW_WORKER_ACCOUNT` and
      `AGILE_FLOW_REVIEWER_ACCOUNT` are set
- [ ] Read through the safety layers (AGENTIC-CONTROLS.md)
- [ ] `/bootstrap-workflow` ran successfully -- board is live, CI is green
- [ ] `/create-ticket` created a new issue on the board
- [ ] `/work-ticket` implemented the ticket and created a PR
- [ ] Preview URL works (if Render secrets configured)
- [ ] `/review-pr` posted a GO/NO-GO review comment
- [ ] You (human) approved and merged the PR
- [ ] Production deploy succeeded -- `/health` returns `{"status": "ok"}`
- [ ] `/error` endpoint created a `bug:auto` GitHub issue automatically
- [ ] Auto-triage workflow posted a `/work-ticket` comment on the issue

---

## Quick Reference: Slash Commands Used Today

| Command | What It Does |
|---------|-------------|
| `/bootstrap-workflow` | Creates project board, branch protection, initial backlog |
| `/create-ticket` | Creates a well-structured ticket on the board |
| `/work-ticket` | Agent picks up next ticket, implements, creates PR |
| `/review-pr` | Agent reviews PR and posts GO/NO-GO recommendation |
| `/sprint-status` | Board health overview (use this tomorrow morning) |

---

## If You Get Stuck

Run the diagnostic first — it catches most setup issues:

```bash
bash scripts/doctor.sh    # standalone
/doctor                    # in Claude Code (adds remote checks)
```

Check the account:

```bash
gh auth status
```

Check the board:

```bash
gh project item-list {project-number} --owner {your-org} --format json
```

Check CI:

```bash
gh run list --limit 5
```

Check Render:

- Open the Render dashboard and look at the build logs

Check Sentry:

- Open your Sentry project dashboard and look for recent events

If none of that helps, ask your instructor. The
[WORKSHOP-GUIDE.md](./WORKSHOP-GUIDE.md) has a full troubleshooting
flowchart under "If Someone Is Stuck."

---

## What Happens Tomorrow

Day 2 focuses on the development workflow loop: grooming the backlog,
working multiple tickets, handling CI failures, and practicing the full
create-work-review-merge cycle independently. Start the morning with:

```
/sprint-status
```
