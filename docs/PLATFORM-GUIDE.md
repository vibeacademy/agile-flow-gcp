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

### Step 5: Set Up Workload Identity Federation (Recommended)

Workload Identity Federation lets GitHub Actions authenticate to GCP
without storing a long-lived service account key. This is the best
practice and should be your default.

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
  --attribute-condition="assertion.repository_owner == 'YOUR_GITHUB_ORG'" \
  --project=YOUR_PROJECT_ID

# Get the project number (different from project ID)
PROJECT_NUMBER=$(gcloud projects describe YOUR_PROJECT_ID --format='value(projectNumber)')

# Allow the GitHub repo to impersonate the deployer service account
gcloud iam service-accounts add-iam-policy-binding \
  "deployer@YOUR_PROJECT_ID.iam.gserviceaccount.com" \
  --role="roles/iam.workloadIdentityUser" \
  --member="principalSet://iam.googleapis.com/projects/${PROJECT_NUMBER}/locations/global/workloadIdentityPools/github/attribute.repository/YOUR_GITHUB_ORG/YOUR_REPO" \
  --project=YOUR_PROJECT_ID
```

The WIF provider resource name you need for GitHub secrets is:

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

## Workshop: Provisioning N Projects

When running a workshop, the facilitator provisions one GCP project per
participant. `scripts/provision-workshop-roster.sh` wraps
`provision-gcp-project.sh` in a CSV-driven loop so all participant
projects can be created with one command.

### Roster format

Create `roster.csv` with this exact header:

```csv
handle,github_user,email,cohort
alice,alice-gh,alice@example.com,2026-05
bob,bob-gh,bob@example.com,2026-05
```

- `handle` — short, lowercase, stable identifier; appears in the GCP project ID
- `github_user` — reserved for future tickets (WIF binding, notification);
  required in the row but not used by this script
- `email` — Google identity granted `roles/editor` on the new project
- `cohort` — `YYYY-MM` of the workshop date; appears in the project ID

Project IDs follow the pattern `af-{handle}-{cohort}`. This shape is
referenced from the facilitator runbook, the participant day-1 doc, and
the dry-run checklist — do not change it.

A working example lives at `scripts/roster.example.csv`.

### Running the wrapper

```bash
BILLING_ACCOUNT_ID=XXXXXX-XXXXXX-XXXXXX \
  ./scripts/provision-workshop-roster.sh roster.csv
```

For each row the wrapper:

1. Computes the project ID and checks whether it already exists
2. Calls `provision-gcp-project.sh --create-project` (idempotent)
3. Grants `roles/editor` on the new project to the participant's email
4. Appends a row to `roster-output.csv` with status + project ID

### Idempotency and fail-fast

Re-running the script with the same `roster.csv` is safe — already-existing
projects are recorded as `skipped` instead of `created`.

The wrapper is fail-fast: if any row fails, the loop stops and exits
non-zero. This is intentional — a half-provisioned classroom is harder
to recover from than a clean stop. Inspect the failing row in
`roster-output.csv`, fix the cause, and re-run. Successful rows from the
prior run will be skipped on the retry.

### What this does NOT do

- Workload Identity Federation setup is intentionally out of scope. Either
  set it up manually per project (see "Step 5: Workload Identity Federation"
  above), or wait for ticket [#5](https://github.com/vibeacademy/agile-flow-gcp/issues/5) to land.
- Budget caps are not configured here. See ticket [#6](https://github.com/vibeacademy/agile-flow-gcp/issues/6).
- Notification emails to participants are not sent. The facilitator runbook
  in `agile-flow-meta` documents the email template.

### Output and gitignore

`roster.csv` (input) and `roster-output.csv` (output) are both gitignored.
They contain participant emails — never commit either.

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
