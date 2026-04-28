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

# ── Test 6: SA-not-exist transient (INVALID_ARGUMENT after SA create) ───
# Reproduces the live bug observed 2026-04-27: `gcloud projects
# add-iam-policy-binding` against a just-created SA returns
# INVALID_ARGUMENT: Service account ... does not exist. The retry helper
# must classify this as transient, not permanent.

echo ""
echo "Test 6: SA-not-exist transient is retried"

COUNTER=$(mktemp); echo 0 > "$COUNTER"
SA_FLAKY=$(mktemp)
cat > "$SA_FLAKY" <<EOF
#!/usr/bin/env bash
n=\$(<"$COUNTER")
n=\$((n + 1))
echo \$n > "$COUNTER"
if (( n < 2 )); then
  echo "ERROR: (gcloud.projects.add-iam-policy-binding) INVALID_ARGUMENT: Service account deployer@af-x.iam.gserviceaccount.com does not exist." >&2
  exit 1
fi
exit 0
EOF
chmod +x "$SA_FLAKY"

out=$(retry_eventual_consistency "sa flaky" -- "$SA_FLAKY" 2>&1)
ec=$?
assert_eq "0" "$ec" "exit 0 after SA-not-exist retried"
assert_eq "2" "$(cat "$COUNTER")" "command invoked twice (1 fail + 1 success)"

if echo "$out" | grep -q "retry 1/"; then
  echo -e "  ${GREEN}✓${NC} SA-not-exist classified as transient"
  PASS=$((PASS + 1))
else
  echo -e "  ${RED}✗${NC} expected '[retry 1/...]' in stderr — was SA-not-exist treated as permanent?"
  FAIL=$((FAIL + 1))
fi

rm -f "$SA_FLAKY" "$COUNTER"

# ── Test 7: project exists but not owned → fail with clear error ─────────
# Reproduces the live bug observed 2026-04-27 where a roster row hit a
# project ID that exists outside the caller's reach (different org, or
# soft-deleted with no perms). describe succeeds, get-iam-policy fails.

echo ""
echo "Test 7: exists-but-not-yours fails fast with clear message"

T7=$(mktemp -d -t aflowtest-XXXX)
mkdir -p "$T7/bin"

# Stub gcloud to: describe succeeds, get-iam-policy fails, all else fail.
cat > "$T7/bin/gcloud" <<EOF
#!/usr/bin/env bash
echo "gcloud \$*" >> "$T7/gcloud.log"
case "\$1 \$2" in
  "projects describe") exit 0 ;;
  "projects get-iam-policy")
    echo "ERROR: PERMISSION_DENIED on getIamPolicy" >&2
    exit 1
    ;;
  *)
    echo "FATAL: stub should never be called for: \$*" >&2
    exit 99
    ;;
esac
EOF
chmod +x "$T7/bin/gcloud"

set +e
PATH="$T7/bin:$PATH" \
  GCP_PROJECT_ID="af-collision-2026-05" \
  BILLING_ACCOUNT_ID="FAKE" \
  "$SCRIPT" --create-project > "$T7/stdout.log" 2>&1
ec=$?
set -e

assert_eq "1" "$ec" "exit 1 on exists-but-not-yours"

# Critical assertion: billing-link must NEVER be called when ownership probe fails.
# That was the live bug — billing-link fired and produced a confusing error.
billing_calls=0
if [[ -f "$T7/gcloud.log" ]]; then
  billing_calls="$(grep -c 'billing projects link' "$T7/gcloud.log" || true)"
fi
assert_eq "0" "$billing_calls" "billing-link was NOT called"

if grep -q "globally unique" "$T7/stdout.log"; then
  echo -e "  ${GREEN}✓${NC} error message names the global-uniqueness cause"
  PASS=$((PASS + 1))
else
  echo -e "  ${RED}✗${NC} expected error message to mention 'globally unique'; got:"
  cat "$T7/stdout.log"
  FAIL=$((FAIL + 1))
fi

