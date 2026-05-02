#!/usr/bin/env bash
#
# create-workshop-neon-projects.sh — create one Neon project per
# attendee under a workshop-scoped Neon org, then write each project's
# ID back into the roster CSV's `neon_project_id` column.
#
# Run ONCE before `provision-workshop-roster.sh` in the workshop-org-
# hosted flow. Idempotent: rows that already have a non-empty
# `neon_project_id` are skipped. Rows whose target name already exists
# in the org are reconciled (the existing project's ID is written back).
#
# Why per-attendee projects (not branches in a shared cohort project)?
# See agile-flow-meta:docs/workshops/gcp-architecture-may-2026.md and
# #108. Briefly:
#   - Console clarity: each attendee sees only their own project
#   - Free-tier quota: each project has its own 10-branch quota; a
#     shared model blows past with ~3 attendees doing per-PR previews
#   - Clean teardown: facilitator deletes the workshop org → all
#     attendee projects gone in one call
#
# Usage:
#   NEON_API_KEY=neon_... NEON_ORG_ID=org-... \
#     ./scripts/create-workshop-neon-projects.sh roster.csv
#
#   ./scripts/create-workshop-neon-projects.sh roster.csv --dry-run
#
# Required environment variables:
#   NEON_API_KEY    Neon API key with write access to the org
#   NEON_ORG_ID     The Neon org ID (org-...) under which to create
#                   projects. Get it from the Neon Console URL or
#                   `GET /api/v2/organizations`.
#
# Optional flags:
#   --dry-run            Print planned actions; don't write to Neon
#                        and don't update the CSV.
#   --region <region>    Neon region for new projects.
#                        Default: aws-us-east-2 (closest to GCP us-central1).
#
# Optional environment variables:
#   NEON_PROJECT_PREFIX  Prefix prepended to each attendee handle when
#                        naming their Neon project. Default: empty
#                        (project name == handle). Useful when you want
#                        to namespace cohort projects, e.g.
#                        NEON_PROJECT_PREFIX="2026-05-" → project name
#                        becomes "2026-05-alice".
#
# Roster CSV format:
#   The roster header must already include `neon_project_id` as the
#   7th column. The script does NOT add the column for you — it expects
#   the facilitator to upgrade the roster file first. Older 4/5/6-column
#   rosters are rejected with a clear error.
#
# Exit codes:
#   0 — all rows reconciled (created or skipped)
#   1 — missing prerequisites (env vars, file, jq) or unrecoverable error
#   2 — at least one row failed to reconcile (per-row WARNs surface
#       individual failures; script continues to attempt all rows)
#
# See also: docs/PLATFORM-GUIDE.md "Workshop deployment models" section.

set -uo pipefail

# Ensure bash even if invoked as `zsh ...`
if [ -z "${BASH_VERSION:-}" ]; then
    exec bash "$0" "$@"
fi

# ───────────────────────────────────────────────────────────────────
#  Colors + print helpers
# ───────────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

print_success() { echo -e "${GREEN}✓ $1${NC}"; }
print_warning() { echo -e "${YELLOW}! $1${NC}"; }
print_error()   { echo -e "${RED}✗ $1${NC}"; }
print_info()    { echo -e "${BLUE}→ $1${NC}"; }

# ───────────────────────────────────────────────────────────────────
#  Argument parsing
# ───────────────────────────────────────────────────────────────────
ROSTER_CSV=""
DRY_RUN=false
REGION="aws-us-east-2"

show_help() {
    sed -n '2,/^$/p' "$0" | sed 's/^# \{0,1\}//'
}

while [ $# -gt 0 ]; do
    case "$1" in
        --dry-run)   DRY_RUN=true; shift ;;
        --region)    REGION="$2"; shift 2 ;;
        --region=*)  REGION="${1#--region=}"; shift ;;
        -h|--help)   show_help; exit 0 ;;
        --*)
            print_error "Unknown flag: $1"
            print_info "Run with --help for usage."
            exit 1
            ;;
        *)
            if [ -n "$ROSTER_CSV" ]; then
                print_error "Multiple positional arguments; expected exactly one (the roster CSV)"
                exit 1
            fi
            ROSTER_CSV="$1"
            shift
            ;;
    esac
done

# ───────────────────────────────────────────────────────────────────
#  Pre-flight
# ───────────────────────────────────────────────────────────────────
echo ""
echo -e "${CYAN}=== Agile Flow — Workshop Neon Project Creation ===${NC}"
echo ""

if [ -z "$ROSTER_CSV" ]; then
    print_error "Roster CSV path required."
    print_info "Usage: NEON_API_KEY=... NEON_ORG_ID=... $0 <roster.csv> [--dry-run]"
    exit 1
fi

if [ ! -f "$ROSTER_CSV" ]; then
    print_error "Roster file not found: $ROSTER_CSV"
    exit 1
fi

