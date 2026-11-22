# Changelog

Format follows Keep a Changelog. Dates are UTC.

## [Unreleased] - 2026-11-14

### Security

- `cross-review.sh`/`.ps1`, `plan-review.sh` and `review-call.sh` fail closed (upstreamed from toolcost 33a7524): a missing or failing gitleaks, or a finding, sends nothing. Only tracked changes are sent (no more `git add --intent-to-add --all`, which leaked untracked `.env`). Untracked files need `--include PATH` (`-Include` in the .ps1). A secret-file deny list is excluded from the diff and refused for `--include` (exit 2). `REQUIRE_SECRET_SCAN` no longer affects the review scripts; `check.sh` still uses it. `tests/test-cross-review.sh` covers it.
- Secret scan (gitleaks) before any text leaves the machine for a review; the check also warns when staged additions match the scan and fails under `PAIRING_STRICT=1` (The Register via TLDR InfoSec 2026-11-09). Unit tests use a fake gitleaks.
- Security defaults in the base agreements: bound external input, deny outbound hosts by default, never log secrets, no secrets in prompts or config, parameterized queries (LSCBench, TLDR InfoSec 2026-11-09). The cross-review prompt names a security pass for SSRF, information exposure and secret handling.
- Tool-call policy in the working agreements plus Claude Code `permissions` (ask `WebFetch`; deny environ/env/secrets/metadata probes).
- Security note on approval fatigue in `SECURITY.md`: new dependencies stay behind explicit approval and the ask list stays short (TLDR InfoSec 2026-11-06). `SECURITY.md` no longer claims CI secret scanning (CI has none).

### Added

- `scripts/skill-lint.sh` (kit-only) lints `profiles/*/skills/*.md`: one H1, a when-to-read line, 6144-byte cap, no duplicate heading text across skills of a profile, `scan-error` for unreadable files. Warns; `PAIRING_STRICT=1` fails. `check.sh` runs it as a `skills` stage when `profiles/` exists; CI runs it strict; `tests/test-skill-lint.sh` covers it. Implemented on the stated default, pending owner confirmation. Installed copies in projects are not checked (NVIDIA SkillEvaluator via TLDR IT 2026-11-17; the kit takes only the cheap structural tier).
- `scripts/assertion-check.sh` (copied into generated projects) scans test files on disk, not diffs, and warns when a test has no assertion; `PAIRING_STRICT=1` fails the gate. It skips `.git`, virtualenvs, `node_modules`, `vendor` and build directories by relative path, fails closed on paths it cannot read under `PAIRING_STRICT=1`, and exits 2 on a bad root or bash older than 4.4. Heuristics ignore comments and strings, accept helper asserts and `expect.assertions`, and skip `TestMain` and non-test helpers; table tests cover the near-misses.
- Agent-misbehavior stage in `scripts/check.sh` (`scripts/misbehavior-check.sh`; warn by default, `PAIRING_STRICT=1` fails): skipped tests, validation gate file edits, test-only changes, and plan `## Files` scope when parseable. It reads changed working-tree files, not diff text, and uses `mktemp` (DECISIONS.md, D2). `assertion-check.sh` and `review-call.sh` are validation gate files.
- `new-project.sh --backfill PATH` adds missing helper scripts to an older generated project without overwriting anything. It does not refresh helpers that already exist; copy those over from the kit.
- Test-first rule in the working agreements: agree a natural-language test list before code and write failing tests first; the plan-review checklist checks for it and the README workflow states the same order (TLDR IT 2026-11-06).
- Review checklist section "Test quality": tests must assert behavior, must not be assertion-free, and must not only mirror the implementation.
- Working agreements note that every enabled tool and MCP server costs context tokens on every turn. `docs/sandboxed-devcontainer.md` is a docs-only pointer for a sandboxed devcontainer; no devcontainer file is added.
- Note on Go 1.27+ `encoding/json/v2` stricter defaults in the Go network-service skill.
- ShellCheck CI, unit tests, and smoke tests for go, python, web and fullstack projects.

### Changed

- The `scripts/check.sh` summary shows `WARN` for a stage that warned. A missing helper script is a named warning (a failure under `PAIRING_STRICT=1`).
- The Python assertion scan no longer ends a test at a nested `def`/`class`: a test runs from its `def test_` until the next line at that indentation or less, and asserts after (or inside) a nested helper count for the enclosing test. Fixes false warnings in platform-agent-harness and agent-harness. Go and TS/JS were not affected.
- Docs: README lists `assertion-check.sh`, the bash 4.4 requirement, the validation gate files, the deny list and how to refresh helpers; the devcontainer pointer in generated agreements names the kit repository; `tests/test-docs.sh` guards README and CONTRIBUTING drift.

### Fixed

- `cross-review.ps1` passed gitleaks the argument `s t d i n`: `$gl = if (...) { @('stdin') }` unrolled the one-element array to a string and `@gl` splatted it a character at a time, so with gitleaks installed every run failed the scan (closed, but unusable). It is now `@(if ...)`. `tests/test-cross-review.sh` runs the script against a gitleaks that records its arguments and asserts `stdin --no-banner ...` (verified to fail on the old script).
- `.claude/settings.json` (from `claude-settings.json`) wrote `Read(/proc/**/environ)` and `Read(/var/run/secrets/**)` with one leading slash, which Claude Code anchors at the project root, so the two denies matched nothing. They are now `Read(//proc/**/environ)` and `Read(//var/run/secrets/**)`. Existing projects keep their copy; change those two lines by hand (or copy the kit file if you have not edited it).
- `cross-review.ps1` did not parse: the fail-closed rewrite put `$f:` inside two double-quoted refusal messages and PowerShell reads that as a scoped variable, so the script never ran (now `${f}`). Found by running it under PowerShell 7.7. `tests/test-cross-review.sh` now parses the script and runs the `-Include .env` and no-gitleaks refusals under `pwsh` when it is installed (skipped with a note otherwise). The `.ps1` is exercised only for parse and those refusal paths.
