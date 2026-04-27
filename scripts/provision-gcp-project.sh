#!/usr/bin/env bash
#
# provision-gcp-project.sh — one-shot GCP project setup for Agile Flow GCP.
#
# Creates a GCP project (optional), enables required APIs, creates an
# Artifact Registry repo, creates a deployer service account with the
# minimum required roles, and optionally generates a service account JSON
# key for workshop use.
#
# Usage:
#   ./scripts/provision-gcp-project.sh [--create-project] [--with-sa-key]
#
# Environment variables:
#   GCP_PROJECT_ID       (required) Project ID to provision into
#   GCP_REGION           (default: us-central1)
#   ARTIFACT_REPO        (default: agile-flow)
#   BILLING_ACCOUNT_ID   (required if --create-project)
#
# Notes:
# - This script is idempotent. Re-running skips resources that already exist.
# - `--with-sa-key` generates a long-lived service account key. Use for
#   workshops only. For production, set up Workload Identity Federation
#   separately (see docs/PLATFORM-GUIDE.md Step 5).
#
# After running, paste the output into your GitHub repo's secrets panel.

set -euo pipefail

GCP_REGION="${GCP_REGION:-us-central1}"
ARTIFACT_REPO="${ARTIFACT_REPO:-agile-flow}"

# ── Retry helper for GCP eventual consistency ────────────────────────────
#
# Enabling a GCP API (e.g. artifactregistry.googleapis.com) is eventually
# consistent: the enable call returns success but the API endpoint can
# return PERMISSION_DENIED for 30-90 seconds afterward, even for project
# owners. Same pattern hits IAM bindings after SA creation. We retry on
# that specific stderr signature only — bad arguments, already-exists,
# and auth failures fail immediately.
#
# Usage:
#   retry_eventual_consistency <label> -- <gcloud command...>
#
# Defaults: 6 attempts, exponential backoff (2,4,8,16,30,30s), ~90s cap.
# Override with RETRY_MAX_ATTEMPTS, RETRY_MAX_SLEEP env vars.

RETRY_MAX_ATTEMPTS="${RETRY_MAX_ATTEMPTS:-6}"
RETRY_MAX_SLEEP="${RETRY_MAX_SLEEP:-30}"

retry_eventual_consistency() {
  local label="$1"; shift
  if [[ "${1:-}" != "--" ]]; then
    echo "ERROR: retry_eventual_consistency expects 'label -- cmd...'" >&2
    return 2
  fi
  shift

  local attempt=1
  local sleep_s=2
  local stderr_file
  stderr_file="$(mktemp)"

  local exit_code
  while (( attempt <= RETRY_MAX_ATTEMPTS )); do
    # Run the command with `set -e` temporarily disabled so we can capture
    # its exit code. Bash function-local `set +e` does not leak out of
    # the function in a `command || handler` pattern, but a bare `if/then`
    # clobbers $?. Cleanest: && / || chain.
    exit_code=0
    "$@" 2> "$stderr_file" || exit_code=$?

    if (( exit_code == 0 )); then
      cat "$stderr_file" >&2
      rm -f "$stderr_file"
      return 0
    fi

    # Permanent error signatures — fail immediately, do not retry.
    if grep -qE 'Invalid argument|already exists|ALREADY_EXISTS|invalid value|Bad Request|UNAUTHENTICATED' "$stderr_file"; then
      cat "$stderr_file" >&2
      rm -f "$stderr_file"
      return "$exit_code"
    fi

    # Transient eventual-consistency signature.
    if grep -qE 'PERMISSION_DENIED.*denied on resource|IAM_PERMISSION_DENIED|API has not been used|SERVICE_DISABLED' "$stderr_file"; then
      if (( attempt == RETRY_MAX_ATTEMPTS )); then
        echo "[retry $attempt/$RETRY_MAX_ATTEMPTS] $label — exhausted" >&2
        cat "$stderr_file" >&2
        rm -f "$stderr_file"
        return "$exit_code"
      fi
      echo "[retry $attempt/$RETRY_MAX_ATTEMPTS] $label — transient 403, sleeping ${sleep_s}s" >&2
      sleep "$sleep_s"
      sleep_s=$(( sleep_s * 2 ))
      (( sleep_s > RETRY_MAX_SLEEP )) && sleep_s=$RETRY_MAX_SLEEP
      attempt=$(( attempt + 1 ))
      continue
    fi

    # Unrecognized error — surface it and bail. Better to fail loudly than
    # to retry indefinitely on something we don't understand.
    cat "$stderr_file" >&2
    rm -f "$stderr_file"
    return "$exit_code"
  done

  rm -f "$stderr_file"
  return 1
}

CREATE_PROJECT=false
WITH_SA_KEY=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --create-project) CREATE_PROJECT=true; shift ;;
    --with-sa-key) WITH_SA_KEY=true; shift ;;
    -h|--help)
      sed -n '1,30p' "$0"
      exit 0
      ;;
    *) echo "Unknown flag: $1" >&2; exit 1 ;;
  esac
done

if [[ -z "${GCP_PROJECT_ID:-}" ]]; then
  echo "ERROR: GCP_PROJECT_ID is required" >&2
  echo "Usage: GCP_PROJECT_ID=my-project ./scripts/provision-gcp-project.sh" >&2
  exit 1
fi

echo "=================================="
echo "  Agile Flow GCP Provisioning"
echo "=================================="
echo "  Project:  $GCP_PROJECT_ID"
echo "  Region:   $GCP_REGION"
echo "  Repo:     $ARTIFACT_REPO"
echo "  Create:   $CREATE_PROJECT"
echo "  SA key:   $WITH_SA_KEY"
echo ""

