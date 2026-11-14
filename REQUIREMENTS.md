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
- Out of scope: items listed as Suggestions, copying the devcontainer doc into generated projects.
