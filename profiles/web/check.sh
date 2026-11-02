#!/usr/bin/env bash
# Web checks: prettier, TypeScript type check, vitest. Runs in the web project's directory.
set -u
fail=0
stage() { printf '\n== web: %s\n' "$1"; }

if [ ! -d node_modules ]; then
  echo "FAIL: node_modules missing. Run: npm install"
  exit 1
fi

stage "prettier"
if npx --no-install prettier --check . >/dev/null 2>&1; then echo "PASS"
else npx --no-install prettier --check . 2>&1 | tail -n 20; echo "FAIL"; echo "Fix: npm run format"; fail=1
fi

stage "unsafe DOM sinks"
# HTML-injection sinks are banned in src/. A line can opt out with a trailing
# comment "pairing-allow-html: <reason>", which keeps every exception visible in review.
hits=$(grep -rnE 'innerHTML|outerHTML|insertAdjacentHTML|document\.write|dangerouslySetInnerHTML' src 2>/dev/null \
  | grep -v 'pairing-allow-html:' || true)
if [ -n "$hits" ]; then
  echo "$hits"
  echo "FAIL: use textContent or createElement instead (or justify with // pairing-allow-html: <reason>)"
  fail=1
else
  echo "PASS"
fi

stage "tsc --noEmit"
if npx --no-install tsc --noEmit; then echo "PASS"; else echo "FAIL"; fail=1; fi

stage "vitest"
if npx --no-install vitest run --passWithNoTests; then echo "PASS"; else echo "FAIL"; fail=1; fi

exit "$fail"
