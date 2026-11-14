#!/usr/bin/env bash
# Create a new project with agent-pairing-kit installed.
#
# Usage: bash new-project.sh PATH [profile ...]
#   go               Go service in the project root (default)
#   python           Python service in the project root
#   web              TypeScript + Vite frontend in the project root
#   fullstack        Go API in api/ plus web frontend in web/
#   fullstack python Python API in api/ plus web frontend in web/
#   expo             Expo (React Native + TypeScript) mobile app in the project root
#
# Installs working agreements, skills, check and review scripts, and empty toolchain setup.
# No application code. Noisy tool output goes to .pairing-setup.log in the new project.
set -euo pipefail
kit="$(cd "$(dirname "$0")" && pwd)"

die() { echo "new-project: $*" >&2; exit 1; }

path="${1:-}"
[ -n "$path" ] || die "usage: new-project.sh PATH [go|python|web|fullstack|expo ...]"
shift
name="$(basename "$path")"
[ "$#" -gt 0 ] || set -- go

backend="" web=0 fullstack=0 expo=0
for arg in "$@"; do
  case "$arg" in
    go|python)
      if [ -n "$backend" ] && [ "$backend" != "$arg" ]; then die "choose one backend: go or python"; fi
      backend="$arg" ;;
    web) web=1 ;;
    fullstack) fullstack=1; web=1 ;;
    expo) expo=1 ;;
    *) die "unknown profile '$arg' (choose: go, python, web, fullstack, expo)" ;;
  esac
done
if [ "$fullstack" = 1 ] && [ -z "$backend" ]; then backend=go; fi

profiles=() dirs=()
if [ "$expo" = 1 ]; then
  if [ -n "$backend" ] || [ "$web" = 1 ]; then die "expo is a standalone profile; do not combine it with others"; fi
  profiles=(expo); dirs=(.); mode=single
elif [ -n "$backend" ] && [ "$web" = 1 ]; then
  profiles=("$backend" web); dirs=(api web); mode=fullstack
elif [ -n "$backend" ]; then
  profiles=("$backend"); dirs=(.); mode=single
else
  profiles=(web); dirs=(.); mode=single
fi

pkg=$(printf '%s' "$name" | tr '-' '_')
case "$pkg" in [0-9]*) pkg="app_$pkg" ;; esac

# Prerequisites, checked before anything is created.
for p in "${profiles[@]}"; do
  case "$p" in
    go)
      command -v go >/dev/null || die "go profile needs Go (https://go.dev/dl/)"
      command -v gcc >/dev/null || echo "new-project: warning: gcc not found; the race detector will be skipped (sudo apt install build-essential)" >&2
      { command -v govulncheck || [ -x "$(go env GOPATH)/bin/govulncheck" ]; } >/dev/null 2>&1 \
        || echo "new-project: warning: govulncheck not installed; the check will skip it (go install golang.org/x/vuln/cmd/govulncheck@latest)" >&2 ;;
    python)
      command -v python3 >/dev/null || die "python profile needs python3"
      python3 -c 'import ensurepip, venv' 2>/dev/null || die "python profile needs venv support: sudo apt install python3-venv" ;;
    web|expo)
      { command -v node && command -v npm; } >/dev/null || die "$p profile needs Node.js 20+ and npm (nvm is the easiest route)"
      major=$(node -p 'process.versions.node.split(".")[0]')
      [ "$major" -ge 20 ] || die "$p profile needs Node.js 20+, found $(node --version)" ;;
  esac
done

if [ -e "$path" ] && [ -n "$(ls -A "$path")" ]; then die "$path exists and is not empty"; fi
mkdir -p "$path"
log="$path/.pairing-setup.log"
: > "$log"

# Working agreements: base rules plus one section per profile.
{
  cat "$kit/base/CLAUDE.md"
  echo
  echo "## This project"
  echo
  for i in "${!profiles[@]}"; do
    echo "- \`${dirs[$i]}\`: ${profiles[$i]}"
  done
  if [ "$mode" = fullstack ]; then
    echo "- In development the API listens on \`localhost:8080\`; the web dev server (\`npm run dev\` in \`web/\`)"
    echo "  proxies \`/api\` to it. Keep API routes under \`/api/\`."
  fi
  for i in "${!profiles[@]}"; do
    echo
    sed -e "s|{{DIR}}|${dirs[$i]}|g" -e "s|{{PKG}}|$pkg|g" "$kit/profiles/${profiles[$i]}/agreements.md"
  done
} > "$path/CLAUDE.md"
cp "$path/CLAUDE.md" "$path/AGENTS.md"

