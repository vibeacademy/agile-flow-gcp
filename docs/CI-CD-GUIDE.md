# CI/CD Guide

This document describes all GitHub Actions workflows, their triggers,
required secrets, and default states. This fork targets **GCP Cloud Run
+ Neon**.

## Workflow Overview

| Workflow | File | Trigger | Default State | Required Secrets |
|----------|------|---------|---------------|------------------|
| CI | `ci.yml` | Push/PR to main | Active | None |
| Release | `release.yml` | Tag `v*` | Active | None |
| Deploy | `deploy.yml` | Push to main | Inert | `GCP_PROJECT_ID`, `GCP_WORKLOAD_IDENTITY_PROVIDER` (or `GCP_SA_KEY`), `GCP_SERVICE_ACCOUNT` |
| Preview Deploy | `preview-deploy.yml` | PR opened/updated | Inert | Same as Deploy, plus `NEON_API_KEY`, `NEON_PROJECT_ID` |
| Preview Cleanup | `preview-cleanup.yml` | PR closed | Inert | Same as Preview Deploy |
| Auto Review | `auto-review.yml` | PR opened/ready | Active | None |
| Auto Fix | `auto-fix.yml` | PR opened/updated | Active | None |
| Rollback | `rollback-production.yml` | Manual dispatch | Inert | Same as Deploy |

Neon secrets are optional — if not configured, preview deploys will use
the production database instead of a branch database.

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
| `node` | ESLint, tsc --noEmit, Vitest, Next.js build |
| `python` | Ruff lint, mypy (non-blocking), pytest with coverage |

The `node` job is conditional — it only runs when `package.json` exists.
The `python` job is conditional — it only runs when `pyproject.toml` exists.
Both can coexist; the template ships with Next.js by default so the `node`
job runs and the `python` job skips. If you swap to the FastAPI starter
(see `starters/fastapi/README.md`), the jobs reverse automatically.

Coverage threshold for the Python job defaults to 80% and can be overridden
via the `COVERAGE_THRESHOLD` environment variable.

### Release (`release.yml`)

Triggers when a `v*` tag is pushed. Extracts the matching section from
`CHANGELOG.md` and creates a GitHub Release.

### Auto Review (`auto-review.yml`)

Posts a review reminder comment on new PRs, prompting the team to run
`/review-pr` for an agent review.

### Auto Fix (`auto-fix.yml`)

Automatically fixes lint issues on PR branches. Detects the project
type and runs the appropriate fixer:

- **Python** (when `pyproject.toml` exists): runs `ruff check --fix`
  and `ruff format`
- **Node.js** (when `package.json` exists): runs `npx eslint . --fix`

Fixed files are committed back to the PR branch automatically.

## Enable When Ready

These workflows require secrets to be configured in the repository settings.
Until configured, they skip gracefully with no red CI.

### Deploy (`deploy.yml`)

Deploys to Cloud Run production on merge to `main`.

**To enable, add these repository secrets** (Settings > Secrets and variables
> Actions):

| Secret | Where to Find |
|--------|--------------|
| `GCP_PROJECT_ID` | GCP project ID (e.g., `my-project-12345`) |
| `GCP_WORKLOAD_IDENTITY_PROVIDER` | Full WIF provider path (see `docs/PLATFORM-GUIDE.md` Step 5) |
| `GCP_SERVICE_ACCOUNT` | Deployer SA email (e.g., `deployer@my-project.iam.gserviceaccount.com`) |
| `GCP_SA_KEY` | **Fallback only**: service account JSON key. Use instead of the WIF trio if you need the workshop shortcut. |

**Recommended repository variables** (non-secret):

| Variable | Default | Purpose |
|----------|---------|---------|
| `GCP_REGION` | `us-central1` | Cloud Run + Artifact Registry region |
| `ARTIFACT_REPO` | `agile-flow` | Artifact Registry repo name |
| `CLOUD_RUN_SERVICE` | `agile-flow-app` | Cloud Run service name |
| `NEXT_PUBLIC_APP_URL` | (your URL) | Baked into client bundle at build time |

The deploy workflow builds a container image with `NEXT_PUBLIC_*` args
passed as `--build-arg`, pushes it to Artifact Registry, then calls
`gcloud run deploy`. Runtime secrets (e.g., `DATABASE_URL`) are mounted
from Secret Manager at deploy time — create the secret once with
`gcloud secrets create database-url --data-file=-`.

**Cloud Run keeps every revision.** Rollback is a traffic split, not a
redeploy. See the Rollback workflow below.

### Preview Deploy (`preview-deploy.yml`)

Creates a preview environment for every pull request: a Cloud Run
revision tag with zero production traffic, plus a Neon database branch.
Comments the preview URL on the PR.

**Required secrets:** Same as Deploy.

**Neon secrets (for per-PR database branching):**

