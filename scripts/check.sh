#!/usr/bin/env bash
# Validation gate: agent-misbehavior heuristics, then every language's checks.
# The project's languages and directories are listed in .pairing-profiles.
# Usage: bash scripts/check.sh
# Set PAIRING_STRICT=1 to fail on misbehavior warnings.
set -u
root="$(cd "$(dirname "$0")/.." && pwd)"
list="$root/.pairing-profiles"
[ -f "$list" ] || { echo "check: $list not found"; exit 2; }

fail=0 results=""

printf '\n######## misbehavior\n'
if bash "$root/scripts/misbehavior-check.sh" "$root"; then
  results="$results\n  misbehavior: PASS"
else
  results="$results\n  misbehavior: FAIL"
  fail=1
fi

while read -r profile dir <&3; do
  [ -n "${profile:-}" ] || continue
  printf '\n######## %s (%s)\n' "$profile" "$dir"
  if (cd "$root/$dir" && bash "$root/scripts/checks/$profile.sh"); then
    results="$results\n  $profile ($dir): PASS"
  else
    results="$results\n  $profile ($dir): FAIL"
    fail=1
  fi
done 3< "$list"

printf '\nSummary:%b\n' "$results"
if [ "$fail" -eq 0 ]; then echo "CHECK PASSED"; else echo "CHECK FAILED"; fi
exit "$fail"
