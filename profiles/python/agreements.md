### Python (`{{DIR}}`)

- Application code uses the standard library only. Dev tools already installed in `.venv`:
  pytest, ruff, mypy. Install nothing else without approval.
- Run tools through `.venv/bin/` (for example `.venv/bin/python`, `.venv/bin/pytest`).
- Type hints on every function; mypy must pass. Code lives in the `{{PKG}}/` package, tests in `tests/`.
- Concurrency: say whether code is threaded or asyncio. Never block the event loop; name which
  thread or task owns shared state.
- Network tests use real sockets on `127.0.0.1` port 0, with a timeout on every read or wait.
- Skill: read `skills/python-service.md` before writing server code.
- Check stages: ruff check, ruff format --check, mypy, pytest.
