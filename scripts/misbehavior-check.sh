#!/usr/bin/env bash
# Deterministic agent-misbehavior heuristics over the working tree diff.
# Warns by default; set PAIRING_STRICT=1 to fail when findings exist.
# Usage: bash scripts/misbehavior-check.sh
# Expects to run from the project root (or pass ROOT as $1).
set -uo pipefail

root="${1:-.}"
cd "$root" || exit 2
root="$(pwd)"

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "misbehavior: skip (not a git repository)"
  exit 0
fi

strict=0
[ "${PAIRING_STRICT:-}" = "1" ] && strict=1
label="WARN"
[ "$strict" -eq 1 ] && label="FAIL"

findings=0
report() {
  printf 'misbehavior: %s: %s\n' "$label" "$1"
  findings=1
}

# Collect changed paths: unstaged, staged, and untracked (excluding ignored).
changed_file="$root/.misbehavior-changed.$$"
{
  git diff --name-only HEAD 2>/dev/null || true
  git diff --cached --name-only HEAD 2>/dev/null || true
  git ls-files --others --exclude-standard 2>/dev/null || true
} | sed '/^$/d' | sort -u > "$changed_file"

trap 'rm -f "$changed_file"' EXIT

if [ ! -s "$changed_file" ]; then
  echo "misbehavior: OK (no changes)"
  exit 0
fi

is_test_path() {
  # In bash case patterns, * matches across '/'.
  case "$1" in
    *_test.go|test_*.py|*_test.py|*.test.ts|*.test.tsx|*.spec.ts|*.spec.tsx) return 0 ;;
    tests/*|*/tests/*|__tests__/*|*/__tests__/*) return 0 ;;
    *) return 1 ;;
  esac
}

is_scope_exempt() {
  case "$1" in
    plans/*|REQUIREMENTS.md|CLAUDE.md|AGENTS.md|.reviews/*|*.reviews/*) return 0 ;;
    .pairing-setup.log|.misbehavior-changed.*) return 0 ;;
    *) return 1 ;;
  esac
}

is_gate_path() {
  case "$1" in
    scripts/check.sh|scripts/misbehavior-check.sh|.pairing-profiles) return 0 ;;
    scripts/checks/*) return 0 ;;
    .github/workflows/*) return 0 ;;
    *) return 1 ;;
  esac
}

# --- Gate files changed ---
while IFS= read -r path; do
  [ -n "$path" ] || continue
  if is_gate_path "$path"; then
    report "validation gate file changed: $path"
  fi
done < "$changed_file"

# --- Newly skipped tests / disabled validation markers in the diff ---
# Look at added lines (+) in the combined staged+unstaged diff.
diff_text=$(git diff HEAD 2>/dev/null || true)
diff_text+=$'\n'
diff_text+=$(git diff --cached HEAD 2>/dev/null || true)

skip_line_re='t\.Skip\(|\.skip\(|xit\(|xdescribe\(|test\.skip|it\.skip|describe\.skip|@pytest\.mark\.skip|passWithNoTests'
skip_diff_re="^\\+.*(${skip_line_re})"
if printf '%s\n' "$diff_text" | grep -E "$skip_diff_re" >/dev/null 2>&1; then
  report "diff adds skipped/disabled test or validation marker"
else
  # Untracked files do not appear in git diff; scan their contents when listed.
  while IFS= read -r path; do
    [ -n "$path" ] || continue
    [ -f "$path" ] || continue
    git ls-files --error-unmatch "$path" >/dev/null 2>&1 && continue
    if grep -E "$skip_line_re" "$path" >/dev/null 2>&1; then
      report "untracked file adds skipped/disabled test or validation marker: $path"
      break
    fi
  done < "$changed_file"
fi

# --- Test-only changes (no matching source change) ---
has_test=0
has_source=0
while IFS= read -r path; do
  [ -n "$path" ] || continue
  is_scope_exempt "$path" && continue
  if is_test_path "$path"; then
    has_test=1
  else
    # Treat non-markdown, non-plan docs as source-ish; ignore pure docs? Plan says
    # "test changes with no matching source change" — any non-test path counts as source.
    has_source=1
  fi
done < "$changed_file"

if [ "$has_test" -eq 1 ] && [ "$has_source" -eq 0 ]; then
  report "test files changed with no matching source change"
fi

# --- Plan scope (only when ## Files is parseable) ---
plan=""
# shellcheck disable=SC2012
plan=$(ls plans/step-*.md 2>/dev/null | sort -V | tail -n 1 || true)
if [ -z "$plan" ] || [ ! -f "$plan" ]; then
  echo "misbehavior: plan-scope skipped (no plans/step-*.md)"
else
  # Extract bullets under ## Files until the next ## heading.
  files_list=$(awk '
    BEGIN { in_files=0; n=0 }
    /^## Files[[:space:]]*$/ { in_files=1; next }
    /^## / { if (in_files) exit }
    in_files && /^-[[:space:]]+/ {
      line=$0
      sub(/^-[[:space:]]+/, "", line)
      sub(/[[:space:]]+$/, "", line)
      if (line != "") { print line; n++ }
    }
    END { }
  ' "$plan")
  if [ -z "$files_list" ]; then
    echo "misbehavior: plan-scope skipped (no parseable ## Files)"
  else
    allowed_file="$root/.misbehavior-allowed.$$"
    printf '%s\n' "$files_list" | sort -u > "$allowed_file"
    while IFS= read -r path; do
      [ -n "$path" ] || continue
      is_scope_exempt "$path" && continue
      if ! grep -Fxq "$path" "$allowed_file"; then
        report "path outside plan ## Files: $path"
      fi
    done < "$changed_file"
    rm -f "$allowed_file"
  fi
fi

if [ "$findings" -eq 0 ]; then
  echo "misbehavior: OK"
  exit 0
fi

if [ "$strict" -eq 1 ]; then
  echo "misbehavior: FAILED (PAIRING_STRICT=1)"
  exit 1
fi
echo "misbehavior: warnings only (set PAIRING_STRICT=1 to fail)"
exit 0
