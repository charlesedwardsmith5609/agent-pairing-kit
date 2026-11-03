# Contributing

Issues and pull requests are welcome. Keep changes small and focused, and explain the why in the PR description.

## Before opening a PR

Run the same checks CI runs:

```bash
shellcheck -x scripts/*.sh tests/*.sh
bash tests/test-secret-scan.sh
bash tests/smoke-new-project.sh python
```

## Guidelines

- Add or update tests with behavior changes.
- Do not commit secrets, tokens, or generated artifacts.
- If a change touches AI-generated code, review it as you would any other contribution.
