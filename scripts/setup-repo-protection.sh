#!/bin/bash
#
# Agile Flow — Branch Protection Setup
#
# Configures branch protection on `main` to match the framework's
# expectations. Idempotent: re-running on a correctly-protected
# branch is a no-op (the API call is PUT-style, so it always sets
# the desired state regardless of prior state).
#
# Required protections (matching CLAUDE.md's "Critical Rules"):
#   - Require pull request reviews (≥1 approving review)
#   - Require status checks to pass (strict: branches must be up-to-date)
#   - Require linear history (no merge commits — squash or rebase only)
#   - Block direct pushes to main
#   - Block force pushes to main
#   - Block branch deletion
#
# Why this is a separate script (not part of bootstrap-workflow's
# Phase 4): branch protection requires admin write on the target
# repo. Under the May 2026 workshop architecture, attendee repos
# live under `vibeacademy/<handle>` with attendees having WRITE but
# NOT admin. The facilitator owns admin and runs this script
# per-attendee-repo at provisioning time. See #114.
#
# For personal-account forks (the non-workshop path), the user can
# also run this script themselves — they have admin on their own
# fork. Or configure manually via the Settings → Branches UI.
#
# Usage:
#   bash scripts/setup-repo-protection.sh                    # current repo
#   bash scripts/setup-repo-protection.sh --repo owner/name  # explicit
#   bash scripts/setup-repo-protection.sh --branch dev       # custom branch
#   bash scripts/setup-repo-protection.sh --dry-run          # preview
#
# Prerequisites:
#   - gh CLI installed and authenticated with admin write on the
#     target repo (classic `repo` + `admin:repo_hook` scopes, or
#     fine-grained `Administration: Read and write`)
#   - Run from the repo root if --repo is omitted (auto-detect via
#     `gh repo view`)
#
# Exit codes:
#   0 — branch protection applied (or already-correct)
#   1 — gh missing, repo not detectable, branch missing, or other
#       non-recoverable error
#   2 — admin write missing on target repo
#
# See also: .claude/commands/bootstrap-workflow.md Step 3 for the
# manual UI fallback when the script can't be run.

set -uo pipefail

# Ensure bash even if invoked as `zsh scripts/setup-repo-protection.sh`
if [ -z "${BASH_VERSION:-}" ]; then
    exec bash "$0" "$@"
fi

# ───────────────────────────────────────────────────────────────────
#  Colors + print helpers (matches setup-solo-mode.sh shape)
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
REPO=""
BRANCH="main"
DRY_RUN=false

show_help() {
    sed -n '2,/^$/p' "$0" | sed 's/^# \{0,1\}//'
}

while [ $# -gt 0 ]; do
    case "$1" in
        --repo)        REPO="$2"; shift 2 ;;
        --repo=*)      REPO="${1#--repo=}"; shift ;;
        --branch)      BRANCH="$2"; shift 2 ;;
        --branch=*)    BRANCH="${1#--branch=}"; shift ;;
        --dry-run)     DRY_RUN=true; shift ;;
        -h|--help)     show_help; exit 0 ;;
        *)
            print_error "Unknown argument: $1"
            print_info "Usage: setup-repo-protection.sh [--repo owner/name] [--branch main] [--dry-run]"
            exit 1
            ;;
    esac
done

# ───────────────────────────────────────────────────────────────────
#  Pre-flight
# ───────────────────────────────────────────────────────────────────
echo ""
echo -e "${CYAN}=== Agile Flow — Branch Protection Setup ===${NC}"
echo ""

if ! command -v gh >/dev/null 2>&1; then
    print_error "gh CLI not found on PATH"
    print_info "Install: https://cli.github.com/"
    exit 1
fi

if [ -z "$REPO" ]; then
    REPO=$(gh repo view --json nameWithOwner -q .nameWithOwner 2>/dev/null || true)
    if [ -z "$REPO" ]; then
        print_error "Could not auto-detect repo (no 'origin' remote, or gh not authenticated)"
        print_info "Pass --repo owner/name explicitly, or run from a repo with an origin remote"
        exit 1
    fi
fi

print_info "Target repo:   ${REPO}"
print_info "Target branch: ${BRANCH}"
if [ "$DRY_RUN" = "true" ]; then
    print_info "Dry-run mode: no writes will be made"
fi
echo ""

# ───────────────────────────────────────────────────────────────────
#  Verify branch exists
# ───────────────────────────────────────────────────────────────────
if ! gh api "repos/${REPO}/branches/${BRANCH}" >/dev/null 2>&1; then
    print_error "Branch '${BRANCH}' not found in ${REPO}"
    print_info "Push at least one commit to ${BRANCH} before running this script."
    exit 1
fi

