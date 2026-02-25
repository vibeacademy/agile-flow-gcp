# Day 1 Walkthrough: Template to Production Bug Ticket

This is a step-by-step guide for workshop participants. It uses a
"Deploy First" approach — you will have a live app on the internet within
15 minutes, then layer on the agentic workflow. If you are an instructor,
see [WORKSHOP-GUIDE.md](./WORKSHOP-GUIDE.md) for session plans and
troubleshooting flowcharts.

By the end of Day 1, you will have:

- Your own repo (from the template) with a live project board
- A deployed app on Render with a working health check
- A pull request created by an agent, reviewed by an agent, merged by you
- A deliberate error captured with a bug ticket auto-created on your board

---

## Prerequisites

Before you start, confirm:

- Three GitHub accounts ready (personal, `{org}-worker`, `{org}-reviewer`)
- Claude Code CLI installed and authenticated
- `GITHUB_PERSONAL_ACCESS_TOKEN` exported with `repo` + `project` + `workflow` scopes
- Node.js 20+ and npm installed
- Render account created (free tier is fine)
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

## Step 2: Connect to Render and Deploy

Deploy before cloning — see your app live in under 15 minutes.

1. Go to <https://dashboard.render.com> and sign in.
2. Click **New > Web Service**.
3. Connect your GitHub repository (`{your-org}/agile-flow`).
4. Render auto-detects `render.yaml`. Verify:
   - **Build Command**: `npm install && npm run build`
   - **Start Command**: `node .next/standalone/server.js`
   - **Instance Type**: Free
5. Click **Create Web Service**.

Wait for the first deploy to complete (2-5 minutes on free tier).

You should see: Your app at `https://agile-flow-starter.onrender.com`
showing "Agile Flow Starter".

Verify the health check:

```bash
curl https://agile-flow-starter.onrender.com/api/health
```

You should see:

```json
{"status":"ok"}
```

> **Free tier spin-down**: Free services spin down after 15 minutes of
> inactivity. The first request after spin-down takes 30-60 seconds.

---

## Step 3: Clone and Verify Local Setup

> **Important:** `cd` to the directory where you want your project *before*
> cloning. A common mistake is cloning inside another repo.

```bash
cd ~/projects   # or wherever you keep repos
git clone https://github.com/{your-org}/agile-flow.git
cd agile-flow
```

Install dependencies and verify:

```bash
npm install
npm run dev
```

Open <http://localhost:3000> and confirm the landing page shows. Then
check the health endpoint:

```bash
curl http://localhost:3000/api/health
```

You should see: `{"status":"ok"}`

Enable the pre-push hook:

```bash
git config core.hooksPath scripts/hooks
```

Run the diagnostic to verify your local setup:

```bash
bash scripts/doctor.sh
```

You should see: A list of `[PASS]` checks with a summary at the end. Fix
any `[FAIL]` items before continuing.

---

## Step 3b: Configure GitHub Secrets

Your repository needs these secrets for the preview deploy and Supabase
branch workflows. Go to your repo > **Settings > Secrets and variables >
Actions > New repository secret** and add each one:

| Secret | Source | Required For |
|--------|--------|-------------|
| `SUPABASE_ACCESS_TOKEN` | Supabase Dashboard > Account > Access Tokens | Preview branch databases |
| `SUPABASE_PROJECT_REF` | Supabase project URL (the ref segment) | Preview branch detection |
| `RENDER_API_KEY` | Render Dashboard > Account Settings > API Keys | Preview env var injection |
| `RENDER_SERVICE_ID` | Render service URL (starts with `srv-`) | Preview service discovery |

---

## Step 4: Verify Three Accounts Work

> **Tip**: If any account is missing, run
> `bash scripts/setup-accounts.sh` to configure all three at once.

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

> **PAT scopes**: Each bot account's PAT needs **`repo`** +
> **`project`** + **`workflow`** scopes (classic PAT) so the agent can
> manage issues, PRs, move tickets on the project board, and push
> workflow file changes. If you used fine-grained PATs, enable
> `Contents`, `Issues`, `Pull requests`, `Metadata` (read), `Projects`,
> and `Workflows` permissions.

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

## Step 5: Run the Bootstrap Wizard

Open Claude Code and run the bootstrap phases:

```bash
claude
```

Inside the Claude Code session, run each phase in order:

```
/bootstrap-product
/bootstrap-architecture
/bootstrap-agents
/bootstrap-workflow
```

The workflow phase will ask you for:

```
GitHub Organization: {your-org}
Repository Name: agile-flow
Project Board Name: Agile Flow
```

After completion you should see:

- A GitHub Project board at your repo with columns populated
- 3-5 tickets in the Ready column
- Branch protection active on `main` (verify at Settings > Branches)

Verify CI is green by checking the Actions tab on your repo.

---

