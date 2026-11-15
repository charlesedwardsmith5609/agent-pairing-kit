# Step 2 (MEDIUM): heuristic table tests, WARN summary, helper backfill

Covers findings 5, 6, 7 (finding 5 is treated as MEDIUM; 6 and 7 as MEDIUM; 8 is LOW, step 3).

## Types / interfaces
Shell only. No new dependencies.
- Table tests: a data-driven loop in `tests/test-assertion-check.sh` (`name | language | source | expect`).
  Heuristic fixes in `assertion-check.sh` only where a table row proves a false positive or negative.
  Near-misses to cover: `assert` inside a comment or string, `t.Run` subtests with assertions only in
  the closure, helper-based asserts (`assertEqual`), `pytest.raises` as context, `expect.assertions`,
  `.skip` tests, Go `func TestMain`, and non-test `Test`-prefixed helpers.
- `check.sh` summary: a stage that exits 0 but printed a `WARN`/`warnings` line shows `WARN`; exit 1 shows
  `FAIL`; clean shows `PASS`. Final line stays `CHECK PASSED`/`CHECK FAILED`; warnings do not change exit code.
- Backfill: `check.sh` reports a missing `scripts/misbehavior-check.sh` or `scripts/assertion-check.sh`
  as a stage WARN (FAIL under `PAIRING_STRICT=1`) instead of an opaque bash error. `new-project.sh
  --backfill PATH` copies only helper scripts that are missing and never overwrites a file.

## Ownership
`check.sh` owns the results string and exit code; stages communicate only via exit code and captured
stdout. `new-project.sh --backfill` owns writes to `PATH/scripts/` and refuses a path without
`.pairing-profiles`.

## Assumptions
- "Scaffolder must backfill" means an explicit, non-overwriting `--backfill` mode, not silent edits
  on every run.
- Stage output is inspected for the literal word `WARN` to choose the summary label.

## Test list (written failing first)
1. Each table row of near-miss inputs gives the expected result for Go, Python and TS/JS.
2. `check.sh` on a project with an assertion-free test shows `assertions: WARN` in the summary,
   still ends `CHECK PASSED`, exit 0.
3. Same project with `PAIRING_STRICT=1` shows `FAIL`, ends `CHECK FAILED`, exit 1.
4. A clean project shows `PASS` for every stage.
5. A project missing `scripts/assertion-check.sh` gets a named warning, not a bash "No such file" error;
   exit 0 by default, 1 strict.
6. `new-project.sh --backfill DIR` adds the missing helper, leaves an edited existing helper byte-identical,
   and exits 2 for a directory without `.pairing-profiles`.
7. Smoke test: a generated project passes `check.sh` and `--backfill` on it changes nothing.

## Files
- scripts/assertion-check.sh
- scripts/check.sh
- new-project.sh
- tests/test-assertion-check.sh
- tests/test-check-summary.sh
- tests/smoke-new-project.sh
- .github/workflows/ci.yml
