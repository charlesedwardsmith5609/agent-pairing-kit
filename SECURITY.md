# Security policy

## Reporting

Please report vulnerabilities through a private GitHub security advisory on this repository. Do not open a public issue with exploit details. This is a personal project maintained on a best-effort basis, so response times are not guaranteed.

## Scope

This repository is a reference implementation: cross-provider plan and code review kit for AI-assisted development. Review defaults before using it in production. Never commit credentials. CI runs shellcheck and the tests; it does not run a secret scanner. Dependabot (`.github/dependabot.yml`) updates the GitHub Actions versions only, with a 7-day cooldown on version updates (security updates are not delayed; see DECISIONS.md, 2026-11-20). New projects also ship a documented tool-call allowlist and Claude Code deny rules for environ/env/secrets/metadata access; Cursor still relies on the agreements and the validation gate.

## Secrets in reviews

`scripts/plan-review.sh` and `scripts/cross-review.sh` (and `.ps1`) send text to a third-party model, so they scan it with gitleaks first and fail closed: a finding, a missing gitleaks or a scanner failure sends nothing. `cross-review` sends tracked changes only; an untracked file needs `--include PATH` (`-Include` in the `.ps1`), and a deny list (`.env*`, keys, `*credential*`, `.netrc`, `.aws/`, `.ssh/`, terraform state and similar) is excluded from the diff and refused for `--include`. The deny list is a filename filter and the scan is pattern based, so neither catches every secret. With Cursor as the reviewer, the agent can also read other files in the repository, which the scan does not see.

`scripts/check.sh` scans staged additions the same way, but only warns by default. `PAIRING_STRICT=1` fails the gate on a match, and `REQUIRE_SECRET_SCAN=1` fails it when the scan cannot run. `REQUIRE_SECRET_SCAN` has no effect on the review scripts.

## Approval fatigue

New dependencies need an explicit approval in the working agreements. Ask lists stay short.

The Claude Dispatch report (TLDR InfoSec, 2026-11-06) depends on a malicious npm package together with a person clicking through repeated approval prompts. A new package is a named trust decision. A short ask list keeps prompts on the few actions that leave the machine.

This note adds no check.
