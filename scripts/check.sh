#!/usr/bin/env bash
# Validation gate: agent-misbehavior heuristics, then every language's checks.
# The project's languages and directories are listed in .pairing-profiles.
# Usage: bash scripts/check.sh
# Staged additions are scanned with the same gitleaks command as the reviews.
# A match warns. Set PAIRING_STRICT=1 to fail the gate. This is not a separate stage.
# The same knob fails agent-misbehavior warnings.
set -u
root="$(cd "$(dirname "$0")/.." && pwd)"
list="$root/.pairing-profiles"
[ -f "$list" ] || { echo "check: $list not found"; exit 2; }

# Fail the gate when a strict knob is set. PAIRING_STRICT covers findings and scan
# failures. REQUIRE_SECRET_SCAN covers a scan that did not finish.
scan_must_fail() {
  [ "${PAIRING_STRICT:-}" = "1" ] || [ "${REQUIRE_SECRET_SCAN:-0}" = 1 ]
}

# Added-line bodies from the staged diff. +++ headers sit outside hunks; a line
# whose text starts with "++ " is an addition once a hunk has begun.
staged_additions() {
  local diff rc=0
  diff=$(git -C "$root" diff --cached --no-color -- .) || rc=$?
  if [ "$rc" -ne 0 ]; then
    echo "check: git diff --cached failed (exit $rc)." >&2
    return "$rc"
  fi
  printf '%s\n' "$diff" | awk '
    /^diff --git / { in_hunk = 0; next }
    /^@@ / { in_hunk = 1; next }
    in_hunk && /^\+/ { print substr($0, 2) }
  '
}

# Returns 0 when the gate may continue, 1 when it must fail.
scan_staged_additions() {
  git -C "$root" rev-parse --is-inside-work-tree >/dev/null 2>&1 || return 0
  local added tmp rc out
  rc=0
  added=$(staged_additions) || rc=$?
  if [ "$rc" -ne 0 ]; then
    scan_must_fail && return 1
    return 0
  fi
  [ -n "$added" ] || return 0
  tmp=$(mktemp) || {
    echo "WARNING: could not create a temp file for the secret scan." >&2
    scan_must_fail && return 1
    return 0
  }
  trap 'rm -f "$tmp"' EXIT INT TERM
  printf '%s\n' "$added" > "$tmp"
  # shellcheck disable=SC1091
  . "$root/scripts/review-call.sh"
  rc=0
  out=$(review_gitleaks_scan "$tmp") || rc=$?
  rm -f "$tmp"
  trap - EXIT INT TERM
  if [ "$rc" -eq 0 ]; then
    return 0
  fi
  if [ "$rc" -eq 127 ]; then
    if [ "${REQUIRE_SECRET_SCAN:-0}" = 1 ]; then
      echo "check: REQUIRE_SECRET_SCAN=1 but gitleaks is not installed." >&2
      return 1
    fi
    echo "WARNING: gitleaks is not installed; staged additions were not secret-scanned." >&2
    return 0
  fi
  if [ "$rc" -ne 7 ]; then
    printf '%s\n' "$out" | tail -n 25 >&2
    echo "WARNING: secret scan failed (gitleaks exit $rc). Staged additions were not cleared." >&2
    scan_must_fail && return 1
    return 0
  fi
  printf '%s\n' "$out" | tail -n 25 >&2
  if [ "${PAIRING_STRICT:-}" = "1" ]; then
    echo "check: staged additions matched the secret scan (PAIRING_STRICT=1)." >&2
    return 1
  fi
  echo "WARNING: staged additions matched the secret scan. Set PAIRING_STRICT=1 to fail." >&2
  return 0
}

fail=0 results=""
if ! scan_staged_additions; then
  results="$results\n  staged secrets: FAIL"
  fail=1
fi

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
