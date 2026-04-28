# Platform Guide: GCP Cloud Run + Neon

This template is configured for **Google Cloud Platform**. The app deploys
to Cloud Run as a container, using Artifact Registry for image storage,
Secret Manager for runtime secrets, and Neon for Postgres with per-PR
branching.

If you need to adapt the template to a different platform, the upstream
`vibeacademy/agile-flow` repo supports Render, Vercel, Cloudflare, and
others. This fork is GCP-only by design.

---

## The Stack

| Layer | Service |
|-------|---------|
| Compute | Cloud Run |
| Image registry | Artifact Registry |
| Secrets | Secret Manager |
| Database | Neon (serverless Postgres, per-PR branching) |
| CI/CD | GitHub Actions |
| Auth (GCP side) | Workload Identity Federation (preferred) or service account key (fallback) |

See `docs/PATTERN-LIBRARY.md` for known pitfalls on this stack.

---

## First-Time Setup

Follow these steps in order. Most of them are one-time and can be
automated (see `scripts/provision-gcp-project.sh`).

### Step 1: Create a GCP Project

```bash
gcloud projects create YOUR_PROJECT_ID --name="Your Project Name"
gcloud config set project YOUR_PROJECT_ID
```

Link it to a billing account:

```bash
gcloud billing projects link YOUR_PROJECT_ID \
  --billing-account=YOUR_BILLING_ACCOUNT_ID
```

Without billing, most GCP APIs will return a 403 with no useful error.

### Step 2: Enable Required APIs

```bash
gcloud services enable \
  run.googleapis.com \
  artifactregistry.googleapis.com \
  secretmanager.googleapis.com \
  iam.googleapis.com \
  iamcredentials.googleapis.com \
  --project=YOUR_PROJECT_ID
```

API enablement is lazy — the first call to each service can take 30-60
seconds to warm up. If you see "API has not been used" errors immediately
after enabling, wait a minute and retry.

### Step 3: Create an Artifact Registry Repository

```bash
gcloud artifacts repositories create agile-flow \
  --repository-format=docker \
  --location=us-central1 \
  --project=YOUR_PROJECT_ID
```

Container images will live at:
`us-central1-docker.pkg.dev/YOUR_PROJECT_ID/agile-flow/agile-flow-app:TAG`

**Do not use `gcr.io` paths.** Container Registry is deprecated and new
projects cannot write to it.

### Step 4: Create a Deployer Service Account

```bash
gcloud iam service-accounts create deployer \
  --display-name="GitHub Actions deployer" \
  --project=YOUR_PROJECT_ID

# Grant permissions to deploy Cloud Run services
gcloud projects add-iam-policy-binding YOUR_PROJECT_ID \
  --member="serviceAccount:deployer@YOUR_PROJECT_ID.iam.gserviceaccount.com" \
  --role="roles/run.admin"

# Grant permission to push images to Artifact Registry
gcloud projects add-iam-policy-binding YOUR_PROJECT_ID \
  --member="serviceAccount:deployer@YOUR_PROJECT_ID.iam.gserviceaccount.com" \
  --role="roles/artifactregistry.writer"

# Grant permission to impersonate the runtime service account
# (Cloud Run needs to run as some identity; default is the Compute SA)
gcloud projects add-iam-policy-binding YOUR_PROJECT_ID \
  --member="serviceAccount:deployer@YOUR_PROJECT_ID.iam.gserviceaccount.com" \
  --role="roles/iam.serviceAccountUser"

# Grant access to read Secret Manager secrets at runtime
gcloud projects add-iam-policy-binding YOUR_PROJECT_ID \
  --member="serviceAccount:deployer@YOUR_PROJECT_ID.iam.gserviceaccount.com" \
  --role="roles/secretmanager.secretAccessor"
```

### How a participant fork "links" to a GCP project

There is no automatic link between a GitHub fork and a GCP project. The
"link" is just **four GitHub Actions secrets** that point the fork's
deploy workflow at the right project. When a participant pushes to
`main` on their fork, `deploy.yml` runs, reads these secrets, and uses
them to authenticate to GCP and deploy to that specific project.

| Secret | Example | Source |
|---|---|---|
| `GCP_PROJECT_ID` | `af-bob-2026-05` | provisioner output |
| `GCP_WORKLOAD_IDENTITY_PROVIDER` | `projects/123456789/locations/global/workloadIdentityPools/github/providers/github` | provisioner output (after Step 5 below) |
| `GCP_SERVICE_ACCOUNT` | `deployer@af-bob-2026-05.iam.gserviceaccount.com` | provisioner output |
| `NEON_API_KEY` | the workshop's shared Neon API key | facilitator |

The first three are *per-participant*; the fourth is shared across the
cohort. The participant pastes them into their fork's
`Settings > Secrets and variables > Actions` panel, and that's the
entire handoff. No shared identity, no project metadata stored in
either system — just secret values.

