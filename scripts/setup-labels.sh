#!/bin/bash
#
# Agile Flow — Canonical Label Setup
#
# Creates or updates the framework's canonical GitHub label set on a
# repo. Idempotent: existing labels with matching name + color +
# description are left alone; mismatched ones are updated; missing
# ones are created.
#
# The canonical label set is the labels referenced by:
#   - /bootstrap-workflow (Phase 4: priority labels P0/P1/P2/P3)
#   - /groom-backlog (priorities, epic)
#   - agile-backlog-prioritizer agent (priorities, epic)
#   - github-ticket-worker, pr-reviewer agents (workflow labels)
#
# Without this script (or an equivalent one-time UI setup), a fresh
# fork ships with only GitHub's default labels (bug, documentation,
# enhancement, etc.) — none of the priority or workflow labels the
# framework references exist. The agents either fail when applying
# a label or improvise a label set, leading to cohort-to-cohort
# drift. See #112.
#
# Usage:
#   bash scripts/setup-labels.sh                    # uses current repo
#   bash scripts/setup-labels.sh --repo owner/name  # explicit repo
#   bash scripts/setup-labels.sh --dry-run          # preview, no writes
#
# Prerequisites:
#   - gh CLI installed and authenticated with a token that has admin
#     write on the target repo (labels require write on Issues + Repo
#     Metadata; classic `repo` scope or fine-grained `Issues: write`
#     + `Metadata: read`).
#   - Run from the repo root if --repo is omitted (auto-detection
#     reads `gh repo view`).
#
# Exit codes:
#   0 — labels are in their canonical state
#   1 — gh missing, repo not detectable, or non-recoverable error
#   2 — admin write missing on target repo (per-call WARNs surface
#       individual label failures; the script keeps going and exits 2
#       at the end so callers know "labels are not in canonical state")
#
# See also: docs/AGENTIC-CONTROLS.md (where label conventions belong).

set -uo pipefail

# Ensure bash even if invoked as `zsh scripts/setup-labels.sh`
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
#  Canonical label set
#
#  Format: "name|color-without-hash|description"
#  Order matters only for deterministic output.
#
#  Source of truth: this list. Anywhere else in the framework that
#  references a label name must match. If you add a label here, also
#  document it in docs/AGENTIC-CONTROLS.md or wherever the
#  conventions live.
# ───────────────────────────────────────────────────────────────────
CANONICAL_LABELS=(
    "P0|d73a4a|Critical priority - blocks other work"
    "P1|e99695|High priority - important work"
    "P2|fbca04|Medium priority - normal work"
    "P3|cccccc|Low priority - nice to have"
    "epic|0052cc|Epic — groups related issues into a deliverable phase"
)

# ───────────────────────────────────────────────────────────────────
#  Argument parsing
# ───────────────────────────────────────────────────────────────────
DRY_RUN=false
REPO=""

while [ $# -gt 0 ]; do
    case "$1" in
        --repo)
            REPO="$2"
            shift 2
            ;;
        --repo=*)
            REPO="${1#--repo=}"
            shift
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --help|-h)
            sed -n '2,/^$/p' "$0" | sed 's/^# \{0,1\}//'
            exit 0
            ;;
        *)
            print_error "Unknown argument: $1"
            print_info "Usage: setup-labels.sh [--repo owner/name] [--dry-run]"
            exit 1
            ;;
    esac
done

# ───────────────────────────────────────────────────────────────────
#  Pre-flight
# ───────────────────────────────────────────────────────────────────
echo ""
echo -e "${CYAN}=== Agile Flow — Canonical Label Setup ===${NC}"
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

print_info "Target repo: ${REPO}"
if [ "$DRY_RUN" = "true" ]; then
    print_info "Dry-run mode: no writes will be made"
fi
echo ""

# ───────────────────────────────────────────────────────────────────
#  Reconcile each canonical label
# ───────────────────────────────────────────────────────────────────
NEEDS_WRITE=0
HAD_ERROR=0

for entry in "${CANONICAL_LABELS[@]}"; do
    IFS='|' read -r name color description <<< "$entry"

    # Look up the existing label (if any) via gh api.
    existing=$(gh api "repos/${REPO}/labels/${name}" 2>/dev/null || true)

    if [ -z "$existing" ]; then
        # Label does not exist: create.
        if [ "$DRY_RUN" = "true" ]; then
            print_info "WOULD CREATE: ${name} (color #${color})"
            NEEDS_WRITE=$((NEEDS_WRITE + 1))
            continue
        fi
        if gh api "repos/${REPO}/labels" \
            -f "name=${name}" \
            -f "color=${color}" \
            -f "description=${description}" \
            >/dev/null 2>&1; then
            print_success "Created: ${name}"
        else
            # Likely missing admin / Issues: write. Don't bail; record
            # and continue so the user sees the full list of failures.
            print_warning "Failed to create '${name}' (likely missing admin/write permission)"
            HAD_ERROR=$((HAD_ERROR + 1))
        fi
    else
        # Label exists: compare and update if name/color/description drift.
        existing_color=$(echo "$existing" | jq -r .color)
        existing_desc=$(echo "$existing" | jq -r '.description // ""')

        if [ "$existing_color" = "$color" ] && [ "$existing_desc" = "$description" ]; then
            print_success "Already canonical: ${name}"
        else
            if [ "$DRY_RUN" = "true" ]; then
                print_info "WOULD UPDATE: ${name}"
                print_info "    color:       ${existing_color} -> ${color}"
                print_info "    description: '${existing_desc}' -> '${description}'"
                NEEDS_WRITE=$((NEEDS_WRITE + 1))
                continue
            fi
            if gh api -X PATCH "repos/${REPO}/labels/${name}" \
                -f "new_name=${name}" \
                -f "color=${color}" \
                -f "description=${description}" \
                >/dev/null 2>&1; then
                print_success "Updated: ${name} (color/desc reconciled)"
            else
                print_warning "Failed to update '${name}' (likely missing admin/write permission)"
                HAD_ERROR=$((HAD_ERROR + 1))
            fi
        fi
    fi
done

echo ""

# ───────────────────────────────────────────────────────────────────
#  Summary
# ───────────────────────────────────────────────────────────────────
if [ "$DRY_RUN" = "true" ]; then
    if [ "$NEEDS_WRITE" -eq 0 ]; then
        print_success "Dry-run: all canonical labels are already in their canonical state."
        exit 0
    fi
    print_info "Dry-run: ${NEEDS_WRITE} label(s) would be created/updated."
    print_info "Re-run without --dry-run to apply."
    exit 0
fi

if [ "$HAD_ERROR" -gt 0 ]; then
    print_warning "${HAD_ERROR} label(s) could not be reconciled (see WARNs above)."
    print_info "If you lack admin/write on this repo, ask the repo owner to run this script."
    exit 2
fi

print_success "All canonical labels are present and current on ${REPO}."
exit 0
