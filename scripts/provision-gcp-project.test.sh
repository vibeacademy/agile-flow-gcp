#!/usr/bin/env bash
#
# Tests for the retry_eventual_consistency helper in
# scripts/provision-gcp-project.sh.
#
# We source the script's helper section by extracting it (the script's
# main body requires GCP_PROJECT_ID; we don't want to run that in tests).
#
# Run: ./scripts/provision-gcp-project.test.sh

# Tests deliberately exercise failure paths, so `set -e` would short-circuit
# before assertions run. We rely on explicit exit-code captures instead.
set -uo pipefail

GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

PASS=0
FAIL=0

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT="$REPO_ROOT/scripts/provision-gcp-project.sh"

# Pull the helper definition into the current shell. The helper block is
# bounded by its leading comment and the `retry_eventual_consistency()`
# closing brace at column 1 (matched by `^}`).
HELPER_SRC="$(awk '
  /^retry_eventual_consistency\(\)/ { capture=1 }
  /^RETRY_MAX_ATTEMPTS=/ || /^RETRY_MAX_SLEEP=/ { print; next }
  capture { print }
  capture && /^}/ { exit }
' "$SCRIPT")"

# Use small delays so the test runs in <1s.
export RETRY_MAX_ATTEMPTS=4
export RETRY_MAX_SLEEP=1

# shellcheck disable=SC1090,SC2086
eval "$HELPER_SRC"

assert_eq() {
  local expected="$1" actual="$2" label="$3"
  if [[ "$expected" == "$actual" ]]; then
    echo -e "  ${GREEN}✓${NC} $label"
    PASS=$((PASS + 1))
  else
    echo -e "  ${RED}✗${NC} $label  (expected: $expected; got: $actual)"
    FAIL=$((FAIL + 1))
  fi
}

# ── Test 1: command succeeds first try → exit 0, no sleep ────────────────

echo ""
echo "Test 1: success on first attempt"

set +e
out=$(retry_eventual_consistency "ok cmd" -- bash -c 'true' 2>&1)
ec=$?
set -e
assert_eq "0" "$ec" "exit 0"
assert_eq "" "$out" "no retry log written"

# ── Test 2: transient 403 → retry → eventual success ────────────────────

echo ""
echo "Test 2: transient 403 then success"

# Stub command that fails twice with the eventual-consistency signature,
# then succeeds. Use a tmpfile counter.
COUNTER=$(mktemp)
echo 0 > "$COUNTER"
FLAKY_CMD=$(mktemp)
cat > "$FLAKY_CMD" <<EOF
#!/usr/bin/env bash
n=\$(<"$COUNTER")
n=\$((n + 1))
echo \$n > "$COUNTER"
if (( n < 3 )); then
  echo "ERROR: PERMISSION_DENIED: foo denied on resource projects/x" >&2
  exit 1
fi
exit 0
EOF
chmod +x "$FLAKY_CMD"

set +e
out=$(retry_eventual_consistency "flaky" -- "$FLAKY_CMD" 2>&1)
ec=$?
set -e
assert_eq "0" "$ec" "exit 0 after retries"
assert_eq "3" "$(cat "$COUNTER")" "command invoked 3 times (2 fail + 1 success)"

if echo "$out" | grep -q "retry 1/4"; then
  echo -e "  ${GREEN}✓${NC} first retry logged"
  PASS=$((PASS + 1))
else
  echo -e "  ${RED}✗${NC} expected '[retry 1/4]' in stderr; got: $out"
  FAIL=$((FAIL + 1))
fi

rm -f "$FLAKY_CMD" "$COUNTER"

# ── Test 3: permanent error (already-exists) → fail immediately ─────────

echo ""
echo "Test 3: permanent error fails on first attempt without retrying"

COUNTER=$(mktemp); echo 0 > "$COUNTER"
PERM_CMD=$(mktemp)
cat > "$PERM_CMD" <<EOF
#!/usr/bin/env bash
n=\$(<"$COUNTER")
echo \$((n + 1)) > "$COUNTER"
echo "ERROR: already exists: foo" >&2
exit 1
EOF
chmod +x "$PERM_CMD"

set +e
retry_eventual_consistency "perm" -- "$PERM_CMD" >/dev/null 2>&1
ec=$?
set -e
assert_eq "1" "$ec" "exit non-zero on permanent error"
assert_eq "1" "$(cat "$COUNTER")" "command invoked exactly once (no retry)"

rm -f "$PERM_CMD" "$COUNTER"

# ── Test 4: transient error exhausts retries → fail with logged exhaustion

echo ""
echo "Test 4: transient error exhausts retries"

COUNTER=$(mktemp); echo 0 > "$COUNTER"
ALWAYS_FLAKY=$(mktemp)
cat > "$ALWAYS_FLAKY" <<EOF
#!/usr/bin/env bash
n=\$(<"$COUNTER")
echo \$((n + 1)) > "$COUNTER"
echo "ERROR: PERMISSION_DENIED: denied on resource projects/x" >&2
exit 1
EOF
chmod +x "$ALWAYS_FLAKY"

set +e
out=$(retry_eventual_consistency "always-flaky" -- "$ALWAYS_FLAKY" 2>&1)
ec=$?
set -e
assert_eq "1" "$ec" "exit non-zero after exhaustion"
assert_eq "$RETRY_MAX_ATTEMPTS" "$(cat "$COUNTER")" "command invoked RETRY_MAX_ATTEMPTS times"

if echo "$out" | grep -q "exhausted"; then
  echo -e "  ${GREEN}✓${NC} exhaustion logged"
  PASS=$((PASS + 1))
else
  echo -e "  ${RED}✗${NC} expected 'exhausted' in stderr; got: $out"
  FAIL=$((FAIL + 1))
fi

rm -f "$ALWAYS_FLAKY" "$COUNTER"

# ── Test 5: bad invocation (missing -- separator) → exit 2 ─────────────

echo ""
echo "Test 5: bad invocation"

set +e
retry_eventual_consistency "label" "not-a-separator" "true" >/dev/null 2>&1
ec=$?
set -e
assert_eq "2" "$ec" "exit 2 on missing -- separator"

# ── Summary ──────────────────────────────────────────────────────────────

echo ""
echo "─────────────────────────────────"
echo "  Passed: $PASS"
echo "  Failed: $FAIL"
echo "─────────────────────────────────"

(( FAIL > 0 )) && exit 1
exit 0