if grep -qi "'cohort' column" "$T7/stdout.log"; then
  echo -e "  ${GREEN}✓${NC} error message names the workaround"
  PASS=$((PASS + 1))
else
  echo -e "  ${RED}✗${NC} expected error message to suggest changing cohort"
  FAIL=$((FAIL + 1))
fi

# ── Test 8: project exists in own org but is DELETE_REQUESTED → fail ─────

echo ""
echo "Test 8: exists-in-own-org-but-not-ACTIVE fails fast"

T8=$(mktemp -d -t aflowtest-XXXX)
mkdir -p "$T8/bin"

# Stub: describe succeeds, get-iam-policy succeeds, lifecycleState query
# returns DELETE_REQUESTED.
cat > "$T8/bin/gcloud" <<EOF
#!/usr/bin/env bash
echo "gcloud \$*" >> "$T8/gcloud.log"
case "\$1 \$2" in
  "projects describe")
    # The script calls describe twice: once to check existence (no flags),
    # once to read lifecycleState. Distinguish by --format presence.
    if echo "\$*" | grep -q -- "--format"; then
      echo "DELETE_REQUESTED"
    fi
    exit 0
    ;;
  "projects get-iam-policy") exit 0 ;;
  *)
    echo "FATAL: stub should never be called for: \$*" >&2
    exit 99
    ;;
esac
EOF
chmod +x "$T8/bin/gcloud"

set +e
PATH="$T8/bin:$PATH" \
  GCP_PROJECT_ID="af-zombie-2026-05" \
  BILLING_ACCOUNT_ID="FAKE" \
  "$SCRIPT" --create-project > "$T8/stdout.log" 2>&1
ec=$?
set -e

assert_eq "1" "$ec" "exit 1 on DELETE_REQUESTED"

billing_calls=0
if [[ -f "$T8/gcloud.log" ]]; then
  billing_calls="$(grep -c 'billing projects link' "$T8/gcloud.log" || true)"
fi
assert_eq "0" "$billing_calls" "billing-link was NOT called"

if grep -q "DELETE_REQUESTED" "$T8/stdout.log"; then
  echo -e "  ${GREEN}✓${NC} error message names the lifecycleState"
  PASS=$((PASS + 1))
else
  echo -e "  ${RED}✗${NC} expected error message to mention DELETE_REQUESTED; got:"
  cat "$T8/stdout.log"
  FAIL=$((FAIL + 1))
fi

# ── Test 9-11: Step 1.5 domain-restricted-sharing override ──────────────
#
# The script's Step 1.5 has three branches:
#   - override already in place (allValues=ALLOW)  → [skip]
#   - constraint enforced, override not yet applied → set-policy is called
#   - constraint not enforced at all                → [skip]
#
# Each branch is exercised below. Stubs inject controlled responses to
# `org-policies describe` and `org-policies list`, capture set-policy
# calls in a log, and short-circuit before the real provisioning steps
# (we exit the stub gcloud non-zero on `services` so the script aborts
# before Step 2 — this is intentional: we only need to verify Step 1.5
# behavior, not the whole flow).

run_step1_5_test() {
  local label="$1"
  local override_state="$2"   # "already-applied" | "enforced" | "not-enforced"
  local tmp; tmp=$(mktemp -d -t aflowtest-XXXX)
  mkdir -p "$tmp/bin"

  cat > "$tmp/bin/gcloud" <<EOF
#!/usr/bin/env bash
echo "gcloud \$*" >> "$tmp/gcloud.log"
case "\$1 \$2" in
  "projects describe")
    # Existence check returns 1 (project doesn't exist) so the script
    # takes the create path — but we stub create to succeed.
    exit 1
    ;;
  "projects create") exit 0 ;;
  "billing projects") exit 0 ;;
  "resource-manager org-policies")
    # Branch on subcommand
    case "\$3" in
      describe)
        case "$override_state" in
          already-applied) echo "ALLOW"; exit 0 ;;
          *)               exit 1 ;;
        esac
        ;;
      list)
        case "$override_state" in
          enforced) echo "constraints/iam.allowedPolicyMemberDomains"; exit 0 ;;
          *)        exit 0 ;;
        esac
        ;;
      set-policy)
        # Read the YAML/JSON body from /dev/stdin, log it
        cat >> "$tmp/set-policy-body.log"
        exit 0
        ;;
    esac
    ;;
  "services enable")
    # Short-circuit here so the test doesn't have to mock the rest.
    exit 1
    ;;
  *) exit 0 ;;
