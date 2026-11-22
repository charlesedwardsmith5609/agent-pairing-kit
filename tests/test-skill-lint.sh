#!/usr/bin/env bash
# scripts/skill-lint.sh: structural lint of profiles/*/skills/*.md, and its check.sh stage.
set -uo pipefail
kit="$(cd "$(dirname "$0")/.." && pwd)"
lint="$kit/scripts/skill-lint.sh"
work=$(mktemp -d)
trap 'chmod -R u+rwx "$work" 2>/dev/null; rm -rf "$work"' EXIT

fail=0
check() { if [ "$2" -eq "$3" ]; then echo "ok   $1"; else echo "FAIL $1 (want rc=$2, got rc=$3)"; fail=1; fi; }
check_out() { if grep -q -- "$2" "$3"; then echo "ok   $1"; else echo "FAIL $1 (missing: $2)"; fail=1; fi; }
check_no() { if grep -q -- "$2" "$3"; then echo "FAIL $1 (unexpected: $2)"; fail=1; else echo "ok   $1"; fi; }

# mk NAME: fresh scratch root with one clean skill in profile p
mk() {
  r="$work/$1"; rm -rf "$r"; mkdir -p "$r/profiles/p/skills"
  printf '# Skill A\n\nLoad before editing services.\n\n## Testing\n\nBody.\n' > "$r/profiles/p/skills/a.md"
}
# run NAME [strict]: lint scratch root, output in $work/out, rc in $rc
run() {
  rc=0
  if [ "${2:-}" = strict ]; then PAIRING_STRICT=1 bash "$lint" "$work/$1" >"$work/out" 2>&1 || rc=$?
  else bash "$lint" "$work/$1" >"$work/out" 2>&1 || rc=$?; fi
}

# 1 clean (two skills, distinct headings)
mk clean
printf '# Skill B\n\nRead when touching queues.\n\n## Queues\n\nBody.\n' > "$work/clean/profiles/p/skills/b.md"
run clean; check "clean rc" 0 "$rc"
check_out "clean OK line" "skill-lint: OK" "$work/out"
check_no "clean no WARN" "WARN" "$work/out"
run clean strict; check "clean strict rc" 0 "$rc"

# 2 missing title
mk notitle
printf 'Load before editing.\n\n## Testing\n' > "$work/notitle/profiles/p/skills/a.md"
run notitle; check "no title rc" 0 "$rc"
check_out "no title named" "a.md.*title" "$work/out"
run notitle strict; check "no title strict rc" 1 "$rc"
check_out "no title strict FAIL" "FAIL" "$work/out"

# 3 two titles
mk twotitles
printf '# One\n\nLoad before editing.\n\n# Two\n' > "$work/twotitles/profiles/p/skills/a.md"
run twotitles; check "two titles rc" 0 "$rc"
check_out "two titles named" "title.*1.*5" "$work/out"
run twotitles strict; check "two titles strict rc" 1 "$rc"

# 4 # inside a fence is not a title
mk fence
printf '# One\n\nLoad before editing.\n\n```sh\n# a comment\n```\n' > "$work/fence/profiles/p/skills/a.md"
run fence; check_no "fenced comment not a title" "title" "$work/out"
# 4b mixed fences
mk fence2
printf '# One\n\nLoad before editing.\n\n```sh\n~~~\n# x\n```\n\n````md\n```\n# y\n````\n' > "$work/fence2/profiles/p/skills/a.md"
run fence2; check_no "mixed fences keep block open" "title" "$work/out"
check_out "mixed fences OK" "skill-lint: OK" "$work/out"

# 4c scan error (skipped as root)
mk unread
chmod 000 "$work/unread/profiles/p/skills/a.md"
if [ -r "$work/unread/profiles/p/skills/a.md" ]; then
  echo "skip scan-error (file still readable, running as root)"
else
  run unread; check "scan error rc" 0 "$rc"
  check_out "scan-error named" "scan-error" "$work/out"
  run unread strict; check "scan error strict rc" 1 "$rc"
fi

