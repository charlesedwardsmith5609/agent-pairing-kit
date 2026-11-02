#!/usr/bin/env bash
# Expo checks: prettier, hard-coded UI text, tsc, content validation, vitest.
set -u
fail=0
stage() { printf '\n== expo: %s\n' "$1"; }

if [ ! -d node_modules ]; then
  echo "FAIL: node_modules missing. Run: npm install"
  exit 1
fi

stage "prettier"
if npx --no-install prettier --check . >/dev/null 2>&1; then echo "PASS"
else npx --no-install prettier --check . 2>&1 | tail -n 20; echo "FAIL"; echo "Fix: npm run format"; fail=1
fi

stage "hard-coded UI text"
# User-visible words must come from content/. Flags literal letters directly inside a <Text>
# element in screens and components. A line can opt out with "// pairing-allow-text: <reason>".
hits=$(grep -rnE '<Text[^>]*>[^<{]*[A-Za-z]{2,}' src/app src/components 2>/dev/null \
  | grep -v 'pairing-allow-text:' || true)
if [ -n "$hits" ]; then
  echo "$hits"
  echo "FAIL: move the words to content/copy.en.json (or justify with // pairing-allow-text: <reason>)"
  fail=1
else
  echo "PASS"
fi

stage "tsc --noEmit"
if npx --no-install tsc --noEmit; then echo "PASS"; else echo "FAIL"; fail=1; fi

stage "content validation"
if [ -f scripts/validate-content.mjs ]; then
  if node scripts/validate-content.mjs; then echo "PASS"; else echo "FAIL"; fail=1; fi
else
  echo "SKIP: scripts/validate-content.mjs not present yet"
fi

stage "vitest"
if npx --no-install vitest run --passWithNoTests; then echo "PASS"; else echo "FAIL"; fail=1; fi

exit "$fail"
