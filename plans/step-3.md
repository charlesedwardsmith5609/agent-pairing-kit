# Step 3 (LOW): docs drift, bash version, dead devcontainer pointer

Covers finding 8.

## Types / interfaces
Docs and one test only. No code behaviour change.
- `base/CLAUDE.md`: the devcontainer sentence names the pairing kit repository's
  `docs/sandboxed-devcontainer.md` as a kit document and does not read like a path inside the project.
- `README.md`: add an `assertion-check.sh` row; correct the misbehavior row ("working-tree file checks",
  not "diff checks"); document "Needs bash 4.4+"; list `tests/test-assertion-check.sh` and
  `tests/test-check-summary.sh`.
- `CONTRIBUTING.md`: run the new tests. `CHANGELOG.md`: entries for steps 1 to 3.
- `DECISIONS.md`: dated entry for the devcontainer pointer wording (supersedes 2026-11-13 wording only).

## Ownership
Documentation only; the human owns wording decisions. `tests/smoke-new-project.sh` owns the check that
generated files contain no pointer to a missing path.

## Assumptions
- Rewording the pointer is preferred over copying the doc into generated projects (copying is a Suggestion).

## Test list (written failing first)
1. Smoke test: every backticked `docs/...` path in the generated `CLAUDE.md` either exists in the
   project or is preceded by the words "pairing kit".
2. README mentions `assertion-check.sh` and "bash 4.4".
3. CONTRIBUTING lists every `tests/test-*.sh` file that exists.
4. Both test checks fail on the current tree (written first).

## Files
- base/CLAUDE.md
- README.md
- CONTRIBUTING.md
- CHANGELOG.md
- DECISIONS.md
- tests/smoke-new-project.sh
- tests/test-docs.sh
- .github/workflows/ci.yml
