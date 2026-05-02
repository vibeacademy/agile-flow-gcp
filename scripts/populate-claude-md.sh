#!/bin/bash
#
# Agile Flow — CLAUDE.md placeholder population
#
# Replaces the bracketed placeholders inside CLAUDE.md's
# `<!-- bootstrap:project-config:start --> ... :end --` marker block
# with values derived from `git remote origin` and (when missing)
# user-supplied flags. Idempotent: re-running on a populated block
# does not duplicate or change values that already match.
#
# The marker block in CLAUDE.md MUST exist with both the start and
# end sentinels and exactly four lines between them, in this order:
#
#     - **Project Name**: ...
#     - **Organization**: ...
#     - **Repository**: ...
#     - **Project Board**: ...
#
# Without this script, fresh forks ship with `[Your project name]`
# and `[GitHub repo URL]` text in CLAUDE.md, which is loaded into
# every subsequent agent session's system prompt. See #113.
#
# Usage:
#   bash scripts/populate-claude-md.sh \
#     --project-name "My App" \
#     --project-board "https://github.com/orgs/myorg/projects/1"
#
#   bash scripts/populate-claude-md.sh   # interactive prompts
#
# Flags:
#   --project-name <name>      Project's human-readable name
#   --project-board <url>      Full URL to the GitHub project board
#   --owner <owner>            Override owner derived from git remote
#   --repo <repo>              Override repo name derived from git remote
#   --file <path>              CLAUDE.md path (default: CLAUDE.md in cwd)
#   --dry-run                  Print planned changes; don't write
#   -h | --help                Show this header
#
# Auto-derived from `git remote get-url origin`:
#   - Organization → owner segment of the remote URL
#   - Repository   → full https URL (https://github.com/<owner>/<repo>)
#
# Exit codes:
#   0 — placeholders populated (or already populated)
#   1 — file missing, marker block missing/malformed, or other
#       non-recoverable error
#   2 — required value couldn't be obtained (no git remote AND no
#       --owner override; or interactive run on a non-TTY stdin)
#
# See also: scripts/setup-solo-mode.sh (which invokes this script).

set -uo pipefail

# Ensure bash even if invoked as `zsh scripts/populate-claude-md.sh`
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
PROJECT_NAME=""
PROJECT_BOARD=""
OWNER=""
REPO=""
FILE="CLAUDE.md"
DRY_RUN=false

show_help() {
    sed -n '2,/^$/p' "$0" | sed 's/^# \{0,1\}//'
}

while [ $# -gt 0 ]; do
    case "$1" in
        --project-name)   PROJECT_NAME="$2"; shift 2 ;;
        --project-name=*) PROJECT_NAME="${1#--project-name=}"; shift ;;
        --project-board)  PROJECT_BOARD="$2"; shift 2 ;;
        --project-board=*) PROJECT_BOARD="${1#--project-board=}"; shift ;;
        --owner)          OWNER="$2"; shift 2 ;;
        --owner=*)        OWNER="${1#--owner=}"; shift ;;
        --repo)           REPO="$2"; shift 2 ;;
        --repo=*)         REPO="${1#--repo=}"; shift ;;
        --file)           FILE="$2"; shift 2 ;;
        --file=*)         FILE="${1#--file=}"; shift ;;
        --dry-run)        DRY_RUN=true; shift ;;
        -h|--help)        show_help; exit 0 ;;
        *)
            print_error "Unknown argument: $1"
            print_info "Run with --help for usage."
            exit 1
            ;;
    esac
done

# ───────────────────────────────────────────────────────────────────
#  Pre-flight
# ───────────────────────────────────────────────────────────────────
echo ""
echo -e "${CYAN}=== Agile Flow — CLAUDE.md placeholder population ===${NC}"
echo ""

if [ ! -f "$FILE" ]; then
    print_error "File not found: $FILE"
    exit 1
fi

if ! grep -q '<!-- bootstrap:project-config:start -->' "$FILE"; then
    print_error "Marker block not found in $FILE"
    print_info "Expected: <!-- bootstrap:project-config:start --> ... <!-- bootstrap:project-config:end -->"
    exit 1
fi
if ! grep -q '<!-- bootstrap:project-config:end -->' "$FILE"; then
    print_error "Marker block end sentinel missing in $FILE"
    print_info "Expected: <!-- bootstrap:project-config:end -->"
    exit 1
fi