esac
EOF
  chmod +x "$tmp/bin/gcloud"

  set +e
  PATH="$tmp/bin:$PATH" \
    GCP_PROJECT_ID="af-policy-test" \
    BILLING_ACCOUNT_ID="FAKE" \
    "$SCRIPT" --create-project > "$tmp/stdout.log" 2>&1
  set -e

  echo "$tmp"
}

# Test 9: override already applied → [skip] message, set-policy NOT called

echo ""
echo "Test 9: Step 1.5 skips when override already in place"

T9=$(run_step1_5_test "already-applied" "already-applied")

if grep -q "already in place" "$T9/stdout.log"; then
  echo -e "  ${GREEN}✓${NC} skip message logged"
  PASS=$((PASS + 1))
else
  echo -e "  ${RED}✗${NC} expected 'already in place' in stdout"
  cat "$T9/stdout.log"
  FAIL=$((FAIL + 1))
fi

set_policy_calls=0
if [[ -f "$T9/gcloud.log" ]]; then
  set_policy_calls="$(grep -c 'set-policy' "$T9/gcloud.log" || true)"
fi
assert_eq "0" "$set_policy_calls" "set-policy NOT called when already in place"

# Test 10: constraint enforced → set-policy called with correct body

echo ""
echo "Test 10: Step 1.5 applies override when constraint is enforced"

T10=$(run_step1_5_test "enforced" "enforced")

if grep -q "applying domain-restricted-sharing override" "$T10/stdout.log"; then
  echo -e "  ${GREEN}✓${NC} override-applied message logged"
  PASS=$((PASS + 1))
else
  echo -e "  ${RED}✗${NC} expected 'applying domain-restricted-sharing override' in stdout"
  cat "$T10/stdout.log"
  FAIL=$((FAIL + 1))
fi

set_policy_calls=0
if [[ -f "$T10/gcloud.log" ]]; then
  set_policy_calls="$(grep -c 'set-policy' "$T10/gcloud.log" || true)"
fi
assert_eq "1" "$set_policy_calls" "set-policy called exactly once"

if [[ -f "$T10/set-policy-body.log" ]] && grep -q '"allValues":"ALLOW"' "$T10/set-policy-body.log"; then
  echo -e "  ${GREEN}✓${NC} set-policy body has allValues:ALLOW"
  PASS=$((PASS + 1))
else
  echo -e "  ${RED}✗${NC} set-policy body did not contain allValues:ALLOW"
  cat "$T10/set-policy-body.log" 2>/dev/null || echo "(body file not written)"
  FAIL=$((FAIL + 1))
fi

# Test 11: constraint not enforced → [skip] message, set-policy NOT called

echo ""
echo "Test 11: Step 1.5 skips when constraint is not enforced"

T11=$(run_step1_5_test "not-enforced" "not-enforced")

if grep -q "not enforced" "$T11/stdout.log"; then
  echo -e "  ${GREEN}✓${NC} not-enforced skip message logged"
  PASS=$((PASS + 1))
else
  echo -e "  ${RED}✗${NC} expected 'not enforced' in stdout"
  cat "$T11/stdout.log"
  FAIL=$((FAIL + 1))
fi

set_policy_calls=0
if [[ -f "$T11/gcloud.log" ]]; then
  set_policy_calls="$(grep -c 'set-policy' "$T11/gcloud.log" || true)"
fi
assert_eq "0" "$set_policy_calls" "set-policy NOT called when constraint absent"

