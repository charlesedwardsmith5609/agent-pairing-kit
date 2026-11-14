#!/usr/bin/env bash
# Tests the staged-addition secret scan in scripts/check.sh with a fake gitleaks.
# No real gitleaks binary, network, or API key. Usage: bash tests/test-staged-secret-scan.sh
set -uo pipefail
kit="$(cd "$(dirname "$0")/.." && pwd)"
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
mkdir -p "$work/bin" "$work/home"
: > "$work/empty.env"

fail=0
check() { # name expected_rc actual_rc
  if [ "$2" -eq "$3" ]; then echo "ok   $1"; else echo "FAIL $1 (want rc=$2, got rc=$3)"; fail=1; fi
}
check_out() { # name expected-present-or-absent needle
  if [ "$2" = present ] && grep -qF "$3" "$work/out"; then echo "ok   $1"
  elif [ "$2" = absent ] && ! grep -qF "$3" "$work/out"; then echo "ok   $1"
  else echo "FAIL $1"; fail=1; fi
}

init_repo() {
  repo="$work/repo"
  rm -rf "$repo"
  mkdir -p "$repo/scripts/checks"
  cp "$kit/scripts/check.sh" "$kit/scripts/review-call.sh" "$kit/scripts/misbehavior-check.sh" "$kit/scripts/assertion-check.sh" "$repo/scripts/"
  printf '#!/bin/sh\necho stub-ok\n' > "$repo/scripts/checks/stub.sh"
  chmod +x "$repo/scripts/checks/stub.sh"
  printf 'stub .\n' > "$repo/.pairing-profiles"
  git -C "$repo" init -q -b main
  git -C "$repo" config user.email smoke@example.invalid
  git -C "$repo" config user.name smoke
  echo base > "$repo/README.md"
  git -C "$repo" add README.md
  git -C "$repo" commit -q -m init
}

# shellcheck disable=SC2016  # the fake script's $1/$2 must stay literal
fake() { # exit code
  printf '#!/bin/sh\n[ "$1" = stdin ] && [ "$2" = --help ] && { echo "gitleaks stdin"; exit 0; }\ncat > "%s/seen"; exit %s\n' "$work" "$1" > "$work/bin/gitleaks"
  chmod +x "$work/bin/gitleaks"
}

# shellcheck disable=SC2016
fake_if_marker() { # exit 7 only when stdin contains this marker
  printf '#!/bin/sh\n[ "$1" = stdin ] && [ "$2" = --help ] && { echo "gitleaks stdin"; exit 0; }\ncat > "%s/seen"\ngrep -q "%s" "%s/seen" && exit 7\nexit 0\n' "$work" "$1" "$work" > "$work/bin/gitleaks"
  chmod +x "$work/bin/gitleaks"
}

run_check() {
  rm -f "$work/seen" "$work/out"
  (
    export HOME="$work/home"
    export PAIRING_KIT_ENV="$work/empty.env"
    export PATH="$work/bin:/usr/bin:/bin"
    cd "$repo" || exit 2
    bash scripts/check.sh >"$work/out" 2>&1
  )
}

init_repo
fake 7
echo ADDED_MARKER > "$repo/added.txt"
git -C "$repo" add added.txt
run_check; check "staged match warns and passes" 0 $?
check_out "warning names the secret scan" present "staged additions matched the secret scan"
check_out "language check still ran" present "stub-ok"

init_repo
fake 7
echo ADDED_MARKER > "$repo/added.txt"
git -C "$repo" add added.txt
PAIRING_STRICT=1 run_check; check "staged match fails when PAIRING_STRICT=1" 1 $?
check_out "strict failure is named" present "PAIRING_STRICT=1"
check_out "language check still ran under strict" present "stub-ok"

init_repo
fake 0
echo hello > "$repo/added.txt"
git -C "$repo" add added.txt
run_check; check "clean scan passes" 0 $?
check_out "clean scan does not warn" absent "matched the secret scan"

init_repo
fake 7
echo UNSTAGED_MARKER > "$repo/loose.txt"
run_check; check "unstaged file does not fail" 0 $?
if [ -f "$work/seen" ]; then echo "FAIL unstaged file invoked gitleaks"; fail=1; else echo "ok   unstaged file does not invoke gitleaks"; fi
check_out "unstaged file does not warn" absent "matched the secret scan"

init_repo
fake 7
run_check; check "no staged diff passes" 0 $?
if [ -f "$work/seen" ]; then echo "FAIL clean tree invoked gitleaks"; fail=1; else echo "ok   clean tree does not invoke gitleaks"; fi

