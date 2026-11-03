#!/usr/bin/env bash
# kit-audit: check the tools and settings this kit depends on for drift.
# Usage: bash kit-audit.sh [--quiet]
#   --quiet  print only warnings (used by newproj); always exits 0
# Checks: installed vs latest versions (Claude Code, Cursor CLI, Go, govulncheck, Node, Expo SDK),
# that gitleaks (the secret scan before a review is sent) is installed,
# whether the saved review models still exist, and whether the Cursor CLI flags the review
# scripts use are still in its help text. Read-only: it changes nothing.
set -u
quiet=0
[ "${1:-}" = "--quiet" ] && quiet=1
env_file="${PAIRING_KIT_ENV:-$HOME/.config/pairing-kit.env}"
# shellcheck source=/dev/null
[ -f "$env_file" ] && . "$env_file"

warns=0
ok()   { [ "$quiet" = 1 ] || printf '  OK    %-14s %s\n' "$1" "$2"; }
info() { [ "$quiet" = 1 ] || printf '  INFO  %-14s %s\n' "$1" "$2"; }
warn() { printf '  WARN  %-14s %s\n' "$1" "$2"; warns=$((warns + 1)); }
semver() { grep -oE '[0-9]+\.[0-9]+(\.[0-9]+)?' | head -n 1; }
older() { [ -n "$1" ] && [ -n "$2" ] && [ "$1" != "$2" ] && [ "$(printf '%s\n%s\n' "$1" "$2" | sort -V | head -n 1)" = "$1" ]; }
fetch() { curl -fsS --max-time 10 "$1" 2>/dev/null; }

[ "$quiet" = 1 ] || echo "kitaudit: checking the tools and settings agent-pairing-kit depends on"

# Claude Code
if command -v claude >/dev/null 2>&1; then
  have=$(timeout 15 claude --version </dev/null 2>/dev/null | semver)
  latest=$(timeout 20 npm view @anthropic-ai/claude-code version 2>/dev/null | semver)
  if [ -z "$latest" ]; then info claude "installed ${have:-?}; couldn't look up the latest"
  elif older "$have" "$latest"; then warn claude "installed $have, latest $latest (run: claude update)"
  else ok claude "$have (latest)"; fi
else
  warn claude "not installed"
fi

# Cursor CLI: version, and the flags the review scripts pass
cbin=""
if command -v agent >/dev/null 2>&1; then cbin=agent; elif command -v cursor-agent >/dev/null 2>&1; then cbin=cursor-agent; fi
if [ -n "$cbin" ]; then
  have=$(timeout 15 "$cbin" --version </dev/null 2>/dev/null | head -n 1)
  ok cursor-cli "${have:-installed}"
  help=$(timeout 15 "$cbin" --help </dev/null 2>&1)
  missing=""
  for flag in --print --mode --output-format --model --trust; do
    printf '%s' "$help" | grep -q -- "$flag" || missing="$missing $flag"
  done
  if [ -n "$missing" ]; then warn cursor-flags "not in '$cbin --help' anymore:$missing (review-call.sh uses them)"
  else ok cursor-flags "all flags the reviews use are still listed"; fi
  if [ -n "${CURSOR_REVIEW_MODEL:-}" ]; then
    if timeout 30 "$cbin" models </dev/null 2>/dev/null | tr -s ' \t,()[]*:' '\n' | grep -qxF -- "$CURSOR_REVIEW_MODEL"; then
      ok cursor-model "$CURSOR_REVIEW_MODEL is available"
      ids=$(timeout 30 "$cbin" models </dev/null 2>/dev/null | tr -s ' \t,()[]*:' '\n' \
        | grep -E '^[a-z0-9][a-z0-9._]*-[a-z0-9._-]*[a-z0-9]$' | awk '!seen[$0]++' | tr '\n' ' ')
      info cursor-models "on your account: $ids"
    else
      warn cursor-model "$CURSOR_REVIEW_MODEL is no longer on your account (run: setreviewer cursor)"
    fi
  fi
elif [ "${REVIEW_PROVIDER:-}" = cursor ]; then
  warn cursor-cli "reviewer is cursor but the CLI isn't installed"
fi

# OpenAI review model (fallback or primary)
if [ -n "${OPENAI_API_KEY:-}" ]; then
  model="${REVIEW_MODEL:-gpt-6.1-sol}"
  code=$(curl -s -o /dev/null -w '%{http_code}' --max-time 15 -H "Authorization: Bearer $OPENAI_API_KEY" \
    "${OPENAI_BASE_URL:-https://api.openai.com}/v1/models/$model")
  if [ "$code" = 200 ]; then ok openai-model "$model is available"
  else warn openai-model "$model check returned HTTP $code (run: keystatus)"; fi
fi

# gitleaks: the reviews scan what they send for secrets only when it is installed
if command -v gitleaks >/dev/null 2>&1; then
  have=$(gitleaks version 2>/dev/null | semver)
  ok gitleaks "${have:-installed}"
else
  warn gitleaks "not installed; reviews are sent without a secret scan (https://github.com/gitleaks/gitleaks)"
fi

# Go and govulncheck
if command -v go >/dev/null 2>&1; then
  have=$(go env GOVERSION 2>/dev/null | semver)
  latest=$(fetch 'https://go.dev/VERSION?m=text' | head -n 1 | semver)
  if [ -z "$latest" ]; then info go "installed ${have:-?}; couldn't look up the latest"
  elif older "$have" "$latest"; then warn go "installed $have, latest $latest"
  else ok go "$have (latest)"; fi
  gv=""
  if command -v govulncheck >/dev/null 2>&1; then gv=govulncheck
  elif [ -x "$(go env GOPATH)/bin/govulncheck" ]; then gv="$(go env GOPATH)/bin/govulncheck"; fi
  if [ -n "$gv" ]; then
    have=$("$gv" -version 2>/dev/null | grep -oE 'govulncheck@v[0-9.]+' | semver)
    latest=$(timeout 20 go list -m -f '{{.Version}}' golang.org/x/vuln@latest 2>/dev/null | semver)
    if [ -n "$have" ] && [ -n "$latest" ] && older "$have" "$latest"; then
      warn govulncheck "installed $have, latest $latest (go install golang.org/x/vuln/cmd/govulncheck@latest)"
    else ok govulncheck "${have:-installed}"; fi
  else
    warn govulncheck "not installed (go install golang.org/x/vuln/cmd/govulncheck@latest)"
  fi
fi

# Node and the Expo SDK new projects get
if command -v node >/dev/null 2>&1; then
  have=$(node --version | semver)
  lts=$(fetch https://nodejs.org/dist/index.json | python3 -c '
import json, sys
try:
    rel = json.load(sys.stdin)
    print(next(r["version"] for r in rel if r.get("lts")).lstrip("v"))
except Exception:
    pass' 2>/dev/null)
  if [ "${have%%.*}" -lt 20 ] 2>/dev/null; then warn node "installed $have; web and expo profiles need 20+"
  elif [ -n "$lts" ] && [ "${have%%.*}" -lt "${lts%%.*}" ]; then info node "installed $have; current LTS is $lts"
  else ok node "$have"; fi
  expo=$(timeout 20 npm view expo version 2>/dev/null | semver)
  [ -n "$expo" ] && info expo "new expo projects get expo $expo (SDK ${expo%%.*})"
fi

if [ "$quiet" = 0 ]; then
  echo
  if [ "$warns" -eq 0 ]; then echo "kitaudit: no drift found"
  else echo "kitaudit: $warns warning(s)"; fi
  [ "$warns" -eq 0 ]
else
  exit 0
fi
