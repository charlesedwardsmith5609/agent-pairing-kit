#!/usr/bin/env bash
# The assertion scan reads test files. It does not read git diffs.
set -uo pipefail
kit="$(cd "$(dirname "$0")/.." && pwd)"
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

fail=0
check() {
  if [ "$2" -eq "$3" ]; then echo "ok   $1"; else echo "FAIL $1 (want rc=$2, got rc=$3)"; fail=1; fi
}
check_out() {
  if grep -q "$2" "$3"; then echo "ok   $1"; else echo "FAIL $1 (missing: $2)"; fail=1; fi
}

run_scan() {
  bash "$kit/scripts/assertion-check.sh" "$work/proj" >"$work/out" 2>&1
}

mkdir -p "$work/proj"
printf 'package p\nfunc TestOk(t *testing.T) {\n\tif false { t.Fatal("no") }\n}\n' > "$work/proj/ok_test.go"
run_scan; check "asserting go test passes" 0 $?
check_out "clean go says OK" "assertions: OK" "$work/out"

printf 'package p\nfunc TestEmpty(t *testing.T) {\n\tHelper()\n}\n' > "$work/proj/empty_test.go"
run_scan; check "empty go test warns" 0 $?
check_out "empty go test is named" "TestEmpty has no assertion" "$work/out"

PAIRING_STRICT=1 run_scan; check "empty go test fails when strict" 1 $?
check_out "strict failure is named" "PAIRING_STRICT=1" "$work/out"

mkdir -p "$work/proj/pkg"
printf 'def test_ok():\n    assert True\n' > "$work/proj/pkg/test_ok.py"
printf 'def test_empty():\n    helper()\n' > "$work/proj/pkg/test_empty.py"
# Keep the go failure so strict still fails, and the python name is present.
run_scan; check "python empty test is a warning by default" 0 $?
unset PAIRING_STRICT
run_scan
check_out "python empty test is named" "test_empty has no assertion" "$work/out"

# A committed assertion-free test is flagged even when the git diff is empty.
rm -rf "$work/proj"
mkdir -p "$work/proj"
git -C "$work/proj" init -q
printf 'package p\nfunc TestQuiet(t *testing.T) {\n\treturn\n}\n' > "$work/proj/quiet_test.go"
git -C "$work/proj" add quiet_test.go
git -C "$work/proj" -c user.email=t@example.invalid -c user.name=t commit -q -m init
run_scan; check "committed empty test still warns" 0 $?
check_out "scan saw the file not the diff" "TestQuiet has no assertion" "$work/out"

printf '\n%s\n' "$fail"
exit "$fail"
