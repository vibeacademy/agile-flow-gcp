#!/usr/bin/env bash
#
# Tests for create-workshop-neon-projects.sh — per-attendee Neon
# project reconciliation. Stubs `curl` and `jq` is real.
#
# Run: ./scripts/create-workshop-neon-projects.test.sh

set -uo pipefail

GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

PASS=0
FAIL=0

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT="$REPO_ROOT/scripts/create-workshop-neon-projects.sh"

new_sandbox() { mktemp -d -t aflowneon-XXXX; }

# Write a 7-column roster fixture
write_fixture() {
    local sandbox="$1" content="$2"
    cat > "$sandbox/roster.csv" <<EOF
handle,github_user,email,cohort,neon_branch,github_full_repo,neon_project_id
${content}
EOF
}

# Stub `curl` — all calls behave per env-var STUB_NEON_STATE.
# Modes:
#   missing      — list returns empty; POST /projects returns 201 with new ID
#   existing     — list returns matching project for each handle
#   denied       — POST returns 403
#   list_fails   — list returns empty + non-zero (script should fail-soft)
make_stubs() {
    local sandbox="$1"
    mkdir -p "$sandbox/bin"

    cat > "$sandbox/bin/curl" <<'STUB_EOF'
#!/usr/bin/env bash
# Log every call
echo "curl $*" >> "$STUB_STATE/curl.log"

# Find the URL (last positional arg, but easier: scan for https://)
url=""
output_file=""
write_out=false
data=""
method="GET"
for arg in "$@"; do
    case "$arg" in
        --output) capture_output=true ;;
        -X) capture_method=true ;;
        -d) capture_data=true ;;
        --write-out) capture_writeout=true ;;
        https://*) url="$arg" ;;
        *)
            if [[ "${capture_output:-}" == "true" ]]; then
                output_file="$arg"; capture_output=""
            elif [[ "${capture_method:-}" == "true" ]]; then
                method="$arg"; capture_method=""
            elif [[ "${capture_data:-}" == "true" ]]; then
                data="$arg"; capture_data=""
            elif [[ "${capture_writeout:-}" == "true" ]]; then
                write_out=true; capture_writeout=""
            fi
            ;;
    esac
done

state="${STUB_NEON_STATE:-missing}"

# GET /projects?org_id=... → list
if [[ "$method" == "GET" && "$url" == *"/projects?org_id="* ]]; then
    if [[ "$state" == "list_fails" ]]; then
        # `--fail` means non-zero exit on HTTP error; the script reads stdout then `|| true`s
        echo ""
        exit 22
    fi
    if [[ "$state" == "existing" ]]; then
        # Return projects matching the test handles
        cat <<'JSON'
{"projects":[
  {"name":"alice","id":"proj-alice-existing-001"},
  {"name":"bob","id":"proj-bob-existing-002"}
]}
JSON
        exit 0
    fi
    # Default: missing
    echo '{"projects":[]}'
    exit 0
fi