# ── Test 12-14: Step 5.5 WIF setup ──────────────────────────────────────
#
# Step 5.5 has three branches:
#   - GITHUB_USERNAME unset                 → entire block skipped
#   - GITHUB_USERNAME set, WIF artifacts absent → pool + provider + binding created
#   - GITHUB_USERNAME set, WIF artifacts present → all three sub-steps log [skip]
#                                                  (binding still calls add-iam — idempotent)
#
# Stubs gcloud at PATH and short-circuits the script after Step 5.5 by
# exiting non-zero in code paths past the WIF block (Step 6 only runs
# when --with-sa-key is set; we don't pass it). The script naturally
# completes after Step 5.5 + the closing summary.

run_step5_5_test() {
  local wif_state="$1"   # "absent" | "present"
  local tmp; tmp=$(mktemp -d -t aflowtest-XXXX)
  mkdir -p "$tmp/bin"

  cat > "$tmp/bin/gcloud" <<EOF
#!/usr/bin/env bash
echo "gcloud \$*" >> "$tmp/gcloud.log"
case "\$1 \$2" in
  "projects describe")
    # Existence check (no --format) returns 1 so we take the create path.
    # Lifecycle check returns ACTIVE.
    # ProjectNumber check returns 12345.
    # Note: bash strips the single quotes around --format='value(...)'
    # before invoking gcloud, so the stub matches without quotes.
    if echo "\$*" | grep -q "projectNumber"; then
      echo "12345"
    elif echo "\$*" | grep -q "lifecycleState"; then
      echo "ACTIVE"
    else
      exit 1
    fi
    exit 0
    ;;
  "projects create"|"projects get-iam-policy"|"projects add-iam-policy-binding") exit 0 ;;
  "billing projects") exit 0 ;;
  "resource-manager org-policies")
    # Step 1.5: pretend constraint not enforced so we skip past quickly
    case "\$3" in
      describe) exit 1 ;;
      list)     exit 0 ;;
    esac
    ;;
  "services enable") exit 0 ;;
  "artifacts repositories")
    case "\$3" in
      describe) exit 1 ;;   # not exists -> create path
      create)   exit 0 ;;
    esac
    ;;
  "iam service-accounts")
    case "\$3" in
      describe) exit 1 ;;   # not exists -> create path
      create)   exit 0 ;;
      add-iam-policy-binding) exit 0 ;;   # used for SA roles + WIF binding
    esac
    ;;
  "iam workload-identity-pools")
    case "\$3" in
      describe)
        case "$wif_state" in
          present) exit 0 ;;
          *)       exit 1 ;;
        esac
        ;;
      create) exit 0 ;;
      providers)
        case "\$4" in
          describe)
            case "$wif_state" in
              present) exit 0 ;;
              *)       exit 1 ;;
            esac
            ;;
          create-oidc) exit 0 ;;
        esac
        ;;
    esac
    ;;
  *) exit 0 ;;
esac
EOF
  chmod +x "$tmp/bin/gcloud"

  set +e
  PATH="$tmp/bin:$PATH" \
    GCP_PROJECT_ID="af-wif-test" \
    BILLING_ACCOUNT_ID="FAKE" \
    GITHUB_USERNAME="${2:-}" \
    "$SCRIPT" --create-project > "$tmp/stdout.log" 2>&1
  set -e

  echo "$tmp"
}

# Test 12: GITHUB_USERNAME unset → entire WIF block skipped

echo ""
echo "Test 12: Step 5.5 skipped when GITHUB_USERNAME unset"

T12=$(run_step5_5_test "absent" "")

if grep -q "WIF setup not requested" "$T12/stdout.log"; then
  echo -e "  ${GREEN}✓${NC} skip message logged"
  PASS=$((PASS + 1))
else
  echo -e "  ${RED}✗${NC} expected 'WIF setup not requested' in stdout"
  cat "$T12/stdout.log"
  FAIL=$((FAIL + 1))
