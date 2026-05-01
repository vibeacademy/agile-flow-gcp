#!/usr/bin/env bash
#
# Tests for setup-labels.sh — canonical label reconciliation. Stubs
# `gh` to simulate the four states each canonical label can be in:
#   1. Missing (create path)
#   2. Already canonical (no-op path)
#   3. Drifted (update path: color or description differs)
#   4. Write denied (admin missing)
#
# Run: ./scripts/setup-labels.test.sh

set -uo pipefail

GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

PASS=0
FAIL=0

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT="$REPO_ROOT/scripts/setup-labels.sh"

new_sandbox() { mktemp -d -t aflowlabels-XXXX; }

# Stub `gh` whose behavior is controlled by env vars set per-test.
# Modes:
#   STUB_LABEL_STATE=missing      — every GET returns 404 (label missing).
#   STUB_LABEL_STATE=canonical    — every GET returns the canonical row.
#   STUB_LABEL_STATE=drifted      — every GET returns drifted color.
#   STUB_LABEL_STATE=denied       — every POST/PATCH returns 403.
#   STUB_LABEL_STATE=mixed        — P0 missing, P1 canonical, P2 drifted.
# All other gh invocations succeed quietly.
make_gh_stub() {
    local sandbox="$1"
    mkdir -p "$sandbox/bin"

    cat > "$sandbox/bin/gh" <<'STUB_EOF'
#!/usr/bin/env bash
set -uo pipefail
echo "gh $*" >> "$STUB_STATE/gh.log"

# Recognize calls:
#   gh repo view --json nameWithOwner -q .nameWithOwner
#   gh api repos/<owner>/<repo>/labels/<name>            (GET, lookup)
#   gh api repos/<owner>/<repo>/labels                    (POST -f name= ...)
#   gh api -X PATCH repos/<owner>/<repo>/labels/<name>    (UPDATE)

# repo auto-detect
if [[ "$1" == "repo" && "$2" == "view" ]]; then
    echo "test-org/test-repo"
    exit 0
fi

# api calls
if [[ "$1" == "api" ]]; then
    # Detect the kind of call
    method="GET"
    path=""
    is_label_lookup=false
    is_label_create=false
    is_label_update=false

    # walk args
    shift
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -X) method="$2"; shift 2 ;;
            -f) shift 2 ;;
            --jq) shift 2 ;;
            *)
                if [[ -z "$path" ]]; then
                    path="$1"
                fi
                shift
                ;;
        esac
    done

    label_name=""
    if [[ "$path" =~ /labels/([A-Za-z0-9_-]+)$ ]]; then
        label_name="${BASH_REMATCH[1]}"
        if [[ "$method" == "PATCH" ]]; then
            is_label_update=true
        else
            is_label_lookup=true
        fi
    elif [[ "$path" =~ /labels$ ]] && [[ "$method" == "POST" || "$method" == "GET" ]]; then
        # Treat /labels with no trailing name as create when -f was used.
        # We can't easily detect that here since we already consumed -f flags;
        # err on the side of "this is a create call from setup-labels.sh".
        is_label_create=true
    fi

    state="${STUB_LABEL_STATE:-missing}"

    if $is_label_lookup; then
        # In mixed mode, P0 missing, P1 canonical, P2 drifted, others canonical
        effective_state="$state"
        if [[ "$state" == "mixed" ]]; then
            case "$label_name" in
                P0) effective_state="missing" ;;
                P1) effective_state="canonical" ;;
                P2) effective_state="drifted" ;;
                *)  effective_state="canonical" ;;
            esac
        fi

        case "$effective_state" in
            missing)
                # 404 — non-zero exit, no output (mirrors `gh api` behavior)
                exit 1
                ;;
            canonical)
                # Return the exact canonical row for this label.
                # The script uses jq on .color and .description, so emit JSON.
                case "$label_name" in
                    P0) cat <<'JSON'
{"name":"P0","color":"d73a4a","description":"Critical priority - blocks other work"}
JSON
                        ;;
                    P1) cat <<'JSON'
{"name":"P1","color":"e99695","description":"High priority - important work"}
JSON
                        ;;
                    P2) cat <<'JSON'
{"name":"P2","color":"fbca04","description":"Medium priority - normal work"}
JSON
                        ;;
                    P3) cat <<'JSON'
{"name":"P3","color":"cccccc","description":"Low priority - nice to have"}
JSON
                        ;;
                    epic) cat <<'JSON'
{"name":"epic","color":"0052cc","description":"Epic — groups related issues into a deliverable phase"}
JSON
                        ;;
                esac
                exit 0
                ;;
            drifted)
                # Wrong color and description so the script triggers an update.
                cat <<JSON
{"name":"$label_name","color":"000000","description":"old description"}
JSON
                exit 0
                ;;
        esac
    fi

    if $is_label_create; then
        if [[ "$state" == "denied" ]]; then
            exit 1
        fi
        echo "{\"name\":\"$label_name\"}"
        exit 0
    fi

    if $is_label_update; then
        if [[ "$state" == "denied" ]]; then
            exit 1
        fi
        echo "{\"name\":\"$label_name\"}"
        exit 0
    fi

    exit 0
