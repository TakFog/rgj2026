# Audio

Tuning is data-only: levels, pitch and filters live in `data/audio_settings.tres`,
so the mix can be rebalanced without touching a script. The rules below apply to
**every new sound**.

## Pieces

| File | What it is |
|---|---|
| `assets/audio/` | The audio assets, one folder per sound (see Events below). The `game_loop*.wav`, `intro.wav` and `outro.wav` files are music. |
| `core/audio_events.gd` | `AudioEvents.TAKES`: event name -> **takes** (file paths), one of which is played at random per play. |
| `systems/b_audio.gd` | The SFX node that plays those events (pool of voices, one bus per event). |
| `data/audio_event.gd` | One event's `gain_db`, `pitch`, `pitch_jitter`, `high_pass_hz` and `low_pass_hz` (an `AudioEvent` resource). |
| `data/audio_settings.gd` / `.tres` | It all comes together here: the music settings, a global effects level, and one `AudioEvent` per event. **Tune in `data/audio_settings.tres`** (open it in the inspector); its entries are named after the events (`AudioEvent_placement`, ...) and the file starts with a short legend. |
| `core/user_settings.gd` | The player's Music/Effects volume, saved in `user://settings.cfg` (separate from the designer mix). |
| `autoload/game.gd` | Exposes the resource as `Game.AUDIO_SETTINGS`. |

## Events

| Event | Plays when | Files |
|---|---|---|
| `placement_nest` | placing a nest | `assets/audio/nido/` |
| `placement_algae` | placing an algae | `assets/audio/alga/` |
| `placement` | placing a coral (or any kind without its own event) | `assets/audio/corallo/` |
| `predator_ate` | a predator bites a fish or a nest's eggs | `assets/audio/eat/` |
| `item_hover` | clicking an inventory item to start placing it | `assets/audio/item/` |
| `item_available` | an inventory slot refills | `assets/audio/item/` |
| `cyclone_wind` | loops while a cyclone is on screen, fading in/out (`cyclone_wind_fade_seconds`; the take must loop) | `assets/audio/wind/` |
| `cyclone_hit` | a cyclone destroys something (fish, coral, algae, nest...) | `assets/audio/` |
| `co2_gone` | a CO2 cloud disappears on screen (not when it drifts off it) | `assets/audio/co2/` (bubble pop) |
| `bag_destroyed` | a plastic bag pops on screen (not when it drifts off it) | `assets/audio/busta/` |

Player and ecosystem feedback:

| Event | Plays when | Files |
|---|---|---|
| `ui_click` | a menu, pause or restart button is pressed | `assets/audio/ui_click/` |
| `ui_cancel` | placement or a fish selection is cancelled | `assets/audio/ui_cancel/` |
| `ui_denied` | an invalid placement is clicked | `assets/audio/ui_denied/` |
| `fish_select` | a fish is clicked to control it | `assets/audio/fish_select/` |
| `fish_order` | a selected fish is sent somewhere | `assets/audio/fish_order/` |
| `fish_eat` | a fish eats an algae | `assets/audio/fish_eat/` |
| `turtle_eat` | the turtle eats an algae (lower pitch) | `assets/audio/turtle_eat/` |
| `eggs_laid` | a fish fertilizes a nest | `assets/audio/eggs_laid/` |
| `eggs_hatched` | nest eggs hatch into juveniles | `assets/audio/eggs_hatched/` |
| `eggs_died` | nest eggs die from heat or CO2 | `assets/audio/eggs_died/` |
| `fish_matured` | a juvenile becomes an adult | `assets/audio/fish_matured/` |
| `fish_died` | a fish starves | `assets/audio/fish_died/` |
| `coral_hit` | a coral takes damage | `assets/audio/coral_hit/` |
| `coral_destroyed` | a coral suffocates and crumbles | `assets/audio/coral_destroyed/` |
| `algae_spread` | an algae expands to a new cell | `assets/audio/algae_spread/` |
| `predator_arrive` | a predator enters the island | `assets/audio/predator_arrive/` |
| `predator_leave` | a sated or scared predator swims away | `assets/audio/predator_leave/` |
| `bag_arrive` / `co2_arrive` | a bag or CO2 cloud drifts into view | `assets/audio/bag_arrive/`, `assets/audio/co2_arrive/` |
| `threat_impact` | a bag or CO2 cloud hits something | `assets/audio/threat_impact/` |
| `turtle_arrive` | the sea turtle arrives to help | `assets/audio/turtle_arrive/` |
| `turtle_ram` | the turtle rams the predator away | `assets/audio/turtle_ram/` |
| `collapse_warning` / `collapse_cancelled` | a population collapse countdown starts / is cancelled | `assets/audio/collapse_warning/`, `assets/audio/collapse_cancelled/` |

