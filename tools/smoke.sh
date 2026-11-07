#!/usr/bin/env bash
# Boots the main scene headless for ~5 s of frames and fails on any script error.
set -euo pipefail
GODOT="${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}"
cd "$(dirname "$0")/.."
"$GODOT" --headless --path . --import >/dev/null 2>&1 || true
OUT="$("$GODOT" --headless --path . --quit-after 300 2>&1)"
if grep -E "SCRIPT ERROR|Parse Error|ERROR:" <<<"$OUT"; then
	echo "SMOKE FAILED"
	exit 1
fi
echo "SMOKE OK"
