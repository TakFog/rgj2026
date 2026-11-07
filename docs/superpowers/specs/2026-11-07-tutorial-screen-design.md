# Tutorial screen — design

## Intent

A short animated screen between the main menu and the run that teaches how the
reef reacts, using the game's own art and oblique view. It replaces equations
("fish + nest = eggs") with looping vignettes, because the game has no combine
action: the relationships happen on their own.

## What the player sees

A full-screen sea card titled **COME FUNZIONA IL REEF**: a stage in the middle,
one caption under it, three progress dots and the buttons. The stage plays three
6-second loops in sequence and wraps around:

1. **Nest** — an adult fish swims onto the empty nest; the nest becomes eggs; a
   clock ring sweeps the wait; two juveniles pop out and swim apart.
2. **Algae + CO2** — a CO2 cloud drifts in, touches an alga, dissolves; the alga
   pulses and a second alga sprouts in the adjacent cell.
3. **Algae + coral** — an alga leans onto a coral cell; the coral flashes red and
   its oxygen bar drops.

Captions (Italian, one line each):

1. "Il pesce adulto feconda il nido: dalle uova nascono due piccoli."
2. "La CO2 tocca l'alga, viene assorbita, e l'alga si espande."
3. "L'alga che cresce sul corallo gli toglie ossigeno."

## Goals

- Teach the three most important reactions without text equations.
- Look like the real game: same textures, same oblique projection, same algae
  sway shader (including the designer's new algae sprite), same seabed shader.
- Never touch the simulation: no entities, no grid, no population counts, no
  score. The run stays paused behind the screen.
- Reachable automatically on the first run, and on demand from the menu.
- Skip at any time; never mandatory for a returning player.
- Web-safe: no video, no extra threads, no new art.

## Non-goals

- No crafting or combine button, and no hint that elements are manually mixed.
- No interactive practice mode, no tutorial level, no placement/fish-order lesson.
- No new art, video files, voice-over or music.
- No new feature flag: this is UI, not gameplay balance.
- No sound effects in v1; the intro music keeps playing.

## Anti-goals

- A screen that mutates `Game`, the run's pause state, or the HUD visibility by
  accident.
- Showing a mechanic that does not exist in the game.
- Making a player who already knows the game sit through it again.

## Approaches considered

1. **Scripted vignettes on a mini-stage.** One overlay with its own sprites,
   animated by tweens, using the real textures and projection. Deterministic, no
   simulation, web-safe, stays correct if balance numbers change. **Chosen.**
2. **Pre-recorded clips.** Exact look, little code, but Godot plays Ogg Theora
   rather than the mp4s in `video/`, files grow the web build, and every art or
   balance change needs a re-record.
3. **Live demo in the actual reef.** Reuse Level01 and drive real entities behind
   a letterbox. Maximum authenticity, but it mutates the run, fights the
   population monitor, scoring and pause, and needs a sandbox world.

## Decided by the designer

- Show animations instead of sums.
- Use the real-game look, not an infographic.
- Build it as scripted vignettes (approach 1).

## Calls made by the builder

- Show automatically only on the first run; add a **Come si gioca** button to the
  menu so it can always be reviewed.
- Remember "seen" in `user://settings.cfg` (same file as the audio preferences).
  Mark it seen when the run actually starts (Inizia or Salta), not when the
  screen opens.
- Three vignettes, 6 s each, auto-advance and loop. Space advances, Esc or right
  click skips (START) / goes back (REVIEW).
- Two modes: **START** (from Play, buttons Salta / Inizia) and **REVIEW** (from
  the menu, button Indietro). Salta and Inizia both start the run.
- Keep captions short and Italian, matching the rest of the UI. No `+`, `=` or
  arrows on screen.
- The tutorial stays silent; existing `ui_click` is reused for its buttons.
- No debug-overlay entry; there is nothing gameplay-related to toggle.

## How it works

### Flow

`MainMenuScreen` gets two new signals: `play_requested` (Play clicked) and
`tutorial_requested` (Come si gioca clicked). Its existing `play_pressed`
keeps its current meaning: *start the run now* (used by the restart path).

- `hide_for_tutorial()`: hides the menu root and panels, leaves the tree paused.
- `close()` stays as today (hide, show gameplay HUD, unpause).
- `open()` stays as today (show, hide gameplay HUD, pause).
- New **Come si gioca** button below **Impostazioni**, same style.

`DevBSystems` sequences the front end:

| Event | Result |
|---|---|
| Play, tutorial unseen | `main_menu.hide_for_tutorial()` → `tutorial.open(START)` |
| Play, tutorial seen | `main_menu.close()` → start game music |
| Come si gioca | `main_menu.hide_for_tutorial()` → `tutorial.open(REVIEW)` |
| Tutorial → Inizia / Salta | mark seen → `tutorial.close()` → `main_menu.close()` → start game music |
| Tutorial → Indietro (REVIEW) | `tutorial.close()` → `main_menu.open()` |
| Restart (pause menu / game over) | unchanged: `_start_without_menu()` skips menu and tutorial |

The tutorial never changes `get_tree().paused`; `main_menu.close()` is the only
thing that unpauses. The tutorial node runs with `PROCESS_MODE_ALWAYS` so its
tweens and timers animate while the tree is paused, exactly like the menu.

While visible, the tutorial consumes the pause action (like `MainMenuScreen`
already does) so Space advances the vignette instead of reaching
`PauseController`. Right click and Esc behave as cancel; the pause action is
swallowed in both modes.

### Screen structure

`ui/b_tutorial_screen.gd` builds:

```
ColorRect (full rect, Color(0.02, 0.05, 0.1, 0.92), PROCESS_MODE_ALWAYS)
└ CenterContainer
  └ PanelContainer (SeaStyle.panel_box, about 900 px wide)
    └ VBoxContainer
      ├ Label "COME FUNZIONA IL REEF" (sand, 34)
      ├ TutorialStage (about 820 × 340)
      ├ Label caption (22, centred, reserved height)
      ├ HBoxContainer: three dots
      └ HBoxContainer: Salta / Inizia, or Indietro
```

`ui/b_tutorial_stage.gd` draws the stage:

- Background: a `ColorRect` using `main/seabed.gdshader`, with
  `to_world_x = (1, 0)` and `to_world_y = (1, 2)` so the caustics lie on the same
  oblique plane as the game. The card's rim frames it; no clipping is needed
  because sprites are kept inside and fade at the edges.
- Sprites: a child `Node2D` layer positioned with a local `ViewProjection` whose
  `x_axis`/`y_axis` come from `Game.VIEW_SETTINGS`; one cell is about 56 px.
  Textures are the game's own (`fish.png`, `nest_empty/eggs.png`,
  `coral.png`/`coral_base.png`), and the CO2 cloud is the real `Co2Bubbles`
  node (fizzy nebula) with its `vanish()` dissolve. The alga uses
  `Algae.TEXTURE`, `Algae.SPRITE_TINT` and a `ShaderMaterial` on
  `entities/algae/algae_sway.gdshader` with a per-sprite `phase`, so it sways
  like in the run.
