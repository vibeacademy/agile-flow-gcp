# Pre-Work Checklist

Complete these steps **before** the workshop starts. Each step includes
what you need, how to do it, and what success looks like. Budget about
60-90 minutes total.

---

## 1. GitHub Organization

You need a GitHub organization to host your project. Free orgs work fine.

**Steps:**

1. Go to <https://github.com/organizations/plan>
2. Choose **Free**
3. Name it something short (e.g., `yourname-workshop`)
4. Skip inviting members for now

**You should see:** Your org page at `https://github.com/yourname-workshop`.

---

## 2. Three GitHub Accounts

The Agile Flow workflow uses three GitHub accounts to enforce separation of
duties: you (the human), a worker bot, and a reviewer bot.

| Account | Purpose | Naming Convention |
|---------|---------|-------------------|
| Your personal account | Final review, merge, project management | (your existing account) |
| Worker bot | Creates branches, writes code, opens PRs | `{org}-worker` |
| Reviewer bot | Reviews PRs, posts GO/NO-GO recommendations | `{org}-reviewer` |

**Steps:**

1. Create two new GitHub accounts using different email addresses:
   - `{org}-worker` (e.g., `myproject-worker`)
   - `{org}-reviewer` (e.g., `myproject-reviewer`)
2. Invite both bot accounts to your organization as **Members**
   - Go to `https://github.com/orgs/{your-org}/people`
   - Click **Invite member** for each

**You should see:** Three accounts listed in your org's People page.

> **Tip:** Use email aliases (e.g., `you+worker@gmail.com`) to create the
> bot accounts without needing separate email addresses.

---

## 3. Three Personal Access Tokens (PATs)

Each account needs its own token. Create **fine-grained** tokens (not
classic) for better security.

### 3a. Personal account PAT

1. Log in as your personal account
2. Go to **Settings > Developer settings > Personal access tokens > Fine-grained tokens**
3. Click **Generate new token**
4. Token name: `agile-flow-workshop`
5. Resource owner: Select your organization
6. Repository access: **All repositories** (or select your repository later)
7. Permissions:

| Permission | Access |
|-----------|--------|
| Contents | Read and write |
| Issues | Read and write |
| Pull requests | Read and write |
| Projects | Read and write |
| Metadata | Read only |

1. Click **Generate token** and save it somewhere safe

### 3b. Worker bot PAT

1. Log in as `{org}-worker`
2. Same steps as above, with these permissions:

| Permission | Access |
|-----------|--------|
| Contents | Read and write |
| Issues | Read and write |
| Pull requests | Read and write |
| Projects | Read and write |
| Metadata | Read only |

### 3c. Reviewer bot PAT

1. Log in as `{org}-reviewer`
2. Same steps as above, with these permissions:

| Permission | Access |
|-----------|--------|
| Contents | Read only |
| Issues | Read only |
| Pull requests | Read and write |
| Projects | Read only |
| Metadata | Read only |

**You should see:** Three tokens saved. You will need all three during
setup.

> **Keep these safe.** Store them in a password manager or a local file
> that you will delete after setup. Never commit tokens to a repository.

---

## 4. GitHub CLI (`gh`)

The workshop uses the GitHub CLI extensively. Install it and log in all
three accounts.

**Steps:**

1. Install the GitHub CLI: <https://cli.github.com>
2. Log in your personal account first:

```bash
gh auth login
# Choose: GitHub.com > HTTPS > Paste your PAT
```

1. Log in the worker bot:

```bash
echo "YOUR_WORKER_PAT" | gh auth login --with-token
```

1. Log in the reviewer bot:

```bash
echo "YOUR_REVIEWER_PAT" | gh auth login --with-token
```

1. Verify all three accounts:

```bash
gh auth status
```

**You should see:** Three accounts listed, with your personal account
marked as active.

1. Set the environment variables (add to `~/.zshrc` or `~/.bashrc`):

```bash
export AGILE_FLOW_WORKER_ACCOUNT="{org}-worker"
export AGILE_FLOW_REVIEWER_ACCOUNT="{org}-reviewer"
```

Then reload your shell:

```bash
source ~/.zshrc  # or source ~/.bashrc
```

> **Quick setup**: If you already have all three PATs, run
> `bash scripts/setup-accounts.sh` to configure all accounts in one step.

---

## 5. Claude Code CLI

Claude Code is the AI assistant that powers the Agile Flow agents.

**Steps:**

1. Install Claude Code: <https://claude.ai/code>
2. Authenticate:

```bash
claude auth login
```

1. Verify:

```bash
claude --version
```

**You should see:** A version number (e.g., `1.x.x`).

---

## 6. Supabase Account

Supabase provides the database with ephemeral per-PR branches — each
pull request gets its own isolated database.

**Steps:**

1. Create a free account at <https://supabase.com>
2. Create a new project:
   - Organization: Create one or use existing
   - Project name: `agile-flow-workshop` (or your project name)
   - Database password: Generate a strong password and **save it**
   - Region: Choose the closest to you