The new takes were sourced as CC0 previews from Freesound; see
`assets/audio/SFX_SOURCES.md` for the original sound pages.

## Levels

All levels are in **dB**: `0.0` is unmodified, `-6.0` is half as loud, positive
values boost, `-80.0` and below is silent. `effects_gain_db` is the global effects
level and is added to every event; each event's `gain_db` then balances it
against the others. The quiet effect takes (peaking around -10 dBFS) rely on
`effects_gain_db` (currently `2.0` in `data/audio_settings.tres`) to sit under
the music.

The current tuning lives in `data/audio_settings.tres` — run `tools/audio.sh` to
see the resolved values without opening the game.

## Pitch

`pitch` is a speed multiplier (`0.5` an octave down, `2.0` an octave up; pitch and
speed move together). `pitch_jitter` adds a random ± spread on every play, handy
for sounds that repeat a lot — `0.0` keeps the pitch fixed. The repeated effects
use small spreads (0.03–0.06) so they do not sound identical every time.

## Filters

`high_pass_hz` removes the frequencies **below** the cutoff, `low_pass_hz` removes
the ones **above** it; `0.0` switches that filter off. They are plain frequencies
in Hz, e.g. `250.0` is a gentle high-pass that thins the low end of a thud and
`4000.0` is a low-pass that muffles a sound.

Each event plays on its own audio bus (`Sfx_<event>`), routed through the
`Effects` bus to Master, so its filters never affect the other sounds; the music
has its own `Music` bus. The in-game settings menu (title screen and pause)
controls the volume of the `Music` and `Effects` groups; those user levels are
saved in `user://settings.cfg` and are separate from the designer levels above.
The buses are created at startup from the settings — nothing to set up by hand
in the Audio panel.

The placement sound is the one that ships with a filter (a gentle high-pass, so
it cuts less through the music).

While the pause menu is open, the `Music` bus is routed through `PauseFilter`, a
dedicated bus with a low-pass at `pause_music_low_pass_hz` (`0.0` disables it).
It eases in/out over `pause_filter_fade_seconds`, so pausing sounds like the reef
slipping underwater. The filter is driven by the pause button, not by
`get_tree().paused`: the game-over outro keeps playing clearly. Effects and UI
clicks are not filtered.

## Placement sounds

Placing an item reports its kind, and the sound is `placement_<kind>` (kind is
`coral`, `algae` or `nest`). When that event has no takes, the generic
`placement` (the coral takes) is used instead:

| Placed item | Event | Files |
|---|---|---|
| nest | `placement_nest` | `assets/audio/nido/` |
| algae | `placement_algae` | `assets/audio/alga/` |
| coral | `placement` | `assets/audio/corallo/` |

Giving another kind its own sound needs no code: add e.g. `placement_algae` to
`AudioEvents.TAKES` with its files and an `AudioEvent` entry in the settings.

## Adding a sound

1. Drop the `.wav` file(s) under a folder in `assets/audio/`, e.g.
   `assets/audio/busta/b1.wav`. More than one file in an event means a random
   one is played each time. Let Godot import them (open the editor once, or run
   `tools/smoke.sh`, which imports automatically).
2. Add the event to `AudioEvents.TAKES` in `core/audio_events.gd`:
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
5. Run `tools/test.sh` and `tools/smoke.sh`, or `tools/audio.sh` to print what the
   game actually resolves (track, gain, pitch, filters, takes found).

## Music

The title screen loops `intro_track` at `intro_gain_db` on the Music bus (the
`.wav.import` must loop; the file's embedded loop point is used). Pressing Play
stops it and starts the run's loop; without an intro track the loop starts
immediately.

The run's music is built from stems in `assets/audio/game_loop/`: two drum takes,
two half-arp takes and two full-arp takes. All six start together and loop in
sync — they share one loop point (`edit/loop_end = 384872` frames = 8.73 s, 4 bars
at 110 BPM in each `.import`), so the arrangement switches purely by fading
volumes:

- the two drum takes **alternate at every loop**;
- the arp is silent with no hostiles, plays **half** with 1-5 hostiles and
  **full** from 6 on (`arp_full_hostiles`), picking one of its two takes at
  random each loop;
- the arp fades in/out over `music_fade_seconds`, the drums crossfade over
  `drum_fade_seconds`.

Hostiles are everything in `Groups.THREATS` (CO2 clouds, plastic bags, cyclones
and predators). Stems, `drums_gain_db` / `arp_gain_db` and `music_gain_db` live
in `data/audio_settings.tres`. Assigning no stems makes the game fall back to
the single looping `music_track`.

Losing the run stops the stems and plays `outro_track` once on the same Music bus
(level `outro_gain_db`; it must not loop).