- Steps: each step builds its own sprites on entry and frees them on exit;
  `show_step(index)` kills the previous tween, clears the layer and starts the
  new chain. Sprite heights follow the game ratios (algae 1.6 cells, nest 0.9,
  fish about 0.7) so the silhouettes read the same.
- Auto-advance is accumulated in `_process` (`PROCESS_MODE_ALWAYS`) by the
  screen, not by timers, so advancing and skipping cannot race an old animation.

`core/tutorial_sequence.gd` is the pure part: the ordered captions, the current
index, `advance()`, `reset()` and wrap-around. It is unit tested without a scene.

### Persistence

`core/user_settings.gd` gains `tutorial_seen(path := PATH)` and
`mark_tutorial_seen(path := PATH)`, stored as section `tutorial`, key `seen` in
the existing `ConfigFile`. Both use the optional path so tests can use a temp
file; the default keeps production behaviour. Saving only touches the tutorial
key, so the audio section survives (as `save()` already preserves other
sections).

### Audio

`systems/b_audio.gd` connects the tutorial's `button_pressed` signal to the same
`ui_click` take the menu uses. The vignettes themselves are silent.

## Files

New:

- `core/tutorial_sequence.gd`
- `ui/b_tutorial_screen.gd`
- `ui/b_tutorial_stage.gd`
- `tests/unit/test_tutorial_sequence.gd`
- `tests/unit/test_user_settings.gd`

Edited:

- `core/user_settings.gd` (seen flag)
- `ui/b_main_menu.gd` (signals, hide-for-tutorial, Come si gioca button)
- `main/dev_b_systems.gd` (menu/tutorial sequencing)
- `systems/b_audio.gd` (button click)
- `docs/GDD.md` §9 (one line: the tutorial exists)

Untouched: `project.godot`, `export_presets.cfg`, and every gameplay entity,
system and balance value.

## Verification

- Unit: sequence wraps after the last step, `reset()` returns to step 0, every
  caption is non-empty; `UserSettings` round-trips the seen flag on a temp path
  and leaves an existing audio section intact.
- `tools/test.sh` and `tools/smoke.sh`.
- Manual checklist:
  - First run: Play shows the tutorial; the reef behind is paused and the HUD is
    hidden; the game music has not started.
  - Inizia and Salta both start the run, unpause, show the HUD and start the game
    music exactly once.
  - Second run: Play goes straight to the game.
  - **Come si gioca** reopens it from the menu; Indietro returns to the menu,
    still paused.
  - Space advances, Esc/right click skips or goes back; the pause menu never
    opens underneath.
  - Restart from pause and game over skips the tutorial.
  - The alga sways in the tutorial exactly like on the reef.