3. Wait for the project to finish provisioning (1-2 minutes)

**You should see:** Your Supabase project dashboard with the project URL
and API keys visible.

### 6a. Generate an access token

1. Click your avatar (top right) > **Account preferences**
2. Go to **Access Tokens**
3. Click **Generate new token**
4. Name: `agile-flow-workshop`
5. Copy and save the token

### 6b. Note your project reference ID

1. Go to **Project Settings** (gear icon in sidebar) > **General**
2. Copy the **Reference ID** (a short alphanumeric string like `abcdefghijkl`)

### 6c. Enable GitHub integration (for branch databases)

1. Go to **Project Settings > Integrations > GitHub**
2. Click **Connect GitHub**
3. Authorize Supabase for your organization
4. Select your repository
5. Enable **Branch previews**

**You should see:** GitHub listed as connected in the Integrations page.

> **Note:** The GitHub integration creates a Supabase branch database
> automatically whenever a PR is opened. This gives each PR its own
> isolated Postgres instance.

---

## 7. Render Account

Render hosts your application and provides automatic preview environments
for every PR.

**Steps:**

1. Create a free account at <https://render.com>
2. Connect your GitHub account in Render settings

> **Do not create a service yet.** You will do that during the workshop
> when you deploy for the first time.

**You should see:** Your Render dashboard with GitHub connected.

---

## 8. Add Secrets to Your Repository

After creating your repository from the Agile Flow template during the
workshop, you will need to add these secrets. You can prepare the values
now so you are ready to paste them in.

Go to your repository > **Settings > Secrets and variables > Actions > New
repository secret** and add:

### Required for Supabase (database)

| Secret Name | Value |
|-------------|-------|
| `SUPABASE_ACCESS_TOKEN` | The access token from Step 6a |
| `SUPABASE_PROJECT_REF` | The reference ID from Step 6b |

### Required for Render (hosting) — add during workshop

| Secret Name | Value |
|-------------|-------|
| `RENDER_API_KEY` | Render Dashboard > Account Settings > API Keys |
| `RENDER_SERVICE_ID` | Render Dashboard > Your Service > Settings (starts with `srv-`) |

### Optional (production database migrations)

| Secret Name | Value |
|-------------|-------|
| `SUPABASE_DB_URL` | Supabase Dashboard > Project Settings > Database > Connection string |

---

## 9. Development Tools

Make sure these are installed on your machine:

| Tool | Install | Verify |
|------|---------|--------|
| Git | <https://git-scm.com/downloads> | `git --version` |
| Node.js 18+ | <https://nodejs.org> | `node --version` |
| Python 3.11+ | <https://python.org> or `brew install python` | `python3 --version` |
| uv (Python package manager) | `curl -LsSf https://astral.sh/uv/install.sh \| sh` | `uv --version` |

---

## Pre-Work Verification Checklist

Run through this checklist to confirm everything is ready:

- [ ] GitHub organization created
- [ ] Worker bot account created and invited to org
- [ ] Reviewer bot account created and invited to org
- [ ] Personal PAT generated with repo + project permissions
- [ ] Worker bot PAT generated
- [ ] Reviewer bot PAT generated
- [ ] `gh auth status` shows all three accounts
- [ ] `AGILE_FLOW_WORKER_ACCOUNT` env var set
- [ ] `AGILE_FLOW_REVIEWER_ACCOUNT` env var set
- [ ] Claude Code CLI installed and authenticated
- [ ] Supabase account created with a project
- [ ] Supabase access token generated
- [ ] Supabase project reference ID noted
- [ ] Supabase GitHub integration enabled for your org
- [ ] Render account created with GitHub connected
- [ ] Git, Node.js, Python 3.11+, and uv installed
- [ ] All tokens and passwords saved securely
- [ ] Run `bash scripts/doctor.sh` (or `/doctor` in Claude Code) — all checks pass

> **Note:** `agile-flow` is a **template repository**. During the workshop
> you will use **"Use this template"** (not Fork) to create your own repo.
> This gives you a clean repo with its own issues and project board.

---

## Troubleshooting

### "Permission denied" when pushing

Your PAT may not have the `Contents: Read and write` permission, or the
token may have expired. Generate a new one.

### Bot account invitation pending

Check the bot account's email for the org invitation, or go to
`https://github.com/orgs/{your-org}/people` and resend the invitation.

### Supabase project still provisioning

New projects take 1-2 minutes. Refresh the page. If it takes longer than
5 minutes, try creating the project in a different region.

### `gh auth login` fails with token

Make sure you are pasting the full token with no extra whitespace. Try:

```bash
echo "ghp_your_token_here" | gh auth login --with-token --hostname github.com
```

---

## What to Bring to the Workshop

- Your laptop with all tools installed (see checklist above)
- All three PATs accessible (password manager or secure note)
- Your Supabase access token and project reference ID
- A charger
- A project idea (optional — the workshop provides a starter project)
