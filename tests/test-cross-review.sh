#!/usr/bin/env bash
# Tests that scripts/cross-review.sh fails closed: no gitleaks, a scanner failure or a finding
# sends nothing; untracked and secret-looking files are never sent; --include of a deny-listed
# file exits 2. Uses a temp git repo, a fake gitleaks and a loopback stub API (python3).
# Usage: bash tests/test-cross-review.sh
set -uo pipefail
kit="$(cd "$(dirname "$0")/.." && pwd)"
for tool in git python3 curl; do
  command -v "$tool" >/dev/null 2>&1 || { echo "skip: $tool not available"; exit 0; }
done
work=$(mktemp -d)
srv_pid=""
# shellcheck disable=SC2317  # runs from the EXIT trap
cleanup() { [ -n "$srv_pid" ] && kill "$srv_pid" 2>/dev/null; rm -rf "$work"; }
trap cleanup EXIT
mkdir -p "$work/bin" "$work/empty-bin" "$work/home"

fail=0
ok() { echo "ok   $1"; }
bad() { echo "FAIL $1"; fail=1; }
check() { # name expected_rc actual_rc
  if [ "$2" -eq "$3" ]; then ok "$1"; else bad "$1 (want rc=$2, got rc=$3)"; fi
}

# Stub OpenAI endpoint on 127.0.0.1: appends each request body to requests.log and answers.
cat > "$work/stub.py" <<'PY'
import http.server, sys
log, portfile = sys.argv[1], sys.argv[2]
class H(http.server.BaseHTTPRequestHandler):
    def do_POST(self):
        body = self.rfile.read(int(self.headers.get("Content-Length", 0)))
        with open(log, "ab") as f:
            f.write(body + b"\n")
        out = b'{"choices":[{"message":{"content":"looks fine"}}]}'
        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(out)))
        self.end_headers()
        self.wfile.write(out)
    def log_message(self, *a):
        pass
s = http.server.HTTPServer(("127.0.0.1", 0), H)
open(portfile, "w").write(str(s.server_address[1]))
s.serve_forever()
PY
: > "$work/requests.log"
python3 "$work/stub.py" "$work/requests.log" "$work/port" &
srv_pid=$!
for _ in $(seq 1 50); do [ -s "$work/port" ] && break; sleep 0.1; done
[ -s "$work/port" ] || { echo "FAIL stub server did not start"; exit 1; }
port=$(cat "$work/port")

sent() { cat "$work/requests.log"; }
reset_log() { : > "$work/requests.log"; }

repo="$work/repo"
init_repo() {
  rm -rf "$repo"; mkdir -p "$repo/scripts" "$repo/skills"
  cp "$kit/scripts/cross-review.sh" "$kit/scripts/review-call.sh" "$repo/scripts/"
  cp "$kit/base/review-checklist.md" "$repo/skills/review-checklist.md"
  git -C "$repo" init -q
  printf 'one\n' > "$repo/app.txt"
  printf 'key v1\n' > "$repo/server.key"
  printf '.reviews/\n' > "$repo/.gitignore"
  git -C "$repo" add app.txt server.key .gitignore scripts skills
  git -C "$repo" -c user.name=t -c user.email=t@example.com commit -q -m init
  printf 'one\nTRACKED_CHANGE_MARKER\n' > "$repo/app.txt"
  printf 'key v2 TRACKED_KEY_MARKER\n' > "$repo/server.key"
  reset_log
}
fake() { # fake gitleaks exiting with $1
  printf '#!/bin/sh\nexit %s\n' "$1" > "$work/bin/gitleaks"
  chmod +x "$work/bin/gitleaks"
}
# run_review ARGS...: prints output to $work/out, returns the script's exit code. PATH holds only
# the fake bin dir (or none) plus system dirs.
run_review() {
  ( cd "$repo" || exit 99
    env -i PATH="$work/${BIN_DIR:-bin}:/usr/bin:/bin" HOME="$work/home" PAIRING_KIT_ENV="$work/none.env" \
      OPENAI_API_KEY=test-key OPENAI_BASE_URL="http://127.0.0.1:$port" \
      timeout 60 bash scripts/cross-review.sh --provider openai "$@" ) > "$work/out" 2>&1
}
has_sent() { # label marker present|absent
  local found=absent
  sent | grep -qF -- "$2" && found=present
  if [ "$found" = "$3" ]; then ok "$1"; else bad "$1 (marker is $found)"; fi
}
nothing_sent() { if [ -s "$work/requests.log" ] && [ "$(sent | tr -d '\n')" != "" ]; then bad "$1 (a request was received)"; else ok "$1"; fi; }

# A gitleaks in /usr/bin or /bin would defeat the missing-scanner case.
if [ -x /usr/bin/gitleaks ] || [ -x /bin/gitleaks ]; then
  echo "skip: missing-gitleaks case (gitleaks is in a system directory)"
else
  init_repo; rm -f "$work/bin/gitleaks"
  BIN_DIR=empty-bin run_review; rc=$?
  if [ "$rc" -ne 0 ]; then ok "missing gitleaks exits nonzero"; else bad "missing gitleaks exits nonzero"; fi
  nothing_sent "missing gitleaks sends nothing"
  if grep -q "Nothing was sent" "$work/out"; then ok "missing gitleaks explains itself"; else bad "missing gitleaks explains itself"; fi
fi

for code in 7 3; do
  init_repo; fake "$code"
  run_review; rc=$?
  if [ "$rc" -ne 0 ]; then ok "gitleaks exit $code exits nonzero"; else bad "gitleaks exit $code exits nonzero"; fi
  nothing_sent "gitleaks exit $code sends nothing"