# Skills and the reviewer prompt.
mkdir -p "$path/skills"
{
  cat "$kit/base/review-checklist.md"
  for p in "${profiles[@]}"; do cat "$kit/profiles/$p/review.md"; done
} > "$path/skills/review-checklist.md"
{
  cat "$kit/base/plan-review-checklist.md"
  for p in "${profiles[@]}"; do cat "$kit/profiles/$p/review.md"; done
} > "$path/skills/plan-review-checklist.md"
for p in "${profiles[@]}"; do
  if [ -d "$kit/profiles/$p/skills" ]; then cp "$kit/profiles/$p/skills/"*.md "$path/skills/"; fi
done

# Check and review scripts.
mkdir -p "$path/scripts/checks"
cp "$kit/scripts/check.sh" "$kit/scripts/misbehavior-check.sh" "$kit/scripts/assertion-check.sh" "$kit/scripts/plan-review.sh" "$kit/scripts/cross-review.sh" "$kit/scripts/review-call.sh" "$kit/scripts/cross-review.ps1" "$path/scripts/"
for i in "${!profiles[@]}"; do
  cp "$kit/profiles/${profiles[$i]}/check.sh" "$path/scripts/checks/${profiles[$i]}.sh"
  echo "${profiles[$i]} ${dirs[$i]}"
done > "$path/.pairing-profiles"

# Editor and agent configuration.
cp -R "$kit/.cursor" "$path/"
mkdir -p "$path/.claude"
cp -R "$kit/claude-commands" "$path/.claude/commands"
cp "$kit/claude-settings.json" "$path/.claude/settings.json"

# Least privilege: switch off every plugin installed for this user (and the MCP servers they
# bring) in this project only. Written to settings.local.json, which is per-machine and
# gitignored, because plugin IDs differ between machines and accounts.
# Output goes to a file, not a pipe: Claude Code can leave a background plugin-sync process
# holding a pipe open, which would make $(...) wait forever. stdin is closed so it can never
# sit at a prompt, and -k hard-kills it if it ignores the timeout. Set PAIRING_SKIP_PLUGINS=1
# to skip this step entirely.
plugin_json=""
if [ -z "${PAIRING_SKIP_PLUGINS:-}" ] && command -v claude >/dev/null 2>&1; then
  echo "new-project: checking installed Claude Code plugins (up to 20s) ..."
  plugin_tmp=$(mktemp)
  ( timeout -k 3 20 claude plugin list --json </dev/null >"$plugin_tmp" 2>/dev/null || true ) 2>/dev/null || true
  plugin_json=$(cat "$plugin_tmp")
  rm -f "$plugin_tmp"
  [ -n "$plugin_json" ] || echo "new-project: could not read the plugin list; toggle plugin servers off with /mcp" >&2
fi
if [ -n "$plugin_json" ] && command -v python3 >/dev/null 2>&1; then
  disabled=$(printf '%s' "$plugin_json" | python3 -c '
import json, sys
try:
    data = json.load(sys.stdin)
except ValueError:
    sys.exit(0)
ids = sorted({str(p.get("id")) for p in data if isinstance(p, dict) and "@" in str(p.get("id", ""))})
if ids:
    with open(sys.argv[1], "w") as f:
        json.dump({"enabledPlugins": {i: False for i in ids}}, f, indent=2)
        f.write("\n")
    print(", ".join(ids))
' "$path/.claude/settings.local.json" || true)
  if [ -n "$disabled" ]; then
    echo "new-project: plugins switched off for this project: $disabled"
  fi
fi
cp "$kit/.gitattributes" "$path/"
{
  cat "$kit/base/gitignore"
  for p in "${profiles[@]}"; do cat "$kit/profiles/$p/gitignore"; done
} | awk '!seen[$0]++' > "$path/.gitignore"

# Toolchain setup per profile.
for i in "${!profiles[@]}"; do
  p="${profiles[$i]}" d="${dirs[$i]}"
  mkdir -p "$path/$d"
  arg="$name"
  if [ "$p" = go ] && [ "$mode" = fullstack ]; then arg="$name/api"; fi
  echo "new-project: setting up $p in $d ..."
  if ! (cd "$path/$d" && bash "$kit/profiles/$p/init.sh" "$arg" "$mode") >> "$log" 2>&1; then
    echo "new-project: $p setup failed. Last lines of $log:" >&2
    tail -n 15 "$log" >&2
    exit 1
  fi
done

cd "$path"
git init -q -b main
git add -A 2>>"$log"
git commit -q -m "chore: agent pairing kit (${profiles[*]})"
echo "new-project: ready at $path (${profiles[*]})"
