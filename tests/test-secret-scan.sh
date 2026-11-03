#!/usr/bin/env bash
# Tests review_scan_secrets in scripts/review-call.sh with a fake gitleaks, so no real binary,
# network or API key is needed. Usage: bash tests/test-secret-scan.sh
set -uo pipefail
kit="$(cd "$(dirname "$0")/.." && pwd)"
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
mkdir -p "$work/bin" "$work/empty-bin"
printf 'Review this diff:\n+aws_key = "AKIAIOSFODNN7EXAMPLE"\n' > "$work/user.md"

fail=0
check() { # name expected_rc actual_rc
  if [ "$2" -eq "$3" ]; then echo "ok   $1"; else echo "FAIL $1 (want rc=$2, got rc=$3)"; fail=1; fi
}

# Run the function in a subshell with a controlled PATH. $1 = PATH extra dir, rest = env.
run_scan() {
  local path_dir="$1"; shift
  ( export HOME="$work/home"; mkdir -p "$HOME"
    export PAIRING_KIT_ENV="$work/none.env"
    export REVIEW_USED_PROVIDER=test
    export PATH="$path_dir:/usr/bin:/bin"
    for kv in "$@"; do export "${kv?}"; done
    # shellcheck source=/dev/null
    . "$kit/scripts/review-call.sh" >/dev/null 2>&1
    review_scan_secrets "$work/user.md" >/dev/null 2>&1 )
}

# shellcheck disable=SC2016  # the fake script's $1/$2 must stay literal
fake() { # exit code the fake gitleaks returns
  printf '#!/bin/sh\n[ "$1" = stdin ] && [ "$2" = --help ] && { echo "gitleaks stdin"; exit 0; }\ncat >/dev/null; exit %s\n' "$1" > "$work/bin/gitleaks"
  chmod +x "$work/bin/gitleaks"
}

fake 7; run_scan "$work/bin"; check "finding refuses the review" 1 $?
fake 0; run_scan "$work/bin"; check "clean scan allows the review" 0 $?
fake 2; run_scan "$work/bin"; check "scanner error refuses the review" 1 $?
rm -f "$work/bin/gitleaks"
run_scan "$work/empty-bin"; check "missing gitleaks only warns by default" 0 $?
run_scan "$work/empty-bin" REQUIRE_SECRET_SCAN=1; check "missing gitleaks refuses when required" 1 $?

exit "$fail"
