# Pre-Work Checklist

Complete these steps **before** the workshop starts. Budget about
60–90 minutes total.

Items are split into **Required** (blocks Day 1) and **Optional**
(enhances but does not block). Do the Required section first.

---

## Required

### 1. Claude Subscription

You need a Claude Pro, Max, or Team plan to access the Code tab in
Claude Desktop.

**Steps:**

1. Go to <https://claude.ai>
1. Subscribe to a **Pro**, **Max**, or **Team** plan if you have not already

**You should see:** The Code tab available when you open Claude Desktop.

---

### 2. Claude Desktop App

Claude Code Desktop is the primary interface for the workshop. It runs
Claude Code inside the desktop app — no terminal required.

**Steps:**

1. Download Claude Desktop from <https://claude.ai/download>
1. Install and open it
1. Verify the **Code** tab appears in the sidebar

**You should see:** The Claude Desktop app with a Code tab you can click
into.

> **Note:** Claude Code Desktop spawns its own shell process. It does
> NOT bundle Git, Node.js, or `gh` — you must install those separately
> (Step 4 below).

---

### 3. Three GitHub Accounts + Organization

The Agile Flow workflow uses three GitHub accounts to enforce separation
of duties: you (the human), a worker bot, and a reviewer bot.

#### 3a. Create a GitHub Organization

1. Go to <https://github.com/organizations/plan>
1. Choose **Free**
1. Name it something short (e.g., `yourname-workshop`)
1. Skip inviting members for now

#### 3b. Create Two Bot Accounts

| Account | Purpose | Naming Convention |
|---------|---------|-------------------|
| Your personal account | Final review, merge, project management | (your existing account) |
| Worker bot | Creates branches, writes code, opens PRs | `{org}-worker` |
| Reviewer bot | Reviews PRs, posts GO/NO-GO recommendations | `{org}-reviewer` |

1. Create two new GitHub accounts using different email addresses:
   - `{org}-worker` (e.g., `myproject-worker`)
   - `{org}-reviewer` (e.g., `myproject-reviewer`)
1. Invite both bot accounts to your organization as **Members**
   - Go to `https://github.com/orgs/{your-org}/people`
   - Click **Invite member** for each

> **Tip:** Use email aliases (e.g., `you+worker@gmail.com`) to create
> the bot accounts without needing separate email addresses.

#### 3c. Create Three Personal Access Tokens (PATs)

Each account needs its own **classic** token. Classic tokens are simpler
to configure and fully supported by the `gh` CLI.

**Steps (repeat for each account):**

1. Log in as that account
1. Go to **Settings > Developer settings > Personal access tokens > Tokens (classic)**
1. Click **Generate new token (classic)**
1. Token name: `agile-flow-workshop`
1. Expiration: choose a date after the workshop ends
1. Select the scopes below, then click **Generate token** and save it

**Personal account + Worker bot scopes:**

| Scope | Why |
|-------|-----|
| `repo` | Full repository access (code, PRs, issues) |
| `read:org` | Read org membership (needed for `gh` CLI) |
| `project` | Manage project boards |
| `gist` | Required minimum for `gh auth login` |

**Reviewer bot scopes (narrower):**

| Scope | Why |
|-------|-----|
| `repo` | Read code + write PR reviews |
| `read:org` | Read org membership |
| `gist` | Required minimum for `gh auth login` |

**You should see:** Three tokens saved securely (they start with
`ghp_`). You will need all three in Step 5.

> **Keep these safe.** Store them in a password manager or a local file
> that you will delete after setup. Never commit tokens to a repository.

---

### 4. System Tools

Claude Code Desktop does **not** bundle these tools — you must install
them yourself.

| Tool | Install | Verify |
|------|---------|--------|
| Git | <https://git-scm.com/downloads> | `git --version` |
| Node.js 18+ | <https://nodejs.org> | `node --version` |
| GitHub CLI (`gh`) | <https://cli.github.com> | `gh --version` |

On macOS with Homebrew:

```bash
brew install git node gh
```

After installing, verify all three:

```bash
git --version && node --version && gh --version
```

> **Why Node.js?** MCP servers (used by Claude Desktop) are launched via
> `npx`, which requires Node.js to be installed.

---

### 5. GitHub CLI Multi-Account Login

You need all three GitHub accounts authenticated in `gh` so the Agile
Flow agents can switch between them.

**Steps:**