# 5 no when-to-read
mk nowhen
printf '# One\n\nSome text.\n\n## Testing\n' > "$work/nowhen/profiles/p/skills/a.md"
run nowhen; check_out "when-to-read named" "when-to-read" "$work/out"
run nowhen strict; check "no when strict rc" 1 "$rc"

# 6 size boundary
mk big
head="$(printf '# One\n\nLoad before editing.\n\n')"
pad() { # pad TOTAL FILE
  printf '%s\n' "$head" > "$2"
  local have; have=$(wc -c < "$2")
  head -c $(( $1 - have )) /dev/zero | tr '\0' 'x' >> "$2"
}
pad 6145 "$work/big/profiles/p/skills/a.md"
[ "$(wc -c < "$work/big/profiles/p/skills/a.md")" -eq 6145 ]; check "fixture is 6145 bytes" 0 $?
run big; check_out "oversize named" "size" "$work/out"
run big strict; check "oversize strict rc" 1 "$rc"
pad 6144 "$work/big/profiles/p/skills/a.md"
[ "$(wc -c < "$work/big/profiles/p/skills/a.md")" -eq 6144 ]; check "fixture is 6144 bytes" 0 $?
run big; check_no "6144 bytes not oversize" "size" "$work/out"

# 7 duplicate heading
mk dup
printf '# Two\n\nLoad before editing.\n\n## 5. testing\n' > "$work/dup/profiles/p/skills/b.md"
printf '# One\n\nLoad before editing.\n\n## 2. Testing\n' > "$work/dup/profiles/p/skills/a.md"
run dup; check_out "duplicate named" "duplicate-heading" "$work/out"
check_out "duplicate names both files" "a.md.*b.md" "$work/out"
run dup strict; check "duplicate strict rc" 1 "$rc"
mk dupx
mkdir -p "$work/dupx/profiles/q/skills"
printf '# Other\n\nLoad before editing.\n\n## Testing\n' > "$work/dupx/profiles/q/skills/b.md"
run dupx; check_no "same heading across profiles ok" "duplicate-heading" "$work/out"

# 9 bad root, 10 no skills
bash "$lint" "$work/nonexistent" >"$work/out" 2>&1; check "bad root rc" 2 $?
mkdir -p "$work/empty"
bash "$lint" "$work/empty" >"$work/out" 2>&1; check "no skills rc" 0 $?
check_out "no skills message" "nothing checked" "$work/out"

# 11 the kit's own skills pass strict
PAIRING_STRICT=1 bash "$lint" "$kit" >"$work/out" 2>&1; check "kit skills strict rc" 0 $?

# 12/13 check.sh stage
mkproj() {
  rm -rf "$work/p"; mkdir -p "$work/p/scripts"
  cp "$kit/scripts/"{check.sh,misbehavior-check.sh,assertion-check.sh,review-call.sh,skill-lint.sh} "$work/p/scripts/"
  : > "$work/p/.pairing-profiles"
  if [ "${1:-}" = profiles ]; then
    mkdir -p "$work/p/profiles/x/skills"
    printf '# A\n\nLoad before editing.\n' > "$work/p/profiles/x/skills/a.md"
  fi
  git -C "$work/p" init -q
  git -C "$work/p" add -A
  git -C "$work/p" -c user.email=t@example.invalid -c user.name=t commit -q -m init
}
run_check() { (cd "$work/p" && bash scripts/check.sh >"$work/out" 2>&1); }
mkproj profiles
run_check; check "check.sh clean rc" 0 $?
check_out "check.sh skills PASS" "^  skills: PASS$" "$work/out"
printf 'no heading\n' > "$work/p/profiles/x/skills/a.md"
run_check; check "check.sh warn rc" 0 $?
check_out "check.sh skills WARN" "^  skills: WARN$" "$work/out"
check_out "check.sh warn still passes" "CHECK PASSED" "$work/out"
PAIRING_STRICT=1 run_check; check "check.sh strict rc" 1 $?
check_out "check.sh skills FAIL" "^  skills: FAIL$" "$work/out"
check_out "check.sh CHECK FAILED" "CHECK FAILED" "$work/out"
mkproj
run_check; check "no profiles rc" 0 $?
check_no "no skills stage without profiles" "skills:" "$work/out"

printf '\n%s\n' "$fail"
exit "$fail"
