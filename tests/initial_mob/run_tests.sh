#!/usr/bin/env bash

set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
project_dir="$(cd -- "$script_dir/../.." && pwd)"
godot_bin="${GODOT_BIN:-godot}"
runtime_root="${TMPDIR:-/tmp}/twd-initial-mob-tests"

run_suite() {
	local suite="$1"
	local suite_runtime="$runtime_root/$suite"

	mkdir -p "$suite_runtime/data" "$suite_runtime/config" "$suite_runtime/cache"

	XDG_DATA_HOME="$suite_runtime/data" \
	XDG_CONFIG_HOME="$suite_runtime/config" \
	XDG_CACHE_HOME="$suite_runtime/cache" \
		"$godot_bin" \
		--headless \
		--path "$project_dir" \
		--log-file "$suite_runtime/godot.log" \
		--script "res://tests/initial_mob/$suite.gd"
}

run_suite "test_mob_behavior"
run_suite "test_combat"
run_suite "test_player_contact"

printf 'PASS: all initial mob suites\n'
