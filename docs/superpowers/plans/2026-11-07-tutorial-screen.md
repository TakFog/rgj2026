# Tutorial Screen Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Show a short, animated, real-game-looking tutorial between Play and the run, teaching three reef reactions without equations.

**Architecture:** A new skipped-on-return overlay (`TutorialScreen`) owns a `TutorialStage` that draws hand-animated vignettes with the game's own textures and oblique projection. A pure `TutorialSequence` holds the captions/order. `MainMenuScreen` and `DevBSystems` sequence menu → tutorial → run, with the run paused throughout and a `seen` flag in `UserSettings`.

**Tech Stack:** Godot 4.7.2, GDScript, Compatibility renderer, existing `SeaStyle`, `ViewProjection`, entity textures, `Co2Bubbles`, `algae_sway.gdshader`, `Tween`, custom headless test runner.

**Spec:** `docs/superpowers/specs/2026-11-07-tutorial-screen-design.md`

## Global Constraints

- Godot **4.7.2**, GDScript, **Compatibility** renderer; web build is single-threaded.
- All in-game UI copy is **Italian**; commit messages and PR text are **English**.
- Never stage `project.godot` or `export_presets.cfg`; stage files by explicit path.
- No new art, video, audio files or balance values.
- The tutorial must not create entities, touch `Game.grid`, add gameplay groups, change population counts, score or the HUD; only the menu/tutorial flow may change `get_tree().paused`.
- Game stays paused while menu/tutorial are visible; tutorial nodes use `PROCESS_MODE_ALWAYS`.
- Use existing art: `fish.png`, `nest_empty.png`, `nest_eggs.png`, `coral.png`, `coral_base.png`, `algae.png` (+ `algae_sway.gdshader`), `Co2Bubbles`.
- Run `tools/test.sh` and `tools/smoke.sh` before the branch is merged.

## Review Focus

1. **Space/Esc while the tutorial is visible:** Space must advance the vignette; Esc/right click must skip (START) or go back (REVIEW). Neither may unpause the run or open the pause overlay. Pinned by `test_tutorial_screen.gd::test_input_mapping` and the manual checklist.
2. **Seen flag:** after the first run starts, Play must go straight to the game, and Restart must never show the tutorial. Pinned by `test_user_settings.gd` and manual checks.
3. **Review mode:** “Come si gioca” must only close back to the menu; it must never start the run. Pinned by `test_tutorial_screen.gd::test_review_mode_only_goes_back`.
4. **Start transition:** starting the run must show the HUD and start game music exactly once, from both Inizia and Salta. Covered by the manual checklist (needs the live scene).
5. **Isolation:** the stage's visuals must not join `corals`/`algae`/`fish`/`nests`/`threats` groups or register in the grid. Pinned by `test_tutorial_stage.gd::test_stage_does_not_join_gameplay_groups`.

---

### Task 1: Remember that the tutorial was seen

**Files:**
- Modify: `core/user_settings.gd`
- Test: `tests/unit/test_user_settings.gd`

**Interfaces:**
- Consumes: existing `UserSettings.PATH`, `SECTION`, `MUSIC_KEY`, `EFFECTS_KEY`.
- Produces: `UserSettings.tutorial_seen(path := PATH) -> bool`, `UserSettings.mark_tutorial_seen(path := PATH) -> void`; `TUTORIAL_SECTION := "tutorial"`, `TUTORIAL_KEY := "seen"`.

- [ ] **Step 1: Write the failing test**

