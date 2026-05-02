#!/usr/bin/env bash
#
# Tests for setup-repo-protection.sh — branch-protection
# reconciliation. Stubs `gh` to simulate the four states branch
# protection can be in:
#   1. Branch missing entirely (script can't proceed)
#   2. Branch exists, no protection (PUT succeeds — happy path)
#   3. Branch exists, protection in canonical state (no-op)
#   4. Branch exists, protection drifted (PUT succeeds — update path)
#   5. PUT denied (admin missing)
#
# Run: ./scripts/setup-repo-protection.test.sh

set -uo pipefail

GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

PASS=0
FAIL=0

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT="$REPO_ROOT/scripts/setup-repo-protection.sh"

new_sandbox() { mktemp -d -t aflowprotect-XXXX; }

# Stub `gh` whose behavior is controlled by env vars set per-test.
#   STUB_BRANCH_EXISTS=true|false   — does the target branch exist?
#   STUB_PROTECTION_STATE=missing|canonical|drifted|denied
#   STUB_PUT_DENIED=true|false      — does PUT return 403?
make_gh_stub() {
    local sandbox="$1"
    mkdir -p "$sandbox/bin"

    cat > "$sandbox/bin/gh" <<'STUB_EOF'
#!/usr/bin/env bash
set -uo pipefail
echo "gh $*" >> "$STUB_STATE/gh.log"

# repo auto-detect
if [[ "$1" == "repo" && "$2" == "view" ]]; then
    echo "test-org/test-repo"
    exit 0
fi

# api calls
if [[ "$1" == "api" ]]; then
    method="GET"
    path=""
    shift

    while [[ $# -gt 0 ]]; do
        case "$1" in
            -X) method="$2"; shift 2 ;;
            -f) shift 2 ;;
            -F) shift 2 ;;
            --jq) shift 2 ;;
            --input) shift 2 ;;
            *)
                if [[ -z "$path" ]]; then
                    path="$1"
                fi
                shift
                ;;
        esac
    done

    state="${STUB_PROTECTION_STATE:-missing}"
    branch_exists="${STUB_BRANCH_EXISTS:-true}"
    put_denied="${STUB_PUT_DENIED:-false}"

    # Branch existence check
    if [[ "$path" =~ /branches/[^/]+$ ]]; then
        if [[ "$branch_exists" == "true" ]]; then
            echo '{"name":"main","protected":false}'
            exit 0
        else
            echo '{"message":"Branch not found","status":"404"}'
            exit 1
        fi
    fi

    # Protection GET
    if [[ "$path" =~ /branches/[^/]+/protection$ && "$method" == "GET" ]]; then
        case "$state" in
            missing)
                echo '{"message":"Branch not protected","status":"404"}'
                exit 1
                ;;
            canonical)
                cat <<'JSON'
{
  "required_pull_request_reviews": {
    "required_approving_review_count": 1
  },
  "required_linear_history": { "enabled": true },
  "allow_force_pushes": { "enabled": false },
  "allow_deletions": { "enabled": false }
}
JSON
                exit 0
                ;;
            drifted)
                # Wrong values across the board so the script triggers an update.
                cat <<'JSON'
{
  "required_pull_request_reviews": {
    "required_approving_review_count": 0
  },
  "required_linear_history": { "enabled": false },
  "allow_force_pushes": { "enabled": true },
  "allow_deletions": { "enabled": true }
}
JSON
                exit 0
                ;;
        esac
    fi

    # Protection PUT
    if [[ "$path" =~ /branches/[^/]+/protection$ && "$method" == "PUT" ]]; then
        if [[ "$put_denied" == "true" ]]; then
            # Mimic the real 404/403 message that 'Resource not accessible by integration' returns
            echo '{"message":"Resource not accessible by integration","status":"403"}' >&2
            exit 1
        fi
        echo '{"url":"...","required_pull_request_reviews":{"required_approving_review_count":1}}'
        exit 0
    fi

    exit 0
fi

exit 0
STUB_EOF
    chmod +x "$sandbox/bin/gh"
}

# Run script in a clean env, forwarding STUB_* vars.
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
        echo -e "  ${RED}FAIL${NC} $label  (expected: $needle)"
        echo "  --- file ---"
        sed -e 's/^/  /' "$file"
        echo "  ------------"
        FAIL=$((FAIL + 1))
    fi
}

# ── Test 1: Branch missing → exit 1 ──────────────────────────────────

echo ""
echo "Test 1: branch does not exist → fail fast"

T1=$(new_sandbox)
make_gh_stub "$T1"

set +e
run_script "$T1" \
    STUB_BRANCH_EXISTS="false" \
    > "$T1/run.log" 2>&1
ec=$?
set -e

assert_eq "1" "$ec" "exit 1 when branch missing"
assert_contains "not found" "$T1/run.log" "names the issue"
# Critical: must NOT have called PUT
if ! grep -q "PUT" "$T1/gh.log" 2>/dev/null; then
    echo -e "  ${GREEN}OK${NC} did NOT call PUT when branch missing"
    PASS=$((PASS + 1))
else
    echo -e "  ${RED}FAIL${NC} called PUT despite missing branch"
    FAIL=$((FAIL + 1))
fi

# ── Test 2: Branch exists, no protection → PUT succeeds ──────────────

echo ""
echo "Test 2: no protection yet → PUT applies canonical state"

T2=$(new_sandbox)
make_gh_stub "$T2"

set +e
run_script "$T2" \
    STUB_BRANCH_EXISTS="true" \
    STUB_PROTECTION_STATE="missing" \
    > "$T2/run.log" 2>&1
