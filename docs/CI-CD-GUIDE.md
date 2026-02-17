# CI/CD Guide

This document describes all GitHub Actions workflows, their triggers,
required secrets, and default states.

## Workflow Overview

| Workflow | File | Trigger | Default State | Required Secrets |
|----------|------|---------|---------------|------------------|
| CI | `ci.yml` | Push/PR to main | Active | None |
| Release | `release.yml` | Tag `v*` | Active | None |
| Deploy | `deploy.yml` | Push to main | Inert | RENDER_API_KEY, RENDER_SERVICE_ID |
| Preview Deploy | `preview-deploy.yml` | PR opened/updated | Inert | RENDER_API_KEY, RENDER_SERVICE_ID |
| Preview Cleanup | `preview-cleanup.yml` | PR closed | Inert | RENDER_API_KEY, RENDER_SERVICE_ID |
| Auto Review | `auto-review.yml` | PR opened/ready | Active | None |
| Auto Fix | `auto-fix.yml` | PR opened/updated | Active | None |
| Rollback | `rollback-production.yml` | Manual dispatch | Inert | RENDER_API_KEY, RENDER_SERVICE_ID |

## Active by Default

These workflows run without any configuration.

### CI (`ci.yml`)

Runs on every push and pull request to `main`.

**Jobs:**

| Job | What It Checks |
|-----|----------------|
| `lint` | Markdown formatting (markdownlint) |
| `typecheck` | JSON file validity |
| `build` | Shell script correctness (shellcheck) |
| `test` | Command and agent file validation |
| `lint-agent-policies` | Agent policy safety rules |
| `python` | Ruff lint, mypy (non-blocking), pytest with coverage |

The `python` job is conditional — it only runs when `pyproject.toml` exists.
Coverage threshold defaults to 80% and can be overridden via the
`COVERAGE_THRESHOLD` environment variable.

If a `features/` directory with `.feature` files exists, BDD tests run
automatically.

### Release (`release.yml`)

Triggers when a `v*` tag is pushed. Extracts the matching section from
`CHANGELOG.md` and creates a GitHub Release.

### Auto Review (`auto-review.yml`)

Posts a review reminder comment on new PRs, prompting the team to run
`/review-pr` for an agent review.

### Auto Fix (`auto-fix.yml`)

Automatically fixes lint issues on PR branches. For Python projects,
runs `ruff check --fix` and `ruff format`, then commits the results
back to the PR branch.

## Enable When Ready

These workflows require secrets to be configured in the repository settings.
Until configured, they skip gracefully with no red CI.

### Deploy (`deploy.yml`)

Deploys to Render production on merge to `main`.

**To enable:**

1. Go to **Settings > Secrets and variables > Actions**
2. Add these repository secrets:

| Secret | Where to Find |
|--------|--------------|
| `RENDER_API_KEY` | Render Dashboard > Account Settings > API Keys |
| `RENDER_SERVICE_ID` | Render Dashboard > Service > Settings (starts with `srv-`) |

The workflow stores the previous deployment ID before deploying, which can
be used for rollback.

If a `supabase/migrations/` directory exists and `SUPABASE_DB_URL` is
configured, database migrations run automatically after deployment.

### Preview Deploy (`preview-deploy.yml`)

Creates a preview environment on Render for every pull request. Comments the
preview URL on the PR.

**Requires the same secrets as Deploy** (`RENDER_API_KEY`, `RENDER_SERVICE_ID`).

Render must also have `previewsEnabled: true` in `render.yaml` (already
configured in this template).

### Preview Cleanup (`preview-cleanup.yml`)

Cleans up preview environments when PRs are closed or merged.

**Requires the same secrets as Deploy.**

### Rollback Production (`rollback-production.yml`)

Emergency rollback triggered manually via GitHub Actions UI.

**To trigger:**

1. Go to **Actions > Rollback Production > Run workflow**
2. Optionally provide a specific deploy ID (defaults to previous deploy)
3. Provide the reason for rollback (required)

**Requires the same secrets as Deploy.**

## Troubleshooting

### Common CI Failures

| Failure | Cause | Fix |
|---------|-------|-----|
| `lint` fails | Markdown formatting issues | Run `markdownlint --fix **/*.md` |
| `python` lint fails | Ruff violations | Run `uv run ruff check . --fix` |
| `python` tests fail | Test failures or coverage below threshold | Fix tests or lower `COVERAGE_THRESHOLD` |
| `lint-agent-policies` fails | Agent file missing safety phrases | Check `scripts/verify-agent-restrictions.sh` output |
| `build` fails | Shell script errors | Run `shellcheck <script>` locally |

### Secret-Gated Workflows Show "Skipped"

This is expected behavior. The workflow checked for secrets, found none
configured, and skipped gracefully. Add the required secrets when you are
ready to enable the workflow.

### Preview URL Not Available

If the preview deploy workflow runs but the URL is not ready:

1. Check the Render dashboard for the preview service status
2. Preview services follow the naming pattern `{service-name}-pr-{number}`
3. First deploys take longer as Render provisions the service

### Coverage Threshold Failures

The default coverage threshold is 80%. To adjust:

1. Set `COVERAGE_THRESHOLD` as a repository variable (not secret)
2. Go to **Settings > Secrets and variables > Actions > Variables**
3. Add `COVERAGE_THRESHOLD` with your desired percentage
