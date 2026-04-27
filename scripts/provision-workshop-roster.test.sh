#!/usr/bin/env bash
#
# Tests for provision-workshop-roster.sh
#
# Stubs `gcloud` and the inner provisioner via PATH injection + env override
# so we can assert behavior without touching real GCP.
#
# Run: ./scripts/provision-workshop-roster.test.sh

set -euo pipefail

GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

PASS=0
FAIL=0

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WRAPPER="$REPO_ROOT/scripts/provision-workshop-roster.sh"

# Each test runs in a fresh tmpdir to keep output CSVs isolated.
new_tmp() {
  mktemp -d -t aflowtest-XXXX
}

# Build a fake gcloud + provision-gcp-project.sh in $tmp/bin and prepend to PATH.
#   $1: tmpdir
#   $2: behavior — "ok", "skip-first" (project exists for first row), or "fail"
make_stubs() {
  local tmp="$1"
  local behavior="$2"
  mkdir -p "$tmp/bin"

  # Fake gcloud
  cat > "$tmp/bin/gcloud" <<EOF
#!/usr/bin/env bash
# Log every invocation to a file so the test can assert on it.
echo "gcloud \$*" >> "$tmp/gcloud.log"

case "\$1" in
  projects)
    case "\$2" in
      describe)
        # describe <project_id>
        if [[ "$behavior" == "skip-first" && "\$3" == af-alice-* ]]; then
          exit 0  # alice's project "exists"
        fi
        exit 1    # default: project does not exist
        ;;
      add-iam-policy-binding)
        exit 0
        ;;
    esac
    ;;
  *)
    exit 0
    ;;
esac
EOF

  # Fake inner provisioner
  cat > "$tmp/bin/provision-gcp-project.sh" <<EOF
#!/usr/bin/env bash
# Log every invocation
echo "provision \$* GCP_PROJECT_ID=\${GCP_PROJECT_ID:-}" >> "$tmp/provision.log"

if [[ "$behavior" == "fail" ]]; then
  echo "fake provision failure" >&2
  exit 1
fi
exit 0
EOF

  chmod +x "$tmp/bin/gcloud" "$tmp/bin/provision-gcp-project.sh"
}

write_roster() {
  local path="$1"
  cat > "$path" <<'EOF'
handle,github_user,email,cohort
alice,alice-gh,alice@example.com,2026-05
bob,bob-gh,bob@example.com,2026-05
EOF
}

assert_contains() {
  local needle="$1"
  local haystack_file="$2"
  local label="$3"
  if grep -q "$needle" "$haystack_file"; then
    echo -e "  ${GREEN}✓${NC} $label"
    PASS=$((PASS + 1))
  else
    echo -e "  ${RED}✗${NC} $label  (looking for: $needle in $haystack_file)"
    FAIL=$((FAIL + 1))
  fi
}

assert_eq() {
  local expected="$1"
  local actual="$2"
  local label="$3"
  if [[ "$expected" == "$actual" ]]; then
    echo -e "  ${GREEN}✓${NC} $label"
    PASS=$((PASS + 1))
  else
    echo -e "  ${RED}✗${NC} $label  (expected: $expected; got: $actual)"
    FAIL=$((FAIL + 1))
  fi
}

# ── Test 1: Happy path — both rows attempted, output CSV correct ─────────

echo ""
echo "Test 1: Happy path with 2-row roster"

T1=$(new_tmp)
make_stubs "$T1" "ok"
write_roster "$T1/roster.csv"

set +e
PATH="$T1/bin:$PATH" \
  BILLING_ACCOUNT_ID="FAKE-BILLING" \
  PROVISION_SCRIPT="$T1/bin/provision-gcp-project.sh" \
  OUTPUT_CSV="$T1/roster-output.csv" \
  "$WRAPPER" "$T1/roster.csv" > "$T1/stdout.log" 2>&1
exit_code=$?
set -e

assert_eq "0" "$exit_code" "wrapper exits 0"
assert_eq "2" "$(grep -c '^provision' "$T1/provision.log")" "inner provisioner called twice"
assert_contains "alice,af-alice-2026-05,created" "$T1/roster-output.csv" "alice row recorded as created"
assert_contains "bob,af-bob-2026-05,created" "$T1/roster-output.csv" "bob row recorded as created"
assert_contains "Total rows processed:   2" "$T1/stdout.log" "summary shows 2 rows"

# ── Test 2: Idempotent re-run — both rows show "skipped" ─────────────────

echo ""
echo "Test 2: Idempotent re-run (project already exists for both rows)"

T2=$(new_tmp)
# Custom stub: gcloud projects describe always succeeds (project exists)
mkdir -p "$T2/bin"
cat > "$T2/bin/gcloud" <<EOF
#!/usr/bin/env bash
echo "gcloud \$*" >> "$T2/gcloud.log"
case "\$1 \$2" in
  "projects describe") exit 0 ;;  # always exists
  "projects add-iam-policy-binding") exit 0 ;;
  *) exit 0 ;;
