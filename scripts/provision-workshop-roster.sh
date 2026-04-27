#!/usr/bin/env bash
#
# provision-workshop-roster.sh — multi-project provisioning from a CSV roster.
#
# Wraps scripts/provision-gcp-project.sh for workshop facilitators who need
# to provision N participant projects in one command.
#
# Usage:
#   BILLING_ACCOUNT_ID=XXX-XXXX-XXXX ./scripts/provision-workshop-roster.sh roster.csv
#
# Required environment variables:
#   BILLING_ACCOUNT_ID   The GCP billing account to attach each project to
#
# Optional environment variables:
#   GCP_REGION           (default: us-central1) — passed through to inner script
#   ARTIFACT_REPO        (default: agile-flow)  — passed through to inner script
#   PROVISION_SCRIPT     (default: scripts/provision-gcp-project.sh) — for tests
#
# CSV format (header required):
#   handle,github_user,email,cohort
#   alice,alice-gh,alice@example.com,2026-05
#   bob,bob-gh,bob@example.com,2026-05
#
# Project IDs follow the pattern  af-{handle}-{cohort}  and are globally
# unique. This is non-negotiable: the runbook, day-1 doc, and dry-run
# checklist all assume this shape.
#
# Side effects per row:
#   1. Calls provision-gcp-project.sh --create-project (idempotent)
#   2. Grants roles/editor on the new project to the participant's email
#   3. Appends a row to roster-output.csv with status + project ID
#
# This script is fail-fast: the loop stops on the first row that errors,
# so a half-provisioned classroom does not silently happen.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROVISION_SCRIPT="${PROVISION_SCRIPT:-$REPO_ROOT/scripts/provision-gcp-project.sh}"
OUTPUT_CSV="${OUTPUT_CSV:-roster-output.csv}"

# ── Argument parsing ─────────────────────────────────────────────────────

if [[ $# -ne 1 ]]; then
  cat >&2 <<EOF
Usage: BILLING_ACCOUNT_ID=XXX ./scripts/provision-workshop-roster.sh <roster.csv>

See header of $0 for full documentation.
EOF
  exit 2
fi

ROSTER_CSV="$1"

if [[ ! -f "$ROSTER_CSV" ]]; then
  echo "ERROR: roster file not found: $ROSTER_CSV" >&2
  exit 2
fi

if [[ -z "${BILLING_ACCOUNT_ID:-}" ]]; then
  echo "ERROR: BILLING_ACCOUNT_ID is required" >&2
  exit 2
fi

if [[ ! -x "$PROVISION_SCRIPT" ]]; then
  echo "ERROR: inner provision script not executable: $PROVISION_SCRIPT" >&2
  exit 2
fi

# ── CSV header validation ────────────────────────────────────────────────

EXPECTED_HEADER="handle,github_user,email,cohort"
ACTUAL_HEADER="$(head -n 1 "$ROSTER_CSV" | tr -d '\r')"

if [[ "$ACTUAL_HEADER" != "$EXPECTED_HEADER" ]]; then
  echo "ERROR: roster CSV header must be exactly: $EXPECTED_HEADER" >&2
  echo "       got: $ACTUAL_HEADER" >&2
  exit 2
fi

# ── Output CSV setup ─────────────────────────────────────────────────────

if [[ ! -f "$OUTPUT_CSV" ]]; then
  echo "handle,project_id,status,wif_provider,timestamp" > "$OUTPUT_CSV"
fi

# ── Counters ─────────────────────────────────────────────────────────────

total=0
created=0
skipped=0

# ── Loop ─────────────────────────────────────────────────────────────────

# tail -n +2 skips header. Process substitution avoids subshell so counters
# survive into the summary block.
while IFS=',' read -r handle github_user email cohort; do
  # Strip whitespace and CR (Windows line endings)
  handle="$(echo "$handle" | tr -d '[:space:]\r')"
  github_user="$(echo "$github_user" | tr -d '[:space:]\r')"
  email="$(echo "$email" | tr -d '[:space:]\r')"
  cohort="$(echo "$cohort" | tr -d '[:space:]\r')"

  if [[ -z "$handle" || -z "$cohort" ]]; then
    continue
  fi

  total=$((total + 1))
  project_id="af-${handle}-${cohort}"
  timestamp="$(date -u '+%Y-%m-%dT%H:%M:%SZ')"

  echo ""
  echo "──────────────────────────────────────────────────"
  echo "  [$total] $handle  ->  $project_id"
  echo "──────────────────────────────────────────────────"

  # Detect whether the project already exists, so we can label the output
  # row honestly. The inner script is idempotent either way, so this is
  # purely for the summary CSV.
  if gcloud projects describe "$project_id" >/dev/null 2>&1; then
    status="skipped"
    skipped=$((skipped + 1))
  else
    status="created"
    created=$((created + 1))
  fi

  # Run the inner provisioner. It handles "already exists" internally;
  # we just pass through the env it needs. GITHUB_USERNAME enables the
  # WIF setup in Step 5.5 of the inner script — when empty, that step
  # is skipped and the SA-key shortcut remains the auth fallback.
  GCP_PROJECT_ID="$project_id" \
  BILLING_ACCOUNT_ID="$BILLING_ACCOUNT_ID" \
  GCP_REGION="${GCP_REGION:-us-central1}" \
  ARTIFACT_REPO="${ARTIFACT_REPO:-agile-flow}" \
  GITHUB_USERNAME="$github_user" \
    "$PROVISION_SCRIPT" --create-project

  # Grant the participant editor on their own project. Idempotent.
  echo ""
  echo "[bind] roles/editor -> user:$email"
  gcloud projects add-iam-policy-binding "$project_id" \
    --member="user:$email" \
    --role="roles/editor" \
    --condition=None \
    --quiet >/dev/null

  # WIF provider resource path. The inner script's Step 5.5 created the
  # pool + provider when GITHUB_USERNAME was non-empty; record the canonical
  # resource string for the summary CSV so the facilitator can paste it
  # straight into participant fork secrets.
  wif_provider=""
  if [[ -n "$github_user" ]]; then
    project_number="$(gcloud projects describe "$project_id" --format='value(projectNumber)' 2>/dev/null || true)"
    if [[ -n "$project_number" ]]; then
      wif_provider="projects/${project_number}/locations/global/workloadIdentityPools/github/providers/github"
    fi
  fi

  echo "$handle,$project_id,$status,$wif_provider,$timestamp" >> "$OUTPUT_CSV"
done < <(tail -n +2 "$ROSTER_CSV")

# ── Summary ──────────────────────────────────────────────────────────────

echo ""
echo "=================================="
echo "  Workshop provisioning summary"
echo "=================================="
echo "  Total rows processed:   $total"
echo "  Newly created:          $created"
echo "  Already existed:        $skipped"
echo "  Failed:                 0   (script is fail-fast — see above for any error)"
echo ""
echo "  Output: $OUTPUT_CSV"
echo "  Next:   set up WIF (manually or via #5) and send each participant"
echo "          their setup email per docs/PLATFORM-GUIDE.md."
