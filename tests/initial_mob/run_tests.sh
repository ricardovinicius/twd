#!/usr/bin/env bash

set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

bash "$script_dir/../run_suite.sh" "tests/initial_mob/test_combat.gd"
bash "$script_dir/../run_suite.sh" "tests/initial_mob/test_mob_behavior.gd"
bash "$script_dir/../run_suite.sh" "tests/initial_mob/test_player_contact.gd"
