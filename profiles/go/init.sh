#!/usr/bin/env bash
# Go profile setup. Runs inside the profile's directory. $1 = module name.
set -euo pipefail
go mod init "$1"