| Secret | Where to Find |
|--------|--------------|
| `NEON_API_KEY` | Neon Console > Settings > API Keys |
| `NEON_PROJECT_ID` | Neon Console > Settings > General |

When Neon is configured, the workflow:

1. Creates a Neon branch named `pr-{N}` off `main` (via `neondatabase/create-branch-action@v5`)
2. Builds the container image with `NEXT_PUBLIC_*` baked in
3. Pushes the image to Artifact Registry with tag `pr-{N}-{sha}`
4. Deploys to Cloud Run as a tagged revision (`--tag=pr-{N} --no-traffic`)
5. Overrides `DATABASE_URL` with the Neon branch pooled URL for this revision only
6. Runs a smoke test against `/api/health`
7. Posts a status comment on the PR

Neon steps are gated on `NEON_API_KEY` — if not configured, the preview
deploys but uses the production database URL.

**Preview URL format:** `https://pr-{N}---{service}-{hash}.{region}.run.app`

### Preview Cleanup (`preview-cleanup.yml`)

Cleans up preview environments when PRs are closed or merged.

**Required secrets:** Same as Preview Deploy.

The workflow:

1. Deletes the Neon branch (`neondatabase/delete-branch-action@v3`)
2. Removes the Cloud Run revision tag (`gcloud run services update-traffic
   --remove-tags=pr-{N}`)

The underlying Cloud Run revision is **not** deleted — inactive revisions
cost nothing on scale-to-zero and are useful for forensics. Cloud Run
garbage-collects revisions automatically after 1000 accumulate per service.

Both steps are idempotent and use `continue-on-error: true` so a missing
branch or tag doesn't fail the workflow.

### Rollback Production (`rollback-production.yml`)

Emergency rollback triggered manually via GitHub Actions UI.

**To trigger:**

1. Go to **Actions > Rollback Production > Run workflow**
2. Optionally provide a specific revision name (defaults to previous ready revision)
3. Provide the reason for rollback (required)

**Requires the same secrets as Deploy.**

The workflow uses `gcloud run services update-traffic` to route 100% of
traffic to the target revision, then verifies with a smoke test. It does
NOT trigger a new build — the previous revision is already in Cloud Run's
revision history.

## Database Migrations

Migrations run as part of the Neon branch creation flow. If you use
Neon's migration runner or your own (e.g., `node-pg-migrate`, Prisma
Migrate, Drizzle Kit), run them after the branch is created but before
deploying.

For production migrations, run them from a one-off job before the
`gcloud run deploy` step in `deploy.yml`, or use Neon's point-in-time
restore if something goes wrong.

## Troubleshooting

### Common CI Failures

| Failure | Cause | Fix |
|---------|-------|-----|
| `lint` fails | Markdown formatting issues | Run `markdownlint --fix **/*.md` |
| `node` lint fails | ESLint violations | Run `npm run lint` locally, then `npx eslint . --fix` |
| `node` typecheck fails | TypeScript errors | Run `npm run typecheck` and fix reported errors |
| `node` test fails | Vitest failures | Run `npm test` locally |
| `node` build fails | Next.js build error | Run `npm run build` locally and check output |
| `python` lint fails | Ruff violations | Run `uv run ruff check . --fix` |
| `python` tests fail | Test failures or coverage below threshold | Fix tests or lower `COVERAGE_THRESHOLD` |
| `lint-agent-policies` fails | Agent file missing safety phrases | Check `scripts/verify-agent-restrictions.sh` output |
| `build` fails | Shell script errors | Run `shellcheck <script>` locally |
| `auto-fix` skips your stack | No fixer detected | Ensure `package.json` (Node.js) or `pyproject.toml` (Python) exists in the repo root |

### Secret-Gated Workflows Show "Skipped"

This is expected behavior. The workflow checked for secrets, found none
configured, and skipped gracefully. Add the required secrets when you are
ready to enable the workflow.

### Deploy Fails with `PERMISSION_DENIED: actAs`

The deployer service account is missing the `roles/iam.serviceAccountUser`
role. See pattern #14 in `docs/PATTERN-LIBRARY.md`.

### Preview URL Returns 404 / Service Unavailable

Most likely `HOSTNAME=0.0.0.0` is missing from the Dockerfile. See pattern
#1 in `docs/PATTERN-LIBRARY.md`. Cloud Run cannot reach a container bound
to localhost.

### Cold Start on First Preview Request

Expected. Cloud Run + Neon both scale to zero. First request after idle
takes 3-7 seconds total. Retry; subsequent requests are fast.

### Coverage Threshold Failures

The default coverage threshold is 80%. To adjust:

1. Set `COVERAGE_THRESHOLD` as a repository variable (not secret)
2. Go to **Settings > Secrets and variables > Actions > Variables**
3. Add `COVERAGE_THRESHOLD` with your desired percentage