ec=$?
set -e

assert_eq "0" "$ec" "exit 0"
assert_contains "Branch protection applied" "$T2/run.log" "success message"
assert_contains "Linear history:      required" "$T2/run.log" "summary lists protections"
# Must have called PUT
if grep -q "PUT" "$T2/gh.log"; then
    echo -e "  ${GREEN}OK${NC} called PUT to apply protection"
    PASS=$((PASS + 1))
else
    echo -e "  ${RED}FAIL${NC} did not call PUT"
    FAIL=$((FAIL + 1))
fi

# ── Test 3: Already canonical → idempotent no-op ─────────────────────

echo ""
echo "Test 3: protection already canonical → no-op"

T3=$(new_sandbox)
make_gh_stub "$T3"

set +e
run_script "$T3" \
    STUB_BRANCH_EXISTS="true" \
    STUB_PROTECTION_STATE="canonical" \
    > "$T3/run.log" 2>&1
ec=$?
set -e

assert_eq "0" "$ec" "exit 0"
assert_contains "already in canonical state" "$T3/run.log" "no-op message"
# Critical: must NOT have called PUT
if ! grep -q "PUT" "$T3/gh.log" 2>/dev/null; then
    echo -e "  ${GREEN}OK${NC} did NOT call PUT on already-canonical state"
    PASS=$((PASS + 1))
else
    echo -e "  ${RED}FAIL${NC} called PUT despite canonical state"
    FAIL=$((FAIL + 1))
fi

# ── Test 4: Drifted state → PUT updates ──────────────────────────────

echo ""
echo "Test 4: protection drifted → PUT applies update"

T4=$(new_sandbox)
make_gh_stub "$T4"

set +e
run_script "$T4" \
    STUB_BRANCH_EXISTS="true" \
    STUB_PROTECTION_STATE="drifted" \
    > "$T4/run.log" 2>&1
ec=$?
set -e

assert_eq "0" "$ec" "exit 0"
assert_contains "Branch protection applied" "$T4/run.log" "applied (re-applied)"
if grep -q "PUT" "$T4/gh.log"; then
    echo -e "  ${GREEN}OK${NC} called PUT to reconcile drift"
    PASS=$((PASS + 1))
else
    echo -e "  ${RED}FAIL${NC} did not call PUT to fix drift"
    FAIL=$((FAIL + 1))
fi

# ── Test 5: PUT denied (admin missing) → exit 2 ──────────────────────

echo ""
echo "Test 5: PUT permission denied → exit 2 with admin guidance"

T5=$(new_sandbox)
make_gh_stub "$T5"

set +e
run_script "$T5" \
    STUB_BRANCH_EXISTS="true" \
    STUB_PROTECTION_STATE="missing" \
    STUB_PUT_DENIED="true" \
    > "$T5/run.log" 2>&1
ec=$?
set -e

assert_eq "2" "$ec" "exit 2 (admin missing)"
assert_contains "lacks admin write" "$T5/run.log" "explains the cause"
assert_contains "Required scopes" "$T5/run.log" "tells user how to fix"

# ── Test 6: Dry-run preview ──────────────────────────────────────────

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
    STUB_BRANCH_EXISTS="true" \
    STUB_PROTECTION_STATE="missing" \
    bash "$SCRIPT" --repo test-org/test-repo --dry-run \
    > "$T6/run.log" 2>&1
ec=$?
set -e

assert_eq "0" "$ec" "exit 0"
assert_contains "Dry-run" "$T6/run.log" "dry-run banner"
assert_contains "would PUT" "$T6/run.log" "shows planned action"
assert_contains "Re-run without --dry-run" "$T6/run.log" "guidance to apply"
# Critical: dry-run must NOT have called PUT
if ! grep -q "PUT" "$T6/gh.log" 2>/dev/null; then
    echo -e "  ${GREEN}OK${NC} dry-run made no PUT call"
    PASS=$((PASS + 1))
else
    echo -e "  ${RED}FAIL${NC} dry-run made a PUT call"
    FAIL=$((FAIL + 1))
fi

# ── Test 7: --branch flag respected ──────────────────────────────────

echo ""
echo "Test 7: --branch flag targets a non-default branch"

T7=$(new_sandbox)
make_gh_stub "$T7"

set +e
env -i \
    HOME="$T7" \
    PATH="$T7/bin:/usr/bin:/bin:/usr/local/bin" \
    STUB_STATE="$T7" \
    TERM="${TERM:-dumb}" \
    STUB_BRANCH_EXISTS="true" \
    STUB_PROTECTION_STATE="missing" \
    bash "$SCRIPT" --repo test-org/test-repo --branch develop \
    > "$T7/run.log" 2>&1
ec=$?
set -e

assert_eq "0" "$ec" "exit 0"
assert_contains "Target branch: develop" "$T7/run.log" "uses --branch value"
if grep -q "branches/develop/protection" "$T7/gh.log"; then
    echo -e "  ${GREEN}OK${NC} called API against develop branch"
    PASS=$((PASS + 1))
else
    echo -e "  ${RED}FAIL${NC} did not call API against develop branch"
    FAIL=$((FAIL + 1))
fi

# ── Test 8: Unknown flag → exit 1 ────────────────────────────────────

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

# ── Summary ──────────────────────────────────────────────────────────

echo ""
echo "─────────────────────────────────"
echo "  Passed: $PASS"
echo "  Failed: $FAIL"
echo "─────────────────────────────────"

(( FAIL > 0 )) && exit 1
exit 0