# ───────────────────────────────────────────────────────────────────
#  Build the desired protection payload
#
#  Format reference:
#  https://docs.github.com/en/rest/branches/branch-protection?apiVersion=2022-11-28#update-branch-protection
# ───────────────────────────────────────────────────────────────────
read -r -d '' PROTECTION_JSON <<'JSON' || true
{
  "required_status_checks": null,
  "enforce_admins": false,
  "required_pull_request_reviews": {
    "dismiss_stale_reviews": false,
    "require_code_owner_reviews": false,
    "required_approving_review_count": 1,
    "require_last_push_approval": false
  },
  "restrictions": null,
  "required_linear_history": true,
  "allow_force_pushes": false,
  "allow_deletions": false,
  "block_creations": false,
  "required_conversation_resolution": false,
  "lock_branch": false,
  "allow_fork_syncing": false
}
JSON

# Notes on the chosen settings:
#
# - `required_status_checks: null` — set to null because the framework
#   doesn't know which CI checks each fork has named at provisioning
#   time. Facilitators who want to enforce specific checks can re-run
#   with a customized payload after CI is green; #114 keeps the script
#   to "the universal subset that always applies."
# - `enforce_admins: false` — facilitators occasionally need to bypass
#   protection for emergency fixes; admin-bypass is an escape valve.
# - `required_approving_review_count: 1` — matches CLAUDE.md's "PRs
#   require review before merge" rule.
# - `required_linear_history: true` — squash or rebase only; matches
#   CLAUDE.md's "short-lived feature branches" model.
# - `allow_force_pushes: false`, `allow_deletions: false`,
#   `restrictions: null` — block direct pushes by default; restrictions
#   can be tightened later per-cohort.

# ───────────────────────────────────────────────────────────────────
#  Compare current state to desired state for idempotency
# ───────────────────────────────────────────────────────────────────
current=$(gh api "repos/${REPO}/branches/${BRANCH}/protection" 2>/dev/null || echo "")

needs_update=true
if [ -n "$current" ]; then
    # Compare the fields we set. The GET endpoint returns a richer
    # shape than the PUT accepts, so we extract the equivalent.
    #
    # jq gotcha: the `//` operator treats BOTH null AND false as
    # "absent," so `.allow_force_pushes.enabled // true` returns
    # `true` when the value is literally `false`. Use explicit
    # null-checking with if/then/else to preserve `false` values.
    cur_pr_reviews=$(echo "$current" | jq -r '.required_pull_request_reviews.required_approving_review_count // 0')
    cur_linear=$(echo "$current" | jq -r 'if .required_linear_history.enabled == null then "false" else (.required_linear_history.enabled | tostring) end')
    cur_force=$(echo "$current" | jq -r 'if .allow_force_pushes.enabled == null then "true" else (.allow_force_pushes.enabled | tostring) end')
    cur_delete=$(echo "$current" | jq -r 'if .allow_deletions.enabled == null then "true" else (.allow_deletions.enabled | tostring) end')

    if [ "$cur_pr_reviews" = "1" ] \
       && [ "$cur_linear" = "true" ] \
       && [ "$cur_force" = "false" ] \
       && [ "$cur_delete" = "false" ]; then
        needs_update=false
    fi
fi

if [ "$needs_update" = "false" ]; then
    print_success "Branch protection on '${BRANCH}' is already in canonical state."
    exit 0
fi

if [ "$DRY_RUN" = "true" ]; then
    print_info "Dry-run: would PUT branch protection with:"
    echo "$PROTECTION_JSON" | sed 's/^/    /'
    print_info "Re-run without --dry-run to apply."
    exit 0
fi

# ───────────────────────────────────────────────────────────────────
#  Apply protection
# ───────────────────────────────────────────────────────────────────
if echo "$PROTECTION_JSON" | gh api -X PUT \
    "repos/${REPO}/branches/${BRANCH}/protection" \
    --input - >/dev/null 2>&1; then
    print_success "Branch protection applied to ${REPO}:${BRANCH}"
    print_info "  Reviews required:    1 approving review"
    print_info "  Status checks:       not required (configure per-cohort)"
    print_info "  Linear history:      required"
    print_info "  Force-push:          blocked"
    print_info "  Direct push to main: blocked"
    print_info "  Branch deletion:     blocked"
    exit 0
else
    err=$(echo "$PROTECTION_JSON" | gh api -X PUT \
        "repos/${REPO}/branches/${BRANCH}/protection" \
        --input - 2>&1 || true)
    print_error "Failed to apply branch protection."
    echo "$err" | sed 's/^/    /' >&2
    if echo "$err" | grep -qE "404|Not Found|Resource not accessible"; then
        print_warning "This usually means the active gh token lacks admin write on ${REPO}."
        print_info "Required scopes: classic 'repo' + 'admin:repo_hook',"
        print_info "  OR fine-grained 'Administration: Read and write'."
        exit 2
    fi
    exit 1
fi
