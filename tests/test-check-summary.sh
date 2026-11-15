#!/usr/bin/env bash
# check.sh summary labels (PASS/WARN/FAIL), missing helper scripts, and new-project.sh --backfill.
# Uses a scratch project with an empty .pairing-profiles so no toolchain is needed.
set -uo pipefail
kit="$(cd "$(dirname "$0")/.." && pwd)"
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

fail=0
check() { if [ "$2" -eq "$3" ]; then echo "ok   $1"; else echo "FAIL $1 (want rc=$2, got rc=$3)"; fail=1; fi; }
check_out() { if grep -q -- "$2" "$3"; then echo "ok   $1"; else echo "FAIL $1 (missing: $2)"; fail=1; fi; }
check_no() { if grep -q -- "$2" "$3"; then echo "FAIL $1 (unexpected: $2)"; fail=1; else echo "ok   $1"; fi; }

mkproj() {
  rm -rf "$work/p"; mkdir -p "$work/p/scripts"
  cp "$kit/scripts/"{check.sh,misbehavior-check.sh,assertion-check.sh,review-call.sh} "$work/p/scripts/"
  : > "$work/p/.pairing-profiles"
  git -C "$work/p" init -q
  git -C "$work/p" add -A
  git -C "$work/p" -c user.email=t@example.invalid -c user.name=t commit -q -m init
}
run_check() { (cd "$work/p" && bash scripts/check.sh >"$work/out" 2>&1); }

mkproj
run_check; check "clean project rc" 0 $?
check_out "clean assertions PASS" "^  assertions: PASS$" "$work/out"
check_out "clean misbehavior PASS" "^  misbehavior: PASS$" "$work/out"
check_no "clean has no WARN label" "^  assertions: WARN$" "$work/out"
check_out "clean ends CHECK PASSED" "CHECK PASSED" "$work/out"

printf 'def test_none():\n    helper()\n' > "$work/p/test_none.py"
run_check; check "warning project rc" 0 $?
check_out "assertions shows WARN" "^  assertions: WARN$" "$work/out"
check_out "warning still CHECK PASSED" "CHECK PASSED" "$work/out"

PAIRING_STRICT=1 run_check; check "strict warning project rc" 1 $?
check_out "strict shows FAIL" "^  assertions: FAIL$" "$work/out"
check_out "strict CHECK FAILED" "CHECK FAILED" "$work/out"

# Missing helper script: named warning, not a bash error.
mkproj
rm "$work/p/scripts/assertion-check.sh"
run_check; check "missing helper rc" 0 $?
check_out "missing helper is named" "scripts/assertion-check.sh" "$work/out"
check_out "missing helper shows WARN" "^  assertions: WARN$" "$work/out"
check_no "no raw bash error" "No such file" "$work/out"
PAIRING_STRICT=1 run_check; check "missing helper strict rc" 1 $?
check_out "missing helper strict FAIL" "^  assertions: FAIL$" "$work/out"

# --- new-project.sh --backfill ---
export PAIRING_SKIP_PLUGINS=1
mkproj
rm "$work/p/scripts/assertion-check.sh"
echo '# edited' >> "$work/p/scripts/misbehavior-check.sh"
cp "$work/p/scripts/misbehavior-check.sh" "$work/edited"
bash "$kit/new-project.sh" --backfill "$work/p" >"$work/out" 2>&1; check "backfill rc" 0 $?
cmp -s "$kit/scripts/assertion-check.sh" "$work/p/scripts/assertion-check.sh"; check "missing helper added" 0 $?
cmp -s "$work/edited" "$work/p/scripts/misbehavior-check.sh"; check "edited helper untouched" 0 $?
bash "$kit/new-project.sh" --backfill "$work/p" >"$work/out" 2>&1; check "second backfill rc" 0 $?
cmp -s "$work/edited" "$work/p/scripts/misbehavior-check.sh"; check "edited helper still untouched" 0 $?

mkdir -p "$work/plain"
bash "$kit/new-project.sh" --backfill "$work/plain" >"$work/out" 2>&1; check "backfill without profiles rc" 2 $?
[ ! -e "$work/plain/scripts" ]; check "nothing written without profiles" 0 $?

printf '\n%s\n' "$fail"
exit "$fail"