```gdscript
extends TestCase

const TEST_PATH := "user://test_settings.cfg"


func before_each() -> void:
	_delete_test_file()


func _delete_test_file() -> void:
	if FileAccess.file_exists(TEST_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_PATH))


func test_tutorial_is_unseen_by_default() -> void:
	assert_false(UserSettings.tutorial_seen(TEST_PATH))
	_delete_test_file()


func test_mark_tutorial_seen_round_trips() -> void:
	UserSettings.mark_tutorial_seen(TEST_PATH)
	assert_true(UserSettings.tutorial_seen(TEST_PATH))
	_delete_test_file()


func test_marking_seen_keeps_the_audio_section() -> void:
	var config := ConfigFile.new()
	config.set_value(UserSettings.SECTION, UserSettings.MUSIC_KEY, -12.0)
	config.set_value(UserSettings.SECTION, UserSettings.EFFECTS_KEY, -4.0)
	assert_eq(config.save(TEST_PATH), OK)

	UserSettings.mark_tutorial_seen(TEST_PATH)

	var reloaded := ConfigFile.new()
	assert_eq(reloaded.load(TEST_PATH), OK)
	assert_almost(float(reloaded.get_value(UserSettings.SECTION, UserSettings.MUSIC_KEY, 0.0)), -12.0)
	assert_almost(float(reloaded.get_value(UserSettings.SECTION, UserSettings.EFFECTS_KEY, 0.0)), -4.0)
	_delete_test_file()
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `tools/test.sh`
Expected: FAIL/parse error mentioning `tutorial_seen` (the functions do not exist yet).

- [ ] **Step 3: Implement the seen flag in `core/user_settings.gd`**

Add the two constants next to `PATH`/`SECTION`, and these functions after `load_and_apply()`:

```gdscript
const TUTORIAL_SECTION := "tutorial"
const TUTORIAL_KEY := "seen"


static func tutorial_seen(path := PATH) -> bool:
	var config := ConfigFile.new()
	if config.load(path) != OK:
		return false
	return bool(config.get_value(TUTORIAL_SECTION, TUTORIAL_KEY, false))


static func mark_tutorial_seen(path := PATH) -> void:
	var config := ConfigFile.new()
	config.load(path)
	config.set_value(TUTORIAL_SECTION, TUTORIAL_KEY, true)
	config.save(path)
```

Loading an existing file and setting one key preserves every other section, including `[audio]`.

- [ ] **Step 4: Run the test to verify it passes**

Run: `tools/test.sh`
Expected: PASS, no failures.

- [ ] **Step 5: Commit**

```bash
git add core/user_settings.gd tests/unit/test_user_settings.gd
git commit -m "feat: remember whether the tutorial was seen"
```

---

### Task 2: Tutorial step sequence

**Files:**
- Create: `core/tutorial_sequence.gd`
- Test: `tests/unit/test_tutorial_sequence.gd`

**Interfaces:**
- Produces: `TutorialSequence` (`RefCounted`) with `const CAPTIONS: Array[String]`, `var index: int`, `count() -> int`, `caption() -> String`, `advance() -> void`, `reset() -> void`.

- [ ] **Step 1: Write the failing test**

```gdscript
extends TestCase


func test_starts_on_the_first_caption() -> void:
	var sequence := TutorialSequence.new()
	assert_eq(sequence.index, 0)
	assert_eq(sequence.caption(), TutorialSequence.CAPTIONS[0])


func test_advances_and_wraps() -> void:
	var sequence := TutorialSequence.new()
	sequence.advance()
	assert_eq(sequence.index, 1)
	sequence.advance()
	assert_eq(sequence.index, 2)
	sequence.advance()
	assert_eq(sequence.index, 0, "wraps after the last step")


func test_reset_returns_to_the_first_caption() -> void:
	var sequence := TutorialSequence.new()
	sequence.advance()
	sequence.reset()
	assert_eq(sequence.index, 0)


func test_every_caption_is_present() -> void:
	var sequence := TutorialSequence.new()
	assert_eq(sequence.count(), 3)
	for i in sequence.count():
		assert_false(sequence.caption().is_empty(), "caption %d is empty" % i)
		sequence.advance()
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `tools/test.sh`
Expected: FAIL/parse error mentioning `TutorialSequence`.

- [ ] **Step 3: Implement `core/tutorial_sequence.gd`**

