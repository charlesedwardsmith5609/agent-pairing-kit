# Changelog

Format follows Keep a Changelog. Dates are UTC.

## [Unreleased]

- Tool-call policy in working agreements plus Claude Code `permissions` (ask `WebFetch`; deny environ/env/secrets/metadata probes)
- Agent-misbehavior stage in `scripts/check.sh` (warn by default; `PAIRING_STRICT=1` fails): skipped tests, gate-file edits, test-only diffs, plan `## Files` scope when parseable
- Note Go 1.27+ `encoding/json/v2` stricter defaults in the Go network-service skill
- Secret scan (gitleaks) before any diff leaves the machine; `REQUIRE_SECRET_SCAN=1` refuses to run without it
- Unit tests for the scan with a fake gitleaks; smoke tests for go and python projects
- ShellCheck and smoke CI
