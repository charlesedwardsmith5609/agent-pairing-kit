#!/usr/bin/env bash
# Warn when a test function has no assertion. Scans test files on disk, not diffs.
# Warns by default. Set PAIRING_STRICT=1 to fail.
# Usage: bash scripts/assertion-check.sh [root]
set -uo pipefail

root="${1:-.}"
cd "$root" || exit 2
root="$(pwd)"

strict=0
[ "${PAIRING_STRICT:-}" = "1" ] && strict=1
label="WARN"
[ "$strict" -eq 1 ] && label="FAIL"

findings=0
report() {
  printf 'assertions: %s: %s\n' "$label" "$1"
  findings=1
}

# shellcheck disable=SC2312
mapfile -d '' files < <(find "$root" -type f \
  ! -path '*/.git/*' ! -path '*/vendor/*' ! -path '*/node_modules/*' \
  \( -name '*_test.go' -o -name 'test_*.py' -o -name '*_test.py' \
     -o -name '*.test.ts' -o -name '*.test.tsx' -o -name '*.spec.ts' -o -name '*.spec.tsx' \) \
  -print0 2>/dev/null || true)

scan_go() {
  local file="$1"
  local hits
  hits=$(awk '
    function flush() {
      if (name != "" && asserted == 0) print name
    }
    /^func Test/ {
      flush()
      name = $2
      sub(/\(.*/, "", name)
      if (name == "TestMain") name = ""
      asserted = 0
      next
    }
    /^func / { flush(); name = "" }
    name != "" && /t\.(Error|Fatal|Fail)|assert\.|require\.|cmp\.(Diff|Equal)/ { asserted = 1 }
    END { flush() }
  ' "$file")
  local name
  while IFS= read -r name; do
    [ -n "$name" ] || continue
    report "${file#"$root"/}: $name has no assertion"
  done <<< "$hits"
}

scan_py() {
  local file="$1"
  local hits
  hits=$(awk '
    function flush() {
      if (name != "" && asserted == 0) print name
    }
    /^[[:space:]]*def test_/ {
      flush()
      name = $2
      sub(/\(.*/, "", name)
      asserted = 0
      next
    }
    /^[[:space:]]*def / { flush(); name = "" }
    name != "" && /assert |assert\(|pytest\.raises|pytest\.fail|self\.assert/ { asserted = 1 }
    END { flush() }
  ' "$file")
  local name
  while IFS= read -r name; do
    [ -n "$name" ] || continue
    report "${file#"$root"/}: $name has no assertion"
  done <<< "$hits"
}

scan_js() {
  local file="$1"
  if ! grep -Eq 'expect\(|assert[[:space:]]*\(|assert\.' "$file"; then
    report "${file#"$root"/}: no expect or assert call"
  fi
}

for file in "${files[@]}"; do
  [ -n "$file" ] || continue
  case "$file" in
    *_test.go) scan_go "$file" ;;
    *.py) scan_py "$file" ;;
    *) scan_js "$file" ;;
  esac
done

if [ "$findings" -eq 0 ]; then
  echo "assertions: OK"
  exit 0
fi
if [ "$strict" -eq 1 ]; then
  echo "assertions: FAILED (PAIRING_STRICT=1)"
  exit 1
fi
echo "assertions: warnings only (set PAIRING_STRICT=1 to fail)"
exit 0
