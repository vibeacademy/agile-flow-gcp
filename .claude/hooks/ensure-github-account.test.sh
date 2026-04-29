#!/usr/bin/env bash
#
# Tests for ensure-github-account.sh — the PreToolUse hook that switches
# `gh` accounts before PR creation/review. Focuses on the solo-mode
# escape hatch (#69) and verifies the hook is a no-op when
# AGILE_FLOW_SOLO_MODE=true.
#
# The harness invokes the hook with stubbed `gh` and `jq` on PATH.
# `jq` is real (the hook uses it for stdin parsing); `gh` is a stub
# whose calls get logged so we can assert on what the hook attempted.
#
# Run: ./.claude/hooks/ensure-github-account.test.sh

set -uo pipefail

GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

PASS=0
FAIL=0

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
HOOK="$REPO_ROOT/.claude/hooks/ensure-github-account.sh"

new_tmp() { mktemp -d -t aflowhook-XXXX; }

# Stub gcloud-irrelevant; we only need a `gh` stub. Logs every call.
make_gh_stub() {
  local tmp="$1"
  local active_account="${2:-some-account}"
  mkdir -p "$tmp/bin"

  cat > "$tmp/bin/gh" <<EOF
#!/usr/bin/env bash
echo "gh \$*" >> "$tmp/gh.log"
case "\$1 \$2" in
  "auth status")
    cat <<STATUS
github.com
  ✓ Logged in to github.com account $active_account (keyring)
  - Active account: true
  - Git operations protocol: https
STATUS
    exit 0 ;;
  "auth switch") exit 0 ;;
  *) exit 0 ;;
esac
EOF
  chmod +x "$tmp/bin/gh"
}

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

# ── Test 1: Solo mode → no-op, no `gh` calls ────────────────────────────

echo ""
echo "Test 1: AGILE_FLOW_SOLO_MODE=true → hook exits 0 with no gh calls"

T1=$(new_tmp)
make_gh_stub "$T1"

# Solo-mode invocation against a `gh pr create` Bash command — the path
# that would normally trigger the worker switch.
input='{"tool_name":"Bash","tool_input":{"command":"gh pr create --title foo"}}'

set +e
PATH="$T1/bin:$PATH" \
  AGILE_FLOW_SOLO_MODE=true \
  bash "$HOOK" <<< "$input" > "$T1/stdout.log" 2>&1
ec=$?
set -e

assert_eq "0" "$ec" "exit 0"

# Critical regression guard: gh must NOT be called when solo mode is on.
gh_call_count=0
if [[ -f "$T1/gh.log" ]]; then
  gh_call_count="$(grep -c '.' "$T1/gh.log" 2>/dev/null || true)"
fi
assert_eq "0" "$gh_call_count" "no gh calls made in solo mode"

# ── Test 2: Solo mode unset (default) → bot-switching path runs ─────────

echo ""
echo "Test 2: solo mode unset → hook still calls gh auth status"

T2=$(new_tmp)
make_gh_stub "$T2" "va-worker"  # already on the worker account → no switch

input='{"tool_name":"Bash","tool_input":{"command":"gh pr create --title foo"}}'

set +e
PATH="$T2/bin:$PATH" \
  AGILE_FLOW_WORKER_ACCOUNT="va-worker" \
  AGILE_FLOW_REVIEWER_ACCOUNT="va-reviewer" \
  bash "$HOOK" <<< "$input" > "$T2/stdout.log" 2>&1
ec=$?
set -e

assert_eq "0" "$ec" "exit 0 when already on correct account"

# Should have called auth status to check current account.
if [[ -f "$T2/gh.log" ]] && grep -q "auth status" "$T2/gh.log"; then
  echo -e "  ${GREEN}✓${NC} gh auth status was called"
  PASS=$((PASS + 1))
else
  echo -e "  ${RED}✗${NC} expected gh auth status call when solo mode unset"
  FAIL=$((FAIL + 1))
fi

# ── Test 3: Solo mode + non-PR command → no-op (fast path) ─────────────

echo ""
echo "Test 3: AGILE_FLOW_SOLO_MODE=true + non-PR command → no gh calls"

T3=$(new_tmp)
make_gh_stub "$T3"

input='{"tool_name":"Bash","tool_input":{"command":"git status"}}'

set +e
PATH="$T3/bin:$PATH" \
  AGILE_FLOW_SOLO_MODE=true \
  bash "$HOOK" <<< "$input" > "$T3/stdout.log" 2>&1
ec=$?
set -e

assert_eq "0" "$ec" "exit 0"

gh_call_count=0
if [[ -f "$T3/gh.log" ]]; then
  gh_call_count="$(grep -c '.' "$T3/gh.log" 2>/dev/null || true)"
fi
assert_eq "0" "$gh_call_count" "no gh calls (solo short-circuit fires before command-pattern match)"

# ── Test 4: AGILE_FLOW_SOLO_MODE=false → bot-switching runs ─────────────
# Verifies the env-var comparison is exact (only "true" disables;
# any other value falls through to normal flow).

echo ""
echo "Test 4: AGILE_FLOW_SOLO_MODE=false → hook still does bot switching"

T4=$(new_tmp)
make_gh_stub "$T4" "va-worker"

input='{"tool_name":"Bash","tool_input":{"command":"gh pr create --title foo"}}'

set +e
PATH="$T4/bin:$PATH" \
  AGILE_FLOW_SOLO_MODE=false \
  AGILE_FLOW_WORKER_ACCOUNT="va-worker" \
  AGILE_FLOW_REVIEWER_ACCOUNT="va-reviewer" \
  bash "$HOOK" <<< "$input" > "$T4/stdout.log" 2>&1
ec=$?
set -e

assert_eq "0" "$ec" "exit 0"

if [[ -f "$T4/gh.log" ]] && grep -q "auth status" "$T4/gh.log"; then
  echo -e "  ${GREEN}✓${NC} gh auth status was called (false != true; falls through)"
  PASS=$((PASS + 1))
else
  echo -e "  ${RED}✗${NC} expected bot-switching path when SOLO_MODE=false"
  FAIL=$((FAIL + 1))
fi

# ── Summary ─────────────────────────────────────────────────────────────

echo ""
echo "─────────────────────────────────"
echo "  Passed: $PASS"
echo "  Failed: $FAIL"
echo "─────────────────────────────────"

(( FAIL > 0 )) && exit 1
exit 0
