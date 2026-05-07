#!/usr/bin/env bash
# install-evidence-page.sh — bring the per-PR evidence-page capability into
# an existing fork of agile-flow-gcp.
#
# New forks of the framework get this for free — the runtime ships in the
# template's app/ scaffolding. This script exists for forks that predate
# the evidence-page branch and need to catch up without waiting for an
# upstream rebase.
#
# What it does:
#   1. Verifies it's running in an agile-flow-gcp-shaped repo and not on
#      `main` (we never commit directly to main).
#   2. Skips cleanly if the runtime is already installed (idempotent).
#   3. Fetches the runtime files from this framework branch via curl:
#        - app/evidence.py
#        - app/api/evidence.py
#        - templates/evidence.html
#        - tests/test_evidence.py
#   4. Appends the evidence-page CSS block to static/style.css (only if
#      the marker comment is absent).
#   5. Replaces app/main.py with the create_app(settings) factory shape,
#      after backing the original up. If app/main.py has been customized
#      beyond the template, the script bails and writes the new file as
#      app/main.py.evidence-template for the user to merge by hand.
#   6. Prints next-steps for testing and committing.
#
# Configuration (env vars):
#   AGILE_FLOW_REF  — git ref to fetch files from. Defaults to `main`,
#                     which is correct after #170 merges. During the
#                     transition window, set to
#                     `feature/issue-170-evidence-pages`.
#   AGILE_FLOW_REPO — owner/repo to fetch from. Default vibeacademy/agile-flow-gcp.
#
# Tracked in vibeacademy/agile-flow-gcp#170.

set -euo pipefail

REPO="${AGILE_FLOW_REPO:-vibeacademy/agile-flow-gcp}"
REF="${AGILE_FLOW_REF:-main}"
RAW_BASE="https://raw.githubusercontent.com/${REPO}/${REF}"

color_red() { printf '\033[31m%s\033[0m\n' "$*"; }
color_green() { printf '\033[32m%s\033[0m\n' "$*"; }
color_yellow() { printf '\033[33m%s\033[0m\n' "$*"; }
info() { printf '→ %s\n' "$*"; }
fail() { color_red "✗ $*" >&2; exit 1; }

# --- Preflight -----------------------------------------------------------

[[ -d .git ]] || fail "Run this from the root of your agile-flow-gcp fork (no .git here)."
[[ -f pyproject.toml ]] || fail "No pyproject.toml — does not look like an agile-flow-gcp fork."
[[ -f app/main.py ]] || fail "app/main.py missing — does not look like an agile-flow-gcp fork."

current_branch=$(git rev-parse --abbrev-ref HEAD)
if [[ "$current_branch" == "main" ]]; then
  fail "You're on main. Create a feature branch first:
    git checkout -b feature/install-evidence-page"
fi

if ! command -v curl >/dev/null 2>&1; then
  fail "curl is required."
fi

info "Fetching from ${REPO}@${REF}"

# --- Idempotency check ---------------------------------------------------

if [[ -f app/evidence.py && -f app/api/evidence.py ]]; then
  color_green "✓ Evidence runtime already installed (app/evidence.py + app/api/evidence.py present)."
  info "Nothing to do. If you want to refresh files from upstream, delete them first."
  exit 0
fi

# --- Fetch helper --------------------------------------------------------

fetch() {
  # fetch <remote-relative-path> <local-path>
  local remote="$1" local_path="$2"
  mkdir -p "$(dirname "$local_path")"
  if ! curl -fsSL "${RAW_BASE}/${remote}" -o "$local_path"; then
    fail "Could not fetch ${remote} from ${REPO}@${REF}.
Check that AGILE_FLOW_REF is set correctly and that the branch exists."
  fi
  info "wrote $local_path"
}

# --- Copy runtime files --------------------------------------------------

fetch app/evidence.py app/evidence.py
fetch app/api/evidence.py app/api/evidence.py
fetch templates/evidence.html templates/evidence.html
fetch tests/test_evidence.py tests/test_evidence.py

