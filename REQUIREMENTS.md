# Requirements

## Review fixes 2026-11-14

Source: `.review/findings.md` (PR #6), `.review/DECISIONS.md` (D2, D12, D13, D14). Needs human
confirmation before step 1 starts.

- R1. The assertion scan must not report test files inside virtualenvs, `node_modules`,
  `vendor` or build output directories (findings 1).
- R2. The assertion scan decides exclusions from paths relative to the scan root, so the
  location of the project on disk never changes the result. When the scan cannot read a
  path or cannot run, it must not report success: `PAIRING_STRICT=1` exits 1 and an
  unusable root or shell exits 2 (finding 2).
- R3. `scripts/assertion-check.sh` and `scripts/review-call.sh` are validation gate files;
  editing either is reported like editing `scripts/check.sh` (finding 3).
- R4. `scripts/misbehavior-check.sh` inspects the content of working-tree files that changed
  (modified, untracked-not-ignored, and staged), not `git diff` text. A new dated entry in
  `DECISIONS.md` supersedes the earlier diff-based description (finding 4, D2).
- R5. Table tests cover near-miss inputs for the Go, Python and TS/JS assertion heuristics
  (finding 5).
- R6. The `scripts/check.sh` summary prints WARN, not PASS, for a stage that exited 0 with
  warnings (finding 6).
- R7. A generated project that predates a helper script is told, loudly, that the helper
  is missing, and the kit can backfill missing helpers without overwriting anything
  (finding 7).
- R8. Tests, README and CHANGELOG match the shipped behaviour; no generated file points at a
  path that does not exist in a generated project. Bash 4.4+ is documented (finding 8).
- No new dependencies. Shell and standard tools only. One local commit per plan step; never push.
- R9. The review scripts (`plan-review.sh`, `cross-review.sh`, `cross-review.ps1`) fail closed:
  a missing gitleaks, a scanner failure or a finding sends nothing. `cross-review` sends tracked
  changes only, takes untracked files by `--include PATH` / `-Include`, and excludes and refuses a
  secret-file deny list. `REQUIRE_SECRET_SCAN` affects only `scripts/check.sh` (DECISIONS.md,
  2026-11-14).
- R10. The Python assertion scan ends a test by indentation, so asserts in or after a nested
  helper count for the enclosing test (DECISIONS.md, 2026-11-14).
- Out of scope: items listed as Suggestions, copying the devcontainer doc into generated projects.

## Skill lint 2026-11-17

- S1. `scripts/skill-lint.sh [ROOT]` checks every `ROOT/profiles/*/skills/*.md`: exactly one H1; a when-to-read line; a byte-size cap (6144); no heading text repeated across two skill files of the same profile.
- S2. Findings warn (exit 0); under `PAIRING_STRICT=1` the same findings fail (exit 1). An unusable ROOT exits 2.
- S3. `scripts/check.sh` runs it as a stage named `skills` (only when `profiles/` exists) and reports it in the summary.
- S4. No semantic or model checks, no live agent test, no new dependencies (bash, grep, awk, wc).
- S5. Installed copies in generated projects (`skills/*.md`) are not checked.
