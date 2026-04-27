# Pattern Library: GCP Cloud Run + Neon + FastAPI Stack

> Canonical reference for agents and workshop participants. Each pattern documents
> the **correct** way to solve a known problem, the **gotcha** that causes it, and
> **sample code** that works.

---

## Table of Contents

### Cloud Run

1. [Cloud Run: Bind Uvicorn to 0.0.0.0](#1-cloud-run-bind-uvicorn-to-0000)
2. [Cloud Run: Env Vars Are Runtime, Not Build-Time](#2-cloud-run-env-vars-are-runtime-not-build-time)
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

### FastAPI / Python

15. [FastAPI: Run Alembic Before Deploying a Schema Change](#15-fastapi-run-alembic-before-deploying-a-schema-change)
16. [SQLModel: Use Column Strings for order_by to Satisfy mypy](#16-sqlmodel-use-column-strings-for-order_by-to-satisfy-mypy)
17. [SQLModel: Small Connection Pool on Cloud Run](#17-sqlmodel-small-connection-pool-on-cloud-run)
18. [HTMX: Return Fragments, Not Full Pages](#18-htmx-return-fragments-not-full-pages)
19. [HTMX: hx-target and hx-swap Must Match Your Response Shape](#19-htmx-hx-target-and-hx-swap-must-match-your-response-shape)

### GitHub Actions

20. [GitHub Actions: hashFiles() Scope Limitation](#20-github-actions-hashfiles-scope-limitation)
21. [GitHub Actions: Graceful Secret Gating](#21-github-actions-graceful-secret-gating)
22. [GitHub Actions: CI Checks Not Attaching to PR](#22-github-actions-ci-checks-not-attaching-to-pr)
23. [GitHub Actions: Reusable Workflow Missing workflow_call](#23-github-actions-reusable-workflow-missing-workflow_call)

### GitHub Platform

24. [GitHub Projects: Labels vs Board Columns](#24-github-projects-labels-vs-board-columns)
25. [GitHub Projects: CLI Truncation at 30 Items](#25-github-projects-cli-truncation-at-30-items)
26. [GitHub: Account Switching for Multi-Agent Workflows](#26-github-account-switching-for-multi-agent-workflows)
27. [GitHub MCP Server vs gh CLI for Agent Workflows](#27-github-mcp-server-vs-gh-cli-for-agent-workflows)

### App Code

28. [Server-Side URLs: Never Hardcode Origins](#28-server-side-urls-never-hardcode-origins)

### Workshop Operations

29. [Workshop: Participant Email Must Match Their Google Identity](#29-workshop-participant-email-must-match-their-google-identity)
30. [Workshop: Domain-Restricted Sharing Blocks External-Email IAM Bindings](#30-workshop-domain-restricted-sharing-blocks-external-email-iam-bindings)

---

## 1. Cloud Run: Bind Uvicorn to 0.0.0.0

**Gotcha:** Uvicorn binds to `127.0.0.1` (localhost) by default. Cloud Run
routes requests via a proxy that cannot reach localhost, so the container
passes its own startup checks but fails the platform health check with
"container started but did not listen on the configured port." There is
no useful error message — just a failed deploy and an unreachable service.

**Pattern:** Always pass `--host 0.0.0.0` to uvicorn.

```dockerfile
CMD ["uv", "run", "--no-sync", "uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8080"]
```

This gotcha is the #1 cause of "it works on my machine" Cloud Run deploy
failures. Local `docker run -p 8080:8080` works because you published the
port, masking the bind address issue.

---

## 2. Cloud Run: Env Vars Are Runtime, Not Build-Time

**Gotcha:** Developers coming from Next.js or other build-time-heavy
frameworks expect env vars to be "baked in" at build. FastAPI reads env
vars at runtime via `os.environ` or `pydantic_settings.BaseSettings`, so
you should **never** pass secrets or configuration via `docker build
--build-arg`. Use `gcloud run deploy --set-env-vars` or mount Secret
Manager secrets.

**Pattern:** Define config in `app/config.py` using pydantic-settings:

```python
from functools import lru_cache
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    database_url: str = "sqlite:///./dev.db"
    app_url: str = "http://localhost:8080"
    environment: str = "development"

    model_config = SettingsConfigDict(env_file=".env", extra="ignore")


@lru_cache
def get_settings() -> Settings:
    return Settings()
```

Deploy with runtime env vars:

```bash
gcloud run deploy my-app \
  --image=$IMAGE \
  --set-env-vars="ENVIRONMENT=production" \
  --set-secrets="DATABASE_URL=database-url:latest"
```

This is genuinely simpler than the Next.js `NEXT_PUBLIC_*` build-time
baking problem — there's no distinction between "client vars" and
"server vars" because FastAPI is server-only. If you add a frontend, its
env vars are your problem, not FastAPI's.

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
that reads `request.url.hostname` or constructs URLs from
`request.base_url` gets the internal Cloud Run origin, not the public URL
your users see. This silently breaks redirects, magic link callbacks, and
anything that constructs absolute URLs server-side. It works correctly in
local dev, so you only notice it on deploy.

**Pattern:** Read `X-Forwarded-Proto` and `X-Forwarded-Host` in FastAPI
route handlers.

```python
from fastapi import FastAPI, Request
from fastapi.responses import RedirectResponse

app = FastAPI()


@app.get("/login")
async def login(request: Request) -> RedirectResponse:
    proto = request.headers.get("x-forwarded-proto", "https")
    host = request.headers.get("x-forwarded-host") or request.headers.get("host")
    if not host:
        return RedirectResponse("/error?reason=missing-host")
    external_origin = f"{proto}://{host}"
    return RedirectResponse(f"{external_origin}/dashboard")
```

**Alternative:** Run uvicorn with `--proxy-headers` and `--forwarded-allow-ips="*"`
so `request.url` is automatically rewritten. Safe on Cloud Run because
the only thing in front of your container is Google's trusted proxy.

```dockerfile
CMD ["uv", "run", "--no-sync", "uvicorn", "app.main:app", \
     "--host", "0.0.0.0", "--port", "8080", \
     "--proxy-headers", "--forwarded-allow-ips=*"]
```

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
(`os.environ["DATABASE_URL"]` or via pydantic-settings).

**Pattern (file mount, for rotating secrets):**

```bash
gcloud run deploy my-app \
  --set-secrets=/secrets/api-key=api-key:latest
```

Your app reads the file on each use:

```python
from pathlib import Path


def get_api_key() -> str:
    return Path("/secrets/api-key").read_text().strip()
```

The file is refreshed automatically when a new secret version is added.

---

## 6. Cloud Run: Scale-to-Zero Cold Starts

**Gotcha:** With `--min-instances=0` (the default), Cloud Run scales the
service down to zero instances after a few minutes of idle. The first
request after scale-down takes 1-3 seconds while a new container starts
(Python containers are typically faster than Node.js containers).

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
processing. For background work (cron handlers, long-running async tasks),
add `--cpu-boost` or `--no-cpu-throttling` so the container stays active.

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
gcloud artifacts repositories create myrepo \
  --repository-format=docker \
  --location=us-central1

gcloud auth configure-docker us-central1-docker.pkg.dev
```

---

## 8. Cloud Run: Revision Tagging for PR Previews

**Gotcha:** A naive PR preview approach creates a new Cloud Run service per
PR (`my-app-pr-42`). This proliferates services, consumes the 1000-per-region
quota, and makes cleanup tedious.

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

- name: Deploy with pooled URL
  run: |
    gcloud run deploy my-app \
      --update-env-vars="DATABASE_URL=${{ steps.neon.outputs.db_url_pooled }}"
```

Pass `db_url_pooled` to Cloud Run, not `db_url`.

**Exception:** Alembic migrations should use the **direct** URL, not the
pooled one. PgBouncer in transaction-pooling mode doesn't support the
session-level operations Alembic needs (e.g., `SET lock_timeout`).
This template runs migrations from GitHub Actions (not Cloud Run), so
just use `db_url` in the migrations step and `db_url_pooled` in the
deploy step.

---

## 10. Neon: Compute Wakes Up on First Query

**Gotcha:** Neon's compute endpoint scales to zero after ~5 minutes of
inactivity. The first query after suspend takes 500ms-2s while the compute
instance wakes up. If your app uses a short connection timeout (e.g., 1s),
that first query fails outright with a connection error.

**Pattern:** Use a generous connection timeout and enable `pool_pre_ping`
in SQLAlchemy/SQLModel so dead connections are detected and replaced:

```python
from sqlmodel import create_engine

engine = create_engine(
    settings.database_url,
    pool_size=5,
    max_overflow=10,
    pool_pre_ping=True,   # detects dead connections on checkout
    pool_recycle=300,     # recycle connections older than 5 min
)
```

**Alternative:** Disable autosuspend on the main branch by setting the
compute endpoint to never suspend. Costs more ($5-10/month) but
eliminates the wakeup latency. For PR branches, keep autosuspend on —
previews are fine with cold starts.

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
  continue-on-error: true
  with:
    project_id: ${{ secrets.NEON_PROJECT_ID }}
    branch: pr-${{ github.event.number }}
    api_key: ${{ secrets.NEON_API_KEY }}
```

`continue-on-error: true` on cleanup handles the case where the branch
was never created. The action is idempotent.

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
role:

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

## 15. FastAPI: Run Alembic Before Deploying a Schema Change

**Gotcha:** If you deploy a new container revision that expects a new
column and the database doesn't have it yet, every request hits a
`UndefinedColumnError` until you run the migration. "Run the migration
after deploy" is backwards. Run it first.

**Pattern:** The `deploy.yml` workflow runs `alembic upgrade head` against
the production Neon URL **before** building and deploying the container.
For PR previews, `preview-deploy.yml` runs Alembic against the freshly-
created Neon branch database before deploying the preview revision.

```yaml
- name: Run Alembic migrations
  env:
    DATABASE_URL: ${{ secrets.PRODUCTION_DATABASE_URL }}
  run: |
    uv sync --frozen
    uv run alembic upgrade head

- name: Build and push container
  run: docker build -t $IMAGE . && docker push $IMAGE

- name: Deploy to Cloud Run
  run: gcloud run deploy ...
```

**For destructive migrations** (dropping columns, renaming tables): use a
two-step deploy. First deploy a revision that tolerates both schemas, then
run the migration, then deploy a revision that uses only the new schema.
Never do destructive migrations and code changes in the same commit.

---

## 16. SQLModel: Use Column Strings for order_by to Satisfy mypy

**Gotcha:** SQLModel's type annotations make `Todo.created_at` look like
a `datetime` to mypy, not a SQLAlchemy column. Calling `.desc()` on it
fails type checking, and using `sqlalchemy.desc(Todo.created_at)` also
fails because mypy thinks you're passing a `datetime` to `desc()`.

**Pattern:** Pass the column name as a string to `desc()`:

```python
from sqlalchemy import desc
from sqlmodel import select

todos = session.exec(
    select(Todo).order_by(desc("created_at"))
).all()
```

This works at runtime and satisfies mypy. The tradeoff is losing the
static check that `created_at` is actually a column — but that's mostly
harmless because Alembic + SQLModel fail loudly at startup if the column
doesn't exist.

**Alternative:** Add `# type: ignore[attr-defined]` on the `.desc()` call.
Cleaner when you want the attribute-based syntax but accept the mypy
escape hatch.

---

## 17. SQLModel: Small Connection Pool on Cloud Run

**Gotcha:** SQLAlchemy's default `pool_size=5, max_overflow=10` means a
single Cloud Run instance can hold 15 Postgres connections. Cloud Run can
spin up dozens of instances during a traffic spike. With Neon's free tier
connection limits, you'll hit `remaining connection slots are reserved`
fast.

**Pattern:** Keep the pool small on Cloud Run (Neon's PgBouncer handles
cross-instance pooling):

```python
engine = create_engine(
    settings.database_url,
    pool_size=5,
    max_overflow=10,
    pool_pre_ping=True,
    pool_recycle=300,
)
```

Combined with Neon's pooled URL (pattern #9), this gives you plenty of
capacity without exhausting connection slots.

For apps with very short request lifetimes and high throughput, consider
`pool_size=1, max_overflow=2` and rely entirely on PgBouncer for pooling.

---

## 18. HTMX: Return Fragments, Not Full Pages

**Gotcha:** When an HTMX request hits a route, the response replaces part
of the DOM — not the whole page. If your handler returns a full HTML
document (`<!DOCTYPE html>...`), HTMX inserts the entire document into
the target element, which breaks layout and duplicates `<html>`, `<head>`,
`<body>` tags.

**Pattern:** Return partial templates (fragments) from HTMX routes.

```python
# Full page: renders base.html → home.html
@router.get("/", response_class=HTMLResponse)
async def home(request: Request, session: SessionDep):
    todos = session.exec(select(Todo)).all()
    return templates.TemplateResponse(
        request, "home.html", {"todos": todos}
    )

# HTMX fragment: renders just the updated list
@router.post("/todos", response_class=HTMLResponse)
async def create_todo(request: Request, session: SessionDep, title: str = Form()):
    session.add(Todo(title=title))
    session.commit()
    todos = session.exec(select(Todo)).all()
    return templates.TemplateResponse(
        request, "_fragments/todo_list.html", {"todos": todos}
    )
```

Convention: prefix fragment templates with `_fragments/` or `_partials/`
so it's obvious which templates are full pages vs partial HTML.

---

## 19. HTMX: hx-target and hx-swap Must Match Your Response Shape

**Gotcha:** If your handler returns an `<li>` but your `hx-target` points
at a `<ul>` with `hx-swap="outerHTML"`, HTMX replaces the `<ul>` with an
`<li>` — breaking the layout. The fragment template, the target selector,
and the swap strategy all have to agree.

**Pattern:** Document the contract explicitly in your route comments.

```python
@router.post("/todos/{todo_id}/toggle", response_class=HTMLResponse)
async def toggle_todo(request: Request, session: SessionDep, todo_id: int):
    """Toggle a todo and return the single item fragment.

    Contract:
    - Fragment: _fragments/todo_item.html (renders a single <li>)
    - hx-target: #todo-{id} (the <li> being toggled)
    - hx-swap: outerHTML (replaces the <li> with the updated <li>)
    """
    todo = session.get(Todo, todo_id)
    if todo is None:
        return HTMLResponse("", status_code=404)
    todo.done = not todo.done
    session.add(todo)
    session.commit()
    session.refresh(todo)
    return templates.TemplateResponse(
        request, "_fragments/todo_item.html", {"todo": todo}
    )
```

Standard combinations:

| Operation | Fragment returns | hx-target | hx-swap |
|-----------|------------------|-----------|---------|
| Create (append to list) | New item only | `#list` | `beforeend` |
| Create (replace list) | Whole list | `#list` | `outerHTML` |
| Update | Updated item only | `#item-{id}` | `outerHTML` |
| Delete | Empty response | `#item-{id}` | `outerHTML` |
| Validate | Inline error message | `#form-errors` | `innerHTML` |

---

## 20. GitHub Actions: hashFiles() Scope Limitation

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
          path: .venv
          key: ${{ runner.os }}-python-${{ hashFiles('uv.lock') }}
```

---

## 21. GitHub Actions: Graceful Secret Gating

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

## 22. GitHub Actions: CI Checks Not Attaching to PR

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

---

## 23. GitHub Actions: Reusable Workflow Missing workflow_call

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

---

## 24. GitHub Projects: Labels vs Board Columns

**Gotcha:** Labels and board columns look similar but are tracked differently.
A ticket can have the `ready` label but still be in the `Backlog` column.
Agents that filter by label will get a different list than agents that
filter by column.

**Pattern:** For board workflow, **always** filter by the column (Status
field), not by label. Labels are free-form metadata; columns are workflow
state.

```bash
gh project item-list 13 --owner myorg --format json --limit 200 \
  | jq '.items[] | select(.status == "Ready")'
```

---

## 25. GitHub Projects: CLI Truncation at 30 Items

**Gotcha:** `gh project item-list` returns at most 30 items by default.
For any board with more than 30 tickets, you silently miss the tail.

**Pattern:** Always pass `--limit` explicitly.

```bash
gh project item-list 13 --owner myorg --format json --limit 200
```

---

## 26. GitHub: Account Switching for Multi-Agent Workflows

**Gotcha:** When multiple agents share one machine (worker bot, reviewer
bot, human operator), `gh` uses whichever account was active last.

**Pattern:** The `.claude/hooks/ensure-github-account.sh` hook auto-switches
accounts before PR operations. Never rely on manual account management.

See `.claude/README.md` for the full account separation model.

---

## 27. GitHub MCP Server vs gh CLI for Agent Workflows

**Gotcha:** The GitHub MCP server does not cleanly support account
switching for multi-agent workflows.

**Pattern:** This template uses the `gh` CLI for all GitHub operations.
The `.claude/hooks/ensure-github-account.sh` hook switches accounts
before PR-creating or PR-reviewing commands.

---

## 28. Server-Side URLs: Never Hardcode Origins

**Gotcha:** Hardcoding `https://myapp.com` in server code breaks preview
environments. Every PR preview has a different URL, and the code still
redirects to production.

**Pattern:**

```python
from fastapi import Request


def get_external_origin(request: Request) -> str:
    proto = request.headers.get("x-forwarded-proto", "https")
    host = request.headers.get("x-forwarded-host") or request.headers.get("host")
    if not host:
        raise ValueError("Missing host header")
    return f"{proto}://{host}"
```

Never store the production URL in code. Construct the origin from request
headers, or read it from a runtime env var (`APP_URL`) that differs per
environment.

---

## 29. Workshop: Participant Email Must Match Their Google Identity

**Gotcha:** `scripts/provision-workshop-roster.sh` grants each participant
`roles/editor` on their project via:

```bash
gcloud projects add-iam-policy-binding "$project_id" \
  --member="user:$email" \
  --role="roles/editor"
```

`gcloud` accepts almost any email-shaped string here as long as the domain
has Google auth attached. That produces two failure modes that look fine
during provisioning but break the participant on day-of:

1. **Wrong identity, valid domain.** Roster says `joe@somecorp.com`. Joe's
   actual Google identity at `somecorp.com` is `joe.smith@somecorp.com`.
   The binding succeeds. Joe opens the project URL on day-of and sees a
   "you do not have access" banner.
2. **No Google identity at all.** Personal address with no Google account
   attached. `gcloud` rejects it with `Invalid value for
   [policy.bindings.members]: must reference a real, existing principal`.
   The wrapper is fail-fast, so the whole loop halts on the offender's row.

Both cost ~30 minutes of live workshop triage if discovered on day-of.

**Pattern:** Validate emails *before* running provisioning.

```bash
# 1. Ask each participant the verification question:
#    "What email do you sign in to https://console.cloud.google.com with?"
#
# 2. Sanity-check each row of the roster for a Google-identity-shaped value:

awk -F, 'NR>1 && $3 !~ /^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$/ {
    print "BAD: row " NR ": " $0; exit 1
  }' roster.csv

# 3. (Optional) For Workspace participants, confirm the email resolves
#    to a real Google identity by attempting a no-op IAM check on a
#    facilitator-owned scratch project:

gcloud projects add-iam-policy-binding <scratch-project-id> \
  --member="user:<participant-email>" \
  --role="roles/viewer" \
  --condition=None --quiet \
  && gcloud projects remove-iam-policy-binding <scratch-project-id> \
       --member="user:<participant-email>" \
       --role="roles/viewer" \
       --condition=None --quiet
```

Step 1 is the highest-leverage check — it costs 2 minutes and catches the
wrong-identity case that step 3 cannot.

**Where this fits in the workshop flow:** add the validation to the
T-3 days "verify provisioning landed" step in
`agile-flow-meta/docs/workshops/gcp-facilitator-runbook.md`, *before* you
run `provision-workshop-roster.sh`. The runbook section 3 callout
documents the same gotcha for facilitators.

**Related:** the dry-run checklist (`gcp-dry-run-checklist.md`) requires
the synthetic participant's email to be the *facilitator's own* real
Google email. That guarantees the dry-run also exercises the
"can the participant see the project" path, not just provisioning.

---

## 30. Workshop: Domain-Restricted Sharing Blocks External-Email IAM Bindings

**Gotcha:** If your GCP organization has the
`constraints/iam.allowedPolicyMemberDomains` org policy enabled (also
called **Domain Restricted Sharing**), `gcloud projects add-iam-policy-binding`
rejects bindings against any identity outside the allowed-domain list —
including consumer Gmail accounts and Workspace identities on
non-allowed domains. The reject is `FAILED_PRECONDITION` with this
exact stderr:

```text
ERROR: (gcloud.projects.add-iam-policy-binding) FAILED_PRECONDITION:
One or more users named in the policy do not belong to a permitted customer.
- '@type': type.googleapis.com/google.rpc.PreconditionFailure
  violations:
  - description: User <email> is not in permitted organization.
    type: constraints/iam.allowedPolicyMemberDomains
```

This is **not** an eventual-consistency error. It's a permanent policy
rejection — no amount of retry will fix it. The retry helper in
`provision-gcp-project.sh` correctly does not retry it (the signature
doesn't match any transient pattern, so it bails immediately).

**Why this hits workshops:** participants sign up with personal Gmail
addresses (`@gmail.com`) by default. Most facilitator GCP organizations
have Domain Restricted Sharing enabled by their security defaults — it
is on by default for orgs created via Cloud Identity Free. The very
first IAM binding for the very first participant fails.

**Pattern: disable the constraint per-project, scoped to workshop projects only.**

Run this *once per participant project*, after `provision-gcp-project.sh`
creates the project and before `gcloud projects add-iam-policy-binding`
attempts the binding (the workshop wrapper calls the binding directly,
so the override must run in between):

```bash
# Check whether the org has the constraint enforced. Idempotent — no-op
# if not enforced. Requires roles/orgpolicy.policyAdmin on the project,
# which the project creator has by default.

if gcloud resource-manager org-policies describe \
  iam.allowedPolicyMemberDomains \
  --project="$GCP_PROJECT_ID" \
  --format='value(booleanPolicy.enforced)' 2>/dev/null | grep -q true; then
  echo "[override] disabling domain-restricted-sharing for $GCP_PROJECT_ID"
  gcloud resource-manager org-policies disable-enforce \
    iam.allowedPolicyMemberDomains \
    --project="$GCP_PROJECT_ID"
fi
```

The override is **scoped to one project**. It does not affect the rest
of your organization's posture — production projects, shared services,
etc. retain the constraint. Workshop projects are short-lived and
deleted at T+1 day, so the security exposure window is bounded.

**Alternatives considered and rejected:**

- **Disable at the org level.** Removes the constraint from every
  project in the org. Wrong scope for a workshop.
- **Add `gmail.com` to the allowed-domains list.** Same scope problem —
  permanently broadens what your org accepts. Also: for Workspace
  participants on assorted corp domains, you'd need to enumerate every
  domain ahead of time.
- **Require Workspace identities on a permitted domain.** Operationally
  hostile — most workshop participants don't have Workspace accounts on
  a domain you control.

**Verification:** after the override, the same `add-iam-policy-binding`
that failed will succeed within seconds. There is no propagation lag
on the policy override itself in our experience, but the SA-binding
retry helper covers the rare case where there is.

**Where this fits in the workshop flow:** the runbook's T-3 days
provisioning step covers the override. Once
`provision-workshop-roster.sh` ships the override inline (planned
follow-up; not yet shipped), facilitators won't need to think about
this.
