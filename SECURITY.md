# Security policy

## Reporting

Please report vulnerabilities through a private GitHub security advisory on this repository. Do not open a public issue with exploit details. This is a personal project maintained on a best-effort basis, so response times are not guaranteed.

## Scope

This repository is a reference implementation: cross-provider plan and code review kit for AI-assisted development. Review defaults before using it in production. Never commit credentials; secret scanning and dependency updates are enabled where noted in the CI configuration.

## Approval fatigue

New dependencies need an explicit approval in the working agreements. Ask lists stay short.

The Claude Dispatch report (TLDR InfoSec, 2026-11-06) depends on a malicious npm package together with a person clicking through repeated approval prompts. A new package is a named trust decision. A short ask list keeps prompts on the few actions that leave the machine.

This note adds no check.
