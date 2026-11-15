# Step 1 (HIGH): assertion scan scope, fail-closed strict, gate paths, working-tree check

Covers findings 1, 2, 3, 4 (finding 4 is decided by D2; treated as HIGH).

## Types / interfaces
Shell only. No new dependencies.
- `assertion-check.sh [root]`: exit 0 clean or warnings, 1 strict findings or strict-unscannable,
  2 unusable root or bash older than 4.4.
- Exclusion rule is applied to paths relative to root with `find . -prune`. Excluded directory
  names: `.git`, `node_modules`, `vendor`, `.venv`, `venv`, `site-packages`, `__pycache__`,
  `.tox`, `.nox`, `build`, `dist`, `target`. Any directory containing `pyvenv.cfg` is also pruned.
- `misbehavior-check.sh`: changed set = `git ls-files -m -o --exclude-standard` plus
  `git diff --cached --name-only`, skipping paths that no longer exist. Skip-marker scan reads the
  content of changed files that are test paths or `*.json`/`*.config.*` files.

## Ownership
No concurrency. Each script owns its own temp files (`mktemp`, removed by `trap`). The scripts
read the working tree and own no shared state. `DECISIONS.md` is edited by appending only.

## Assumptions
- A skip marker already present in a changed file is reported (restrictive reading of D2).
- Committed but unchanged-in-working-tree edits are not seen; D2 accepts this.

## Test list (written failing first)
1. A `test_x.py` with no assertion under `.venv/` is not reported.
2. Same under `venv/`, `node_modules/`, `vendor/`, `build/`, `dist/`, `target/` and under a
   directory with a `pyvenv.cfg` but an unusual name.
3. A real assertion-free test in a normal directory is still reported (guards over-exclusion).
4. A project whose absolute path contains `node_modules` or `vendor` is still scanned and its
   assertion-free test is reported.
5. Strict mode with an unreadable subdirectory exits 1 and names the path; default mode warns, exit 0.
6. A root that is not a directory exits 2.
7. Editing `scripts/assertion-check.sh` or `scripts/review-call.sh` reports "validation gate file changed".
8. A staged (committed-to-index) `t.Skip(` in a test file is reported; exact exit code 0 default, 1 strict.
9. A skip marker in an untracked file is reported; a deleted tracked file does not error.
10. An ignored file (via `.gitignore`) with a skip marker is not reported.
11. A clean repo still prints `misbehavior: OK (no changes)`.
12. All existing assertion and misbehavior tests still pass.

## Files
- scripts/assertion-check.sh
- scripts/misbehavior-check.sh
- tests/test-assertion-check.sh
- tests/test-misbehavior-check.sh
- DECISIONS.md