**End-to-end for one participant (`bob`):**

1. Facilitator runs `provision-workshop-roster.sh` → `af-bob-2026-05` exists with the deployer SA.
2. Facilitator runs the WIF setup in Step 5 below, plugging in `bob-gh/agile-flow-gcp` as the GitHub repo. This creates the trust relationship: "GitHub Actions runs in `bob-gh/agile-flow-gcp` may impersonate `deployer@af-bob-2026-05`."
3. Facilitator emails bob the four secret values. (Template in `agile-flow-meta/docs/workshops/gcp-facilitator-runbook.md` §7.)
4. Bob forks `vibeacademy/agile-flow-gcp` to his account, pastes the four secrets, pushes a trivial change to `main`. The deploy workflow uses WIF to assume the deployer SA and ships the container to bob's project.

**The most common participant footgun:** if bob renames his fork (e.g.
`bob-gh/my-cool-project`), WIF auth fails because the trust binding
names `bob-gh/agile-flow-gcp` exactly. Tell participants in their
day-1 email: do not rename the fork.

As of #5, WIF setup is automatic per-project — the four secrets above
fall out of `provision-gcp-project.sh` Step 5.5 when `GITHUB_USERNAME`
is set. The workshop wrapper exports it automatically per CSV row.
See Step 5 below for details.

---

### Step 5: Set Up Workload Identity Federation (Recommended)

Workload Identity Federation lets GitHub Actions authenticate to GCP
without storing a long-lived service account key. This is the best
practice and should be your default.

**As of `provision-gcp-project.sh` Step 5.5, this is automatic per
project.** Set `GITHUB_USERNAME` and the script creates the pool, the
OIDC provider, and the IAM binding scoped to
`<github_user>/agile-flow-gcp`.

```bash
GCP_PROJECT_ID=af-alice-2026-05 \
BILLING_ACCOUNT_ID=XXX-XXXX-XXXX \
GITHUB_USERNAME=alice-gh \
  ./scripts/provision-gcp-project.sh --create-project
```

The script's "Next steps" output prints the exact `GCP_WORKLOAD_IDENTITY_PROVIDER`
and `GCP_SERVICE_ACCOUNT` values to paste into the participant's fork
secrets — no copying from this doc, no project-number arithmetic.

The workshop wrapper (`provision-workshop-roster.sh`) reads `github_user`
from each `roster.csv` row and exports `GITHUB_USERNAME` automatically,
so a facilitator running the canonical workshop flow never needs to
think about WIF setup at all. The wrapper also records the WIF provider
resource string in `roster-output.csv` per row.

> **Don't rename the fork.** The IAM binding is pinned to
> `<github_user>/agile-flow-gcp` exactly. If a participant renames their
> fork (e.g. `bob-gh/my-cool-project`), WIF auth fails on first deploy
> with a clear error from `google-github-actions/auth`. Tell participants
> in their day-1 email: fork as-is, do not rename.

#### Manual fallback (rarely needed)

If you need to set WIF up by hand — for an out-of-band project, a
non-default repo name without using the `WIF_REPO` env override, or
debugging — the original sequence:

```bash
# Create the pool
gcloud iam workload-identity-pools create github \
  --location="global" \
  --display-name="GitHub Actions" \
  --project=YOUR_PROJECT_ID

# Create the provider (trusts GitHub's OIDC tokens)
gcloud iam workload-identity-pools providers create-oidc github \
  --workload-identity-pool=github \
  --location=global \
  --issuer-uri="https://token.actions.githubusercontent.com" \
  --attribute-mapping="google.subject=assertion.sub,attribute.repository=assertion.repository,attribute.actor=assertion.actor" \
  --attribute-condition="assertion.repository != ''" \
  --project=YOUR_PROJECT_ID

# Get the project number (different from project ID)
PROJECT_NUMBER=$(gcloud projects describe YOUR_PROJECT_ID --format='value(projectNumber)')

# Allow the GitHub repo to impersonate the deployer service account.
# Two roles are required: workloadIdentityUser to authenticate as the SA,
# and serviceAccountTokenCreator to mint access tokens (gcloud, docker push).
for role in roles/iam.workloadIdentityUser roles/iam.serviceAccountTokenCreator; do
  gcloud iam service-accounts add-iam-policy-binding \
    "deployer@YOUR_PROJECT_ID.iam.gserviceaccount.com" \
    --role="$role" \
    --member="principalSet://iam.googleapis.com/projects/${PROJECT_NUMBER}/locations/global/workloadIdentityPools/github/attribute.repository/GITHUB_USER/REPO_NAME" \
    --project=YOUR_PROJECT_ID
done
```

The WIF provider resource name to paste into GitHub secrets is:

```
projects/${PROJECT_NUMBER}/locations/global/workloadIdentityPools/github/providers/github
```

### Step 5 (Alternative): Service Account Key (Workshop Shortcut)

If WIF feels like too much setup for your timeline (e.g., for a workshop),
you can use a service account JSON key instead. This is **not recommended
for production** — the key is a long-lived credential that can be leaked.

```bash
gcloud iam service-accounts keys create deployer-key.json \
  --iam-account="deployer@YOUR_PROJECT_ID.iam.gserviceaccount.com" \
  --project=YOUR_PROJECT_ID
```

Paste the contents of `deployer-key.json` into the GitHub secret
`GCP_SA_KEY`. Delete the local file immediately after.

### Step 6: Create a Neon Account and Project

Sign up at <https://neon.tech>. On the free tier you get one project, 10
branches, 0.5 GB storage, and ~192 compute hours per month — enough for
development and small workshops.

Create a Neon project in the same region as your Cloud Run service (e.g.,
`us-central1` → `us-east-2` is the closest Neon region at the time of
writing; pick the Neon region closest to your Cloud Run region).

From the Neon Console, grab:

- **Project ID** — for the `NEON_PROJECT_ID` secret
- **API key** — Settings → API Keys → create one — for the `NEON_API_KEY` secret
- **Connection string (pooled)** — Dashboard → Connection Details → select
  "Pooled connection" — this is your `DATABASE_URL` for production

### Step 7: Create a Secret Manager Secret for the Database URL

```bash
echo -n "postgresql://user:pass@pooled-host/db" | \
  gcloud secrets create database-url \
    --data-file=- \
    --project=YOUR_PROJECT_ID
```

Use the **pooled** Neon connection string. Cloud Run exhausts direct
connections fast because every revision instance opens its own pool.

### Step 8: Configure GitHub Secrets and Variables

In your GitHub repo settings (Settings → Secrets and variables → Actions):

**Secrets (encrypted, not visible after save):**

| Name | Value |
|------|-------|
| `GCP_PROJECT_ID` | `YOUR_PROJECT_ID` |
| `GCP_WORKLOAD_IDENTITY_PROVIDER` | The full WIF provider path from Step 5 |
| `GCP_SERVICE_ACCOUNT` | `deployer@YOUR_PROJECT_ID.iam.gserviceaccount.com` |
| `GCP_SA_KEY` | (Only if not using WIF — contents of `deployer-key.json`) |
| `NEON_API_KEY` | From Neon Console |
| `NEON_PROJECT_ID` | From Neon Console |

**Variables (plain text, visible):**

| Name | Default | Purpose |
|------|---------|---------|
| `GCP_REGION` | `us-central1` | Cloud Run + Artifact Registry region |
| `ARTIFACT_REPO` | `agile-flow` | Artifact Registry repo name |
| `CLOUD_RUN_SERVICE` | `agile-flow-app` | Cloud Run service name |
| `APP_URL` | (your production URL) | Passed to the container at runtime for self-referential URL construction |
| `NEON_DB_USER` | `neondb_owner` | Neon database role |

### Step 9: First Deploy

Push to `main` (or trigger the `Deploy to Production` workflow manually
via `gh workflow run deploy.yml`). Watch the workflow logs. First deploys
often reveal missing IAM grants — fix and retry.

If the workflow succeeds but the container fails its health check with
"starting but not ready," the most likely cause is a missing
`--host 0.0.0.0` on the uvicorn command in the Dockerfile. See pattern #1 in `docs/PATTERN-LIBRARY.md`.

---

## Workshop: Lifecycle (Setup and Teardown)

When running a workshop, the facilitator's mental model is two commands:

```bash
# Bring up the classroom
BILLING_ACCOUNT_ID=XXXXXX-XXXXXX-XXXXXX \
  ./scripts/workshop-setup.sh roster.csv

# Tear it down at T+1 day
./scripts/workshop-teardown.sh roster.csv          # interactive prompt
./scripts/workshop-teardown.sh roster.csv --yes    # non-interactive
```

The setup script runs four pre-flight checks (gcloud auth, billing
account is OPEN, roster file exists with the expected header, roster
has data rows) and then hands off to the underlying provisioning logic.
Pre-flight failures exit 2 with actionable messages — far better than
discovering a missing auth token mid-loop.

### Roster format

Create `roster.csv` with this exact header:

```csv
handle,github_user,email,cohort
alice,alice-gh,alice@example.com,2026-05
bob,bob-gh,bob@example.com,2026-05
```

- `handle` — short, lowercase, stable identifier; appears in the GCP project ID
- `github_user` — reserved for future use (WIF binding, notification);
  required in the row but not used by the current scripts
- `email` — Google identity granted `roles/editor` on the new project
- `cohort` — `YYYY-MM` of the workshop date; appears in the project ID

