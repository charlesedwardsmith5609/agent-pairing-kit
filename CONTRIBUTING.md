# Contributing

Issues and pull requests are welcome. Keep changes small and focused, and explain the why in the PR description.

## Before opening a PR

Run the same checks CI runs:

```bash
git ls-files -z '*.sh' | xargs -0 shellcheck -x
bash tests/test-secret-scan.sh
bash tests/test-staged-secret-scan.sh
bash tests/test-cross-review.sh
bash tests/test-misbehavior-check.sh
bash tests/test-assertion-check.sh
bash tests/test-check-summary.sh
bash tests/test-skill-lint.sh
PAIRING_STRICT=1 bash scripts/skill-lint.sh .
bash tests/test-docs.sh
bash tests/smoke-new-project.sh python
```

Needs bash 4.4+, `shellcheck`, `python3` and `git`. `tests/test-cross-review.sh` also parses
`scripts/cross-review.ps1` and runs its refusal paths when `pwsh` is on your `PATH`, and prints a
skip note otherwise. CI also smoke-tests `go`, `web` and `fullstack` (`expo` is not in CI). Any new
`tests/test-*.sh` must be listed in this file and in the README (`tests/test-docs.sh` checks).

## Guidelines

- Add or update tests with behavior changes.
- Do not commit secrets, tokens, or generated artifacts.
- If a change touches AI-generated code, review it as you would any other contribution.