# ── Step 1: Create project (optional) ────────────────────────────────────

if [[ "$CREATE_PROJECT" == "true" ]]; then
  if [[ -z "${BILLING_ACCOUNT_ID:-}" ]]; then
    echo "ERROR: BILLING_ACCOUNT_ID required when --create-project is set" >&2
    exit 1
  fi

  if gcloud projects describe "$GCP_PROJECT_ID" >/dev/null 2>&1; then
    echo "[skip] Project $GCP_PROJECT_ID already exists"
  else
    echo "[create] Project $GCP_PROJECT_ID"
    gcloud projects create "$GCP_PROJECT_ID"
  fi

  echo "[link] Billing account $BILLING_ACCOUNT_ID"
  gcloud billing projects link "$GCP_PROJECT_ID" \
    --billing-account="$BILLING_ACCOUNT_ID"
fi

# ── Step 2: Enable APIs ──────────────────────────────────────────────────

echo "[enable] Required APIs (may take 30-60 seconds on first run)"
gcloud services enable \
  run.googleapis.com \
  artifactregistry.googleapis.com \
  secretmanager.googleapis.com \
  iam.googleapis.com \
  iamcredentials.googleapis.com \
  --project="$GCP_PROJECT_ID"

# ── Step 3: Artifact Registry repo ───────────────────────────────────────

if gcloud artifacts repositories describe "$ARTIFACT_REPO" \
  --location="$GCP_REGION" \
  --project="$GCP_PROJECT_ID" >/dev/null 2>&1; then
  echo "[skip] Artifact Registry repo '$ARTIFACT_REPO' already exists"
else
  echo "[create] Artifact Registry repo '$ARTIFACT_REPO'"
  retry_eventual_consistency "artifact registry create" -- \
    gcloud artifacts repositories create "$ARTIFACT_REPO" \
      --repository-format=docker \
      --location="$GCP_REGION" \
      --project="$GCP_PROJECT_ID"
fi

# ── Step 4: Deployer service account ─────────────────────────────────────

SA_EMAIL="deployer@${GCP_PROJECT_ID}.iam.gserviceaccount.com"

if gcloud iam service-accounts describe "$SA_EMAIL" \
  --project="$GCP_PROJECT_ID" >/dev/null 2>&1; then
  echo "[skip] Service account 'deployer' already exists"
else
  echo "[create] Service account 'deployer'"
  retry_eventual_consistency "service account create" -- \
    gcloud iam service-accounts create deployer \
      --display-name="GitHub Actions deployer" \
      --project="$GCP_PROJECT_ID"
fi

# ── Step 5: IAM roles ────────────────────────────────────────────────────

ROLES=(
  "roles/run.admin"
  "roles/artifactregistry.writer"
  "roles/iam.serviceAccountUser"
  "roles/secretmanager.secretAccessor"
)

for role in "${ROLES[@]}"; do
  echo "[bind] $role -> $SA_EMAIL"
  retry_eventual_consistency "iam bind $role" -- \
    gcloud projects add-iam-policy-binding "$GCP_PROJECT_ID" \
      --member="serviceAccount:${SA_EMAIL}" \
      --role="$role" \
      --condition=None \
      --quiet >/dev/null
done

# ── Step 6: Service account key (workshop shortcut) ─────────────────────

if [[ "$WITH_SA_KEY" == "true" ]]; then
  KEY_FILE="${GCP_PROJECT_ID}-deployer-key.json"

  if [[ -f "$KEY_FILE" ]]; then
    echo "[skip] Key file $KEY_FILE already exists (delete it first if you need a new one)"
  else
    echo "[create] Service account key -> $KEY_FILE"
    gcloud iam service-accounts keys create "$KEY_FILE" \
      --iam-account="$SA_EMAIL" \
      --project="$GCP_PROJECT_ID"
    echo ""
    echo "  WARNING: This key is a long-lived credential."
    echo "  For production, use Workload Identity Federation instead."
    echo "  See docs/PLATFORM-GUIDE.md Step 5."
  fi
fi

# ── Done ─────────────────────────────────────────────────────────────────

echo ""
echo "=================================="
echo "  Provisioning complete"
echo "=================================="
echo ""
echo "Next steps:"
echo ""
echo "1. Set these GitHub repository secrets:"
echo ""
echo "   GCP_PROJECT_ID         = $GCP_PROJECT_ID"
if [[ "$WITH_SA_KEY" == "true" ]]; then
  echo "   GCP_SA_KEY             = (contents of ${GCP_PROJECT_ID}-deployer-key.json)"
else
  echo "   GCP_WORKLOAD_IDENTITY_PROVIDER = (see docs/PLATFORM-GUIDE.md Step 5)"
  echo "   GCP_SERVICE_ACCOUNT    = $SA_EMAIL"
fi
echo ""
echo "2. Sign up at https://neon.tech and create a project."
echo "   Set these GitHub secrets from the Neon console:"
echo ""
echo "   NEON_API_KEY           = (from Neon Settings -> API Keys)"
echo "   NEON_PROJECT_ID        = (from Neon Settings -> General)"
echo ""
echo "3. Create the production database secret:"
echo ""
echo "   echo -n 'postgresql://...' | gcloud secrets create database-url \\"
echo "     --data-file=- --project=$GCP_PROJECT_ID"
echo ""
echo "4. (Optional) Set these repository variables (non-secret):"
echo ""
echo "   GCP_REGION             = $GCP_REGION"
echo "   ARTIFACT_REPO          = $ARTIFACT_REPO"
echo "   CLOUD_RUN_SERVICE      = agile-flow-app"
echo "   NEXT_PUBLIC_APP_URL    = (your production URL)"
echo ""
echo "5. Push to main to trigger your first deployment."