# --- Append CSS block (idempotent) ---------------------------------------

CSS_MARKER="/* Evidence page (preview-only) */"
if [[ -f static/style.css ]] && grep -qF "$CSS_MARKER" static/style.css; then
  info "skipped static/style.css (already contains evidence-page block)"
else
  tmp_css=$(mktemp)
  curl -fsSL "${RAW_BASE}/static/style.css" -o "$tmp_css" || fail "Could not fetch static/style.css"
  if [[ -f static/style.css ]]; then
    # Append only the evidence-page section (everything from the marker onward).
    start_line=$(grep -nF "$CSS_MARKER" "$tmp_css" | head -1 | cut -d: -f1)
    if [[ -z "$start_line" ]]; then
      fail "Upstream static/style.css is missing the '${CSS_MARKER}' marker — installer needs an update."
    fi
    # Insert a leading blank line so the appended block doesn't run into existing rules.
    printf '\n' >> static/style.css
    tail -n "+${start_line}" "$tmp_css" >> static/style.css
    info "appended evidence-page block to static/style.css"
  else
    cp "$tmp_css" static/style.css
    info "wrote static/style.css"
  fi
  rm -f "$tmp_css"
fi

# --- Patch app/main.py ---------------------------------------------------

if grep -q "def create_app" app/main.py; then
  info "skipped app/main.py (already uses create_app factory)"
else
  ts=$(date +%Y%m%d-%H%M%S)
  backup="app/main.py.bak.${ts}"
  cp app/main.py "$backup"
  info "backed up existing app/main.py → ${backup}"

  tmp_main=$(mktemp)
  curl -fsSL "${RAW_BASE}/app/main.py" -o "$tmp_main" || fail "Could not fetch app/main.py"

  # Detect substantial divergence from the framework template. The pre-
  # evidence template main.py is short and stylized; if the user has added
  # routers, middleware, or lifespan hooks, we shouldn't clobber it.
  divergence=0
  if grep -qE "include_router\(" app/main.py; then
    extra_routers=$(grep -c "include_router(" app/main.py || true)
    # Template has 2 routers (health, todos). More than 2 → user has added.
    if [[ "$extra_routers" -gt 2 ]]; then divergence=1; fi
  fi
  if grep -qE "app\.add_middleware|app\.middleware|lifespan=" app/main.py; then
    divergence=1
  fi

  if [[ "$divergence" -eq 1 ]]; then
    mv "$tmp_main" app/main.py.evidence-template
    color_yellow "! app/main.py looks customized; not overwriting."
    info "wrote app/main.py.evidence-template — merge it into app/main.py by hand."
    info "Key change: wrap the FastAPI() construction in a create_app(settings) factory"
    info "and conditionally include app.api.evidence.router when settings.environment == 'preview'."
  else
    mv "$tmp_main" app/main.py
    info "wrote app/main.py (factory shape; original saved at ${backup})"
  fi
fi

# --- Done ----------------------------------------------------------------

echo
color_green "✓ Evidence-page runtime installed."
cat <<'NEXT'

Next steps:

  1. Run the test suite to confirm nothing regressed:

       uv run pytest

     You should see test_evidence.py contributing 8 new passing tests.

  2. Review the changes:

       git status
       git diff

  3. If app/main.py.evidence-template was written, merge it into app/main.py
     by hand, then delete the template file.

  4. Commit and open a PR per your normal workflow:

       git add app/ templates/ static/ tests/
       git commit -m "feat(evidence): install per-PR evidence page"
       git push -u origin HEAD

  5. After the preview deploy succeeds, hit /healthz/evidence on the
     preview URL to confirm the framework starter sections probe green
     against PostgreSQL.

  See docs/EVIDENCE-PAGES.md for the full model and how to add a section
  per acceptance criterion in future PRs.

NEXT