done

init_repo; fake 0
printf 'API_TOKEN=UNTRACKED_ENV_MARKER\n' > "$repo/.env"
printf 'UNTRACKED_KEY_MARKER\n' > "$repo/id_ed25519"
printf 'UNTRACKED_NOTES_MARKER\n' > "$repo/notes.txt"
run_review; check "clean default run succeeds" 0 $?
has_sent "tracked diff is sent when clean" TRACKED_CHANGE_MARKER present
has_sent "untracked .env is not sent" UNTRACKED_ENV_MARKER absent
has_sent "untracked key file is not sent" UNTRACKED_KEY_MARKER absent
has_sent "untracked notes are not sent without --include" UNTRACKED_NOTES_MARKER absent
has_sent "modified tracked key file is not sent" TRACKED_KEY_MARKER absent
if git -C "$repo" status --porcelain | grep -q '^?? notes.txt'; then ok "index left alone (notes.txt still untracked)"; else bad "index left alone (notes.txt still untracked)"; fi

init_repo; fake 0
printf 'UNTRACKED_ENV_MARKER\n' > "$repo/.env"
printf 'UNTRACKED_NOTES_MARKER\n' > "$repo/notes.txt"
run_review --include notes.txt; check "--include of a plain untracked file succeeds" 0 $?
has_sent "--include sends the named file" UNTRACKED_NOTES_MARKER present
has_sent "--include does not send .env" UNTRACKED_ENV_MARKER absent

init_repo; fake 0
mkdir -p "$repo/deploy" "$repo/.aws"
for f in .env .env.local deploy/id_ed25519 aws-credentials.txt .aws/config; do printf 'UNTRACKED_ENV_MARKER\n' > "$repo/$f"; done
printf 'ok\n' > "$repo/notes.txt"
ln -s notes.txt "$repo/link.txt"
for p in .env ./.env.local deploy/id_ed25519 aws-credentials.txt .aws/config server.key link.txt ../outside.txt; do
  reset_log
  run_review --include "$p"; rc=$?
  check "--include $p exits 2" 2 "$rc"
  nothing_sent "--include $p sends nothing"
done

# The .sh and .ps1 deny lists must stay identical (compared as text).
list() { # file name: the words inside NAME=( ... ) or $name = @( ... ), one per line
  tr -d '\r' < "$1" | awk -v n="$2" '
    $0 ~ n"=\\(" || $0 ~ "\\$"n" = @\\(" { on=1 }
    on { print }
    on && /\)/ { exit }' | sed -e 's/^[^(]*(//' -e 's/)[^)]*$//' | tr -s ', \t' '\n' | sed '/^$/d' | tr -d "'"
}
for pair in "deny_names:denyNames" "deny_dirs:denyDirs"; do
  a=$(list "$kit/scripts/cross-review.sh" "${pair%%:*}")
  b=$(list "$kit/scripts/cross-review.ps1" "${pair#*:}")
  if [ -n "$a" ] && [ "$a" = "$b" ]; then ok "${pair%%:*} matches ${pair#*:} in .ps1"; else bad "${pair%%:*} differs from ${pair#*:} in .ps1"; fi
done

# cross-review.ps1 under real PowerShell, when pwsh is installed: it must parse, refuse a
# deny-listed -Include with exit 2, and send nothing when gitleaks is missing.
if command -v pwsh >/dev/null 2>&1; then
  export DOTNET_SYSTEM_GLOBALIZATION_INVARIANT=1
  ps="$work/ps"; mkdir -p "$ps/scripts" "$ps/skills"
  cp "$kit/scripts/cross-review.ps1" "$ps/scripts/"; cp "$kit/base/review-checklist.md" "$ps/skills/"
  ( cd "$ps" && git init -q && git config user.email t@example.com && git config user.name t \
    && echo one > app.txt && git add -A && git commit -qm init && echo two >> app.txt && echo X=1 > .env )
  cat > "$work/parse.ps1" <<'PS'
param([string]$Path)
$e = $null; $t = $null
[void][System.Management.Automation.Language.Parser]::ParseFile($Path, [ref]$t, [ref]$e)
$e.Count
PS
  perr=$(pwsh -NoProfile -File "$work/parse.ps1" "$kit/scripts/cross-review.ps1" 2>&1 | tail -1)
  if [ "$perr" = 0 ]; then ok "cross-review.ps1 parses under pwsh"; else bad "cross-review.ps1 has parse errors under pwsh ($perr)"; fi
  pnogl="$work/pwsh-path"; mkdir -p "$pnogl"
  run_ps() { ( cd "$ps" && env -i HOME="$work/home" PATH="/usr/bin:/bin:$(dirname "$(command -v pwsh)")" DOTNET_SYSTEM_GLOBALIZATION_INVARIANT=1 \
    OPENAI_API_KEY=dummy OPENAI_BASE_URL=http://127.0.0.1:9 pwsh -NoProfile -File scripts/cross-review.ps1 "$@" 2>&1 ); }
  out=$(run_ps -Include .env); rc=$?
  check "ps1 -Include .env exits 2" 2 "$rc"
  out=$(run_ps); rc=$?
  if [ "$rc" -ne 0 ] && printf '%s' "$out" | grep -q 'gitleaks is not installed'; then ok "ps1 without gitleaks sends nothing"; else bad "ps1 without gitleaks did not refuse (rc=$rc)"; fi
else
  echo "skip: pwsh not installed; cross-review.ps1 was only compared as text"
fi

exit "$fail"
