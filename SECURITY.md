# Security policy

## Reporting

Please report vulnerabilities through a private GitHub security advisory on this repository. Do not open a public issue with exploit details. This is a personal project maintained on a best-effort basis, so response times are not guaranteed.

## Scope

This repository is a reference implementation: cross-provider plan and code review kit for AI-assisted development. Review defaults before using it in production. Never commit credentials; secret scanning and dependency updates are enabled where noted in the CI configuration. New projects also ship a documented tool-call allowlist and Claude Code deny rules for environ/env/secrets/metadata access; Cursor still relies on the agreements and the validation gate.
