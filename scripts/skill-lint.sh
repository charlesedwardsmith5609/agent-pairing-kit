#!/usr/bin/env bash
# Structural lint of kit skill files: profiles/*/skills/*.md under ROOT (default .).
# Rules: title (exactly one H1), when-to-read (a "Load before ..." style line near the top),
# size (byte cap), duplicate-heading (same heading text in two skills of one profile),
# scan-error (a skill or skills directory that could not be read).
# Warns by default (exit 0); set PAIRING_STRICT=1 to fail (exit 1). Exit 2: bad ROOT.
# Kit-only: not copied into generated projects. Checks no semantics and calls no model.
# Usage: bash scripts/skill-lint.sh [ROOT]
set -uo pipefail

max_bytes=6144   # largest skill at adoption was 4537 bytes (DECISIONS.md, 2026-11-17)

root="${1:-.}"
cd "$root" || exit 2

label="WARN"
[ "${PAIRING_STRICT:-}" = "1" ] && label="FAIL"

findings=0
report() { # report PATH RULE DETAIL
  printf 'skill-lint: %s: %s: %s: %s\n' "$label" "$1" "$2" "$3"
  findings=$((findings + 1))
}

# One awk pass per file. Emits tab-separated records:
#   T<TAB>line   an H1 outside a fence
#   H<TAB>line<TAB>normalized heading text (H1-H6 outside fences)
#   W<TAB>0|1    a when-to-read line was found
# Fences follow CommonMark: 3+ backticks or tildes (up to 3 leading spaces) open; a close is
# the same character, at least as long, and nothing else on the line.
scan_file() {
  awk '
    function fence(line,   s, c, n) {
      s = line
      sub(/^ {1,3}/, "", s)
      c = substr(s, 1, 1)
      if (c != "`" && c != "~") return ""
      n = 0
      while (substr(s, n + 1, 1) == c) n++
      if (n < 3) return ""
      return c " " n " " substr(s, n + 1)
    }
    BEGIN { infence = 0; seen_h1 = 0; nb = 0; when = 0; win_open = 1 }
    {
      line = $0
      sub(/\r$/, "", line)
      f = fence(line)
      if (infence) {
        if (f != "") {
          split(f, p, " ")
          rest = substr(f, length(p[1]) + length(p[2]) + 3)
          if (p[1] == fc && p[2] + 0 >= fn && rest ~ /^[ \t]*$/) infence = 0
        }
        if (line ~ /[^ \t]/ ) countwin(line)
        next
      }
      if (f != "") {
        split(f, p, " ")
        infence = 1; fc = p[1]; fn = p[2] + 0
        if (line ~ /[^ \t]/) countwin(line)
        next
      }
      if (line ~ /^#{1,6}[ \t]+/) {
        h = line
        lvl = 0
        while (substr(h, lvl + 1, 1) == "#") lvl++
        sub(/^#+[ \t]+/, "", h)
        sub(/[ \t]+#+[ \t]*$/, "", h)
        sub(/^[0-9]+[.)][ \t]+/, "", h)
        gsub(/[ \t]+/, " ", h)
        sub(/ $/, "", h)
        print "H\t" NR "\t" tolower(h)
        if (lvl == 1) {
          print "T\t" NR
          if (!seen_h1) { seen_h1 = 1; nb = 0; win_open = 1 }
        }
        next
      }
      if (line ~ /[^ \t]/) countwin(line)
    }
    function countwin(l) {
      if (!win_open) return
      nb++
      if (nb > 10) { win_open = 0; return }
      if (tolower(l) ~ /^(load|read)( this| it)? (before|when|first)/ || tolower(l) ~ /^use (this|it) when/) when = 1
    }
    END { print "W\t" when }
  ' "$1"
}

shopt -s nullglob
# Every skills directory must be listable, whether or not other profiles matched.
for d in profiles/*/skills; do
  if [ -d "$d" ] && { [ ! -r "$d" ] || [ ! -x "$d" ]; }; then
    report "$d" scan-error "directory cannot be listed"
  fi
done
files=(profiles/*/skills/*.md)
if [ "${#files[@]}" -eq 0 ] && [ "$findings" -eq 0 ]; then
  echo "skill-lint: no profiles/*/skills/*.md under $root; nothing checked"
  exit 0
fi

heads=$(mktemp) || exit 2
trap 'rm -f "$heads"' EXIT

for f in "${files[@]}"; do
  if [ ! -f "$f" ]; then report "$f" scan-error "not a regular file"; continue; fi
  if [ ! -r "$f" ]; then report "$f" scan-error "file is not readable"; continue; fi
  bytes=$(wc -c < "$f") || { report "$f" scan-error "wc failed"; continue; }
  rec=$(scan_file "$f") || { report "$f" scan-error "awk failed"; continue; }

  tlines=$(printf '%s\n' "$rec" | awk -F'\t' '$1=="T"{printf "%s%s", (n++?", ":""), $2}')
  count=$(printf '%s\n' "$rec" | awk -F'\t' '$1=="T"{n++} END{print n+0}')
  if [ "$count" -eq 0 ]; then report "$f" title "no H1 title"
  elif [ "$count" -ge 2 ]; then report "$f" title "$count H1 titles (lines $tlines)"; fi

  when=$(printf '%s\n' "$rec" | awk -F'\t' '$1=="W"{print $2}')
  if [ "$when" != "1" ]; then
    report "$f" when-to-read "no when-to-read line (start a line near the top with 'Load before ...' or 'Read when ...')"
  fi

  if [ "$bytes" -gt "$max_bytes" ]; then
    report "$f" size "$bytes bytes exceeds the $max_bytes byte cap"
  fi

  profile=${f#profiles/}; profile=${profile%%/*}
  printf '%s\n' "$rec" | awk -F'\t' -v p="$profile" -v f="$f" '$1=="H"{print p "\t" $3 "\t" f ":" $2}' >> "$heads"
done

# duplicate-heading: same normalized text in two different files of one profile.
dups=$(awk -F'\t' '
  { split($3, a, ":"); file = a[1]; key = $1 "\t" $2
    if (!((key SUBSEP file) in seen)) { seen[key SUBSEP file] = 1; nfiles[key]++ }
    loc[key] = loc[key] (loc[key] == "" ? "" : ", ") $3 }
  END { for (k in nfiles) if (nfiles[k] >= 2) { split(k, b, "\t"); print b[1] "\t" b[2] "\t" loc[k] } }
' "$heads" | sort)
if [ -n "$dups" ]; then
  while IFS=$'\t' read -r p text locs; do
    report "profiles/$p/skills" duplicate-heading "\"$text\" appears in: $locs"
  done <<< "$dups"
fi

if [ "$findings" -eq 0 ]; then
  echo "skill-lint: OK (${#files[@]} skill files)"
  exit 0
fi
echo "skill-lint: $findings finding(s)"
[ "${PAIRING_STRICT:-}" = "1" ] && exit 1
exit 0
