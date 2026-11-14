# Changelog

Format follows Keep a Changelog. Dates are UTC.

## [Unreleased] - 2026-11-02

- `new-project.sh` copies `scripts/assertion-check.sh` so a generated project's check can run the assertion scan.
- Working agreements note that every enabled tool and MCP server costs context tokens on every turn. `docs/sandboxed-devcontainer.md` is a docs-only pointer for a sandboxed devcontainer. No devcontainer file is added.
- Assertion scan in `scripts/check.sh` reads test files (not diffs) and warns when a test has no assertion. `PAIRING_STRICT=1` fails the gate.
- Review checklist section "Test quality": tests must assert behavior, must not be assertion-free, and must not only mirror the implementation.
- Tool-call policy in working agreements plus Claude Code `permissions` (ask `WebFetch`; deny environ/env/secrets/metadata probes)
- Agent-misbehavior stage in `scripts/check.sh` (warn by default; `PAIRING_STRICT=1` fails): skipped tests, gate-file edits, test-only diffs, plan `## Files` scope when parseable
- Note Go 1.27+ `encoding/json/v2` stricter defaults in the Go network-service skill
- Security defaults in the base agreements: bound external input, deny outbound hosts by default, never log secrets, no secrets in prompts or config, parameterized queries (LSCBench, TLDR InfoSec 2026-11-09)
- Security-review pass for SSRF, information exposure, and secret handling, named in the cross-review prompt (same report)
- Secrets stay out of agent-to-agent channels; the check warns when staged additions match the gitleaks scan and fails when PAIRING_STRICT=1 (The Register via TLDR InfoSec 2026-11-09)
- Security note on approval fatigue: new dependencies stay behind explicit approval and the ask list stays short (TLDR InfoSec 2026-11-06)
- Test-first rule in the working agreements: agree a natural-language test list before code and write failing tests first; the plan-review checklist checks for it, and the README workflow states the same order (TLDR IT 2026-11-06)
- Secret scan (gitleaks) before any diff leaves the machine; `REQUIRE_SECRET_SCAN=1` refuses to run without it
- Unit tests for the scan with a fake gitleaks; smoke tests for go and python projects
- ShellCheck and smoke CI