Project IDs follow the pattern `af-{handle}-{cohort}`. This shape is
referenced from the facilitator runbook, the participant day-1 doc, and
the dry-run checklist — do not change it. A working example lives at
`scripts/roster.example.csv`.

### Setup behavior

`workshop-setup.sh` is a thin wrapper: after pre-flight passes, it
delegates to `scripts/provision-workshop-roster.sh`. That script:

1. Computes each project ID and checks whether it already exists
2. Calls `provision-gcp-project.sh --create-project` (idempotent)
3. Grants `roles/editor` on the new project to the participant's email
4. Appends a row to `roster-output.csv` with status + project ID

### Idempotency and fail-fast

Re-running setup with the same roster is safe — already-existing
projects are recorded as `skipped` instead of `created`. The wrapper is
fail-fast: if any row fails, the loop stops and exits non-zero. This is
intentional — a half-provisioned classroom is harder to recover from
than a clean stop. Inspect `roster-output.csv`, fix the cause, and
re-run; successful rows are skipped.

### Teardown behavior

`workshop-teardown.sh` reads the same roster, derives the project IDs
(only IDs matching `af-{handle}-{cohort}` from the CSV are touched —
this is a guard against malformed rosters taking down unrelated
projects), and runs `gcloud projects delete` per row.

By default the script prints the list and prompts for confirmation
(`[y/N]`). Pass `--yes` to skip the prompt for non-interactive use.
Idempotent: re-running on already-deleted projects logs `[skip]` rows
and exits 0.

After deletion, `roster-output.csv` is removed (it's stale once
projects are gone). `roster.csv` (input) is preserved.

> **GCP holds project IDs for ~30 days after deletion.** Re-creating
> with the *exact* same project ID during that window will fail with
> `PROJECT_ID_NOT_AVAILABLE`. If you need to reprovision quickly, change
> the `cohort` column in the roster (e.g. `2026-05` → `2026-05a`) so
> new project IDs are generated.

### What the lifecycle scripts do NOT do

- Workload Identity Federation setup — currently manual per project
  (see "Step 5: Workload Identity Federation" above), or track ticket
  [#5](https://github.com/vibeacademy/agile-flow-gcp/issues/5).
- Budget caps — see ticket [#6](https://github.com/vibeacademy/agile-flow-gcp/issues/6).
- Org-policy override for `iam.allowedPolicyMemberDomains` — currently
  manual per project (see [`PATTERN-LIBRARY.md` pattern #30](./PATTERN-LIBRARY.md)),
  or track ticket [#19](https://github.com/vibeacademy/agile-flow-gcp/issues/19).
- Notification emails to participants — facilitator runbook in
  `agile-flow-meta` documents the email template.

### Output and gitignore

`roster.csv` (input) and `roster-output.csv` (output) are both
gitignored. They contain participant emails — never commit either.

---

## Daily Operations

### Viewing Logs

```bash
gcloud logging read 'resource.type="cloud_run_revision" AND resource.labels.service_name="agile-flow-app"' \
  --project=YOUR_PROJECT_ID \
  --limit=50 \
  --format='value(timestamp,textPayload)'
```

### Rolling Back

Cloud Run keeps every revision. To roll back:

```bash
# List recent revisions
gcloud run revisions list \
  --service=agile-flow-app \
  --region=us-central1 \
  --limit=10

# Route 100% of traffic to a specific revision
gcloud run services update-traffic agile-flow-app \
  --region=us-central1 \
  --to-revisions=agile-flow-app-00042-xyz=100
```

### Updating Runtime Secrets

Runtime secrets are mounted from Secret Manager at deploy time. To rotate:

```bash
# Add a new secret version
echo -n "new-value" | gcloud secrets versions add database-url --data-file=-

# Redeploy to pick up the new version
# (The :latest reference resolves at deploy time, not runtime.)
gh workflow run deploy.yml
```

If you need true live rotation without a redeploy, mount the secret as a
file instead of an env var. See `docs/PATTERN-LIBRARY.md`.

### Monitoring Cost

Cloud Run billing is per-request with a generous free tier (2M
requests/month, 360k GB-seconds, 180k vCPU-seconds). For a low-traffic
app, monthly cost is typically under $5.

Set a budget alert in Cloud Console → Billing → Budgets. Alert at 50%
and 90% of your chosen cap.

---

## Switching Away From GCP

This fork is GCP-specific. If you want to target another platform, fork
the upstream `vibeacademy/agile-flow` repo instead — it ships with
Render as the default and documents alternatives for Vercel, Cloudflare,
Railway, and Fly.io.

Do not try to run this template on another platform without removing the
GCP-specific workflows and Dockerfile settings. The `--host 0.0.0.0`
binding is correct for Cloud Run but may need
adjustment on other targets.
