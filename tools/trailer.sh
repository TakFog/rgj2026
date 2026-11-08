#!/usr/bin/env bash
# Records the game-jam trailer: plays a scripted run of the real game
# (tools/trailer/trailer_director.gd) through Godot's Movie Maker at a fixed
# frame rate, then encodes it to an H.264 MP4 with ffmpeg.
#
#   tools/trailer.sh                 # 1920x1080, 30 fps -> video/trailer.mp4
#   RES=1280x720 FPS=60 tools/trailer.sh
#
# A real (non-headless) window opens while recording; Movie Maker renders
# frame by frame, so the take is not real-time. Don't click inside it, and
# keep the screen unlocked: macOS stops Godot drawing while the window is
# hidden (locked screen, display asleep, minimised), and Movie Maker then
# repeats the last frame. The script detects that and fails.
set -euo pipefail
GODOT="${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}"
RES="${RES:-1920x1080}"
FPS="${FPS:-30}"
cd "$(dirname "$0")/.."
OUT_DIR="video"
RAW="$OUT_DIR/trailer_raw.avi"
MP4="$OUT_DIR/trailer.mp4"
mkdir -p "$OUT_DIR"

if [ -e override.cfg ]; then
	echo "override.cfg already exists; refusing to overwrite it" >&2
	exit 2
fi
# Temporary overrides: window size of the take (the 1280x720 base layout is
# scaled up, as a fullscreen player sees it) and a higher MJPEG quality than
# the 0.75 default for the intermediate file.
trap 'rm -f override.cfg' EXIT
printf '[display]\n\nwindow/size/window_width_override=%s\nwindow/size/window_height_override=%s\n\n[editor]\n\nmovie_writer/mjpeg_quality=0.95\n' \
	"${RES%x*}" "${RES#*x}" > override.cfg

"$GODOT" --path . --import >/dev/null 2>&1 || true
LOG="$(mktemp)"
# caffeinate keeps the display awake; --always-on-top keeps other windows off it.
caffeinate -d -i "$GODOT" --path . --always-on-top --fixed-fps "$FPS" --write-movie "$RAW" \
	-s res://tools/trailer/trailer.gd -- --smoke-play 2>&1 | tee "$LOG"

# Godot reports the frames it actually rendered; the AVI holds every frame of
# the take. Fewer rendered frames means the window was hidden for a while and
# part of the trailer is a frozen image.
RENDERED="$(sed -n 's/^\([0-9]*\) frames at .*/\1/p' "$LOG" | tail -1)"
rm -f "$LOG"
WRITTEN="$(ffprobe -v error -select_streams v:0 -count_packets -show_entries stream=nb_read_packets -of csv=p=0 "$RAW")"
if [ -z "$RENDERED" ] || [ "$RENDERED" -lt $((WRITTEN * 99 / 100)) ]; then
	echo "Only ${RENDERED:-?} of $WRITTEN frames were rendered: the Godot window was hidden" >&2
	echo "(locked screen, display asleep or minimised). Keep it visible and run again." >&2
	exit 1
fi

DURATION="$(ffprobe -v error -show_entries format=duration -of csv=p=0 "$RAW")"
FADE_OUT_START="$(awk -v d="$DURATION" 'BEGIN { printf "%.2f", d - 1.5 }')"
ffmpeg -y -loglevel error -i "$RAW" \
	-vf "format=yuv420p" -c:v libx264 -preset slow -crf 18 -r "$FPS" \
	-af "afade=t=in:d=1,afade=t=out:st=$FADE_OUT_START:d=1.5" -c:a aac -b:a 192k \
	-movflags +faststart "$MP4"
echo "Trailer: $MP4 (${DURATION}s)"
# The jam caps the trailer at one minute.
MAX_SECONDS="${MAX_SECONDS:-60}"
if awk -v d="$DURATION" -v m="$MAX_SECONDS" 'BEGIN { exit !(d > m) }'; then
	echo "The trailer is ${DURATION}s, over the ${MAX_SECONDS}s limit: shorten the" >&2
	echo "timeline in tools/trailer/trailer_director.gd and record it again." >&2
	exit 1
fi
