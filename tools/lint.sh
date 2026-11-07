#!/usr/bin/env bash
# Loads every GDScript file headless with all "warn"-level GDScript warnings
# escalated to errors (via a temporary override.cfg); fails if any script
# reports an error or warning. Override the binary with GODOT=/path/to/godot.
set -uo pipefail
GODOT="${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}"
cd "$(dirname "$0")/.."
if [ -e override.cfg ]; then
	echo "override.cfg already exists; refusing to overwrite it" >&2
	exit 2
fi
"$GODOT" --headless --path . --import >/dev/null 2>&1 || true
keys=$(timeout 120 "$GODOT" --headless --path . -s res://tools/lint_check.gd -- --list-warnings 2>&1 \
	| sed -n 's/^warning-key //p')
if [ -z "$keys" ]; then
	echo "could not list GDScript warning settings" >&2
	exit 2
fi
trap 'rm -f override.cfg' EXIT
{ echo "[debug]"; echo; printf '%s=2\n' $keys; } > override.cfg
out=$(timeout 300 "$GODOT" --headless --path . -s res://tools/lint_check.gd 2>&1)
status=$?
problems=$(printf '%s\n' "$out" | grep -E "SCRIPT ERROR|WARNING|Parse Error|Compile Error|Failed to load" -A1)
printf '%s\n' "$out" | grep "^lint:"
if [ "$status" -ne 0 ] || [ -n "$problems" ]; then
	printf '%s\n' "$problems"
	echo "LINT FAILED"
	exit 1
fi
echo "LINT OK"
