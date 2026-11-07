#!/usr/bin/env bash
# Runs all unit tests headless. Override the binary with GODOT=/path/to/godot.
# Fails if the runner reports a failure or if any script error / parse error is
# printed (belt and braces: the runner already fails tests that raise errors).
set -euo pipefail
GODOT="${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}"
cd "$(dirname "$0")/.."
"$GODOT" --headless --path . --import >/dev/null 2>&1 || true
status=0
OUT="$("$GODOT" --headless --path . -s res://tests/run_tests.gd 2>&1)" || status=$?
printf '%s\n' "$OUT"
if grep -qE "SCRIPT ERROR|Parse Error" <<<"$OUT"; then
	echo "TESTS FAILED: script errors were printed"
	exit 1
fi
exit "$status"