init_repo
fake 7
echo DELETE_MARKER > "$repo/old.txt"
git -C "$repo" add old.txt
git -C "$repo" commit -q -m add-old
git -C "$repo" rm -q old.txt
run_check; check "deletion-only passes" 0 $?
if [ -f "$work/seen" ]; then echo "FAIL deletion invoked gitleaks"; fail=1; else echo "ok   deletion does not invoke gitleaks"; fi
check_out "deletion does not warn" absent "matched the secret scan"

init_repo
fake_if_marker CONTEXT_MARKER
printf 'keep\nCONTEXT_MARKER\nkeep\n' > "$repo/near.txt"
git -C "$repo" add near.txt
git -C "$repo" commit -q -m add-near
printf 'keep\nCONTEXT_MARKER\nchanged\n' > "$repo/near.txt"
git -C "$repo" add near.txt
run_check; check "context line does not fail" 0 $?
check_out "context line does not warn" absent "matched the secret scan"
if [ -f "$work/seen" ] && grep -qF changed "$work/seen" && ! grep -qF CONTEXT_MARKER "$work/seen"; then
  echo "ok   scan saw the addition and not the context line"
else
  echo "FAIL scan input was not limited to the addition"; fail=1
fi

init_repo
fake_if_marker '++ADDED_PLUS'
printf '++ADDED_PLUS\n' > "$repo/plus.txt"
git -C "$repo" add plus.txt
run_check; check "added line starting with plus signs warns" 0 $?
check_out "plus-sign addition matched" present "matched the secret scan"

init_repo
fake_if_marker '++ SPACED_PLUS'
printf '++ SPACED_PLUS\n' > "$repo/spaced.txt"
echo other > "$repo/other.txt"
git -C "$repo" add spaced.txt other.txt
run_check; check "added line starting with plus signs and a space warns" 0 $?
check_out "spaced plus-sign addition matched" present "matched the secret scan"
if [ -f "$work/seen" ] && grep -qF '++ SPACED_PLUS' "$work/seen" && ! grep -qF '++ b/' "$work/seen"; then
  echo "ok   spaced plus line was scanned and file headers were not"
else
  echo "FAIL spaced plus line was dropped or a header was scanned"; fail=1
fi

init_repo
rm -f "$work/bin/gitleaks"
echo hello > "$repo/added.txt"
git -C "$repo" add added.txt
run_check; check "missing gitleaks only warns" 0 $?
check_out "missing gitleaks warning" present "gitleaks is not installed"

init_repo
rm -f "$work/bin/gitleaks"
echo hello > "$repo/added.txt"
git -C "$repo" add added.txt
REQUIRE_SECRET_SCAN=1 run_check; check "missing gitleaks fails when required" 1 $?

init_repo
fake 2
echo hello > "$repo/added.txt"
git -C "$repo" add added.txt
run_check; check "scanner error only warns by default" 0 $?
check_out "scanner error warns" present "secret scan failed"

init_repo
fake 2
echo hello > "$repo/added.txt"
git -C "$repo" add added.txt
PAIRING_STRICT=1 run_check; check "scanner error fails when PAIRING_STRICT=1" 1 $?
check_out "strict scanner failure is a scan failure" present "secret scan failed"

init_repo
fake 2
echo hello > "$repo/added.txt"
git -C "$repo" add added.txt
REQUIRE_SECRET_SCAN=1 run_check; check "scanner error fails when the scan is required" 1 $?

init_repo
fake 0
echo hello > "$repo/added.txt"
git -C "$repo" add added.txt
cat > "$work/bin/git" << 'EOF'
#!/bin/sh
if [ "$1" = -C ] && [ "$3" = diff ]; then
  echo "git diff failed" >&2
  exit 128
fi
exec /usr/bin/git "$@"
EOF
chmod +x "$work/bin/git"
run_check; check "diff failure only warns by default" 0 $?
check_out "diff failure warns" present "git diff --cached failed"
rm -f "$work/bin/git"

init_repo
fake 0
echo hello > "$repo/added.txt"
git -C "$repo" add added.txt
cat > "$work/bin/git" << 'EOF'
#!/bin/sh
if [ "$1" = -C ] && [ "$3" = diff ]; then
  echo "git diff failed" >&2
  exit 128
fi
exec /usr/bin/git "$@"
EOF
chmod +x "$work/bin/git"
PAIRING_STRICT=1 run_check; check "diff failure fails when PAIRING_STRICT=1" 1 $?
rm -f "$work/bin/git"

exit "$fail"
