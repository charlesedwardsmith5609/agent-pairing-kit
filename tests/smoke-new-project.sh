#!/usr/bin/env bash
# Smoke run of new-project.sh: create a project for the given profiles in a temp directory,
# assert the files a project must get are there, then run the project's own validation gate.
# Usage: bash tests/smoke-new-project.sh [profile ...]     (default: go)
# Needs the toolchain for each profile (Go, or python3 with venv) and network for pip/go.
set -euo pipefail
kit="$(cd "$(dirname "$0")/.." && pwd)"
[ "$#" -gt 0 ] || set -- go

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

# Don't depend on the machine's plugins, or on a git identity for the initial commit.
export PAIRING_SKIP_PLUGINS=1
export GIT_AUTHOR_NAME="${GIT_AUTHOR_NAME:-smoke}" GIT_AUTHOR_EMAIL="${GIT_AUTHOR_EMAIL:-smoke@example.invalid}"
export GIT_COMMITTER_NAME="${GIT_COMMITTER_NAME:-smoke}" GIT_COMMITTER_EMAIL="${GIT_COMMITTER_EMAIL:-smoke@example.invalid}"

fail() { echo "smoke: FAIL: $*" >&2; exit 1; }

target="$work/smoke-project"
echo "smoke: new-project.sh $* -> $target"
bash "$kit/new-project.sh" "$target" "$@"

cd "$target"
for f in AGENTS.md CLAUDE.md .pairing-profiles .gitignore .gitattributes \
  scripts/check.sh scripts/plan-review.sh scripts/cross-review.sh scripts/review-call.sh \
  skills/review-checklist.md skills/plan-review-checklist.md \
  .cursor/rules/pairing-mode.mdc .claude/settings.json .claude/commands/check.md; do
  [ -f "$f" ] || fail "missing $f"
done
# fullstack is a new-project.sh mode: Go API plus web, not a check-script name.
profiles=("$@")
if [ "${#profiles[@]}" -eq 1 ] && [ "${profiles[0]}" = fullstack ]; then
  profiles=(go web)
fi
for p in "${profiles[@]}"; do
  [ -f "scripts/checks/$p.sh" ] || fail "missing scripts/checks/$p.sh"
  grep -q "^$p " .pairing-profiles || fail "$p not listed in .pairing-profiles"
done
cmp -s AGENTS.md CLAUDE.md || fail "AGENTS.md and CLAUDE.md differ"
security_phrases=(
  '## Security defaults'
  'Validate and bound every external input'
  'Deny outbound hosts by default'
  'Never log or echo secrets'
  'Keep secrets out of prompts'
  'Parameterize queries'
  'Never paste tokens or credentials'
)
for phrase in "${security_phrases[@]}"; do
  grep -qF "$phrase" CLAUDE.md || fail "CLAUDE.md missing: $phrase"
done
[ -z "$(git status --porcelain)" ] || fail "working tree not clean after setup"
git log -1 --format=%s | grep -q 'agent pairing kit' || fail "unexpected initial commit"

echo "smoke: running the project's own check on the empty project"
bash scripts/check.sh || fail "scripts/check.sh failed on the empty project"
echo "smoke: OK ($*)"
