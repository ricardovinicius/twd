#!/usr/bin/env bash

set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
bash "$script_dir/../run_suite.sh" "tests/homunculus_couple/test_homunculus_couple.gd"