```gdscript
class_name TutorialSequence
extends RefCounted
## Ordered tutorial vignettes. Pure data/state so it is testable headless;
## TutorialStage draws them and TutorialScreen advances them.

const CAPTIONS: Array[String] = [
	"Il pesce adulto feconda il nido: dalle uova nascono due piccoli.",
	"La CO2 tocca l'alga, viene assorbita, e l'alga si espande.",
	"L'alga che cresce sul corallo gli toglie ossigeno.",
]

var index := 0


func count() -> int:
	return CAPTIONS.size()


func caption() -> String:
	return CAPTIONS[index]


func advance() -> void:
	index = (index + 1) % CAPTIONS.size()


func reset() -> void:
	index = 0
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `tools/test.sh`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add core/tutorial_sequence.gd tests/unit/test_tutorial_sequence.gd
git commit -m "feat: add the tutorial step sequence"
```

---

### Task 3: Animated mini-stage

**Files:**
- Create: `ui/b_tutorial_stage.gd`
- Test: `tests/unit/test_tutorial_stage.gd`

**Interfaces:**
- Consumes: `TutorialSequence.CAPTIONS`, `ViewProjection`, `FishVisual`, `Co2Bubbles`, `Algae.TEXTURE`, `Algae.SPRITE_TINT`, `Algae.SWAY_SHADER`, `Nest.EMPTY_TEXTURE`/`EGGS_TEXTURE`, `Coral.BASE_TEXTURE`/`CORAL_TEXTURE`/`CORAL_HEALTHY_TINT`.
- Produces: `TutorialStage` (`Control`) with constructor `_init(x_axis := Vector2(1, 0), y_axis := Vector2(-0.5, 0.5))`, `show_step(index: int) -> void`, `stop() -> void`, `sprite_count() -> int`, `visual_nodes() -> Array[Node]`.

- [ ] **Step 1: Write the failing test**

```gdscript
extends TestCase


func test_every_step_builds_visuals() -> void:
	var stage := TutorialStage.new()
	for i in TutorialSequence.CAPTIONS.size():
		stage.show_step(i)
		assert_true(stage.sprite_count() > 0, "step %d has no visuals" % i)
	stage.stop()
	assert_eq(stage.sprite_count(), 0)


func test_rebuilding_a_step_does_not_stack_visuals() -> void:
	var stage := TutorialStage.new()
	stage.show_step(0)
	var first := stage.sprite_count()
	stage.show_step(0)
	assert_eq(stage.sprite_count(), first, "show_step must clear before rebuilding")


func test_stage_does_not_join_gameplay_groups() -> void:
	var stage := TutorialStage.new()
	stage.show_step(2)
	for node in stage.visual_nodes():
		for group in [Groups.FISH, Groups.NESTS, Groups.CORALS, Groups.ALGAE, Groups.THREATS]:
			assert_false(node.is_in_group(group), "%s joined %s" % [node.name, group])
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `tools/test.sh`
Expected: FAIL/parse error mentioning `TutorialStage`.

- [ ] **Step 3: Implement the stage shell and all three vignettes in `ui/b_tutorial_stage.gd`**

The file declares `class_name TutorialStage`, `extends Control`, and:

```gdscript
const CELL_PX := 56.0
const STAGE_SIZE := Vector2(820, 340)
const NEST_HEIGHT := 110.0
const ALGAE_HEIGHT := 90.0
const CORAL_HEIGHT := 120.0

var _projection: ViewProjection
var _layer: Node2D
var _tween: Tween
```

Constructor: set `custom_minimum_size = STAGE_SIZE`, `size_flags_horizontal = Control.SIZE_EXPAND_FILL`, `mouse_filter = Control.MOUSE_FILTER_IGNORE`, and `_projection = ViewProjection.new(x_axis, y_axis, CELL_PX)`.

`_ready()`: add a `ColorRect` with `color = Color8(100, 96, 70)` (sandy water), full-rect anchors, `mouse_filter = IGNORE`, and a `ShaderMaterial` on `res://main/seabed.gdshader` with `to_world_x = Vector2(1, 0)`, `to_world_y = Vector2(1, 2)`, `tint_amount = 0.35`, `vignette_strength = 0.4`. The stage is inside the screen's sea card, so it needs no clipping.