1. Log in your personal account first:

   ```bash
   gh auth login
   # Choose: GitHub.com > HTTPS > Paste your personal PAT
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

1. Set environment variables — add to your **`~/.zshrc`** (macOS) or
   `~/.bashrc` (Linux):

   ```bash
   export GITHUB_PERSONAL_ACCESS_TOKEN="ghp_your_personal_pat_here"
   export AGILE_FLOW_WORKER_ACCOUNT="{org}-worker"
   export AGILE_FLOW_REVIEWER_ACCOUNT="{org}-reviewer"
   ```

   Then reload:

   ```bash
   source ~/.zshrc  # or source ~/.bashrc
   ```

> **Quick setup:** If you have all three PATs ready, run
> `bash scripts/setup-accounts.sh` to configure everything in one step.

---

### 6. Shell Environment for Claude Desktop

**This is the most common setup pitfall.** Claude Code Desktop spawns a
shell that reads your shell profile file. If your env vars or PATH
changes live somewhere else, Desktop will not see them.

#### Where to put env vars

| OS | File to edit |
|----|-------------|
| macOS | `~/.zshrc` |
| Linux | `~/.bashrc` |

**Do NOT put them in:** iTerm preferences, `.bash_profile` (macOS only
sources `.zshrc` for zsh), terminal-app-specific config, or GUI
environment editors.

#### Required env vars

Make sure these lines are in your `~/.zshrc` (or `~/.bashrc`):

```bash
export GITHUB_PERSONAL_ACCESS_TOKEN="ghp_your_personal_pat_here"
export AGILE_FLOW_WORKER_ACCOUNT="{org}-worker"
export AGILE_FLOW_REVIEWER_ACCOUNT="{org}-reviewer"
```

#### Required PATH entries

If you installed tools via Homebrew, nvm, or another version manager,
make sure the relevant PATH line is in `~/.zshrc`, for example:

```bash
# Homebrew (Apple Silicon)
eval "$(/opt/homebrew/bin/brew shellenv)"

# or Homebrew (Intel Mac)
eval "$(/usr/local/bin/brew shellenv)"
```

#### Restart Claude Desktop

After editing your shell profile, **quit and relaunch Claude Desktop**.
Reloading the shell in a terminal is not enough — Desktop must restart
to pick up the changes.

#### Verify from inside Desktop

Open the Code tab in Claude Desktop and ask Claude to run:

```
echo $GITHUB_PERSONAL_ACCESS_TOKEN
```

If it prints your token, the environment is set up correctly. If it
prints a blank line, your env vars are not in the right file — re-check
the steps above.

---

### 7. Required Verification Checklist

Run through this before the workshop:

- [ ] Claude Pro/Max/Team subscription active
- [ ] Claude Desktop installed, Code tab visible
- [ ] GitHub organization created
- [ ] Worker bot account created and invited to org
- [ ] Reviewer bot account created and invited to org
- [ ] Personal PAT generated with correct scopes
- [ ] Worker bot PAT generated
- [ ] Reviewer bot PAT generated
- [ ] `gh auth status` shows all three accounts
- [ ] `GITHUB_PERSONAL_ACCESS_TOKEN` env var set in `~/.zshrc`
- [ ] `AGILE_FLOW_WORKER_ACCOUNT` env var set in `~/.zshrc`
- [ ] `AGILE_FLOW_REVIEWER_ACCOUNT` env var set in `~/.zshrc`
- [ ] Git, Node.js 18+, and `gh` CLI installed
- [ ] Claude Desktop can see env vars (verified from Code tab)
- [ ] All tokens and passwords saved securely

---

## Optional

These enhance the workshop experience but are **not required** before
Day 1. You can set them up during the workshop.

### 8. Supabase Account

Supabase provides the database with ephemeral per-PR branches — each
pull request gets its own isolated database.

> **You can do this during the workshop.** If you want a head start,
> complete the steps below.

**Steps:**

1. Create a free account at <https://supabase.com>
1. Create a new project:
   - Organization: Create one or use existing
   - Project name: `agile-flow-workshop` (or your project name)
   - Database password: Generate a strong password and **save it**
   - Region: Choose the closest to you
1. Wait for the project to finish provisioning (1–2 minutes)

#### Generate an access token

1. Click your avatar (top right) > **Account preferences**
1. Go to **Access Tokens**
1. Click **Generate new token**
1. Name: `agile-flow-workshop`
1. Copy and save the token

#### Note your project reference ID

1. Go to **Project Settings** (gear icon in sidebar) > **General**
1. Copy the **Reference ID** (a short alphanumeric string like
   `abcdefghijkl`)

**You should see:** Your Supabase project dashboard with the project URL
and API keys visible.

---

### 9. Render Account

Render hosts your application and provides automatic preview
environments for every PR.

> **You can do this during the workshop.** If you want a head start,
> create the account now.

**Steps:**

1. Create a free account at <https://render.com>
1. Connect your GitHub account in Render settings

> **Do not create a service yet.** You will do that during the workshop
> when you deploy for the first time.

**You should see:** Your Render dashboard with GitHub connected.

---

## Troubleshooting

### Claude Desktop does not show the Code tab

Make sure you have a Pro, Max, or Team plan. Free plans do not include
the Code tab.

### Environment variables are blank inside Desktop

Your env vars are not in `~/.zshrc` (macOS) or `~/.bashrc` (Linux).
Move them there and **restart Claude Desktop** (not just the terminal).

### "Permission denied" when pushing

Your PAT may not have the `repo` scope, or the token may have expired.
Generate a new one.

### Bot account invitation pending

Check the bot account's email for the org invitation, or go to
`https://github.com/orgs/{your-org}/people` and resend the invitation.

### `gh auth login` fails with token

Make sure you are pasting the full token with no extra whitespace. Try:

```bash
echo "ghp_your_token_here" | gh auth login --with-token --hostname github.com
```

### `npx` command not found

Node.js is not installed or not in your PATH. Install Node.js 18+ and
make sure the install location is in your PATH in `~/.zshrc`.

---

## What to Bring to the Workshop

- Your laptop with all required tools installed (see checklist above)
- All three PATs accessible (password manager or secure note)
- Claude Desktop installed and working
- A charger
- A project idea (optional — the workshop provides a starter project)
