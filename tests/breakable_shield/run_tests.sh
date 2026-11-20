#!/usr/bin/env bash

set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

bash "$script_dir/../run_suite.sh" "tests/breakable_shield/test_breakable_shield.gd"
