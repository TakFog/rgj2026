# B2 — Populations, Collapse Timeout, HUD, Pause and Game Over Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Turn the sandbox into a game (GDD M4, Dev B half): count the four populations on the map, start an independent 10 s collapse countdown when one reaches zero, end the run with a game-over screen showing the survival time, and give the player a HUD, pause and restart.

**Architecture:** One pure rule class, `CollapseTracker` (per-population countdowns, first expiry wins), unit-tested headless. A pausable `PopulationMonitor` node counts groups every frame (roadmap contract #9), feeds the tracker, accumulates the score (seconds survived) and pauses the tree on collapse. UI is built in code under `Game.ui`: `Hud` (counters, time, collapse warning with the fish-rescue hint from contract #10), `PauseController` + pause overlay (contract #8), `GameOverScreen` with Restart (contract #11). Everything is wired in `main/dev_b_systems.gd`.

**Tech Stack:** Godot 4.7.2, GDScript, headless test runner from P0.

**Owner:** Dev B. **Depends on:** P0 merged; B1 merged (only because both edit `main/dev_b_systems.gd` — this plan uses **no** B1 code, only P0 contracts). **Runs in parallel with:** A2.

---

## Context for the engineer

- Read `docs/GDD.md` §3 (end conditions, collapse timeout, score) and §9 (UI), and roadmap contracts #8, #9, #10, #11, #12, #13.
- Population ids are the group names from `core/groups.gd`: `Groups.CORALS`, `Groups.ALGAE`, `Groups.FISH`, `Groups.NESTS` (`&"corals"`, `&"algae"`, `&"fish"`, `&"nests"`). Only entities **on the map** count; `destroy()` removes an entity from its group immediately, so `get_tree().get_nodes_in_group(...).size()` is exact in the same frame.
- Timers advance only with `delta` in pausable nodes, so pause freezes countdowns and score (contract #13).
- `Nest.eggs_time_left()` returns `-1.0` with the P0 stub; the fish-rescue hint simply stays hidden until A2 lands.
- **Input order matters.** `_unhandled_input` reaches later-added nodes first, and `DevBSystems` is added after `DevASystems`, so the pause controller sees Esc **before** A2's placement controller. That is why `PauseController` ignores the pause action while `Game.placing` is true: the event then reaches the placement controller, which cancels placement (contract #8). Space is ignored while placing too ("you cannot place while paused", GDD §9).
- After game over the tree is paused; only `PROCESS_MODE_ALWAYS` nodes (the game-over screen) react. Restart calls `get_tree().reload_current_scene()`; `Main._ready()` calls `Game.reset()`, which unpauses.
- UI text is in Italian (the game's language); code and comments are in English.

> **Test runner caveat:** the P0 runner keeps counting other tests when a test script fails to compile, so always also check that the output has **no `SCRIPT ERROR` line**: `tools/test.sh 2>&1 | grep -c "SCRIPT ERROR"` must print `0`.

## File map

| File | Action | Responsibility |
|---|---|---|
| `core/collapse_tracker.gd` | Create | `CollapseTracker`: per-population countdowns, collapse |
| `systems/b_population_monitor.gd` | Create | `PopulationMonitor`: counts, score, game over, soonest hatch |
| `ui/b_hud.gd` | Create | `Hud`: counters, time, collapse warning + text helpers |
| `systems/b_pause_controller.gd` | Create | `PauseController`: pause toggle + pause overlay |
| `ui/b_game_over.gd` | Create | `GameOverScreen`: result + Restart |
| `main/dev_b_systems.gd` | Modify | Wire monitor, HUD, pause, game over |
| `tests/unit/test_collapse_tracker.gd` | Create | 10 tests |
| `tests/unit/test_population_monitor.gd` | Create | 3 tests |
| `tests/unit/test_hud_text.gd` | Create | 6 tests |

Expected test totals: **T** (your total after B1) → T + 10 after Task 2 → T + 13 after Task 3 → T + 19 after Task 4.

Public API produced by this plan (other code may rely on it):

```text
PopulationMonitor (Node)
  const POPULATIONS: Array[StringName]
  signal counts_changed(counts: Dictionary)          # StringName -> int, emitted when any count changes
  signal score_changed(seconds: float)                # every unpaused frame
  signal countdown_started(population: StringName)
  signal countdown_cancelled(population: StringName)
  signal game_over(population: StringName, score_seconds: float)
  var tracker: CollapseTracker
  var counts: Dictionary
  var score_seconds: float
  var is_over: bool
  func soonest_hatch_seconds() -> float
  static func soonest_hatch(nests: Array) -> float

Hud (Control)
  func bind(monitor: PopulationMonitor) -> void
  static func display_name(population: StringName) -> String
  static func format_time(seconds: float) -> String
  static func is_critical(count: int) -> bool
  static func warning_text(population: StringName, seconds_left: float, hatch_seconds: float) -> String

PauseController (Node)
  var monitor: PopulationMonitor
  var overlay: Control
  func set_paused(value: bool) -> void

GameOverScreen (ColorRect)
  func show_result(population: StringName, score_seconds: float) -> void
```

---

### Task 1: Feature branch

- [ ] **Step 1: Create the feature branch from an up-to-date `main`**

```bash
git switch main && git pull origin main
git switch -c "$(gh api user -q .login)/b2-population-hud"
```

- [ ] **Step 2: Record the current test total T**

Run: `tools/test.sh 2>&1 | tail -1`
Expected: `T passed, 0 failed` (write T down; later steps refer to it).

---

### Task 2: CollapseTracker rules

**Files:**
- Create: `core/collapse_tracker.gd`
- Test: `tests/unit/test_collapse_tracker.gd`

- [ ] **Step 1: Write the failing tests** in `tests/unit/test_collapse_tracker.gd`

```gdscript
extends TestCase

var tracker: CollapseTracker


func before_each() -> void:
	tracker = CollapseTracker.new(10.0)


func test_no_countdown_while_population_alive() -> void:
	tracker.report(&"fish", 3)
	tracker.tick(5.0)
	assert_false(tracker.is_counting(&"fish"))
	assert_almost(tracker.time_left(&"fish"), -1.0)
	assert_false(tracker.is_collapsed())


func test_zero_starts_full_countdown() -> void:
	tracker.report(&"fish", 0)
	assert_true(tracker.is_counting(&"fish"))
	assert_almost(tracker.time_left(&"fish"), 10.0)


func test_tick_counts_down() -> void:
	tracker.report(&"fish", 0)
	tracker.tick(4.0)
	assert_almost(tracker.time_left(&"fish"), 6.0)


func test_recovery_cancels_countdown() -> void:
	tracker.report(&"fish", 0)
	tracker.tick(4.0)
	tracker.report(&"fish", 2)
	tracker.tick(20.0)
	assert_false(tracker.is_counting(&"fish"))
	assert_false(tracker.is_collapsed())


func test_new_zero_restarts_from_full() -> void:
	tracker.report(&"fish", 0)
	tracker.tick(7.0)
	tracker.report(&"fish", 1)
	tracker.report(&"fish", 0)
	assert_almost(tracker.time_left(&"fish"), 10.0)


func test_expiry_collapses_with_population() -> void:
	tracker.report(&"fish", 0)
	tracker.tick(9.9)
	assert_false(tracker.is_collapsed())
	tracker.tick(0.2)
	assert_true(tracker.is_collapsed())
	assert_eq(tracker.collapsed_population, &"fish")


func test_countdowns_are_independent_and_first_expiry_wins() -> void:
	tracker.report(&"fish", 0)
	tracker.tick(3.0)
	tracker.report(&"algae", 0)
	assert_almost(tracker.time_left(&"algae"), 10.0)
	tracker.tick(7.5)
	assert_true(tracker.is_collapsed())
	assert_eq(tracker.collapsed_population, &"fish")


func test_collapse_is_final() -> void:
	tracker.report(&"nests", 0)
	tracker.tick(10.0)
	tracker.report(&"nests", 4)
	tracker.tick(1.0)
	assert_true(tracker.is_collapsed())
	assert_eq(tracker.collapsed_population, &"nests")


func test_most_urgent_is_lowest_time_left() -> void:
	assert_eq(tracker.most_urgent(), &"")
	tracker.report(&"algae", 0)
	tracker.tick(4.0)
	tracker.report(&"corals", 0)
	assert_eq(tracker.most_urgent(), &"algae")


func test_signals() -> void:
	var started := []
	var cancelled := []
	var collapsed := []
	tracker.countdown_started.connect(func(p: StringName) -> void: started.append(p))
	tracker.countdown_cancelled.connect(func(p: StringName) -> void: cancelled.append(p))
	tracker.collapsed.connect(func(p: StringName) -> void: collapsed.append(p))
	tracker.report(&"fish", 0)
	tracker.report(&"fish", 0)
	tracker.report(&"fish", 2)
	tracker.report(&"algae", 0)
	tracker.tick(10.0)
	assert_eq(started, [&"fish", &"algae"])
	assert_eq(cancelled, [&"fish"])
	assert_eq(collapsed, [&"algae"])
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `tools/test.sh`
Expected: `SCRIPT ERROR` mentioning `Identifier "CollapseTracker" not declared`; non-zero exit.

- [ ] **Step 3: Implement `core/collapse_tracker.gd`**

```gdscript
class_name CollapseTracker
extends RefCounted
## Per-population collapse countdowns (GDD §3).
## A population at zero starts its own countdown of `grace_seconds`; going back
## above zero cancels it; going to zero again restarts it from full. The first
## countdown to expire collapses the ecosystem (final). Advance with tick(delta).

signal countdown_started(population: StringName)
signal countdown_cancelled(population: StringName)
signal collapsed(population: StringName)

var grace_seconds: float
var collapsed_population: StringName = &""
var _remaining: Dictionary = {} # StringName -> float, only populations at zero
var _collapsed := false


func _init(p_grace_seconds: float) -> void:
	grace_seconds = p_grace_seconds


## Report the latest count of `population`. Call every frame for every population.
func report(population: StringName, count: int) -> void:
	if _collapsed:
		return
	if count <= 0:
		if not _remaining.has(population):
			_remaining[population] = grace_seconds
			countdown_started.emit(population)
	elif _remaining.has(population):
		_remaining.erase(population)
		countdown_cancelled.emit(population)


func tick(delta: float) -> void:
	if _collapsed:
		return
	var expired: StringName = &""
	var lowest := INF
	for population: StringName in _remaining.keys():
		var left: float = _remaining[population] - delta
		_remaining[population] = left
		if left <= 0.0 and left < lowest:
			lowest = left
			expired = population
	if expired != &"":
		_collapsed = true
		collapsed_population = expired
		collapsed.emit(expired)


func is_counting(population: StringName) -> bool:
	return _remaining.has(population)


## Seconds left before `population` collapses the ecosystem, or -1.0 if not counting.
func time_left(population: StringName) -> float:
	return _remaining.get(population, -1.0)


func is_collapsed() -> bool:
	return _collapsed


## The counting population closest to expiry, or &"" if none is counting.
func most_urgent() -> StringName:
	var result: StringName = &""
	var lowest := INF
	for population: StringName in _remaining.keys():
		if _remaining[population] < lowest:
			lowest = _remaining[population]
			result = population
	return result
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `tools/test.sh 2>&1 | tail -1 && tools/test.sh 2>&1 | grep -c "SCRIPT ERROR"`
Expected: `T+10 passed, 0 failed` (all tests pass, including the 10 new CollapseTracker tests), then `0`.

- [ ] **Step 5: Commit**

```bash
git add core/collapse_tracker.gd tests/unit/test_collapse_tracker.gd
git commit -m "Add CollapseTracker for per-population collapse countdowns"
```

---

### Task 3: PopulationMonitor

**Files:**
- Create: `systems/b_population_monitor.gd`
- Test: `tests/unit/test_population_monitor.gd`

Only the static `soonest_hatch()` is unit-tested (the rest needs a scene tree and is checked in Task 6).

- [ ] **Step 1: Write the failing tests** in `tests/unit/test_population_monitor.gd`

```gdscript
extends TestCase


class FakeNest:
	extends RefCounted
	var left: float

	func _init(p_left: float) -> void:
		left = p_left

	func eggs_time_left() -> float:
		return left


func test_soonest_hatch_without_nests() -> void:
	assert_almost(PopulationMonitor.soonest_hatch([]), -1.0)


func test_soonest_hatch_ignores_nests_without_eggs() -> void:
	assert_almost(PopulationMonitor.soonest_hatch([FakeNest.new(-1.0), FakeNest.new(-1.0)]), -1.0)


func test_soonest_hatch_picks_smallest_positive() -> void:
	var nests := [FakeNest.new(-1.0), FakeNest.new(12.0), FakeNest.new(5.0)]
	assert_almost(PopulationMonitor.soonest_hatch(nests), 5.0)
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `tools/test.sh`
Expected: `SCRIPT ERROR` mentioning `Identifier "PopulationMonitor" not declared`; non-zero exit.

- [ ] **Step 3: Implement `systems/b_population_monitor.gd`**

```gdscript
class_name PopulationMonitor
extends Node
## Counts the four map populations every frame (roadmap contract #9), drives the
## CollapseTracker, accumulates the score (seconds survived) and ends the run.
## Pausable: score and countdowns freeze while the tree is paused.

signal counts_changed(counts: Dictionary)
signal score_changed(seconds: float)
signal countdown_started(population: StringName)
signal countdown_cancelled(population: StringName)
signal game_over(population: StringName, score_seconds: float)

const POPULATIONS: Array[StringName] = [Groups.CORALS, Groups.ALGAE, Groups.FISH, Groups.NESTS]

var tracker: CollapseTracker
var counts: Dictionary = {} # StringName -> int
var score_seconds := 0.0
var is_over := false


## Smallest positive eggs_time_left() among `nests`, or -1.0 if no nest has eggs.
static func soonest_hatch(nests: Array) -> float:
	var best := -1.0
	for nest in nests:
		var left: float = nest.eggs_time_left()
		if left > 0.0 and (best < 0.0 or left < best):
			best = left
	return best


func _ready() -> void:
	tracker = CollapseTracker.new(Game.actors.collapse_grace_seconds)
	tracker.countdown_started.connect(func(p: StringName) -> void: countdown_started.emit(p))
	tracker.countdown_cancelled.connect(func(p: StringName) -> void: countdown_cancelled.emit(p))
	tracker.collapsed.connect(_on_collapsed)


func _process(delta: float) -> void:
	if is_over:
		return
	score_seconds += delta
	score_changed.emit(score_seconds)
	var new_counts := {}
	for population in POPULATIONS:
		var count := get_tree().get_nodes_in_group(population).size()
		new_counts[population] = count
		tracker.report(population, count)
	if new_counts != counts:
		counts = new_counts
		counts_changed.emit(counts)
	tracker.tick(delta)


## Seconds until the first nest hatches, or -1.0 (fish-rescue hint, contract #10).
func soonest_hatch_seconds() -> float:
	return soonest_hatch(get_tree().get_nodes_in_group(Groups.NESTS))


func _on_collapsed(population: StringName) -> void:
	is_over = true
	game_over.emit(population, score_seconds)
	get_tree().paused = true
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `tools/test.sh 2>&1 | tail -1 && tools/test.sh 2>&1 | grep -c "SCRIPT ERROR"`
Expected: `T+13 passed, 0 failed` (including the 3 new PopulationMonitor tests), then `0`.

- [ ] **Step 5: Commit**

```bash
git add systems/b_population_monitor.gd tests/unit/test_population_monitor.gd
git commit -m "Add PopulationMonitor for population counts, score and game over"
```

---

### Task 4: HUD

**Files:**
- Create: `ui/b_hud.gd`
- Test: `tests/unit/test_hud_text.gd`

The text and threshold helpers are static and unit-tested; layout is checked in Task 6.

- [ ] **Step 1: Write the failing tests** in `tests/unit/test_hud_text.gd`

```gdscript
extends TestCase


func test_format_time() -> void:
	assert_eq(Hud.format_time(0.0), "00:00")
	assert_eq(Hud.format_time(125.7), "02:05")


func test_is_critical() -> void:
	assert_true(Hud.is_critical(0))
	assert_true(Hud.is_critical(1))
	assert_false(Hud.is_critical(2))


func test_warning_text_for_coral() -> void:
	assert_eq(Hud.warning_text(&"corals", 6.2, -1.0), "Coralli a zero! Collasso tra 7 s")


func test_warning_text_fish_without_eggs_has_no_hint() -> void:
	assert_eq(Hud.warning_text(&"fish", 9.5, -1.0), "Pesci a zero! Collasso tra 10 s")


func test_warning_text_fish_eggs_in_time() -> void:
	assert_eq(Hud.warning_text(&"fish", 9.5, 4.0),
		"Pesci a zero! Collasso tra 10 s\nUova in schiusa tra 4 s (in tempo)")


func test_warning_text_fish_eggs_too_late() -> void:
	assert_eq(Hud.warning_text(&"fish", 3.0, 12.0),
		"Pesci a zero! Collasso tra 3 s\nUova in schiusa tra 12 s (troppo tardi)")
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `tools/test.sh`
Expected: `SCRIPT ERROR` mentioning `Identifier "Hud" not declared`; non-zero exit.

- [ ] **Step 3: Implement `ui/b_hud.gd`**

```gdscript
class_name Hud
extends Control
## Population counters (top left, flashing red when <= 1), survival time (top
## centre) and the collapse warning below it (GDD §3, §9, roadmap contract #10).

const NAMES := {&"corals": "Coralli", &"algae": "Alghe", &"fish": "Pesci", &"nests": "Nidi"}
const FLASH_PERIOD := 0.5
const CRITICAL_COLOR := Color(1.0, 0.3, 0.3)

var monitor: PopulationMonitor
var _counter_labels: Dictionary = {} # StringName -> Label
var _counts: Dictionary = {} # StringName -> int
var _score_label: Label
var _warning_label: Label
var _flash_time := 0.0


static func display_name(population: StringName) -> String:
	return NAMES.get(population, String(population))


static func format_time(seconds: float) -> String:
	var whole := floori(seconds)
	return "%02d:%02d" % [floori(whole / 60.0), whole % 60]


static func is_critical(count: int) -> bool:
	return count <= 1


## Collapse warning text. `hatch_seconds` < 0 means "no eggs" (no hint shown).
static func warning_text(population: StringName, seconds_left: float, hatch_seconds: float) -> String:
	var text := "%s a zero! Collasso tra %d s" % [display_name(population), ceili(seconds_left)]
	if population == Groups.FISH and hatch_seconds >= 0.0:
		var verdict := "in tempo" if hatch_seconds <= seconds_left else "troppo tardi"
		text += "\nUova in schiusa tra %d s (%s)" % [ceili(hatch_seconds), verdict]
	return text


## Connect to a monitor. Safe to call before the HUD enters the tree.
func bind(p_monitor: PopulationMonitor) -> void:
	monitor = p_monitor
	monitor.counts_changed.connect(_on_counts_changed)
	monitor.score_changed.connect(_on_score_changed)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_counters()
	_score_label = _make_centered_label(12.0, 32)
	_score_label.text = format_time(0.0)
	_warning_label = _make_centered_label(56.0, 24)
	_warning_label.add_theme_color_override("font_color", CRITICAL_COLOR)
	_warning_label.visible = false


func _process(delta: float) -> void:
	_flash_time += delta
	var flash_on := fmod(_flash_time, FLASH_PERIOD) < FLASH_PERIOD * 0.5
	for population: StringName in _counter_labels:
		var label: Label = _counter_labels[population]
		var critical := is_critical(_counts.get(population, 99))
		label.modulate = CRITICAL_COLOR if critical and flash_on else Color.WHITE
	_update_warning()


func _update_warning() -> void:
	if monitor == null or monitor.tracker == null:
		return
	var population := monitor.tracker.most_urgent()
	if population == &"":
		_warning_label.visible = false
		return
	var hatch := monitor.soonest_hatch_seconds() if population == Groups.FISH else -1.0
	_warning_label.text = warning_text(population, monitor.tracker.time_left(population), hatch)
	_warning_label.visible = true


func _on_counts_changed(counts: Dictionary) -> void:
	_counts = counts
	for population: StringName in counts:
		if _counter_labels.has(population):
			var label: Label = _counter_labels[population]
			label.text = "%s: %d" % [display_name(population), counts[population]]


func _on_score_changed(seconds: float) -> void:
	_score_label.text = format_time(seconds)


func _build_counters() -> void:
	var box := VBoxContainer.new()
	box.position = Vector2(16, 16)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(box)
	for population in PopulationMonitor.POPULATIONS:
		var label := Label.new()
		label.add_theme_font_size_override("font_size", 22)
		label.text = "%s: -" % display_name(population)
		box.add_child(label)
		_counter_labels[population] = label


func _make_centered_label(top: float, font_size: int) -> Label:
	var label := Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	add_child(label)
	label.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	label.offset_top = top
	label.offset_bottom = top + font_size * 2.5
	return label
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `tools/test.sh 2>&1 | tail -1 && tools/test.sh 2>&1 | grep -c "SCRIPT ERROR"`
Expected: `T+19 passed, 0 failed` (including the 6 new HUD text tests), then `0`.

- [ ] **Step 5: Commit**

```bash
git add ui/b_hud.gd tests/unit/test_hud_text.gd
git commit -m "Add HUD with population counters, survival time and collapse warning"
```

---

### Task 5: Pause controller and game-over screen

**Files:**
- Create: `systems/b_pause_controller.gd`, `ui/b_game_over.gd`

Both are input/scene-tree driven; they are verified manually in Task 6.

- [ ] **Step 1: Implement `systems/b_pause_controller.gd`**

```gdscript
class_name PauseController
extends Node
## Space/Esc toggles pause (GDD §9). Ignored while placing — Esc must reach the
## placement controller to cancel (roadmap contract #8) — and after game over.
## PROCESS_MODE_ALWAYS so it can unpause.

var monitor: PopulationMonitor
var overlay: Control


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	overlay = _build_overlay()
	Game.ui.add_child(overlay)


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed(InputActions.PAUSE):
		return
	if Game.placing or (monitor != null and monitor.is_over):
		return
	set_paused(not get_tree().paused)
	get_viewport().set_input_as_handled()


func set_paused(value: bool) -> void:
	get_tree().paused = value
	overlay.visible = value


func _build_overlay() -> Control:
	var root := ColorRect.new()
	root.name = "PauseOverlay"
	root.color = Color(0, 0, 0, 0.5)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.visible = false
	var label := Label.new()
	label.text = "PAUSA\nSpazio per riprendere"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 40)
	root.add_child(label)
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return root
```

- [ ] **Step 2: Implement `ui/b_game_over.gd`**

```gdscript
class_name GameOverScreen
extends ColorRect
## Full-screen game-over overlay: which population collapsed, survival time and
## a Restart button (GDD §3, roadmap contract #11). Works while the tree is paused.

var _title: Label
var _score: Label


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	color = Color(0.02, 0.05, 0.1, 0.85)
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false
	var center := CenterContainer.new()
	add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 16)
	center.add_child(box)
	_title = _add_label(box, 40)
	_score = _add_label(box, 28)
	var restart := Button.new()
	restart.text = "Ricomincia"
	restart.add_theme_font_size_override("font_size", 28)
	restart.pressed.connect(_on_restart_pressed)
	box.add_child(restart)


func show_result(population: StringName, score_seconds: float) -> void:
	_title.text = "Ecosistema collassato: %s a zero" % Hud.display_name(population)
	_score.text = "Sei sopravvissuto %s" % Hud.format_time(score_seconds)
	visible = true


func _add_label(parent: Control, font_size: int) -> Label:
	var label := Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	parent.add_child(label)
	return label


func _on_restart_pressed() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()
```

- [ ] **Step 3: Run tests (both scripts must compile)**

Run: `tools/test.sh 2>&1 | tail -1 && tools/test.sh 2>&1 | grep -c "SCRIPT ERROR"`
Expected: `T+19 passed, 0 failed`, then `0`.

- [ ] **Step 4: Commit**

```bash
git add systems/b_pause_controller.gd ui/b_game_over.gd
git commit -m "Add pause controller and game-over screen"
```

---

### Task 6: Wire everything in DevBSystems and verify in the game

**Files:**
- Modify: `main/dev_b_systems.gd`

B1 already edited this file (fish commander). Do **not** replace it: add one call at the end of `_ready()` and append one function.

- [ ] **Step 1: Add the call as the last line of `_ready()` in `main/dev_b_systems.gd`**

```gdscript
	_setup_population_and_hud()
```

- [ ] **Step 2: Append this function to `main/dev_b_systems.gd`**

```gdscript
## B2: population monitor, HUD, pause and game over (GDD §3, §9).
## Game.ui is not in the tree yet when this runs (Main adds it last); adding
## children to it is fine, they enter the tree together with it.
func _setup_population_and_hud() -> void:
	var monitor := PopulationMonitor.new()
	monitor.name = "PopulationMonitor"
	add_child(monitor)

	var hud := Hud.new()
	hud.name = "Hud"
	hud.bind(monitor)
	Game.ui.add_child(hud)

	var game_over := GameOverScreen.new()
	game_over.name = "GameOver"
	Game.ui.add_child(game_over)
	monitor.game_over.connect(game_over.show_result)

	var pause := PauseController.new()
	pause.name = "PauseController"
	pause.monitor = monitor
	add_child(pause)
```

- [ ] **Step 3: Run unit tests and the smoke test**

Run: `tools/test.sh 2>&1 | tail -1 && tools/smoke.sh`
Expected: `T+19 passed, 0 failed`, then `SMOKE OK` (the level is populated, so no game over happens in the 300 smoke frames).

- [ ] **Step 4: Manual check in the editor (F5)**

1. Top left shows `Coralli: 5`, `Alghe: 5` (or more if algae already spread), `Pesci: 3`, `Nidi: 1`. `Nidi: 1` flashes red (≤ 1).
2. Top centre shows the time counting up `00:01`, `00:02`, …
3. Press **Space**: the pause overlay appears, the time stops, fish stop. Press **Space** again: it resumes. **Esc** does the same when nothing is being placed.
4. With A2 merged: pick an inventory slot, press **Esc** → placement is cancelled and the game is **not** paused; press **Space** while placing → nothing happens.
5. Force a collapse: in the editor's **Remote** scene tree expand `Main/World`, select the nest (the only `Area2D` child; check the Inspector shows the `nest.gd` script) and press **Delete**. `Nidi: 0` flashes, and the red warning `Nidi a zero! Collasso tra 10 s` counts down. After 10 s the game-over screen shows `Ecosistema collassato: Nidi a zero` and `Sei sopravvissuto mm:ss`; the time no longer advances; Space does nothing.
6. Click **Ricomincia**: the level reloads with the starting populations and the time restarts from `00:00`.
7. Fish hint (needs A2 merged): order an adult fish onto the nest until it has eggs, then delete all `CharacterBody2D` children of `Main/World` (the fish) from the Remote tree → the warning shows a second line `Uova in schiusa tra N s (in tempo)` and, when the eggs hatch before the countdown expires, the warning disappears and the game continues.

- [ ] **Step 5: Commit**

```bash
git add main/dev_b_systems.gd
git commit -m "Wire population monitor, HUD, pause and game over into the game"
```

---

### Task 7: Integrate into main (git flow)

- [ ] **Step 1: Merge `main` into the branch and re-verify**

```bash
git fetch origin && git merge origin/main
tools/test.sh && tools/smoke.sh
```
Expected: all tests pass (`0 failed`, no `SCRIPT ERROR`), `SMOKE OK`. Open the project in the editor and press F5: no errors in the Output panel, and the manual checks of Task 6 steps 1–3 still hold.

- [ ] **Step 2: Merge to main, push, delete the branch**

```bash
BR="$(git branch --show-current)"
git switch main && git pull origin main
git merge "$BR" && git push origin main
git branch -d "$BR"
```

Then tell Dev A: the game now ends when a population stays at zero for 10 s; Esc/Space pause is ignored while `Game.placing` (contract #8); the fish warning reads `Nest.eggs_time_left()` (contract #10). Checkpoint 2 (first playable) can start once A2 is also on `main`.
