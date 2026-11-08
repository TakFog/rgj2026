# Game-jam trailer

The trailer is recorded from the real game, so re-running the script after any
change to the game produces an up-to-date trailer.

```sh
tools/trailer.sh                       # 1920x1080, 30 fps -> video/trailer.mp4
RES=1280x720 FPS=60 tools/trailer.sh   # other size / frame rate
```

Requirements: Godot 4.7.2 in `/Applications` (or `GODOT=/path/to/godot`) and
`ffmpeg` on `PATH`. A game window opens while recording (~30-45 s); Movie Maker
renders frame by frame, so the take is not real-time. Losing focus is handled
(the director dismisses the game's focus-loss pause), but don't click inside
the window and **keep the screen unlocked**: macOS stops Godot drawing while
its window is hidden (locked screen, display asleep, minimised) and Movie
Maker then repeats the last frame. The script keeps the display awake and the
window on top, and fails with a clear message if frames were not rendered. Output goes to `video/` (gitignored): `trailer_raw.avi` (MJPEG +
game audio) and the final `trailer.mp4`.

## How it works

- `tools/trailer/trailer.gd` loads `main/main.tscn` with `--smoke-play` (no
  title menu) and adds the director.
- `tools/trailer/trailer_director.gd` plays the run through the same entry
  points the player uses (`PlacementController`, `FishCommander`), draws a fake
  cursor, the title/end cards and the captions, ramps the temperature through
  the debug override, spawns threats, predator and turtle on cue, and finally
  crumbles the corals so the collapse countdown and game-over screen appear.
- `tools/trailer.sh` runs it under `--write-movie` with a temporary
  `override.cfg` (window size, MJPEG quality) and encodes the MP4 with ffmpeg.
  Captions are drawn in Godot because Homebrew's ffmpeg has no `drawtext`.

## Editing

Captions, tagline and credits are constants/strings in
`tools/trailer/trailer_director.gd` (`_run()` holds the whole timeline, one
numbered block per beat). Scripted events use a fixed seed (`SEED`), but the
inventory draws and fish behaviour stay random, so each take differs slightly
in what appears where and in total length (~70-75 s).

If a game change renames `DevASystems/PlacementController`,
`DevBSystems/FishCommander`, `DevBSystems/PauseController`, the
`PlacementGhost` node or the `InventoryBar`, update the director accordingly.
