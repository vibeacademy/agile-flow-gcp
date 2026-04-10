# Pattern Library: GCP Cloud Run + Neon + GitHub Stack

> Canonical reference for agents and workshop participants. Each pattern documents
> the **correct** way to solve a known problem, the **gotcha** that causes it, and
> **sample code** that works.

---

## Table of Contents

### Cloud Run

1. [Cloud Run: HOSTNAME Must Be 0.0.0.0](#1-cloud-run-hostname-must-be-0000)
2. [Cloud Run: NEXT_PUBLIC_* Vars Are Baked at Build Time](#2-cloud-run-next_public_-vars-are-baked-at-build-time)
3. [Cloud Run: Env Var Updates Create a New Revision](#3-cloud-run-env-var-updates-create-a-new-revision)
4. [Cloud Run: Reverse Proxy Headers for Redirects](#4-cloud-run-reverse-proxy-headers-for-redirects)
5. [Cloud Run: Secret Manager Env Mount vs File Mount](#5-cloud-run-secret-manager-env-mount-vs-file-mount)
6. [Cloud Run: Scale-to-Zero Cold Starts](#6-cloud-run-scale-to-zero-cold-starts)
7. [Cloud Run: Artifact Registry Path, Not gcr.io](#7-cloud-run-artifact-registry-path-not-gcrio)
8. [Cloud Run: Revision Tagging for PR Previews](#8-cloud-run-revision-tagging-for-pr-previews)

### Neon

9. [Neon: Use the Pooled Connection String from Serverless](#9-neon-use-the-pooled-connection-string-from-serverless)
10. [Neon: Compute Wakes Up on First Query](#10-neon-compute-wakes-up-on-first-query)
11. [Neon: Region Must Match Cloud Run Region](#11-neon-region-must-match-cloud-run-region)
12. [Neon: Per-PR Branches Via create-branch-action](#12-neon-per-pr-branches-via-create-branch-action)

### GCP IAM and Auth

13. [Workload Identity Federation vs Service Account Keys](#13-workload-identity-federation-vs-service-account-keys)
14. [GCP: iam.serviceAccountUser Is Required to Deploy to Cloud Run](#14-gcp-iamserviceaccountuser-is-required-to-deploy-to-cloud-run)

### GitHub Actions

15. [GitHub Actions: hashFiles() Scope Limitation](#15-github-actions-hashfiles-scope-limitation)
16. [GitHub Actions: Graceful Secret Gating](#16-github-actions-graceful-secret-gating)
17. [GitHub Actions: CI Checks Not Attaching to PR](#17-github-actions-ci-checks-not-attaching-to-pr)
18. [GitHub Actions: Reusable Workflow Missing workflow_call](#18-github-actions-reusable-workflow-missing-workflow_call)

### GitHub Platform

19. [GitHub Projects: Labels vs Board Columns](#19-github-projects-labels-vs-board-columns)
20. [GitHub Projects: CLI Truncation at 30 Items](#20-github-projects-cli-truncation-at-30-items)
21. [GitHub: Account Switching for Multi-Agent Workflows](#21-github-account-switching-for-multi-agent-workflows)
22. [GitHub MCP Server vs gh CLI for Agent Workflows](#22-github-mcp-server-vs-gh-cli-for-agent-workflows)

### App Code

23. [Server-Side URLs: Never Hardcode Origins](#23-server-side-urls-never-hardcode-origins)
24. [Next.js Standalone Output Is Required](#24-nextjs-standalone-output-is-required)

---

## 1. Cloud Run: HOSTNAME Must Be 0.0.0.0

**Gotcha:** Next.js binds to `localhost` by default. Cloud Run routes requests
via a proxy that cannot reach `localhost`, so the container passes its own
startup checks but fails the platform health check with "container started but
did not listen on the configured port." There is no useful error message —
just a failed deploy and an unreachable service.

**Pattern:** Set `HOSTNAME=0.0.0.0` in the Dockerfile runner stage. Next.js's
standalone `server.js` honors this environment variable.

```dockerfile
FROM node:20-alpine AS runner
ENV NODE_ENV=production
ENV PORT=8080
ENV HOSTNAME=0.0.0.0

COPY --from=builder --chown=nextjs:nodejs /app/.next/standalone ./
COPY --from=builder --chown=nextjs:nodejs /app/.next/static ./.next/static
COPY --from=builder --chown=nextjs:nodejs /app/public ./public

CMD ["node", "server.js"]
```

This gotcha is the #1 cause of "it works on my machine" Cloud Run deploy
failures. Local `docker run -p 8080:8080` works because you published the
port, masking the bind address issue.

---

## 2. Cloud Run: NEXT_PUBLIC_* Vars Are Baked at Build Time

**Gotcha:** Next.js inlines any env var prefixed with `NEXT_PUBLIC_` into the
client JavaScript bundle during `next build`. Setting these vars at Cloud Run
deploy time has **no effect** on the client code — the browser reads whatever
was present at build time. No error is thrown; the value silently becomes an
empty string or whatever the build-time default was.

**Wrong:**

```bash
gcloud run deploy my-app \
  --set-env-vars=NEXT_PUBLIC_APP_URL=https://myapp.com  # Has no client effect
```

**Pattern:** Pass `NEXT_PUBLIC_*` vars to `docker build --build-arg`:

```dockerfile
FROM node:20-alpine AS builder
ARG NEXT_PUBLIC_APP_URL
ENV NEXT_PUBLIC_APP_URL=$NEXT_PUBLIC_APP_URL
RUN npm run build
```

```bash
docker build \
  --build-arg NEXT_PUBLIC_APP_URL=https://myapp.com \
  -t $IMAGE \
  .
```

**Server-only vars** (no `NEXT_PUBLIC_` prefix) are read at runtime and work
fine with `--set-env-vars`. Use this distinction to decide where each var
goes.

**Alternative:** For per-PR preview builds where the URL changes every time,
you'd either rebuild the image per PR or use runtime config (via
`getServerSideProps`, route handlers, or a `/api/config` endpoint the client
fetches on startup). This template rebuilds per PR.

---

## 3. Cloud Run: Env Var Updates Create a New Revision

**Gotcha:** Updating env vars via `gcloud run services update
--update-env-vars=KEY=VALUE` creates a new revision and routes traffic to
it. Updating via the Cloud Console without clicking "Deploy" stages the
change but **never applies it**. The Console shows the new value; the
running container keeps the old one. There is no visual indicator that the
change is pending.

**Pattern:** Always update via CLI or always verify with describe after a
Console edit:

```bash
gcloud run services update my-app \
  --region=us-central1 \
  --update-env-vars=LOG_LEVEL=debug

# Verify the new revision is serving
gcloud run services describe my-app \
  --region=us-central1 \
  --format='value(status.latestReadyRevisionName,status.traffic[0].revisionName)'
```

The two revision names should match. If not, the latest revision exists but
isn't receiving traffic.

---

## 4. Cloud Run: Reverse Proxy Headers for Redirects

**Gotcha:** Cloud Run sits behind a Google-managed proxy. Server-side code
that reads `request.url` or constructs URLs via `new URL(path, request.url)`
gets the internal Cloud Run origin, not the public URL your users see. This
silently breaks redirects, magic link callbacks, and anything that
constructs absolute URLs server-side. It works correctly in local dev, so
you only notice it on deploy.

**Pattern:** Read forwarded headers to construct the external origin.

```typescript
// app/api/redirect/route.ts
export async function GET(request: Request) {
  const headers = request.headers;

  const proto = headers.get('x-forwarded-proto') ?? 'https';
  const host = headers.get('x-forwarded-host') ?? headers.get('host');

  if (!host) {
    return new Response('Missing host header', { status: 400 });
  }

  const origin = `${proto}://${host}`;
  return Response.redirect(`${origin}/dashboard`, 302);
}
```

For Next.js middleware, use `request.nextUrl` — it handles this correctly
for you. The gotcha is specifically about Route Handlers and custom
redirects.

---

## 5. Cloud Run: Secret Manager Env Mount vs File Mount

**Gotcha:** Cloud Run can mount secrets two ways: as environment variables
(`--set-secrets=FOO=foo:latest`) or as files (`--set-secrets=/mnt/foo=foo:latest`).
Env var mounts capture the secret value at deploy time. Rotating the
underlying secret does NOT update the running revision — you have to
redeploy. File mounts read the secret on each access, so rotation works
without redeploy.

**Pattern (env var, for static secrets):**

```bash
gcloud run deploy my-app \
  --set-secrets=DATABASE_URL=database-url:latest
```

Use this for secrets that don't rotate often. Simpler to read in app code
(`process.env.DATABASE_URL`).

**Pattern (file mount, for rotating secrets):**

```bash
gcloud run deploy my-app \
  --set-secrets=/secrets/api-key=api-key:latest
```

Your app reads the file on each use:

```typescript
import { readFileSync } from 'fs';

function getApiKey(): string {
  return readFileSync('/secrets/api-key', 'utf-8').trim();
}
```

The file is refreshed automatically when a new secret version is added.

---

## 6. Cloud Run: Scale-to-Zero Cold Starts

**Gotcha:** With `--min-instances=0` (the default), Cloud Run scales the
service down to zero instances after a few minutes of idle. The first
request after scale-down takes 2-5 seconds while a new container starts.
For a latency-sensitive endpoint, this looks like "the site is randomly
slow once a day."

**Patterns by use case:**

- **Development/workshop apps:** `--min-instances=0`. Cost is near zero.
  Accept cold starts.
- **Production apps with SLA:** `--min-instances=1`. Costs ~$5-10/month for
  one always-on instance but eliminates cold starts.
- **Bursty production traffic:** `--min-instances=1 --max-instances=10`.
  Warm baseline + elastic scale-up.

```bash
gcloud run deploy my-app \
  --min-instances=1 \
  --max-instances=10 \
  --memory=512Mi \
  --cpu=1
```

**CPU allocation:** By default, Cloud Run only allocates CPU during request
processing. For background work (cron handlers, WebSocket servers), add
`--cpu-boost` or `--no-cpu-throttling` so the container stays active.

---

## 7. Cloud Run: Artifact Registry Path, Not gcr.io

**Gotcha:** Older GCP docs reference `gcr.io/PROJECT/image` for container
images. Container Registry is deprecated and new projects cannot create
`gcr.io` repos. An image pushed to `gcr.io` will work for a while, then
silently stop pulling once the deprecation window closes. The
replacement is Artifact Registry at `REGION-docker.pkg.dev`.

**Pattern:** Always use the full Artifact Registry path.

```bash
# Correct (Artifact Registry)
us-central1-docker.pkg.dev/myproject/myrepo/my-app:abc1234

# Wrong (deprecated Container Registry)
gcr.io/myproject/my-app:abc1234
```

Setup:

```bash
# Create the repo (once per project)
gcloud artifacts repositories create myrepo \
  --repository-format=docker \
  --location=us-central1

# Configure docker to auth against it
gcloud auth configure-docker us-central1-docker.pkg.dev
```

---

## 8. Cloud Run: Revision Tagging for PR Previews

**Gotcha:** A naive PR preview approach creates a new Cloud Run service per
PR (`my-app-pr-42`). This proliferates services, consumes the 1000-per-region
quota, and makes cleanup tedious. It also means every PR needs its own IAM
setup, secret mounts, and Artifact Registry tags.

**Pattern:** Deploy each PR as a tagged revision of the **same** service
with `--no-traffic`. The tag gives you a stable preview URL without
routing production traffic.

```bash
gcloud run deploy my-app \
  --image=$IMAGE \
  --region=us-central1 \
  --tag=pr-42 \
  --no-traffic \
  --update-env-vars="DATABASE_URL=${NEON_BRANCH_URL}"
```

Cloud Run generates a preview URL in the format:

```
https://pr-42---my-app-xyz123.us-central1.run.app
```

The `---` separator is literal. The tag URL is stable for the life of the
revision tag.

**Cleanup:**

```bash
gcloud run services update-traffic my-app \
  --region=us-central1 \
  --remove-tags=pr-42
```

The revision itself stays in the revision history but receives no traffic
and costs nothing on scale-to-zero.

---

## 9. Neon: Use the Pooled Connection String from Serverless

**Gotcha:** Neon gives you two connection strings per branch: a direct
connection and a pooled connection (via PgBouncer). From a serverless
runtime like Cloud Run, every container instance opens its own connection
pool. With the direct connection, you exhaust Neon's connection limit fast
under even modest load — queries start failing with
`remaining connection slots are reserved`.

**Pattern:** Always use the **pooled** connection string from Cloud Run:

```
postgresql://user:pass@ep-xxx-pooler.region.aws.neon.tech/dbname
                        ^^^^^^^ "-pooler" suffix marks the pooled endpoint
```

Neon's `create-branch-action` exposes both URLs as outputs:

```yaml
- name: Create Neon branch
  id: neon
  uses: neondatabase/create-branch-action@v5
  with:
    project_id: ${{ secrets.NEON_PROJECT_ID }}
    branch_name: pr-${{ github.event.pull_request.number }}
    api_key: ${{ secrets.NEON_API_KEY }}

- name: Use pooled URL
  run: |
    echo "POOLED: ${{ steps.neon.outputs.db_url_pooled }}"
    echo "DIRECT: ${{ steps.neon.outputs.db_url }}"
```

Pass `db_url_pooled` to Cloud Run, not `db_url`.

**Exception:** If you're running long-lived migrations or a single
background worker with `--min-instances=1`, the direct connection is fine
and gives you session-level features PgBouncer transaction-pooling mode
doesn't support (e.g., `LISTEN/NOTIFY`, `SET SESSION`).

---

## 10. Neon: Compute Wakes Up on First Query

**Gotcha:** Neon's compute endpoint scales to zero after ~5 minutes of
inactivity. The first query after suspend takes 500ms-2s while the compute
instance wakes up. If your app uses a short connection timeout (e.g., 1s),
that first query fails outright with a connection error. From Cloud Run,
the symptom looks like "my app is randomly broken the first time I load it
each day."

**Pattern:** Use a generous connection timeout and retry on connection
errors at the app layer.

```typescript
import { Pool } from 'pg';

const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
  connectionTimeoutMillis: 10_000,  // Generous wakeup budget
  idleTimeoutMillis: 30_000,
  max: 5,  // Small pool; Cloud Run instances are short-lived
});
```

**Alternative:** Disable autosuspend on the main branch by setting the
compute endpoint to never suspend. Costs more ($5-10/month for the
always-on compute) but eliminates the wakeup latency. For PR branches,
keep autosuspend on — previews are fine with cold starts.

**Keep-alive hack (workshop-acceptable, not for prod):** Set up a Cloud
Scheduler job to hit the main branch every 4 minutes. Keeps compute warm
for pennies. Don't do this for PR branches or you'll rack up compute hours.

---

## 11. Neon: Region Must Match Cloud Run Region

**Gotcha:** Neon runs in AWS or GCP regions. If your Cloud Run service is
in `us-central1` and your Neon project is in `us-east-1`, every query
crosses the US with ~30ms latency. For a single query that's tolerable,
but a request that makes 10 DB calls adds 300ms of pure network overhead.

**Pattern:** Create the Neon project in the region closest to your Cloud
Run service. For `us-central1` Cloud Run, use Neon's `aws-us-east-2`
(the closest available). For `europe-west1`, use Neon's `aws-eu-central-1`.

Neon's region list is at <https://neon.tech/docs/introduction/regions>.

**Verification:**

```bash
# From a Cloud Run container or a local machine in the same region:
time curl -o /dev/null -s $NEON_HOST

# Should be well under 50ms. Over 100ms = wrong region.
```

---

## 12. Neon: Per-PR Branches Via create-branch-action

**Gotcha:** Manually creating and destroying Neon branches in CI is error
prone — you have to wire up the Neon CLI, handle branch name collisions,
delete branches on PR close, and handle the case where the action runs
twice on the same PR. The action handles all of this.

**Pattern:**

```yaml
# .github/workflows/preview-deploy.yml
- name: Create Neon branch
  id: neon
  if: secrets.NEON_API_KEY != ''
  uses: neondatabase/create-branch-action@v5
  with:
    project_id: ${{ secrets.NEON_PROJECT_ID }}
    branch_name: pr-${{ github.event.pull_request.number }}
    parent: main
    username: neondb_owner
    api_key: ${{ secrets.NEON_API_KEY }}

# Output: steps.neon.outputs.db_url_pooled
```

```yaml
# .github/workflows/preview-cleanup.yml
- name: Delete Neon branch
  if: secrets.NEON_API_KEY != ''
  uses: neondatabase/delete-branch-action@v3
  continue-on-error: true  # PR may have been closed without a branch
  with:
    project_id: ${{ secrets.NEON_PROJECT_ID }}
    branch: pr-${{ github.event.number }}
    api_key: ${{ secrets.NEON_API_KEY }}
```

`continue-on-error: true` on the cleanup handles the case where the branch
was never created (e.g., PR opened before Neon was configured). The action
is idempotent — calling it twice on the same branch is safe.

---

## 13. Workload Identity Federation vs Service Account Keys

**Gotcha:** GitHub Actions needs to authenticate to GCP. The obvious approach
is to create a service account JSON key, store it as `GCP_SA_KEY`, and use
`google-github-actions/auth` with `credentials_json`. This works, but the
key is a long-lived credential that can be leaked. Workload Identity
Federation (WIF) lets GitHub trade its short-lived OIDC token for GCP
credentials, with no long-lived secret stored anywhere.

**Pattern (preferred — WIF):**

```yaml
- uses: google-github-actions/auth@v2
  with:
    workload_identity_provider: projects/NUM/locations/global/workloadIdentityPools/github/providers/github
    service_account: deployer@PROJECT.iam.gserviceaccount.com
```

Setup (one-time, see `docs/PLATFORM-GUIDE.md` Step 5 for full details):

```bash
gcloud iam workload-identity-pools create github --location=global
gcloud iam workload-identity-pools providers create-oidc github \
  --workload-identity-pool=github \
  --location=global \
  --issuer-uri="https://token.actions.githubusercontent.com" \
  --attribute-mapping="google.subject=assertion.sub,attribute.repository=assertion.repository"

# Bind the GitHub repo to the service account
gcloud iam service-accounts add-iam-policy-binding deployer@PROJECT.iam.gserviceaccount.com \
  --role=roles/iam.workloadIdentityUser \
  --member=principalSet://iam.googleapis.com/projects/NUM/locations/global/workloadIdentityPools/github/attribute.repository/ORG/REPO
```

**Pattern (fallback — SA key, workshop only):**

```yaml
- uses: google-github-actions/auth@v2
  with:
    credentials_json: ${{ secrets.GCP_SA_KEY }}
```

Acceptable when you need to move fast (e.g., a workshop) and the blast
radius of a leaked key is limited to a single throwaway project. Not
recommended for production.

**This template's workflows support both.** Set `GCP_WORKLOAD_IDENTITY_PROVIDER`
to use WIF; set `GCP_SA_KEY` to use the fallback.

---

## 14. GCP: iam.serviceAccountUser Is Required to Deploy to Cloud Run

**Gotcha:** Cloud Run services run **as** a service account (the runtime
identity). When you `gcloud run deploy`, the deployer identity needs
permission to **impersonate** the runtime identity — otherwise you get a
cryptic `PERMISSION_DENIED: Permission 'iam.serviceaccounts.actAs' denied`
error.

**Pattern:** Grant the deployer service account the `roles/iam.serviceAccountUser`
role on itself (if runtime and deployer are the same SA) or on the runtime
SA:

```bash
gcloud projects add-iam-policy-binding YOUR_PROJECT_ID \
  --member="serviceAccount:deployer@YOUR_PROJECT_ID.iam.gserviceaccount.com" \
  --role="roles/iam.serviceAccountUser"
```

This is easy to miss because the deployer may have `roles/run.admin` and
everything else it needs, and the error message doesn't name the missing
role clearly. If your first deploy fails with an `actAs` error, this is
almost always the fix.

---

## 15. GitHub Actions: hashFiles() Scope Limitation

**Gotcha:** The `hashFiles()` function in GitHub Actions only sees files in
the workspace. Using it in a workflow that runs before checkout (e.g., to
decide whether to skip a step) returns an empty string, which hashes to a
constant. This can make conditional caching silently broken.

**Pattern:** Always run `actions/checkout` before any `hashFiles()` call
that needs to see source files.

```yaml
jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4  # Must come first

      - uses: actions/cache@v4
        with:
          path: node_modules
          key: ${{ runner.os }}-node-${{ hashFiles('package-lock.json') }}
```

If you need to compute a hash before checkout, use a different strategy
(e.g., use the commit SHA as the cache key).

---

## 16. GitHub Actions: Graceful Secret Gating

**Gotcha:** A workflow that hard-requires a secret will fail on any fork or
downstream repo that hasn't configured it. For a template repo, this means
every fresh clone gets a red "X" on the first commit. The fix is to gate
steps on secret presence and gracefully skip.

**Pattern:**

```yaml
jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - name: Check for required secrets
        id: check_secrets
        run: |
          if [ -z "${{ secrets.GCP_PROJECT_ID }}" ]; then
            echo "skip=true" >> "$GITHUB_OUTPUT"
            echo "GCP_PROJECT_ID not configured — skipping deployment."
          else
            echo "skip=false" >> "$GITHUB_OUTPUT"
          fi

      - name: Deploy
        if: steps.check_secrets.outputs.skip != 'true'
        run: gcloud run deploy ...
```

The workflow "passes" when secrets are missing, logging a clear skip
reason. This keeps the template green out of the box.

---

## 17. GitHub Actions: CI Checks Not Attaching to PR

**Gotcha:** Workflows triggered only by `push:` don't attach their check
runs to PRs from forks or other branches. The PR shows "no status checks"
and branch protection rules that require CI to pass will block the PR
indefinitely.

**Pattern:** Trigger on both `push:` and `pull_request:`:

```yaml
on:
  push:
    branches: [main]
  pull_request:
    branches: [main]
```

The `pull_request` event attaches the check run to the PR, even if the PR
is from a fork. Combine with `workflow_call:` if another workflow invokes
this one (see pattern 18).

---

## 18. GitHub Actions: Reusable Workflow Missing workflow_call

**Gotcha:** When one workflow calls another via `uses: ./.github/workflows/ci.yml`,
the called workflow must have `workflow_call:` in its `on:` block. Without
it, GitHub silently shows "0 jobs" with a vague "could not find workflow"
error. The caller workflow runs, doesn't execute any steps, reports success.
This can go undetected for weeks.

**Pattern:**

```yaml
# ci.yml — the reusable workflow
on:
  push:
    branches: [main]
  pull_request:
    branches: [main]
  workflow_call:  # REQUIRED for other workflows to invoke this
```

```yaml
# preview-deploy.yml — the caller
jobs:
  ci:
    uses: ./.github/workflows/ci.yml
```

If you see "0 jobs" in a workflow run, check that the called workflow has
`workflow_call:` in its triggers.

---

## 19. GitHub Projects: Labels vs Board Columns

**Gotcha:** Labels and board columns look similar but are tracked differently.
A ticket can have the `ready` label but still be in the `Backlog` column —
or vice versa. Agents that filter by label will get a different list than
agents that filter by column.

**Pattern:** For board workflow, **always** filter by the column (Status
field), not by label. Labels are free-form metadata; columns are workflow
state.

```bash
# Correct: filter by board column
gh project item-list 13 --owner myorg --format json \
  | jq '.items[] | select(.status == "Ready")'

# Wrong: filter by label (may include items in other columns)
gh issue list --label ready
```

Use labels for classification (priority, type, area) and columns for
workflow state.

---

## 20. GitHub Projects: CLI Truncation at 30 Items

**Gotcha:** `gh project item-list` returns at most 30 items by default.
For any board with more than 30 tickets, you silently miss the tail. This
breaks grooming scripts, prioritization passes, and milestone checks.

**Pattern:** Always pass `--limit` explicitly.

```bash
gh project item-list 13 --owner myorg --format json --limit 200
```

Pick a limit higher than you expect the board to grow. 200 is usually
safe for a team-scale board. If you're managing a larger backlog, paginate.

---

## 21. GitHub: Account Switching for Multi-Agent Workflows

**Gotcha:** When multiple agents share one machine (worker bot, reviewer
bot, human operator), `gh` uses whichever account was active last.
Worker-created PRs may accidentally come from the reviewer account (if it
was last active), corrupting the audit trail.

**Pattern:** The `.claude/hooks/ensure-github-account.sh` hook
auto-switches accounts before PR operations. Never rely on manual account
management.

See `.claude/README.md` for the full account separation model.

---

## 22. GitHub MCP Server vs gh CLI for Agent Workflows

**Gotcha:** The GitHub MCP server is convenient for simple queries but
does not cleanly support account switching. For multi-agent workflows that
require the worker and reviewer to operate as different identities, the
MCP server gets stuck on whichever token it was initialized with.

**Pattern:** This template uses the `gh` CLI for all GitHub operations.
The `.claude/hooks/ensure-github-account.sh` hook switches accounts before
PR-creating or PR-reviewing commands. If you want to use the MCP server
for read-only queries, fine — but PR creation, review, and merge must go
through `gh`.

---

## 23. Server-Side URLs: Never Hardcode Origins

**Gotcha:** Hardcoding `https://myapp.com` in server code breaks preview
environments. Every PR preview has a different URL, and the code still
redirects to production, leaks production URLs into emails, or fails
CORS checks. This is the single most common preview-environment breakage.

**Pattern:**

```typescript
// Client-side: use window.location
const origin = window.location.origin;

// Server-side (Next.js route handler): read from forwarded headers
export async function GET(request: Request) {
  const proto = request.headers.get('x-forwarded-proto') ?? 'https';
  const host = request.headers.get('x-forwarded-host') ?? request.headers.get('host');
  const origin = `${proto}://${host}`;
  // ... use `origin` for redirects, absolute URLs, email links
}
```

Never store the production URL in code or in a `NEXT_PUBLIC_*` variable
if it's used for redirects. The whole point of preview environments is
that they behave like production — including URL construction.

---

## 24. Next.js Standalone Output Is Required

**Gotcha:** The default `next build` output assumes you have the full
`node_modules` directory at runtime. Copying `node_modules` into a Cloud
Run container bloats the image to 1 GB+ and slows cold starts
dramatically. The `output: 'standalone'` build mode produces a pruned,
self-contained directory with only the files needed to run the server.

**Pattern:**

```typescript
// next.config.ts
import type { NextConfig } from 'next';

const nextConfig: NextConfig = {
  output: 'standalone',
};

export default nextConfig;
```

Dockerfile runner stage copies only the standalone output + static
assets + public dir:

```dockerfile
COPY --from=builder --chown=nextjs:nodejs /app/.next/standalone ./
COPY --from=builder --chown=nextjs:nodejs /app/.next/static ./.next/static
COPY --from=builder --chown=nextjs:nodejs /app/public ./public

CMD ["node", "server.js"]
```

**Note:** With standalone, the entry point is `node server.js`, NOT
`next start`. The `next` binary is not in the standalone bundle. If your
Dockerfile has `CMD ["npm", "start"]`, it will fail with "next: command
not found."

Typical image size with standalone: ~150 MB. Without: ~1 GB. The cold
start time difference alone is worth the switch.