`_visual_layer()` lazily creates `_layer` (`Node2D`, `name = "Visuals"`, `y_sort_enabled = true`) and adds it. `visual_nodes()` returns `_layer.get_children()` (empty when there is no layer). `sprite_count()` returns the same size.

`show_step(index)`:
1. `_clear()` — kill `_tween` if valid; if `_layer` exists, `for child in _layer.get_children(): child.free()` (immediate, not `queue_free()`, so tests see an empty stage).
2. `match index`: `0: _build_nest()`, `1: _build_co2()`, `2: _build_coral()`.
3. `_animate(index)` — starts the step's tween, but only if `is_inside_tree()` (tests build visuals without a tree).

`stop()` calls `_clear()`.

Positions: `_pos(cell: Vector2) -> Vector2` returns `Vector2(size.x * 0.5, size.y * 0.72) + _projection.to_screen(cell) - _projection.to_screen(Vector2.ZERO)`. Cell coordinates are the storyboard space (x right, y depth).

Helpers:
- `_sprite(texture, height_px, cell, tint := Color.WHITE) -> Sprite2D`: set texture, `scale = Vector2.ONE * height_px / texture.get_height()`, `position = _pos(cell)`, `offset = Vector2(0, -texture.get_height() * 0.45)`, `modulate = tint`; add to `_visual_layer()`.
- `_fit(sprite, texture, height_px)`: swap the texture and recompute scale/offset (used when the nest becomes eggs).
- `_fish(cell, adult, heading) -> FishVisual`: `radius_world = 15.0`, `adult`, `heading`, `position = _pos(cell)`, `z_index = 10`; add to layer.
- `_algae(cell) -> Sprite2D`: `_sprite(Algae.TEXTURE, ALGAE_HEIGHT, cell, Algae.SPRITE_TINT)` plus a `ShaderMaterial` on `Algae.SWAY_SHADER` with a per-sprite `phase` (use the cell's `x * 0.73 + y * 1.21`).
- `_co2(cell) -> Co2Bubbles`: `radius_px = 55.0`, `tint = Color.WHITE`, `position = _pos(cell)`, `z_index = 20`; add to layer.
- `_coral(cell)`: base sprite then coral sprite at the same cell; coral tint `Coral.CORAL_HEALTHY_TINT`.
- Inner `ClockRing extends Node2D`: `var ratio := 0.0` with a setter that calls `queue_redraw()`; `_draw()` draws an arc of radius 34 px from `-PI/2` through `TAU * ratio` in sand `Color(1.0, 0.76, 0.16, 0.9)`, width 3.
- Inner `OxygenBar extends Control`: `var ratio := 1.0` with a setter that updates the fill width; two `ColorRect`s, a 44 × 6 dark back and a 44 × 6 aqua fill scaled by `ratio`; `position` just above the coral.

The three vignettes (all tweens use `_start_tween()`, which returns `null` outside the tree):

1. **Nest** — nest at `(5.0, 2.0)` (empty), adult fish at `(1.2, 2.7)`.
   - 0.2 s delay, 1.6 s: fish `position` to `_pos(5.0, 2.0)`.
   - At 1.8 s: `_fit(nest, Nest.EGGS_TEXTURE, NEST_HEIGHT)`, pop the nest scale to 1.08 and back; add `ClockRing` at the nest and tween `ratio` 0 → 1 over 1.6 s.
   - At 3.4 s: add two `_fish(5.0, 2.0, false, ...)` juveniles with headings left/right and tween them to `(3.8, 1.5)` and `(6.2, 1.5)` over 1.4 s.
   - At 5.2 s: fade every visual's `modulate:a` to 0 over 0.5 s.
2. **Algae + CO2** — algae at `(3.0, 2.2)`, CO2 at `(0.0, 1.6)`.
   - 0.2 s delay, 1.8 s: CO2 `position` to `_pos(3.0, 2.2)`.
   - At 2.0 s: call `co2.vanish()`; pulse the algae scale to 1.1 and back; add a second `_algae(4.0, 2.2)` with `scale = Vector2.ZERO` and tween it to `Vector2.ONE` over 0.5 s with `TRANS_BACK`/`EASE_OUT`.
   - Fade at 5.2 s.
3. **Algae + coral** — coral at `(5.0, 2.2)`, algae at `(3.2, 2.2)`, a ghost algae at `(4.0, 2.2)` starting at `scale = Vector2.ZERO`; `OxygenBar` above the coral.
   - 0.4 s delay, 0.6 s: ghost algae scale to `Vector2.ONE` (the spread attempt).
   - At 1.0 s: ghost algae fades/shrinks back to zero (the coral blocks it); coral sprite `modulate` flashes to `Color(2.0, 0.6, 0.6)` and back over 0.6 s; `OxygenBar.ratio` 1.0 → 0.8 over 0.4 s.
   - Fade at 5.2 s.

`_animate(index)` creates one `Tween` with `set_parallel(true)` and uses `set_delay()` for the offsets above. Do not loop inside the stage; the screen advances every 6 s.

- [ ] **Step 4: Run the test to verify it passes**

Run: `tools/test.sh`
Expected: PASS; all three steps build visuals and leave no gameplay groups.

- [ ] **Step 5: Commit**

```bash
git add ui/b_tutorial_stage.gd tests/unit/test_tutorial_stage.gd
git commit -m "feat: animate the tutorial mini-reef"
```

---

### Task 4: Tutorial overlay

**Files:**
- Create: `ui/b_tutorial_screen.gd`
- Test: `tests/unit/test_tutorial_screen.gd`

**Interfaces:**
- Consumes: `TutorialSequence`, `TutorialStage`, `SeaStyle`.
- Produces: `TutorialScreen` (`ColorRect`) with `enum Mode { START, REVIEW }`, `enum InputAction { NONE, NEXT, PRIMARY }`, signals `run_started`, `closed`, `button_pressed`, `open(mode: Mode) -> void`, `close() -> void`, static `primary_label(mode: Mode) -> String`, `skip_visible(mode: Mode) -> bool`, `starts_run(mode: Mode) -> bool`, `action_for(is_cancel: bool, is_pause: bool) -> InputAction`.

- [ ] **Step 1: Write the failing test**

```gdscript
extends TestCase


func test_start_mode_offers_start_and_skip() -> void:
	assert_eq(TutorialScreen.primary_label(TutorialScreen.Mode.START), "Inizia")
	assert_true(TutorialScreen.skip_visible(TutorialScreen.Mode.START))
	assert_true(TutorialScreen.starts_run(TutorialScreen.Mode.START))


func test_review_mode_only_goes_back() -> void:
	assert_eq(TutorialScreen.primary_label(TutorialScreen.Mode.REVIEW), "Indietro")
	assert_false(TutorialScreen.skip_visible(TutorialScreen.Mode.REVIEW))
	assert_false(TutorialScreen.starts_run(TutorialScreen.Mode.REVIEW))


func test_input_mapping() -> void:
	assert_eq(TutorialScreen.action_for(true, true), TutorialScreen.InputAction.PRIMARY)
	assert_eq(TutorialScreen.action_for(false, true), TutorialScreen.InputAction.NEXT)
	assert_eq(TutorialScreen.action_for(false, false), TutorialScreen.InputAction.NONE)
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `tools/test.sh`
Expected: FAIL/parse error mentioning `TutorialScreen`.

- [ ] **Step 3: Implement `ui/b_tutorial_screen.gd`**

`_ready()`:
- `process_mode = Node.PROCESS_MODE_ALWAYS`, `visible = false`, `mouse_filter = STOP`, full-rect anchors, `color = Color(0.02, 0.05, 0.1, 0.94)`.
- `_sequence = TutorialSequence.new()`.
- Centered `PanelContainer` with `SeaStyle.panel_box()`; a `VBoxContainer` (`separation = 18`, `custom_minimum_size.x = 900`) inside.
- Title `"COME FUNZIONA IL REEF"`, font 34, `SeaStyle.SAND_COLOR`, centred; divider like other cards.
- `_stage = TutorialStage.new(Game.VIEW_SETTINGS.x_axis, Game.VIEW_SETTINGS.y_axis)`, added to the box.
- `_caption` Label, font 22, `SeaStyle.CAPTION_COLOR`, centered, `custom_minimum_size.y = 56`, `autowrap_mode = TextServer.AUTOWRAP_WORD_SMART`.
- Dots: `_dots: Array[Panel]` with one 10 × 10 panel per `_sequence.count()`, style `StyleBoxFlat` corner radius 5, active `SeaStyle.SAND_COLOR`, inactive `Color(SeaStyle.RIM_COLOR, 0.35)`, in a centred `HBoxContainer`.
- Buttons in a centred `HBoxContainer` (`separation = 16`): `_skip` ("Salta", secondary) and `_primary` (highlighted), both 180 × 60, font 24, wired to `_on_skip_pressed` / `_on_primary_pressed`.

Static helpers:

```gdscript
enum Mode { START, REVIEW }
enum InputAction { NONE, NEXT, PRIMARY }

static func primary_label(mode: Mode) -> String:
	return "Inizia" if mode == Mode.START else "Indietro"


static func skip_visible(mode: Mode) -> bool:
	return mode == Mode.START


static func starts_run(mode: Mode) -> bool:
	return mode == Mode.START


static func action_for(is_cancel: bool, is_pause: bool) -> InputAction:
	if is_cancel:
		return InputAction.PRIMARY
	if is_pause:
		return InputAction.NEXT
	return InputAction.NONE
```

`open(mode)`:
- `_mode = mode`, `_sequence.reset()`, `_elapsed = 0`, `visible = true`.
- Set `_skip.visible = skip_visible(mode)`, `_primary.text = primary_label(mode)`, then `_show_current()`.

`close()`: `visible = false`, `_stage.stop()`.

`_process(delta)`: if not visible return; `_elapsed += delta`; when `_elapsed >= SECONDS_PER_STEP` (`6.0`), call `_next_step()`.

`_next_step()`: `_sequence.advance(); _elapsed = 0.0; _show_current()`.

`_show_current()`: `_stage.show_step(_sequence.index)`, `_caption.text = _sequence.caption()`, recolour the dots by `_sequence.index`.

`_on_primary_pressed()`: `button_pressed.emit()`; emit `run_started` when `starts_run(_mode)`, else `closed`.
`_on_skip_pressed()`: `button_pressed.emit()`; `run_started.emit()` (the button only exists in START).

`_unhandled_input(event)`:
```gdscript
if not visible:
	return
match action_for(event.is_action_pressed(InputActions.CANCEL), event.is_action_pressed(InputActions.PAUSE)):
	InputAction.PRIMARY:
		get_viewport().set_input_as_handled()
		_on_primary_pressed()
	InputAction.NEXT:
		get_viewport().set_input_as_handled()
		_next_step()
```
Esc maps to both CANCEL and PAUSE; the cancel case is checked first, so Esc goes back/skips, Space advances.

- [ ] **Step 4: Run the test to verify it passes**

Run: `tools/test.sh`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add ui/b_tutorial_screen.gd tests/unit/test_tutorial_screen.gd
git commit -m "feat: add the tutorial overlay"
```

---

### Task 5: Menu and front-end flow

**Files:**
- Modify: `ui/b_main_menu.gd`
- Modify: `main/dev_b_systems.gd`
- Modify: `systems/b_audio.gd`

**Interfaces:**
- Consumes: `TutorialScreen` (Task 4), `UserSettings.tutorial_seen()` / `mark_tutorial_seen()` (Task 1).
- Produces: `MainMenuScreen.play_requested`, `MainMenuScreen.tutorial_requested`, `MainMenuScreen.hide_for_tutorial()`; `DevBSystems` keeps the existing `play_pressed` meaning “start the run now”.

- [ ] **Step 1: Add the menu signals, button and hide method**

In `ui/b_main_menu.gd`:

```gdscript
## Play was pressed: the front end shows the tutorial, then starts the run.
signal play_requested
## The "Come si gioca" button was pressed.
signal tutorial_requested
```

In `_build_menu_panel()`, after the Settings button, add a centred “Come si gioca” button below it:

```gdscript
var tutorial_btn := _button("Come si gioca")
tutorial_btn.add_theme_font_size_override("font_size", 22)
tutorial_btn.pressed.connect(_on_tutorial_pressed)
panel.add_child(tutorial_btn)
tutorial_btn.set_anchors_preset(Control.PRESET_CENTER)
tutorial_btn.offset_left = -BUTTON_SIZE.x * 0.5
tutorial_btn.offset_right = BUTTON_SIZE.x * 0.5
tutorial_btn.offset_top = BUTTON_SIZE.y * 1.5 + 32.0
tutorial_btn.offset_bottom = BUTTON_SIZE.y * 2.5 + 32.0
```

Replace `_on_play_pressed()` with:

```gdscript
func _on_play_pressed() -> void:
	button_pressed.emit()
	hide_for_tutorial()
	play_requested.emit()


func _on_tutorial_pressed() -> void:
	button_pressed.emit()
	hide_for_tutorial()
	tutorial_requested.emit()
```

Add next to `close()`:

```gdscript
## Play / How-to-play hides the menu but leaves the run paused for the tutorial.
func hide_for_tutorial() -> void:
	visible = false
	_settings_panel.close()
```

`_start_without_menu()` (restart) stays as it is: `close()` + deferred `play_pressed`, so restart skips the tutorial.

- [ ] **Step 2: Sequence the front end in `main/dev_b_systems.gd`**

Add the preload and members:

```gdscript
const TutorialScreen := preload("res://ui/b_tutorial_screen.gd")

var _main_menu: MainMenuScreen
var _tutorial: TutorialScreen
```

In `_setup_population_and_hud()`, connect the new menu signals and create the tutorial after the menu:

```gdscript
_main_menu = MainMenuScreen.new()
_main_menu.name = "MainMenu"
_main_menu.play_requested.connect(_on_play_requested)
_main_menu.tutorial_requested.connect(_on_tutorial_requested)
_main_menu.play_pressed.connect(_on_run_started)
_main_menu.exit_pressed.connect(_on_exit_pressed)
Game.ui.add_child(_main_menu)

_tutorial = TutorialScreen.new()
_tutorial.name = "Tutorial"
_tutorial.run_started.connect(_on_tutorial_run_started)
_tutorial.closed.connect(_on_tutorial_closed)
Game.ui.add_child(_tutorial)
```

Replace `_on_play_pressed()` with:

```gdscript
func _on_play_requested() -> void:
	if UserSettings.tutorial_seen():
		_main_menu.close()
		_start_game_music()
	else:
		_main_menu.hide_for_tutorial()
		_tutorial.open(TutorialScreen.Mode.START)


func _on_tutorial_requested() -> void:
	_main_menu.hide_for_tutorial()
	_tutorial.open(TutorialScreen.Mode.REVIEW)


func _on_tutorial_run_started() -> void:
	UserSettings.mark_tutorial_seen()
	_tutorial.close()
	_main_menu.close()
	_start_game_music()


func _on_tutorial_closed() -> void:
	_tutorial.close()
	_main_menu.open()


func _on_run_started() -> void:
	_start_game_music()


func _start_game_music() -> void:
	var music := get_tree().get_first_node_in_group(Groups.MUSIC)
	if music != null and music.has_method(&"start_game_music"):
		music.start_game_music()
```

`_main_menu.close()` is the only unpause. `_on_run_started` is the restart path; it must not show the tutorial.

- [ ] **Step 3: Reuse the UI click sound**

In `systems/b_audio.gd` `_connect_ui()`, after the menu block:

```gdscript
var tutorial := Game.ui.get_node_or_null("Tutorial") as TutorialScreen
if tutorial != null:
	tutorial.button_pressed.connect(func() -> void: play(&"ui_click"))
```

- [ ] **Step 4: Run the tests and smoke test**

Run: `tools/test.sh`
Expected: PASS.

Run: `tools/smoke.sh`
Expected: `SMOKE OK` (no script/parse errors when the tutorial is built at boot).

- [ ] **Step 5: Manual flow check**

Run the game (F5) and verify:
- First Play shows the tutorial; the reef is paused, the HUD is hidden, game music has not started.
- Inizia and Salta both start the run, show the HUD and start game music once.
- Space advances the vignette; Esc/right click skips (START) or returns to the menu (REVIEW); the pause overlay never opens underneath.
- Second Play goes straight to the game.
- “Come si gioca” reopens the tutorial; Indietro returns to the paused menu.
- Restart from pause and from game over skips the tutorial.

- [ ] **Step 6: Commit**

```bash
git add ui/b_main_menu.gd main/dev_b_systems.gd systems/b_audio.gd
git commit -m "feat: route the menu through the tutorial"
```

---

### Task 6: Documentation and end-to-end verification

**Files:**
- Modify: `docs/GDD.md`

**Interfaces:**
- Consumes: everything above.

- [ ] **Step 1: Document the tutorial in the GDD**

In `docs/GDD.md` §9 (Interfaccia), add one bullet:

```markdown
- **Tutorial**: al primo avvio, dopo Gioca, una schermata animata mostra tre reazioni della barriera (pesce/nido, CO2/alga, alga/corallo). Sempre riapribile da "Come si gioca".
```

- [ ] **Step 2: Run the full verification**

```bash
tools/test.sh
tools/smoke.sh
```

Expected: all tests pass; `SMOKE OK`.

- [ ] **Step 3: Re-run the manual checklist from Task 5**

Also confirm:
- The alga sways in the tutorial exactly like on the reef.
- No population counter, score or grid cell changes while the tutorial is open.
- The tutorial never appears after a restart.
- `git status` shows no changes to `project.godot` or `export_presets.cfg`.

- [ ] **Step 4: Commit**

```bash
git add docs/GDD.md
git commit -m "docs: describe the tutorial screen"
```

---

## Self-Review

**Spec coverage:** Intent / what the player sees → Tasks 2–4; goals and real-art constraint → Task 3; pause and no simulation → Tasks 3–5; first-run + menu review → Tasks 1 and 5; skip/input → Task 4; web-safe/no new art → Global Constraints and Task 3; persistence → Task 1; audio click → Task 5; GDD note → Task 6. Verification → Tasks 5–6.

**Step scan:** each task has a failing test, a run, an implementation with exact signatures/values, a passing run, and a commit. Visual tween timing is pinned in Task 3; the design leaves colors/easing inside those timings to the implementer.

**Type consistency:** `TutorialSequence.index/caption()/advance()/reset()` are used unchanged in Tasks 3–4. `TutorialStage.show_step/stop/sprite_count/visual_nodes` match the screen and tests. `TutorialScreen.Mode/InputAction` and the static helpers match DevB and the tests. `UserSettings.tutorial_seen/mark_tutorial_seen` match Tasks 4–5.

**Review Focus:** each risk has either a unit test (input mapping, seen flag, review mode, isolation) or the manual checklist (start transition, HUD/music), named in the tasks.
