# Changelog

Format follows Keep a Changelog. Dates are UTC.

## [Unreleased] - 2026-11-02

- Security defaults in the base agreements: bound external input, deny outbound hosts by default, never log secrets, no secrets in prompts or config, parameterized queries (LSCBench, TLDR InfoSec 2026-11-09)
- Security-review pass for SSRF, information exposure, and secret handling, named in the cross-review prompt (same report)
- Security note on approval fatigue: new dependencies stay behind explicit approval and the ask list stays short (TLDR InfoSec 2026-11-06)
- Test-first rule in the working agreements: agree a natural-language test list before code and write failing tests first; the plan-review checklist checks for it, and the README workflow states the same order (TLDR IT 2026-11-06)
- Secret scan (gitleaks) before any diff leaves the machine; `REQUIRE_SECRET_SCAN=1` refuses to run without it
- Unit tests for the scan with a fake gitleaks; smoke tests for go and python projects
- ShellCheck and smoke CI