if [ -z "${NEON_API_KEY:-}" ]; then
    print_error "NEON_API_KEY env var is required."
    print_info "Get one from https://console.neon.tech/app/settings/api-keys"
    exit 1
fi

if [ -z "${NEON_ORG_ID:-}" ]; then
    print_error "NEON_ORG_ID env var is required."
    print_info "Find it via: curl -H 'Authorization: Bearer \$NEON_API_KEY' https://console.neon.tech/api/v2/organizations"
    exit 1
fi

if ! command -v curl >/dev/null 2>&1; then
    print_error "curl not found on PATH"
    exit 1
fi

if ! command -v jq >/dev/null 2>&1; then
    print_error "jq not found on PATH"
    print_info "Install: brew install jq  OR  apt-get install jq"
    exit 1
fi

# ───────────────────────────────────────────────────────────────────
#  Validate roster header (must include neon_project_id as 7th col)
# ───────────────────────────────────────────────────────────────────
EXPECTED_HEADER_7="handle,github_user,email,cohort,neon_branch,github_full_repo,neon_project_id"
ACTUAL_HEADER="$(head -n 1 "$ROSTER_CSV" | tr -d '\r')"

if [ "$ACTUAL_HEADER" != "$EXPECTED_HEADER_7" ]; then
    print_error "Roster CSV must have 7-column header for per-attendee Neon projects:"
    echo "       expected: $EXPECTED_HEADER_7" >&2
    echo "       got:      $ACTUAL_HEADER" >&2
    print_info "Upgrade your roster: add 'neon_project_id' as the 7th column, leave values empty for new projects."
    exit 1
fi

print_info "Target roster:    $ROSTER_CSV"
print_info "Target Neon org:  $NEON_ORG_ID"
print_info "Region:           $REGION"
print_info "Project prefix:   ${NEON_PROJECT_PREFIX:-(none)}"
if [ "$DRY_RUN" = "true" ]; then
    print_info "Dry-run mode: no Neon writes, no CSV updates"
fi
echo ""

# ───────────────────────────────────────────────────────────────────
#  Neon API helpers
# ───────────────────────────────────────────────────────────────────
NEON_API_BASE="${NEON_API_BASE:-https://console.neon.tech/api/v2}"

# GET. Echoes body to stdout, returns curl exit code (0 = ok).
neon_get() {
    local path="$1"
    curl --silent --show-error --fail \
        -H "Authorization: Bearer $NEON_API_KEY" \
        -H "Accept: application/json" \
        "${NEON_API_BASE}${path}"
}

# POST. Echoes body to a tempfile (path passed in), echoes HTTP code
# to stdout, returns curl exit code (0 = curl-ok, regardless of HTTP).
# Caller checks the HTTP code.
neon_post() {
    local path="$1"
    local body="$2"
    local out_file="$3"
    curl --silent --show-error \
        --output "$out_file" \
        --write-out '%{http_code}' \
        -X POST \
        -H "Authorization: Bearer $NEON_API_KEY" \
        -H "Accept: application/json" \
        -H "Content-Type: application/json" \
        -d "$body" \
        "${NEON_API_BASE}${path}"
}

# ───────────────────────────────────────────────────────────────────
#  Look up existing org projects once (for idempotent name reuse)
# ───────────────────────────────────────────────────────────────────
echo "[lookup] Fetching existing projects in org $NEON_ORG_ID"
existing_projects_json="$(neon_get "/projects?org_id=${NEON_ORG_ID}" || true)"

if [ -z "$existing_projects_json" ]; then
    print_warning "Could not list existing Neon projects in org $NEON_ORG_ID."
    print_warning "Proceeding anyway; new-project creation may collide on names."
    existing_projects_json='{"projects":[]}'
fi

# Map from project name → id, written as one "name<TAB>id" per line
existing_map_file="$(mktemp -t aflow-neon-XXXX)"
trap 'rm -f "$existing_map_file"' EXIT
echo "$existing_projects_json" | \
    jq -r '.projects[] | "\(.name)\t\(.id)"' > "$existing_map_file"

print_info "Found $(wc -l < "$existing_map_file" | tr -d ' ') existing project(s) in org"
echo ""

# ───────────────────────────────────────────────────────────────────
#  Iterate roster rows
# ───────────────────────────────────────────────────────────────────
HAD_ERROR=0
CREATED=0
REUSED=0
SKIPPED=0

# Build the new CSV in a tempfile so we can swap atomically at the end
new_csv="$(mktemp -t aflow-roster-XXXX)"
trap 'rm -f "$existing_map_file" "$new_csv"' EXIT
head -n 1 "$ROSTER_CSV" > "$new_csv"

