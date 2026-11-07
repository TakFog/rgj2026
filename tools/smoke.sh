#!/usr/bin/env bash
# Boots the main scene headless for ~10 s of frames and fails on any script error.
# --smoke-play skips the title menu and starts a run (MainMenuScreen), so the
# spawners, entities and systems actually tick instead of a paused tree.
set -euo pipefail
GODOT="${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}"
cd "$(dirname "$0")/.."
"$GODOT" --headless --path . --import >/dev/null 2>&1 || true
OUT="$("$GODOT" --headless --path . --quit-after 600 -- --smoke-play 2>&1)"
# The dummy audio driver never mixes after the quit request, so the music stems
# still playing are reported as "in use at exit" (godotengine/godot#95484).
# That single line is an engine shutdown artifact; anything else fails.
ERRORS="$(grep -E "SCRIPT ERROR|Parse Error|ERROR:" <<<"$OUT" \
	| grep -vE "^ERROR: [0-9]+ resources still in use at exit" || true)"
if [[ -n "$ERRORS" ]]; then
	echo "$ERRORS"
	echo "SMOKE FAILED"
	exit 1
fi
echo "SMOKE OK"
