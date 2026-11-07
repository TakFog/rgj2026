#!/usr/bin/env bash
# Prints the resolved audio settings: music track and, per event, its level,
# pitch, filters and the takes found on disk. Override the binary with GODOT=.
set -euo pipefail
GODOT="${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}"
cd "$(dirname "$0")/.."
"$GODOT" --headless --path . -s res://tools/audio_check.gd
