#!/usr/bin/env bash
# Docs drift checks: README and CONTRIBUTING must match the files that exist.
set -uo pipefail
kit="$(cd "$(dirname "$0")/.." && pwd)"
fail=0
ok() { echo "ok   $1"; }
bad() { echo "FAIL $1"; fail=1; }
# has FILE PATTERN LABEL: ok when the fixed string is in the file.
has() { if grep -qF -- "$2" "$1"; then ok "$3"; else bad "$3"; fi; }

has "$kit/README.md" 'assertion-check.sh' "README mentions assertion-check.sh"
has "$kit/README.md" 'bash 4.4' "README documents bash 4.4"
if grep 'misbehavior-check\.sh' "$kit/README.md" | grep -qi 'diff checks'; then
  bad "README no longer calls misbehavior a diff check"
else
  ok "README no longer calls misbehavior a diff check"
fi

for t in "$kit"/tests/test-*.sh; do
  n="tests/$(basename "$t")"
  has "$kit/CONTRIBUTING.md" "$n" "CONTRIBUTING lists $n"
  has "$kit/README.md" "$n" "README lists $n"
done

printf '\n%s\n' "$fail"
exit "$fail"