## Step 6: Understand the Safety Layers

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

---

## Step 7: Create a Ticket, Work It, and Get a PR

### 7a. Create a ticket

In your Claude Code session:

```
/create-ticket Add a /api/ping endpoint that returns {"ping": "pong"}
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

### 7b. Work the ticket

```
/work-ticket
```

The agent (using the `{org}-worker` account) will:

1. Pick the top ticket from the Ready column
2. Move it to In Progress
3. Create a branch: `feature/issue-7-ping-endpoint` (number will vary)
4. Implement the `/api/ping` endpoint
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
Created PR #8: Add /api/ping endpoint
CI checks passing
Moved #7 to In Review
```

### 7c. Preview URL

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
curl https://agile-flow-starter-pr-8.onrender.com/api/ping
```

You should see:

```json
{"ping": "pong"}
```

---

## Step 8: Review the PR, Merge, and Deploy to Production

### 8a. Agent review

In your Claude Code session:

```
/review-pr
```

The agent (using the `{org}-reviewer` account) will:

1. Find the PR in the In Review column
2. Read the diff and analyze code quality
3. Check that tests exist and CI is green
4. Post a structured review comment with a GO or NO-GO recommendation

### 8b. Human review and merge

This is your job. The agent cannot merge -- only you can.

1. Go to the PR on GitHub
2. If a preview URL exists, test the endpoint in your browser
3. Click **Files changed** and read the diff yourself
4. Click **Review changes > Approve**
5. Click **Squash and merge**
6. Delete the branch when prompted

### 8c. Production deployment

If Render secrets are configured, the deploy workflow triggers
automatically on merge to `main`.

Wait for it to complete (1-3 minutes for Render free tier). Then verify:

```bash
curl https://agile-flow-starter.onrender.com/api/health
```

You should see:

```json
{"status":"ok"}
```

And your new endpoint:

```bash
curl https://agile-flow-starter.onrender.com/api/ping
```

You should see:

```json
{"ping":"pong"}
```

### 8d. Close the ticket

Move ticket `#7` to the Done column on your project board. Only you (the
human) do this -- agents are not allowed to mark tickets as Done.

---

## Step 9: Trigger a Bug -- Error to GitHub Issue to Agent Fix

The starter app has a deliberate `/api/error` endpoint that throws an
error. When no external Sentry account is configured, the app captures
errors itself and creates GitHub issues automatically.

### 9a. Hit the error endpoint

```bash
curl https://agile-flow-starter.onrender.com/api/error
```

You should see: An HTTP 500 response.

### 9b. Check for the auto-created issue

Wait 10-30 seconds, then check your repository for new issues:

```bash
gh issue list --label bug:auto
```

You should see:

```
#N  bug: Error: Test error for Sentry verification...  bug:auto, P1
```

Open the issue on GitHub. The body contains the error type, message, and
stack trace — everything the agent needs to fix it.

### 9c. Agent fixes the bug

Run the command from the triage comment:

```
/work-ticket #N
```

The agent will read the error details, create a branch, write a fix, and
open a pull request.

### 9d. Review and merge

Follow the same review process from Step 8 — run `/review-pr`, check the
diff, and merge.

You should see: The bug fix deployed to production. You have now
experienced the full loop:

```
Error in production -> Auto-detected -> GitHub issue -> Agent fix -> PR -> Human merge
```

No Sentry account required. If you want a full error monitoring dashboard
with history and alerts, see the upgrade options in
[SENTRY-SETUP.md](./SENTRY-SETUP.md).

---

## Day 1 Checklist

Verify you have completed each item:

- [ ] Created repo from template
- [ ] Deployed to Render — `/api/health` returns `{"status":"ok"}`
- [ ] Cloned locally — `npm run dev` works
- [ ] All three accounts show up in `gh auth status`
- [ ] Environment variables `AGILE_FLOW_WORKER_ACCOUNT` and
      `AGILE_FLOW_REVIEWER_ACCOUNT` are set
- [ ] Bootstrap phases completed — board is live, CI is green
- [ ] Read through the safety layers (AGENTIC-CONTROLS.md)
- [ ] `/create-ticket` created a new issue on the board
- [ ] `/work-ticket` implemented the ticket and created a PR
- [ ] Preview URL works (if Render secrets configured)
- [ ] `/review-pr` posted a GO/NO-GO review comment
- [ ] You (human) approved and merged the PR
- [ ] Production deploy succeeded
- [ ] `/api/error` endpoint created a `bug:auto` GitHub issue automatically

---

## Quick Reference: Slash Commands Used Today

| Command | What It Does |
|---------|-------------|
| `/bootstrap-product` | Creates PRD and roadmap |
| `/bootstrap-architecture` | Defines tech stack and system design |
| `/bootstrap-agents` | Specializes agents with project context |
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