# ───────────────────────────────────────────────────────────────────
#  Derive owner/repo from git remote when not supplied
# ───────────────────────────────────────────────────────────────────
if [ -z "$OWNER" ] || [ -z "$REPO" ]; then
    remote_url=""
    if command -v git >/dev/null 2>&1; then
        remote_url=$(git remote get-url origin 2>/dev/null || true)
    fi

    if [ -z "$remote_url" ]; then
        if [ -z "$OWNER" ] && [ -z "$REPO" ]; then
            print_error "No git remote found and --owner/--repo not provided."
            print_info "Either run this from a repo with an 'origin' remote,"
            print_info "or pass --owner <name> --repo <name>."
            exit 2
        fi
    else
        # Normalize remote_url. Handles:
        #   git@github.com:owner/repo.git
        #   git@github.com:owner/repo
        #   https://github.com/owner/repo.git
        #   https://github.com/owner/repo
        normalized=$(echo "$remote_url" | sed -E '
            s|^git@github\.com:|/|
            s|^https://github\.com/||
            s|\.git$||
            s|^/||
        ')
        derived_owner=$(echo "$normalized" | cut -d/ -f1)
        derived_repo=$(echo "$normalized" | cut -d/ -f2)

        [ -z "$OWNER" ] && OWNER="$derived_owner"
        [ -z "$REPO" ] && REPO="$derived_repo"
    fi
fi

if [ -z "$OWNER" ] || [ -z "$REPO" ]; then
    print_error "Could not determine owner/repo. Pass --owner and --repo explicitly."
    exit 2
fi

REPO_URL="https://github.com/${OWNER}/${REPO}"

# ───────────────────────────────────────────────────────────────────
#  Interactive prompts for missing values
# ───────────────────────────────────────────────────────────────────
prompt_for() {
    local label="$1" var_name="$2" suggested="$3"

    if [ ! -t 0 ]; then
        # Non-interactive context (Codespace postCreateCommand, CI, piped invocation)
        if [ -n "$suggested" ]; then
            print_warning "$label not provided; using suggested value: $suggested"
            eval "$var_name=\"\$suggested\""
            return 0
        fi
        print_error "$label not provided and stdin is not a TTY (cannot prompt)."
        print_info "Pass --${var_name//_/-} <value> to fill it in."
        exit 2
    fi

    if [ -n "$suggested" ]; then
        echo -ne "${BLUE}? ${label}${NC} [${suggested}]: "
    else
        echo -ne "${BLUE}? ${label}${NC}: "
    fi
    read -r reply
    if [ -z "$reply" ] && [ -n "$suggested" ]; then
        reply="$suggested"
    fi
    eval "$var_name=\"\$reply\""
}

if [ -z "$PROJECT_NAME" ]; then
    prompt_for "Project name" PROJECT_NAME "$REPO"
fi

if [ -z "$PROJECT_BOARD" ]; then
    # Reasonable default: org-scoped projects URL listing.
    suggested_board="https://github.com/orgs/${OWNER}/projects"
    prompt_for "Project board URL" PROJECT_BOARD "$suggested_board"
fi

# ───────────────────────────────────────────────────────────────────
#  Apply replacement inside the marker block
# ───────────────────────────────────────────────────────────────────
new_block=$(cat <<EOF
<!-- bootstrap:project-config:start -->
- **Project Name**: ${PROJECT_NAME}
- **Organization**: ${OWNER}
- **Repository**: ${REPO_URL}
- **Project Board**: ${PROJECT_BOARD}
<!-- bootstrap:project-config:end -->
EOF
)

print_info "Target file:    $FILE"
print_info "Project Name:   $PROJECT_NAME"
print_info "Organization:   $OWNER"
print_info "Repository:     $REPO_URL"
print_info "Project Board:  $PROJECT_BOARD"
echo ""

# Idempotency: if the existing block already matches what we'd write,
# do nothing.
existing_block=$(awk '
    /<!-- bootstrap:project-config:start -->/ { capture=1 }
    capture { print }
    /<!-- bootstrap:project-config:end -->/ { capture=0 }
' "$FILE")

if [ "$existing_block" = "$new_block" ]; then
    print_success "CLAUDE.md project-config block is already up to date."
    exit 0
fi

if [ "$DRY_RUN" = "true" ]; then
    print_info "Dry-run: would replace the marker block with:"
    echo ""
    echo "$new_block" | sed 's/^/    /'
    echo ""
    exit 0
fi

# Replace the block. Stash the new block in a temp file (BSD awk
# doesn't accept multi-line strings via -v, so we read the
# replacement from a sibling file via getline). Works on macOS BSD
# awk and GNU awk.
block_file=$(mktemp -t aflow-claudemd-block-XXXX)
out_file=$(mktemp -t aflow-claudemd-out-XXXX)
trap 'rm -f "$block_file" "$out_file"' EXIT

printf '%s\n' "$new_block" > "$block_file"

awk -v block_file="$block_file" '
    /<!-- bootstrap:project-config:start -->/ {
        # Inject the new block (already contains start + end markers)
        while ((getline line < block_file) > 0) {
            print line
        }
        close(block_file)
        skip = 1
        next
    }
    /<!-- bootstrap:project-config:end -->/ {
        skip = 0
        next
    }
    !skip { print }
' "$FILE" > "$out_file"

mv "$out_file" "$FILE"

print_success "Populated CLAUDE.md project-config block."
exit 0