# POST /projects → create
if [[ "$method" == "POST" && "$url" == *"/projects" ]]; then
    if [[ "$state" == "denied" ]]; then
        echo '{"message":"Forbidden"}' > "$output_file"
        if $write_out; then echo -n "403"; fi
        exit 0
    fi
    # Extract the project name from the JSON body for echo-back
    name="$(echo "$data" | sed -E 's/.*"name":"([^"]+)".*/\1/')"
    new_id="proj-${name}-new-$(date +%s)$RANDOM"
    cat > "$output_file" <<EOF
{"project":{"id":"$new_id","name":"$name"}}
EOF
    if $write_out; then echo -n "201"; fi
    exit 0
fi

# Anything else: succeed quietly
exit 0
STUB_EOF
    chmod +x "$sandbox/bin/curl"
}

# Run script in a clean env, forwarding STUB_* vars.
run_script() {
    local sandbox="$1"
    shift
    env -i \
        HOME="$sandbox" \
        PATH="$sandbox/bin:/usr/bin:/bin:/usr/local/bin:/opt/homebrew/bin" \
        STUB_STATE="$sandbox" \
        TERM="${TERM:-dumb}" \
        "$@" \
        bash "$SCRIPT" "$sandbox/roster.csv"
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

# ── Test 1: All rows missing → creates all, updates CSV ──────────────

echo ""
echo "Test 1: 3 rows with no project_id → creates all 3"

T1=$(new_sandbox)
make_stubs "$T1"
write_fixture "$T1" "alice,alice-gh,alice@x.com,2026-05,alice,vibeacademy/alice,
bob,bob-gh,bob@x.com,2026-05,bob,vibeacademy/bob,
carol,carol-gh,carol@x.com,2026-05,carol,vibeacademy/carol,"

set +e
run_script "$T1" \
    NEON_API_KEY="key123" \
    NEON_ORG_ID="org-test" \
    > "$T1/run.log" 2>&1
ec=$?
set -e

assert_eq "0" "$ec" "exit 0"
assert_contains "created Neon project 'alice'" "$T1/run.log" "alice created"
assert_contains "created Neon project 'bob'" "$T1/run.log" "bob created"
assert_contains "created Neon project 'carol'" "$T1/run.log" "carol created"
# CSV should now have non-empty neon_project_id for each row
created_count=$(grep -c "proj-.*-new-" "$T1/roster.csv" || true)
assert_eq "3" "$created_count" "all 3 rows have new project IDs in CSV"
# Backup created
if [ -f "$T1/roster.csv.bak" ]; then
    echo -e "  ${GREEN}OK${NC} backup file created"
    PASS=$((PASS + 1))
else
    echo -e "  ${RED}FAIL${NC} no backup file"
    FAIL=$((FAIL + 1))
fi

# ── Test 2: Idempotent — rows with existing IDs are skipped ─────────

echo ""
echo "Test 2: rows already have project_id → skipped"

T2=$(new_sandbox)
make_stubs "$T2"
write_fixture "$T2" "alice,alice-gh,alice@x.com,2026-05,alice,vibeacademy/alice,proj-existing-1
bob,bob-gh,bob@x.com,2026-05,bob,vibeacademy/bob,proj-existing-2"

set +e
run_script "$T2" \
    NEON_API_KEY="key123" \
    NEON_ORG_ID="org-test" \
    > "$T2/run.log" 2>&1
ec=$?
set -e

assert_eq "0" "$ec" "exit 0"
assert_contains "alice': already has project_id proj-existing-1" "$T2/run.log" "alice skipped"
assert_contains "bob': already has project_id proj-existing-2" "$T2/run.log" "bob skipped"
# Critical: must NOT have called POST
if ! grep -q "POST" "$T2/curl.log" 2>/dev/null; then
    echo -e "  ${GREEN}OK${NC} no POST calls when all rows already have IDs"
    PASS=$((PASS + 1))
else
    echo -e "  ${RED}FAIL${NC} POST called despite existing IDs"
    FAIL=$((FAIL + 1))
fi

# ── Test 3: Reuse existing org project by name ──────────────────────

echo ""
echo "Test 3: existing org project with matching name → reuse, not re-create"

T3=$(new_sandbox)
make_stubs "$T3"
write_fixture "$T3" "alice,alice-gh,alice@x.com,2026-05,alice,vibeacademy/alice,
bob,bob-gh,bob@x.com,2026-05,bob,vibeacademy/bob,"

set +e
run_script "$T3" \
    NEON_API_KEY="key123" \
    NEON_ORG_ID="org-test" \
    STUB_NEON_STATE="existing" \
    > "$T3/run.log" 2>&1
ec=$?
set -e

assert_eq "0" "$ec" "exit 0"
assert_contains "reusing existing project 'alice' (id=proj-alice-existing-001)" "$T3/run.log" "alice reused"
assert_contains "reusing existing project 'bob' (id=proj-bob-existing-002)" "$T3/run.log" "bob reused"
# Should NOT have called POST
if ! grep -q "POST" "$T3/curl.log" 2>/dev/null; then
    echo -e "  ${GREEN}OK${NC} no POST when names exist"
    PASS=$((PASS + 1))
else
    echo -e "  ${RED}FAIL${NC} POST called despite existing names"
    FAIL=$((FAIL + 1))
fi
# CSV updated with the existing IDs
assert_contains "proj-alice-existing-001" "$T3/roster.csv" "alice's existing ID written to CSV"
assert_contains "proj-bob-existing-002" "$T3/roster.csv" "bob's existing ID written to CSV"

# ── Test 4: Wrong header (6-column) → fail fast ─────────────────────

echo ""
echo "Test 4: 6-column header → fail fast with clear message"

T4=$(new_sandbox)
make_stubs "$T4"
cat > "$T4/roster.csv" <<'EOF'
handle,github_user,email,cohort,neon_branch,github_full_repo
alice,alice-gh,alice@x.com,2026-05,alice,vibeacademy/alice
EOF

set +e
run_script "$T4" \
    NEON_API_KEY="key123" \
    NEON_ORG_ID="org-test" \
    > "$T4/run.log" 2>&1
ec=$?
set -e

assert_eq "1" "$ec" "exit 1 on wrong header"
assert_contains "must have 7-column header" "$T4/run.log" "names the issue"
assert_contains "Upgrade your roster" "$T4/run.log" "tells user how to fix"

# ── Test 5: Missing NEON_API_KEY → fail fast ────────────────────────

echo ""
echo "Test 5: missing NEON_API_KEY → exit 1"

T5=$(new_sandbox)
make_stubs "$T5"
write_fixture "$T5" "alice,alice-gh,alice@x.com,2026-05,alice,vibeacademy/alice,"

set +e
run_script "$T5" \
    NEON_ORG_ID="org-test" \
    > "$T5/run.log" 2>&1
ec=$?
set -e

assert_eq "1" "$ec" "exit 1"
assert_contains "NEON_API_KEY" "$T5/run.log" "names missing var"

# ── Test 6: Missing NEON_ORG_ID → fail fast ─────────────────────────

echo ""
echo "Test 6: missing NEON_ORG_ID → exit 1"

T6=$(new_sandbox)
make_stubs "$T6"
write_fixture "$T6" "alice,alice-gh,alice@x.com,2026-05,alice,vibeacademy/alice,"

set +e
run_script "$T6" \
    NEON_API_KEY="key123" \
    > "$T6/run.log" 2>&1
ec=$?
set -e

assert_eq "1" "$ec" "exit 1"
assert_contains "NEON_ORG_ID" "$T6/run.log" "names missing var"

# ── Test 7: Dry-run does not write to Neon or CSV ───────────────────

echo ""
echo "Test 7: --dry-run preview only"

T7=$(new_sandbox)
make_stubs "$T7"
write_fixture "$T7" "alice,alice-gh,alice@x.com,2026-05,alice,vibeacademy/alice,"
hash_before=$(md5 -q "$T7/roster.csv" 2>/dev/null || md5sum "$T7/roster.csv" | cut -d' ' -f1)

set +e
env -i \
    HOME="$T7" \
    PATH="$T7/bin:/usr/bin:/bin:/usr/local/bin:/opt/homebrew/bin" \
    STUB_STATE="$T7" \
    TERM="${TERM:-dumb}" \
    NEON_API_KEY="key123" \
    NEON_ORG_ID="org-test" \
    bash "$SCRIPT" "$T7/roster.csv" --dry-run \
    > "$T7/run.log" 2>&1
ec=$?
set -e

hash_after=$(md5 -q "$T7/roster.csv" 2>/dev/null || md5sum "$T7/roster.csv" | cut -d' ' -f1)

assert_eq "0" "$ec" "exit 0"
assert_contains "WOULD CREATE" "$T7/run.log" "dry-run shows planned action"
assert_contains "Dry-run: roster file unchanged" "$T7/run.log" "summary"
assert_eq "$hash_before" "$hash_after" "roster CSV unchanged"
# No POST call should have been made
if ! grep -q "POST" "$T7/curl.log" 2>/dev/null; then
    echo -e "  ${GREEN}OK${NC} dry-run made no POST call"
    PASS=$((PASS + 1))
else
    echo -e "  ${RED}FAIL${NC} dry-run made a POST call"
    FAIL=$((FAIL + 1))
fi

# ── Test 8: Neon write denied → exit 2 ──────────────────────────────

echo ""
echo "Test 8: POST returns 403 → exit 2 with WARN per failed row"

T8=$(new_sandbox)
make_stubs "$T8"
write_fixture "$T8" "alice,alice-gh,alice@x.com,2026-05,alice,vibeacademy/alice,
bob,bob-gh,bob@x.com,2026-05,bob,vibeacademy/bob,"

set +e
run_script "$T8" \
    NEON_API_KEY="key123" \
    NEON_ORG_ID="org-test" \
    STUB_NEON_STATE="denied" \
    > "$T8/run.log" 2>&1
ec=$?
set -e

assert_eq "2" "$ec" "exit 2 on at-least-one failure"
assert_contains "alice': Neon API returned HTTP 403" "$T8/run.log" "alice failure surfaced"
assert_contains "bob': Neon API returned HTTP 403" "$T8/run.log" "bob failure surfaced"
# Both failures must be reported (no early-exit on first failure)
fail_count=$(grep -c "Neon API returned HTTP 403" "$T8/run.log" || true)
assert_eq "2" "$fail_count" "both failures surfaced (no early-exit)"

# ── Test 9: Mixed state — some rows have IDs, some don't ────────────

echo ""
echo "Test 9: mixed roster (1 with id, 1 without) → only creates the missing one"

T9=$(new_sandbox)
make_stubs "$T9"
write_fixture "$T9" "alice,alice-gh,alice@x.com,2026-05,alice,vibeacademy/alice,proj-alice-prefilled
bob,bob-gh,bob@x.com,2026-05,bob,vibeacademy/bob,"

set +e
run_script "$T9" \
    NEON_API_KEY="key123" \
    NEON_ORG_ID="org-test" \
    > "$T9/run.log" 2>&1
ec=$?
set -e

assert_eq "0" "$ec" "exit 0"
assert_contains "alice': already has project_id proj-alice-prefilled" "$T9/run.log" "alice skipped"
assert_contains "created Neon project 'bob'" "$T9/run.log" "bob created"
# CSV should preserve alice's prefilled ID and have a new one for bob
assert_contains "proj-alice-prefilled" "$T9/roster.csv" "alice's prefilled ID preserved"

# ── Test 10: NEON_PROJECT_PREFIX → applied to project name ──────────

echo ""
echo "Test 10: NEON_PROJECT_PREFIX prepends to handle for project name"

T10=$(new_sandbox)
make_stubs "$T10"
write_fixture "$T10" "alice,alice-gh,alice@x.com,2026-05,alice,vibeacademy/alice,"

set +e
run_script "$T10" \
    NEON_API_KEY="key123" \
    NEON_ORG_ID="org-test" \
    NEON_PROJECT_PREFIX="2026-05-" \
    > "$T10/run.log" 2>&1
ec=$?
set -e

assert_eq "0" "$ec" "exit 0"
assert_contains "created Neon project '2026-05-alice'" "$T10/run.log" "prefix applied"

# ── Summary ──────────────────────────────────────────────────────────

echo ""
echo "─────────────────────────────────"
echo "  Passed: $PASS"
echo "  Failed: $FAIL"
echo "─────────────────────────────────"

(( FAIL > 0 )) && exit 1
exit 0