fi

exit 0
STUB_EOF
    chmod +x "$sandbox/bin/gh"
}

# Run script in a clean env. Forward STUB_* vars.
run_script() {
    local sandbox="$1"
    shift
    env -i \
        HOME="$sandbox" \
        PATH="$sandbox/bin:/usr/bin:/bin:/usr/local/bin" \
        STUB_STATE="$sandbox" \
        TERM="${TERM:-dumb}" \
        "$@" \
        bash "$SCRIPT" --repo test-org/test-repo
}

assert_eq() {
    local expected="$1" actual="$2" label="$3"
    if [[ "$expected" == "$actual" ]]; then
        echo -e "  ${GREEN}OK${NC} $label"
        PASS=$((PASS + 1))
    else
        echo -e "  ${RED}FAIL${NC} $label  (expected: $expected; got: $actual)"
        FAIL=$((FAIL + 1))
    fi
}

assert_contains() {
    local needle="$1" file="$2" label="$3"
    if grep -qF "$needle" "$file"; then
        echo -e "  ${GREEN}OK${NC} $label"
        PASS=$((PASS + 1))
    else
        echo -e "  ${RED}FAIL${NC} $label  (expected to contain: $needle)"
        echo "  --- file content ---"
        sed -e 's/^/  /' "$file"
        echo "  --------------------"
        FAIL=$((FAIL + 1))
    fi
}

assert_not_contains() {
    local needle="$1" file="$2" label="$3"
    if ! grep -qF "$needle" "$file"; then
        echo -e "  ${GREEN}OK${NC} $label"
        PASS=$((PASS + 1))
    else
        echo -e "  ${RED}FAIL${NC} $label  (should NOT contain: $needle)"
        FAIL=$((FAIL + 1))
    fi
}

# ── Test 1: All labels missing → 5 creates, exit 0 ────────────────────

echo ""
echo "Test 1: empty repo (all labels missing) → creates all 5"

T1=$(new_sandbox)
make_gh_stub "$T1"

set +e
run_script "$T1" \
    STUB_LABEL_STATE="missing" \
    > "$T1/run.log" 2>&1
ec=$?
set -e

assert_eq "0" "$ec" "exit 0"
assert_contains "Created: P0" "$T1/run.log" "P0 created"
assert_contains "Created: P1" "$T1/run.log" "P1 created"
assert_contains "Created: P2" "$T1/run.log" "P2 created"
assert_contains "Created: P3" "$T1/run.log" "P3 created"
assert_contains "Created: epic" "$T1/run.log" "epic created"
assert_contains "All canonical labels are present" "$T1/run.log" "summary success"

# ── Test 2: All labels already canonical → no-op, exit 0 ──────────────

echo ""
echo "Test 2: all labels already canonical → no-op (idempotent re-run)"

T2=$(new_sandbox)
make_gh_stub "$T2"

set +e
run_script "$T2" \
    STUB_LABEL_STATE="canonical" \
    > "$T2/run.log" 2>&1
ec=$?
set -e

assert_eq "0" "$ec" "exit 0"
assert_contains "Already canonical: P0" "$T2/run.log" "P0 noted as canonical"
assert_contains "Already canonical: epic" "$T2/run.log" "epic noted as canonical"
assert_not_contains "Created:" "$T2/run.log" "no creates on canonical re-run"
assert_not_contains "Updated:" "$T2/run.log" "no updates on canonical re-run"

# ── Test 3: All labels drifted → 5 updates, exit 0 ────────────────────

echo ""
echo "Test 3: all labels drifted (wrong color/description) → updates all 5"

T3=$(new_sandbox)
make_gh_stub "$T3"

set +e
run_script "$T3" \
    STUB_LABEL_STATE="drifted" \
    > "$T3/run.log" 2>&1
ec=$?
set -e

assert_eq "0" "$ec" "exit 0"
assert_contains "Updated: P0" "$T3/run.log" "P0 updated"
assert_contains "Updated: P3" "$T3/run.log" "P3 updated"
assert_contains "Updated: epic" "$T3/run.log" "epic updated"
assert_not_contains "Created:" "$T3/run.log" "no creates when label exists"

# ── Test 4: Mixed state (missing + canonical + drifted) → exit 0 ─────

echo ""
echo "Test 4: mixed state (P0 missing, P1 canonical, P2 drifted)"

T4=$(new_sandbox)
make_gh_stub "$T4"

set +e
run_script "$T4" \
    STUB_LABEL_STATE="mixed" \
    > "$T4/run.log" 2>&1
ec=$?
set -e

