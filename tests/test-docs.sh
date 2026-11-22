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

# Review evidence fields (plans/step-5.md, 5a)
chk="$kit/base/review-checklist.md"
has "$chk" 'Quote:' "review checklist requires a Quote: field"
has "$chk" 'Would be wrong if:' "review checklist requires a Would be wrong if: field"
for f in "$chk" "$kit/base/CLAUDE.md" "$kit/claude-commands/cross-review.md"; do
  if grep -qi 'unverified' "$f"; then ok "unverified rule in ${f#"$kit"/}"; else bad "unverified rule in ${f#"$kit"/}"; fi
done
if grep -qF -- '--verify' "$chk"; then bad "review checklist has no --verify"; else ok "review checklist has no --verify"; fi

# Server-side enforcement note (plans/step-5.md, 5b)
ssd="$kit/docs/server-side-enforcement.md"
if [ -f "$ssd" ]; then
  ok "docs/server-side-enforcement.md exists"
  for phrase in 'branch protection' 'CODEOWNERS' 'cannot'; do
    has "$ssd" "$phrase" "server-side doc mentions $phrase"
  done
  while IFS= read -r p; do
    if [ -e "$kit/$p" ]; then ok "server-side doc cites existing $p"; else bad "server-side doc cites missing $p"; fi
  done < <(grep -oE '(scripts/[A-Za-z0-9_-]+\.sh|kit-audit\.sh)' "$ssd" | sort -u)
else
  bad "docs/server-side-enforcement.md exists"
fi
has "$kit/README.md" 'docs/server-side-enforcement.md' "README links docs/server-side-enforcement.md"

# Dependabot cooldown (plans/step-5.md, 5c): every ecosystem entry has cooldown.default-days: 7
dep="$kit/.github/dependabot.yml"
if awk '
  /^  - package-ecosystem:/ { if (eco && !ok) bad = 1; eco = 1; ok = 0; incd = 0; next }
  /^    cooldown:/ { incd = 1; next }
  incd && /^      default-days: 7[ \t]*$/ { ok = 1; next }
  /^    [^ ]/ { incd = 0 }
  END { if (eco && !ok) bad = 1; exit (eco && !bad) ? 0 : 1 }
' "$dep"; then ok "dependabot entries have cooldown default-days: 7"; else bad "dependabot entries have cooldown default-days: 7"; fi
has "$kit/DECISIONS.md" 'Dependabot cooldown' "DECISIONS records the Dependabot cooldown"

printf '\n%s\n' "$fail"
exit "$fail"
