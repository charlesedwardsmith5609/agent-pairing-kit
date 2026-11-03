# Changelog

Format follows Keep a Changelog. Dates are UTC.

## [Unreleased] - 2026-11-02

- Secret scan (gitleaks) before any diff leaves the machine; `REQUIRE_SECRET_SCAN=1` refuses to run without it
- Unit tests for the scan with a fake gitleaks; smoke tests for go and python projects
- ShellCheck and smoke CI
