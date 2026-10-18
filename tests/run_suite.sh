#!/usr/bin/env bash

set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
project_dir="$(cd -- "$script_dir/.." && pwd)"
godot_bin="${GODOT_BIN:-godot}"
suite_path="${1:?Usage: run_suite.sh tests/path/test_suite.gd}"
runtime_root="$(mktemp -d "${TMPDIR:-/tmp}/twd-test.XXXXXX")"

mkdir -p "$runtime_root/data" "$runtime_root/config" "$runtime_root/cache"

if XDG_DATA_HOME="$runtime_root/data" \
	XDG_CONFIG_HOME="$runtime_root/config" \
	XDG_CACHE_HOME="$runtime_root/cache" \
	"$godot_bin" --headless --path "$project_dir" \
	--log-file "$runtime_root/godot.log" --quit-after 3600 \
	--script "res://tests/bootstrap.gd" -- "res://$suite_path" 2>&1 | tee "$runtime_root/output.log"; then
	:
else
	exit 1
fi

# Godot can exit successfully after a script error aborts a test function.
# Ignore only the macOS system certificate lookup error seen in sandboxed runs.
if grep -E 'SCRIPT ERROR:|^ERROR:|^FAIL:' "$runtime_root/output.log" \
	| grep -v '^ERROR: Condition "ret != noErr" is true. Returning: ""$'; then
	printf 'FAIL: engine errors in %s (log: %s)\n' "$suite_path" "$runtime_root/output.log" >&2
	exit 1
fi

if ! grep -q '^PASS:' "$runtime_root/output.log"; then
	printf 'FAIL: %s did not finish (log: %s)\n' "$suite_path" "$runtime_root/output.log" >&2
	exit 1
fi
