# Audio

Tuning is data-only: levels, pitch and filters live in `data/audio_settings.tres`,
so the mix can be rebalanced without touching a script. The rules below apply to
**every new sound**.

## Pieces

| File | What it is |
|---|---|
| `assets/audio/` | The audio assets. One folder per sound: `corallo/` (placing an item), `item/` (an inventory slot refills), `busta/` (a plastic bag pops). `game_loop.wav` is the music. |
| `systems/b_audio.gd` | The SFX node. Its `EVENTS` dictionary maps an event name to the **takes** (file paths) played at random, one per play. |
| `data/audio_event.gd` | One event's `gain_db`, `pitch`, `pitch_jitter`, `high_pass_hz` and `low_pass_hz` (an `AudioEvent` resource). |
| `data/audio_settings.gd` / `.tres` | It all comes together here: the music settings, a global effects level, and one `AudioEvent` per event. **Tune in `data/audio_settings.tres`** (open it in the inspector). |
| `autoload/game.gd` | Exposes the resource as `Game.AUDIO_SETTINGS`. |

## Levels

All levels are in **dB**: `0.0` is unmodified, `-6.0` is half as loud, positive
values boost, `-80.0` and below is silent. `effects_gain_db` is the global effects
level and is added to every event; each event's `gain_db` then balances it
against the others. The quiet effect takes (peaking around -10 dBFS) rely on the
default `effects_gain_db = 8.0` to sit under the music.

Shipped tuning: `item_available` sits at `-3.0` dB, `placement` at `-3.0` dB and
`bag_destroyed` at `0.0`.

## Pitch

`pitch` is a speed multiplier (`0.5` an octave down, `2.0` an octave up; pitch and
speed move together). `pitch_jitter` adds a random ± spread on every play, handy
for sounds that repeat a lot — `0.0` keeps the pitch fixed.

## Filters

`high_pass_hz` removes the frequencies **below** the cutoff, `low_pass_hz` removes
the ones **above** it; `0.0` switches that filter off. They are plain frequencies
in Hz, e.g. `250.0` is a gentle high-pass that thins the low end of a thud and
`4000.0` is a low-pass that muffles a sound.

Each event plays on its own audio bus (`Sfx_<event>`, routed to Master), so its
filters never affect the other sounds; the music has its own `Music` bus. The
buses are created at startup from the settings — nothing to set up by hand in
the Audio panel.

Shipped tuning: the placement sound is slightly high-passed at `350` Hz
(`placement`).

## Adding a sound

1. Drop the `.wav` file(s) under a folder in `assets/audio/`, e.g.
   `assets/audio/busta/b1.wav`. More than one file in an event means a random
   one is played each time. Let Godot import them (open the editor once, or run
   `tools/smoke.sh`, which imports automatically).
2. Add the event to `EVENTS` in `systems/b_audio.gd`:
   ```gdscript
   &"bag_destroyed": [
       "res://assets/audio/busta/b0.wav",
       "res://assets/audio/busta/b1.wav",
   ],
   ```
   Missing files are skipped silently, so a take can be dropped in later.
3. Add an entry for the event in the `events` dictionary of
   `data/audio_settings.gd` (`&"bag_destroyed": AudioEvent.new(),`) and tune it
   in `data/audio_settings.tres`. An event *without* an entry still plays, but at
   the neutral defaults (`gain_db 0.0`, `pitch 1.0`, no jitter, no filters) —
   `tests/unit/test_audio_settings.gd` fails when a shipped event is missing
   from the settings, so this stays enforced.
4. Call `play(&"event_name")` from wherever the game event happens, e.g. in
   `b_audio.gd` `_ready()` when wiring signals.
5. Run `tools/test.sh` and `tools/smoke.sh`.

## Music

The music is a single looping track played by `Main` (`main/main.gd`). To change
it, set `music_track` in `data/audio_settings.tres` (Music section): pick any
`.wav` from `assets/audio/` in the inspector, or clear it for silence. The
available tracks are `game_loop.wav` and `game_loop_alt.wav` (currently used);
`intro.wav` and `outro.wav` are kept for later.

Level, pitch and filters are `music_gain_db`, `music_pitch`,
`music_high_pass_hz` and `music_low_pass_hz` in the same resource. The loop comes
from the WAV import setting `edit/loop_mode` (`2` = forward) in the track's
`.wav.import` file, so a new track must have it set — `tools/test.sh` fails if the
configured track does not loop.
