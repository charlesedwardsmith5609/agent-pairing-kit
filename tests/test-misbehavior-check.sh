#!/usr/bin/env bash
# Unit tests for scripts/misbehavior-check.sh in a temp git repo.
# Usage: bash tests/test-misbehavior-check.sh
set -uo pipefail
kit="$(cd "$(dirname "$0")/.." && pwd)"
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

fail=0
check() { # name expected_rc actual_rc
  if [ "$2" -eq "$3" ]; then echo "ok   $1"; else echo "FAIL $1 (want rc=$2, got rc=$3)"; fail=1; fi
}
check_out() { # name needle haystack-file
  if grep -q "$2" "$3"; then echo "ok   $1"; else echo "FAIL $1 (missing: $2)"; fail=1; fi
}
check_not_out() { # name needle haystack-file
  if grep -q "$2" "$3"; then echo "FAIL $1 (unexpected: $2)"; fail=1; else echo "ok   $1"; fi
}

export GIT_AUTHOR_NAME=test GIT_AUTHOR_EMAIL=test@example.invalid
export GIT_COMMITTER_NAME=test GIT_COMMITTER_EMAIL=test@example.invalid

setup_repo() {
  rm -rf "$work/repo"
  mkdir -p "$work/repo"
  cd "$work/repo" || exit 2
  git init -q
  printf 'package main\nfunc Hello() string { return "hi" }\n' > main.go
  printf 'package main\nimport "testing"\nfunc TestHello(t *testing.T) {\n\tif Hello() != "hi" { t.Fatal("no") }\n}\n' > main_test.go
  git add main.go main_test.go
  git commit -q -m init
}

run_check() {
  # stdout+stderr captured; return code in $?
  bash "$kit/scripts/misbehavior-check.sh" "$work/repo" >"$work/out" 2>&1
}

# --- clean tree ---
setup_repo
run_check; check "clean tree exits 0" 0 $?
check_out "clean tree says OK" "misbehavior: OK" "$work/out"

# --- skip marker in diff ---
setup_repo
printf 'package main\nimport "testing"\nfunc TestHello(t *testing.T) {\n\tt.Skip("later")\n\tif Hello() != "hi" { t.Fatal("no") }\n}\n' > main_test.go
run_check; check "skip marker warns but exits 0" 0 $?
check_out "skip marker message" "skipped/disabled" "$work/out"
PAIRING_STRICT=1 run_check; check "skip marker fails when PAIRING_STRICT=1" 1 $?

# --- test-only change ---
setup_repo
printf 'package main\nimport "testing"\nfunc TestHello(t *testing.T) {\n\tif Hello() != "hi" { t.Fatal("nope") }\n}\n' > main_test.go
run_check; check "test-only warns exits 0" 0 $?
check_out "test-only message" "test files changed with no matching source change" "$work/out"

# --- test + source: no test-only finding ---
setup_repo
printf 'package main\nfunc Hello() string { return "hey" }\n' > main.go
printf 'package main\nimport "testing"\nfunc TestHello(t *testing.T) {\n\tif Hello() != "hey" { t.Fatal("no") }\n}\n' > main_test.go
run_check
check_not_out "paired test+source skips test-only" "test files changed with no matching source change" "$work/out"

# --- plan-scope with ## Files ---
setup_repo
mkdir -p plans
cat > plans/step-1.md <<'EOF'
# Step 1
## Files
- main.go
- main_test.go
EOF
printf 'extra\n' > other.go
run_check; check "out-of-plan warns exits 0" 0 $?
check_out "out-of-plan message" "path outside plan ## Files: other.go" "$work/out"
PAIRING_STRICT=1 run_check; check "out-of-plan fails when strict" 1 $?

# --- no ## Files: skip plan-scope ---
setup_repo
mkdir -p plans
printf '# Step 1\nJust prose about files touched.\n' > plans/step-1.md
printf 'extra\n' > other.go
run_check; check "no Files section exits 0" 0 $?
check_out "plan-scope skipped message" "plan-scope skipped (no parseable ## Files)" "$work/out"
check_not_out "no false out-of-plan" "path outside plan ## Files" "$work/out"

# --- gate file change ---
setup_repo
mkdir -p scripts
printf '#!/bin/sh\necho gate\n' > scripts/check.sh
run_check; check "gate file warns exits 0" 0 $?
check_out "gate file message" "validation gate file changed: scripts/check.sh" "$work/out"

exit "$fail"