assert_eq "0" "$ec" "exit 0"
assert_contains "Created: P0" "$T4/run.log" "P0 created (was missing)"
assert_contains "Already canonical: P1" "$T4/run.log" "P1 noted canonical"
assert_contains "Updated: P2" "$T4/run.log" "P2 updated (was drifted)"

# ── Test 5: Write denied → fail-soft, exit 2 ─────────────────────────

echo ""
echo "Test 5: write permission denied → exit 2, WARN per failed label"

T5=$(new_sandbox)
make_gh_stub "$T5"

set +e
run_script "$T5" \
    STUB_LABEL_STATE="denied" \
    > "$T5/run.log" 2>&1
ec=$?
set -e

assert_eq "2" "$ec" "exit 2 (admin missing)"
assert_contains "Failed to create 'P0'" "$T5/run.log" "P0 failure surfaced"
assert_contains "Failed to create 'epic'" "$T5/run.log" "epic failure surfaced"
assert_contains "could not be reconciled" "$T5/run.log" "summary mentions failures"
# Critical: the script must NOT exit 1 mid-loop. It should walk all labels
# and surface every failure. Verify all 5 are listed.
fail_count=$(grep -c "Failed to" "$T5/run.log" || true)
assert_eq "5" "$fail_count" "all 5 failures surfaced (no early-exit on first fail)"

# ── Test 6: Dry-run (missing labels) → reports without writing ────────

echo ""
echo "Test 6: --dry-run mode → reports planned writes without making them"

T6=$(new_sandbox)
make_gh_stub "$T6"

set +e
env -i \
    HOME="$T6" \
    PATH="$T6/bin:/usr/bin:/bin:/usr/local/bin" \
    STUB_STATE="$T6" \
    TERM="${TERM:-dumb}" \
    STUB_LABEL_STATE="missing" \
    bash "$SCRIPT" --repo test-org/test-repo --dry-run \
    > "$T6/run.log" 2>&1
ec=$?
set -e

assert_eq "0" "$ec" "exit 0"
assert_contains "Dry-run mode: no writes" "$T6/run.log" "dry-run banner"
assert_contains "WOULD CREATE: P0" "$T6/run.log" "P0 marked WOULD CREATE"
assert_contains "Re-run without --dry-run" "$T6/run.log" "guidance to apply"
# Critical: dry-run must NOT have called the create endpoint.
if grep -q "labels -f name=" "$T6/gh.log" 2>/dev/null || grep -q "POST" "$T6/gh.log" 2>/dev/null; then
    echo -e "  ${RED}FAIL${NC} dry-run made a write call"
    FAIL=$((FAIL + 1))
else
    echo -e "  ${GREEN}OK${NC} dry-run made no write calls"
    PASS=$((PASS + 1))
fi

# ── Test 7: --repo flag overrides auto-detection ─────────────────────

echo ""
echo "Test 7: --repo flag is respected"

T7=$(new_sandbox)
make_gh_stub "$T7"

set +e
env -i \
    HOME="$T7" \
    PATH="$T7/bin:/usr/bin:/bin:/usr/local/bin" \
    STUB_STATE="$T7" \
    TERM="${TERM:-dumb}" \
    STUB_LABEL_STATE="canonical" \
    bash "$SCRIPT" --repo explicit-org/explicit-repo \
    > "$T7/run.log" 2>&1
ec=$?
set -e

assert_eq "0" "$ec" "exit 0"
assert_contains "explicit-org/explicit-repo" "$T7/run.log" "uses explicit --repo value"
# Should NOT have called gh repo view (auto-detect path)
if ! grep -q "repo view" "$T7/gh.log" 2>/dev/null; then
    echo -e "  ${GREEN}OK${NC} auto-detect skipped when --repo given"
    PASS=$((PASS + 1))
else
    echo -e "  ${RED}FAIL${NC} called gh repo view despite explicit --repo"
    FAIL=$((FAIL + 1))
fi

# ── Test 8: Unknown flag → exit 1 with usage hint ─────────────────────

echo ""
echo "Test 8: unknown argument → fail fast"

T8=$(new_sandbox)
make_gh_stub "$T8"

set +e
env -i \
    HOME="$T8" \
    PATH="$T8/bin:/usr/bin:/bin:/usr/local/bin" \
    STUB_STATE="$T8" \
    TERM="${TERM:-dumb}" \
    bash "$SCRIPT" --bogus-flag \
    > "$T8/run.log" 2>&1
ec=$?
set -e

assert_eq "1" "$ec" "exit 1 on unknown flag"
assert_contains "Unknown argument" "$T8/run.log" "names the issue"
assert_contains "Usage:" "$T8/run.log" "shows usage hint"

# ── Summary ──────────────────────────────────────────────────────────

echo ""
echo "─────────────────────────────────"
echo "  Passed: $PASS"
echo "  Failed: $FAIL"
echo "─────────────────────────────────"

(( FAIL > 0 )) && exit 1
exit 0