fi

wif_pool_calls=0
if [[ -f "$T12/gcloud.log" ]]; then
  wif_pool_calls="$(grep -c 'workload-identity-pools' "$T12/gcloud.log" || true)"
fi
assert_eq "0" "$wif_pool_calls" "no workload-identity-pools calls when GITHUB_USERNAME unset"

# Test 13: GITHUB_USERNAME set, WIF artifacts absent → pool + provider + binding created

echo ""
echo "Test 13: Step 5.5 creates pool + provider + binding when WIF absent"

T13=$(run_step5_5_test "absent" "alice-gh")

if grep -q "create.*WIF pool" "$T13/stdout.log"; then
  echo -e "  ${GREEN}✓${NC} create-pool log line"
  PASS=$((PASS + 1))
else
  echo -e "  ${RED}✗${NC} expected '[create] WIF pool' in stdout"
  FAIL=$((FAIL + 1))
fi

if grep -q "create.*WIF provider" "$T13/stdout.log"; then
  echo -e "  ${GREEN}✓${NC} create-provider log line"
  PASS=$((PASS + 1))
else
  echo -e "  ${RED}✗${NC} expected '[create] WIF provider' in stdout"
  FAIL=$((FAIL + 1))
fi

if grep -q "alice-gh/agile-flow-gcp" "$T13/stdout.log"; then
  echo -e "  ${GREEN}✓${NC} binding log names alice-gh/agile-flow-gcp (default WIF_REPO)"
  PASS=$((PASS + 1))
else
  echo -e "  ${RED}✗${NC} expected binding log to mention alice-gh/agile-flow-gcp"
  cat "$T13/stdout.log"
  FAIL=$((FAIL + 1))
fi

# Final summary line should print the WIF provider resource path with project number 12345
if grep -q "GCP_WORKLOAD_IDENTITY_PROVIDER = projects/12345/locations/global/workloadIdentityPools/github/providers/github" "$T13/stdout.log"; then
  echo -e "  ${GREEN}✓${NC} final summary prints concrete WIF provider resource"
  PASS=$((PASS + 1))
else
  echo -e "  ${RED}✗${NC} expected concrete WIF provider in final summary; got:"
  grep "WORKLOAD_IDENTITY" "$T13/stdout.log" || echo "(no WORKLOAD_IDENTITY line found)"
  FAIL=$((FAIL + 1))
fi

# Test 14: GITHUB_USERNAME set, WIF artifacts present → idempotent skip

echo ""
echo "Test 14: Step 5.5 idempotent when WIF artifacts already present"

T14=$(run_step5_5_test "present" "alice-gh")

if grep -q "skip.*WIF pool" "$T14/stdout.log"; then
  echo -e "  ${GREEN}✓${NC} skip-pool log line"
  PASS=$((PASS + 1))
else
  echo -e "  ${RED}✗${NC} expected '[skip] WIF pool' in stdout"
  FAIL=$((FAIL + 1))
fi

if grep -q "skip.*WIF provider" "$T14/stdout.log"; then
  echo -e "  ${GREEN}✓${NC} skip-provider log line"
  PASS=$((PASS + 1))
else
  echo -e "  ${RED}✗${NC} expected '[skip] WIF provider' in stdout"
  FAIL=$((FAIL + 1))
fi

# Binding step is always called (it's idempotent at the gcloud level)
if grep -q "bind.*workloadIdentityUser" "$T14/stdout.log"; then
  echo -e "  ${GREEN}✓${NC} binding step still ran (idempotent)"
  PASS=$((PASS + 1))
else
  echo -e "  ${RED}✗${NC} expected binding step to log [bind]"
  FAIL=$((FAIL + 1))
fi

# ── Summary ──────────────────────────────────────────────────────────────

echo ""
echo "─────────────────────────────────"
echo "  Passed: $PASS"
echo "  Failed: $FAIL"
echo "─────────────────────────────────"

(( FAIL > 0 )) && exit 1
exit 0
