#!/usr/bin/env bash
# Python profile setup. Runs inside the profile's directory. $1 = project name.
set -euo pipefail
name="$1"
pkg=$(printf '%s' "$name" | tr '-' '_')
case "$pkg" in [0-9]*) pkg="app_$pkg" ;; esac

cat > pyproject.toml <<EOF
[project]
name = "$name"
version = "0.1.0"
requires-python = ">=3.11"

[tool.pytest.ini_options]
testpaths = ["tests"]
pythonpath = ["."]
# Every network wait in a test must have its own timeout.

[tool.ruff]
line-length = 100

[tool.ruff.lint]
select = ["E", "F", "W", "I", "B", "UP", "S", "ASYNC"]

[tool.ruff.lint.per-file-ignores]
"tests/*" = ["S101"]

[tool.mypy]
python_version = "3.11"
disallow_untyped_defs = true
check_untyped_defs = true
warn_unused_ignores = true
EOF

mkdir -p "$pkg" tests
: > "$pkg/__init__.py"
: > tests/__init__.py

if ! python3 -m venv .venv; then
  echo "python: could not create .venv. On Ubuntu: sudo apt install python3-venv" >&2
  exit 1
fi
.venv/bin/pip install --quiet --disable-pip-version-check pytest ruff mypy
