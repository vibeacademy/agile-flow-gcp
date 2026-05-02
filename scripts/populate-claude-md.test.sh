#!/usr/bin/env bash
#
# Tests for populate-claude-md.sh — CLAUDE.md placeholder population.
# Exercises the marker-block replacement, git-remote auto-detection,
# idempotency, dry-run, and error handling.
#
# Run: ./scripts/populate-claude-md.test.sh

set -uo pipefail

GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

PASS=0
FAIL=0

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT="$REPO_ROOT/scripts/populate-claude-md.sh"

new_sandbox() { mktemp -d -t aflowclaudemd-XXXX; }

# Write a CLAUDE.md test fixture into the sandbox with the marker
# block in its initial (placeholder) state.
write_fixture() {
    local sandbox="$1"
    cat > "$sandbox/CLAUDE.md" <<'EOF'
# Some project

## Project-Specific Configuration

### Project Information

- **License**: BSL 1.1
<!-- bootstrap:project-config:start -->
- **Project Name**: [Your project name]
- **Organization**: [GitHub org name]
- **Repository**: [GitHub repo URL]
- **Project Board**: [GitHub project board URL]
<!-- bootstrap:project-config:end -->
- **Tech Stack**: FastAPI

## Reference
EOF
}

# Initialize a git repo with origin set so the script can auto-detect.
init_git_remote() {
    local sandbox="$1" remote_url="$2"
    git -C "$sandbox" init -q -b main 2>/dev/null
    git -C "$sandbox" remote add origin "$remote_url" 2>/dev/null
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

# ── Test 1: Happy path with all flags ─────────────────────────────────

echo ""
echo "Test 1: happy path with --project-name + --project-board"

T1=$(new_sandbox)
write_fixture "$T1"

set +e
(cd "$T1" && bash "$SCRIPT" \
    --project-name "MyApp" \
    --project-board "https://github.com/orgs/myorg/projects/3" \
    --owner "myorg" \
    --repo "myapp" \
    > "$T1/run.log" 2>&1)
ec=$?
set -e

assert_eq "0" "$ec" "exit 0"
assert_contains "Project Name**: MyApp" "$T1/CLAUDE.md" "Project Name replaced"
assert_contains "Organization**: myorg" "$T1/CLAUDE.md" "Organization replaced"
assert_contains "Repository**: https://github.com/myorg/myapp" "$T1/CLAUDE.md" "Repository URL derived"
assert_contains "Project Board**: https://github.com/orgs/myorg/projects/3" "$T1/CLAUDE.md" "Project Board replaced"
assert_not_contains "[Your project name]" "$T1/CLAUDE.md" "no leftover placeholder"
assert_contains "Tech Stack**: FastAPI" "$T1/CLAUDE.md" "Tech Stack line preserved (outside marker)"

# ── Test 2: Idempotent re-run ─────────────────────────────────────────

echo ""
echo "Test 2: re-run on already-populated file → no-op"

T2=$(new_sandbox)
write_fixture "$T2"

# First run
(cd "$T2" && bash "$SCRIPT" \
    --project-name "MyApp" \
    --project-board "https://github.com/orgs/myorg/projects/3" \
    --owner "myorg" --repo "myapp" \
    > "$T2/run1.log" 2>&1)
hash1=$(md5 -q "$T2/CLAUDE.md" 2>/dev/null || md5sum "$T2/CLAUDE.md" | cut -d' ' -f1)

# Second run with same args
set +e
(cd "$T2" && bash "$SCRIPT" \
    --project-name "MyApp" \
    --project-board "https://github.com/orgs/myorg/projects/3" \
    --owner "myorg" --repo "myapp" \
    > "$T2/run2.log" 2>&1)
ec=$?
set -e
hash2=$(md5 -q "$T2/CLAUDE.md" 2>/dev/null || md5sum "$T2/CLAUDE.md" | cut -d' ' -f1)

assert_eq "0" "$ec" "exit 0"
assert_eq "$hash1" "$hash2" "file content unchanged on re-run"
assert_contains "already up to date" "$T2/run2.log" "no-op message on re-run"

# ── Test 3: Auto-detect owner/repo from git remote (HTTPS) ────────────

echo ""
echo "Test 3: auto-detect from HTTPS git remote"

T3=$(new_sandbox)
write_fixture "$T3"
init_git_remote "$T3" "https://github.com/auto-org/auto-repo.git"

set +e
(cd "$T3" && bash "$SCRIPT" \
    --project-name "AutoApp" \
    --project-board "https://github.com/orgs/auto-org/projects/1" \
    > "$T3/run.log" 2>&1)
ec=$?
set -e

assert_eq "0" "$ec" "exit 0"
assert_contains "Organization**: auto-org" "$T3/CLAUDE.md" "owner derived from HTTPS remote"
assert_contains "Repository**: https://github.com/auto-org/auto-repo" "$T3/CLAUDE.md" "repo derived from HTTPS remote"

# ── Test 4: Auto-detect from SSH git remote ───────────────────────────

echo ""
echo "Test 4: auto-detect from SSH git remote"

T4=$(new_sandbox)
write_fixture "$T4"
init_git_remote "$T4" "git@github.com:ssh-org/ssh-repo.git"

set +e
(cd "$T4" && bash "$SCRIPT" \
    --project-name "SshApp" \
    --project-board "https://github.com/orgs/ssh-org/projects/1" \
    > "$T4/run.log" 2>&1)
ec=$?
set -e

assert_eq "0" "$ec" "exit 0"
assert_contains "Organization**: ssh-org" "$T4/CLAUDE.md" "owner derived from SSH remote"
assert_contains "Repository**: https://github.com/ssh-org/ssh-repo" "$T4/CLAUDE.md" "repo URL normalized to https"

# ── Test 5: Marker block missing → exit 1 ─────────────────────────────

echo ""
echo "Test 5: missing marker block → fail fast"

T5=$(new_sandbox)
cat > "$T5/CLAUDE.md" <<'EOF'
# Project without markers

- **Project Name**: foo
EOF

set +e
(cd "$T5" && bash "$SCRIPT" \
    --project-name "X" --project-board "Y" \
    --owner "o" --repo "r" \
    > "$T5/run.log" 2>&1)
ec=$?
set -e

assert_eq "1" "$ec" "exit 1 when markers missing"
assert_contains "Marker block not found" "$T5/run.log" "names the issue"

# ── Test 6: File missing → exit 1 ─────────────────────────────────────

echo ""
echo "Test 6: target file missing → fail fast"

T6=$(new_sandbox)

set +e
(cd "$T6" && bash "$SCRIPT" \
    --project-name "X" --project-board "Y" \
    --owner "o" --repo "r" \
    --file "nope.md" \
    > "$T6/run.log" 2>&1)
ec=$?
set -e

assert_eq "1" "$ec" "exit 1 when file missing"
assert_contains "File not found" "$T6/run.log" "names the issue"

# ── Test 7: Dry-run does not modify the file ──────────────────────────

echo ""
echo "Test 7: --dry-run preview without writes"

T7=$(new_sandbox)
write_fixture "$T7"
hash_before=$(md5 -q "$T7/CLAUDE.md" 2>/dev/null || md5sum "$T7/CLAUDE.md" | cut -d' ' -f1)

set +e
(cd "$T7" && bash "$SCRIPT" \
    --project-name "DryApp" \
    --project-board "https://github.com/orgs/dry/projects/1" \
    --owner "dry" --repo "dryrepo" \
    --dry-run \
    > "$T7/run.log" 2>&1)
ec=$?
set -e

hash_after=$(md5 -q "$T7/CLAUDE.md" 2>/dev/null || md5sum "$T7/CLAUDE.md" | cut -d' ' -f1)

assert_eq "0" "$ec" "exit 0"
assert_contains "Dry-run" "$T7/run.log" "dry-run banner"
assert_contains "Project Name**: DryApp" "$T7/run.log" "planned content shown in output"
assert_eq "$hash_before" "$hash_after" "file unchanged in dry-run"
assert_contains "[Your project name]" "$T7/CLAUDE.md" "placeholders still present in dry-run"

# ── Test 8: Non-interactive without --project-name → uses suggested ──

echo ""
echo "Test 8: non-interactive context with no --project-name → uses suggested"

T8=$(new_sandbox)
write_fixture "$T8"

# Run with stdin redirected from /dev/null so [ -t 0 ] is false.
# Provide --owner --repo so derivation succeeds. Skip --project-name
# and --project-board. Both should fall through to suggested values
# (repo name and orgs URL respectively) with WARN messages.
set +e
(cd "$T8" && bash "$SCRIPT" \
    --owner "octo" --repo "octopus" \
    < /dev/null \
    > "$T8/run.log" 2>&1)
ec=$?
set -e

assert_eq "0" "$ec" "exit 0 (used suggested defaults non-interactively)"
assert_contains "using suggested value" "$T8/run.log" "WARN about suggested fallback"
assert_contains "Project Name**: octopus" "$T8/CLAUDE.md" "fell through to repo-name suggestion"

# ── Test 9: Unknown flag → exit 1 ─────────────────────────────────────

echo ""
echo "Test 9: unknown argument → fail fast"

T9=$(new_sandbox)

set +e
(cd "$T9" && bash "$SCRIPT" --bogus-flag > "$T9/run.log" 2>&1)
ec=$?
set -e

assert_eq "1" "$ec" "exit 1 on unknown flag"
assert_contains "Unknown argument" "$T9/run.log" "names the issue"

# ── Test 10: No git remote AND no --owner/--repo → exit 2 ─────────────

echo ""
echo "Test 10: no git remote and no --owner/--repo → exit 2"

T10=$(new_sandbox)
write_fixture "$T10"
# Initialize a git repo BUT do NOT add a remote
git -C "$T10" init -q -b main 2>/dev/null

set +e
(cd "$T10" && bash "$SCRIPT" \
    --project-name "NoRemote" --project-board "x" \
    < /dev/null \
    > "$T10/run.log" 2>&1)
ec=$?
set -e

assert_eq "2" "$ec" "exit 2 when neither remote nor flag is available"
assert_contains "No git remote found" "$T10/run.log" "names the issue"

# ── Summary ──────────────────────────────────────────────────────────

echo ""
echo "─────────────────────────────────"
echo "  Passed: $PASS"
echo "  Failed: $FAIL"
echo "─────────────────────────────────"

(( FAIL > 0 )) && exit 1
exit 0