while IFS=',' read -r handle github_user email cohort neon_branch github_full_repo neon_project_id; do
    # Strip whitespace and CR (Windows line endings)
    handle="$(echo "$handle" | tr -d '[:space:]\r')"
    github_user="$(echo "$github_user" | tr -d '[:space:]\r')"
    email="$(echo "$email" | tr -d '[:space:]\r')"
    cohort="$(echo "$cohort" | tr -d '[:space:]\r')"
    neon_branch="$(echo "${neon_branch:-}" | tr -d '[:space:]\r')"
    github_full_repo="$(echo "${github_full_repo:-}" | tr -d '[:space:]\r')"
    neon_project_id="$(echo "${neon_project_id:-}" | tr -d '[:space:]\r')"

    if [ -z "$handle" ]; then
        # Pass empty/blank rows through unchanged
        echo "${handle},${github_user},${email},${cohort},${neon_branch},${github_full_repo},${neon_project_id}" >> "$new_csv"
        continue
    fi

    # Skip rows that already have a project ID
    if [ -n "$neon_project_id" ]; then
        print_success "Row '${handle}': already has project_id ${neon_project_id} (skipping)"
        SKIPPED=$((SKIPPED + 1))
        echo "${handle},${github_user},${email},${cohort},${neon_branch},${github_full_repo},${neon_project_id}" >> "$new_csv"
        continue
    fi

    # Compute target project name
    project_name="${NEON_PROJECT_PREFIX:-}${handle}"

    # Look up existing project by name
    existing_id="$(awk -F'\t' -v target="$project_name" '$1 == target { print $2; exit }' "$existing_map_file")"

    if [ -n "$existing_id" ]; then
        print_success "Row '${handle}': reusing existing project '${project_name}' (id=${existing_id})"
        REUSED=$((REUSED + 1))
        echo "${handle},${github_user},${email},${cohort},${neon_branch},${github_full_repo},${existing_id}" >> "$new_csv"
        continue
    fi

    # Need to create
    if [ "$DRY_RUN" = "true" ]; then
        print_info "Row '${handle}': WOULD CREATE Neon project '${project_name}' under org $NEON_ORG_ID"
        # Still write the row through with empty neon_project_id (dry-run leaves it untouched)
        echo "${handle},${github_user},${email},${cohort},${neon_branch},${github_full_repo}," >> "$new_csv"
        continue
    fi

    response_file="$(mktemp -t aflow-neon-resp-XXXX)"
    body="$(printf '{"project":{"name":"%s","org_id":"%s","region_id":"%s"}}' "$project_name" "$NEON_ORG_ID" "$REGION")"
    http_code="$(neon_post "/projects" "$body" "$response_file" || echo "000")"

    if [ "$http_code" = "201" ] || [ "$http_code" = "200" ]; then
        new_id="$(jq -r '.project.id // empty' < "$response_file")"
        if [ -z "$new_id" ]; then
            print_warning "Row '${handle}': Neon returned ${http_code} but no project.id in body"
            cat "$response_file" | sed 's/^/    /' >&2
            HAD_ERROR=$((HAD_ERROR + 1))
            echo "${handle},${github_user},${email},${cohort},${neon_branch},${github_full_repo}," >> "$new_csv"
            rm -f "$response_file"
            continue
        fi
        print_success "Row '${handle}': created Neon project '${project_name}' (id=${new_id})"
        CREATED=$((CREATED + 1))
        echo "${handle},${github_user},${email},${cohort},${neon_branch},${github_full_repo},${new_id}" >> "$new_csv"
    else
        print_warning "Row '${handle}': Neon API returned HTTP ${http_code} for project '${project_name}'"
        cat "$response_file" 2>/dev/null | sed 's/^/    /' >&2 || true
        HAD_ERROR=$((HAD_ERROR + 1))
        echo "${handle},${github_user},${email},${cohort},${neon_branch},${github_full_repo}," >> "$new_csv"
    fi
    rm -f "$response_file"
done < <(tail -n +2 "$ROSTER_CSV")

# ───────────────────────────────────────────────────────────────────
#  Apply CSV update (or report dry-run summary)
# ───────────────────────────────────────────────────────────────────
echo ""
echo "─────────────────────────────────"
echo "  Summary"
echo "─────────────────────────────────"
echo "  Created (new):     $CREATED"
echo "  Reused (existing): $REUSED"
echo "  Skipped (had id):  $SKIPPED"
echo "  Failed:            $HAD_ERROR"
echo "─────────────────────────────────"
echo ""

if [ "$DRY_RUN" = "true" ]; then
    print_info "Dry-run: roster file unchanged."
    exit 0
fi

# Swap CSV atomically
cp "$ROSTER_CSV" "${ROSTER_CSV}.bak"
mv "$new_csv" "$ROSTER_CSV"
print_success "Updated $ROSTER_CSV with neon_project_id values (backup: ${ROSTER_CSV}.bak)"

if [ "$HAD_ERROR" -gt 0 ]; then
    print_warning "${HAD_ERROR} row(s) failed; see WARNs above."
    print_info "Re-run after resolving the underlying Neon API issue (the script is idempotent)."
    exit 2
fi

print_success "All rows reconciled."
exit 0
