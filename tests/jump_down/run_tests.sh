#!/usr/bin/env bash

set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
project_dir="$(cd -- "$script_dir/../.." && pwd)"
godot_bin="${GODOT_BIN:-godot}"
runtime_root="${TMPDIR:-/tmp}/twd-jump-down-tests"

mkdir -p "$runtime_root/data" "$runtime_root/config" "$runtime_root/cache"

XDG_DATA_HOME="$runtime_root/data" \
XDG_CONFIG_HOME="$runtime_root/config" \
XDG_CACHE_HOME="$runtime_root/cache" \
	"$godot_bin" \
	--headless \
	--path "$project_dir" \
	--log-file "$runtime_root/godot.log" \
	--script "res://tests/jump_down/test_jump_down.gd"