esac
EOF
cat > "$T2/bin/provision-gcp-project.sh" <<EOF
#!/usr/bin/env bash
echo "provision \$* GCP_PROJECT_ID=\${GCP_PROJECT_ID:-}" >> "$T2/provision.log"
exit 0
EOF
chmod +x "$T2/bin/gcloud" "$T2/bin/provision-gcp-project.sh"

write_roster "$T2/roster.csv"

set +e
PATH="$T2/bin:$PATH" \
  BILLING_ACCOUNT_ID="FAKE-BILLING" \
  PROVISION_SCRIPT="$T2/bin/provision-gcp-project.sh" \
  OUTPUT_CSV="$T2/roster-output.csv" \
  "$WRAPPER" "$T2/roster.csv" > "$T2/stdout.log" 2>&1
exit_code=$?
set -e

assert_eq "0" "$exit_code" "wrapper exits 0 on re-run"
assert_contains "alice,af-alice-2026-05,skipped" "$T2/roster-output.csv" "alice row recorded as skipped"
assert_contains "bob,af-bob-2026-05,skipped" "$T2/roster-output.csv" "bob row recorded as skipped"
assert_contains "Already existed:        2" "$T2/stdout.log" "summary shows 2 skipped"

# ── Test 3: Fail-fast — first row fails, second row never attempted ─────

echo ""
echo "Test 3: Fail-fast on first-row error"

T3=$(new_tmp)
make_stubs "$T3" "fail"
write_roster "$T3/roster.csv"

set +e
PATH="$T3/bin:$PATH" \
  BILLING_ACCOUNT_ID="FAKE-BILLING" \
  PROVISION_SCRIPT="$T3/bin/provision-gcp-project.sh" \
  OUTPUT_CSV="$T3/roster-output.csv" \
  "$WRAPPER" "$T3/roster.csv" > "$T3/stdout.log" 2>&1
exit_code=$?
set -e

if [[ "$exit_code" -ne 0 ]]; then
  echo -e "  ${GREEN}✓${NC} wrapper exits non-zero on inner failure (got $exit_code)"
  PASS=$((PASS + 1))
else
  echo -e "  ${RED}✗${NC} wrapper should fail on inner script failure (got 0)"
  FAIL=$((FAIL + 1))
fi
assert_eq "1" "$(grep -c '^provision' "$T3/provision.log")" "inner provisioner called only once before exit"

# ── Test 4: Bad CSV header rejected ──────────────────────────────────────

echo ""
echo "Test 4: Bad CSV header is rejected"

T4=$(new_tmp)
make_stubs "$T4" "ok"
cat > "$T4/roster.csv" <<EOF
name,email
alice,alice@example.com
EOF

set +e
PATH="$T4/bin:$PATH" \
  BILLING_ACCOUNT_ID="FAKE-BILLING" \
  PROVISION_SCRIPT="$T4/bin/provision-gcp-project.sh" \
  OUTPUT_CSV="$T4/roster-output.csv" \
  "$WRAPPER" "$T4/roster.csv" > "$T4/stdout.log" 2>&1
exit_code=$?
set -e

if [[ "$exit_code" -eq 2 ]]; then
  echo -e "  ${GREEN}✓${NC} wrapper exits 2 on bad header"
  PASS=$((PASS + 1))
else
  echo -e "  ${RED}✗${NC} wrapper should exit 2 on bad header (got $exit_code)"
  FAIL=$((FAIL + 1))
fi
assert_contains "header must be exactly" "$T4/stdout.log" "error message mentions header format"

# ── Test 5: Missing BILLING_ACCOUNT_ID rejected ─────────────────────────

echo ""
echo "Test 5: Missing BILLING_ACCOUNT_ID is rejected"

T5=$(new_tmp)
make_stubs "$T5" "ok"
write_roster "$T5/roster.csv"

set +e
PATH="$T5/bin:$PATH" \
  PROVISION_SCRIPT="$T5/bin/provision-gcp-project.sh" \
  OUTPUT_CSV="$T5/roster-output.csv" \
  "$WRAPPER" "$T5/roster.csv" > "$T5/stdout.log" 2>&1
exit_code=$?
set -e

if [[ "$exit_code" -eq 2 ]]; then
  echo -e "  ${GREEN}✓${NC} wrapper exits 2 when BILLING_ACCOUNT_ID is unset"
  PASS=$((PASS + 1))
else
  echo -e "  ${RED}✗${NC} wrapper should exit 2 when BILLING_ACCOUNT_ID is unset (got $exit_code)"
  FAIL=$((FAIL + 1))
fi

# ── Summary ──────────────────────────────────────────────────────────────

echo ""
echo "─────────────────────────────────"
echo "  Passed: $PASS"
echo "  Failed: $FAIL"
echo "─────────────────────────────────"

if [[ "$FAIL" -gt 0 ]]; then
  exit 1
fi
exit 0
