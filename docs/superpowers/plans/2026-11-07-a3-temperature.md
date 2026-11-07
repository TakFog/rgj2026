# A3 — Temperature Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add the ever-rising temperature (GDD M6, §6): it climbs from 0 to 1 in about 8 minutes, living coral cells slow it down (never stop it, never lower it), and a thermometer at the top right shows it in °C. Everyone else reacts through `Game.by_temperature()`.

**Architecture:** Pure `TemperatureModel` (rate formula, clamping, °C mapping), unit-tested. `TemperatureSystem` is the **only writer** of `Game.temperature` (roadmap contract #1): every frame it counts living coral cells with `Game.grid.count_cells(...)` and ticks the model. `Thermometer` is a custom-drawn `Control` listening to `Game.temperature_changed`.

**Tech Stack:** Godot 4.7.2, GDScript, headless test runner from P0.

**Owner:** Dev A. **Depends on:** P0, A1, A2 merged (it extends `main/dev_a_systems.gd` from A2). **Runs in parallel with:** B3 (threats).

---

## Context for the engineer

- Formula (GDD §6): `dT/dt = temp_base_rate × (1 − min(coral_cells × temp_slow_per_cell, temp_max_slowdown))`, with `temp_base_rate = 1/480`, `temp_slow_per_cell = 0.03`, `temp_max_slowdown = 0.6` (all in `data/balance_ecosystem.gd`). Coral **cells**, not corals: a 2×2 coral counts 4. Oxygen does not matter.
- Consumers already read the temperature: A1 algae growth interval (12 s → 4 s); Dev B fish speed (100% → 50%) and threat intervals. Nothing else has to change for them to react.
- Crumbling corals leave the grid immediately (A1), so they stop slowing the temperature right away.
- The run restarts with `Game.reset()` (temperature back to 0) and a fresh `TemperatureSystem`.

> **Test runner caveat:** the P0 runner keeps counting other tests when a test script fails to compile, so always also check that the output has **no `SCRIPT ERROR` line**. A quick way: `tools/test.sh 2>&1 | grep -c "SCRIPT ERROR"` must print `0`.

## File map

| File | Action | Responsibility |
|---|---|---|
| `core/temperature_model.gd` | Create | `TemperatureModel`: rate, clamp, °C |
| `systems/a_temperature_system.gd` | Create | `TemperatureSystem`: ticks the model, writes `Game.temperature` |
| `ui/a_thermometer.gd` | Create | `Thermometer`: top-right gauge + °C label |
| `main/dev_a_systems.gd` | Modify (full replace) | Add the system and the thermometer |
| `tests/unit/test_temperature_model.gd` | Create | 7 tests |
| `dev/verify.gd`, `dev/verify.tscn` | Temporary | Accelerated live check, **never committed** |

Expected test totals: 41 after A2 → 48 after Task 2.

---

### Task 1: Feature branch

- [ ] **Step 1: Create the feature branch from an up-to-date `main`**

```bash
git switch main && git pull origin main
git switch -c "$(gh api user -q .login)/a3-temperature"
```

---

### Task 2: TemperatureModel rules

**Files:**
- Create: `core/temperature_model.gd`
- Test: `tests/unit/test_temperature_model.gd`

- [ ] **Step 1: Write the failing tests**

```gdscript
extends TestCase

var model: TemperatureModel


func before_each() -> void:
	model = TemperatureModel.new(1.0 / 480.0, 0.03, 0.6)


func test_reaches_max_in_8_minutes_without_corals() -> void:
	model.tick(240.0, 0)
	assert_almost(model.value, 0.5)
	model.tick(240.0, 0)
	assert_almost(model.value, 1.0)


func test_slowdown_is_proportional_to_coral_cells() -> void:
	assert_almost(model.slowdown(0), 0.0)
	assert_almost(model.slowdown(10), 0.3)


func test_slowdown_is_capped() -> void:
	assert_almost(model.slowdown(20), 0.6)
	assert_almost(model.slowdown(100), 0.6)


func test_corals_slow_the_rise_but_never_stop_it() -> void:
	model.tick(100.0, 1000)
	assert_almost(model.value, 100.0 / 480.0 * 0.4)
	assert_true(model.value > 0.0)


func test_never_exceeds_one() -> void:
	model.tick(10000.0, 0)
	assert_almost(model.value, 1.0)


func test_never_decreases() -> void:
	model.tick(60.0, 0)
	var before := model.value
	model.tick(60.0, 1000)
	assert_true(model.value > before)


func test_celsius_mapping() -> void:
	assert_almost(TemperatureModel.to_celsius(0.0, 26.0, 32.0), 26.0)
	assert_almost(TemperatureModel.to_celsius(0.5, 26.0, 32.0), 29.0)
	assert_almost(TemperatureModel.to_celsius(2.0, 26.0, 32.0), 32.0)
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `tools/test.sh 2>&1 | grep -m1 "SCRIPT ERROR" -A1`
Expected: a `SCRIPT ERROR` mentioning `TemperatureModel`.

- [ ] **Step 3: Implement `core/temperature_model.gd`**

```gdscript
class_name TemperatureModel
extends RefCounted
## Ever-rising normalised temperature (GDD §6), slowed by living coral cells.
## dT/dt = base_rate * (1 - min(coral_cells * slow_per_cell, max_slowdown)).

var base_rate: float
var slow_per_cell: float
var max_slowdown: float
var value := 0.0


func _init(p_base_rate: float, p_slow_per_cell: float, p_max_slowdown: float) -> void:
	base_rate = p_base_rate
	slow_per_cell = p_slow_per_cell
	max_slowdown = p_max_slowdown


func slowdown(coral_cells: int) -> float:
	return minf(coral_cells * slow_per_cell, max_slowdown)


## Never decreases (max_slowdown < 1) and never exceeds 1.0.
func tick(delta: float, coral_cells: int) -> void:
	value = minf(value + base_rate * (1.0 - slowdown(coral_cells)) * delta, 1.0)


static func to_celsius(normalised: float, min_c: float, max_c: float) -> float:
	return lerpf(min_c, max_c, clampf(normalised, 0.0, 1.0))
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `tools/test.sh`
Expected: `48 passed, 0 failed`, no `SCRIPT ERROR` line.

- [ ] **Step 5: Commit**

```bash
git add core/temperature_model.gd tests/unit/test_temperature_model.gd
git commit -m "Add temperature model slowed by coral cells"
```

---

### Task 3: TemperatureSystem

**Files:**
- Create: `systems/a_temperature_system.gd`

- [ ] **Step 1: Create `systems/a_temperature_system.gd`**

```gdscript
class_name TemperatureSystem
extends Node
## The only writer of Game.temperature (roadmap contract #1). Pausable.

var model: TemperatureModel


func _ready() -> void:
	model = TemperatureModel.new(Game.eco.temp_base_rate, Game.eco.temp_slow_per_cell, Game.eco.temp_max_slowdown)
	Game.temperature = 0.0


func _process(delta: float) -> void:
	model.tick(delta, Game.grid.count_cells(_is_coral))
	Game.temperature = model.value


func _is_coral(entity: Object) -> bool:
	return entity is Coral
```

- [ ] **Step 2: Run tests (class must compile)**

Run: `tools/test.sh`
Expected: `48 passed, 0 failed`, no `SCRIPT ERROR` line.

- [ ] **Step 3: Commit**

```bash
git add systems/a_temperature_system.gd
git commit -m "Add temperature system writing Game.temperature"
```

---

### Task 4: Thermometer UI and wiring

**Files:**
- Create: `ui/a_thermometer.gd`
- Modify (replace the whole file): `main/dev_a_systems.gd`
- Temporary: `dev/verify.gd`, `dev/verify.tscn`

- [ ] **Step 1: Create `ui/a_thermometer.gd`**

A tube + bulb drawn with `draw_rect`/`draw_circle`, filling and shifting from blue to red with the temperature, and a `°C` label below (26 °C → 32 °C by default). Set `size` and `grow_horizontal = GROW_DIRECTION_BEGIN` **before** applying the top-right preset; otherwise the control is anchored with zero width and ends up off-screen at the right edge.

```gdscript
class_name Thermometer
extends Control
## Top-right thermometer (GDD §6, §9): fills and reddens as Game.temperature rises.

const TUBE_SIZE := Vector2(22, 160)
const BULB_RADIUS := 18.0
const COLD := Color(0.35, 0.7, 1.0)
const HOT := Color(1.0, 0.25, 0.15)

var _label: Label


func _ready() -> void:
	custom_minimum_size = Vector2(90, TUBE_SIZE.y + BULB_RADIUS * 2.0 + 30.0)
	size = custom_minimum_size
	grow_horizontal = Control.GROW_DIRECTION_BEGIN
	set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT, Control.PRESET_MODE_KEEP_SIZE, 16)
	_label = Label.new()
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.position = Vector2(0, TUBE_SIZE.y + BULB_RADIUS * 2.0 + 4.0)
	_label.size = Vector2(custom_minimum_size.x, 24)
	add_child(_label)
	Game.temperature_changed.connect(_on_temperature_changed)
	_on_temperature_changed(Game.temperature)


func _on_temperature_changed(value: float) -> void:
	_label.text = "%.1f °C" % TemperatureModel.to_celsius(value, Game.eco.temp_display_min_c, Game.eco.temp_display_max_c)
	queue_redraw()


func _draw() -> void:
	var t := clampf(Game.temperature, 0.0, 1.0)
	var color := COLD.lerp(HOT, t)
	var x := (custom_minimum_size.x - TUBE_SIZE.x) * 0.5
	var tube := Rect2(Vector2(x, 0), TUBE_SIZE)
	var bulb_center := Vector2(custom_minimum_size.x * 0.5, TUBE_SIZE.y + BULB_RADIUS)
	draw_rect(tube, Color(1, 1, 1, 0.2))
	draw_circle(bulb_center, BULB_RADIUS, Color(1, 1, 1, 0.2))
	var fill_height := TUBE_SIZE.y * t
	draw_rect(Rect2(Vector2(x + 4, TUBE_SIZE.y - fill_height), Vector2(TUBE_SIZE.x - 8, fill_height)), color)
	draw_circle(bulb_center, BULB_RADIUS - 4.0, color)
```

- [ ] **Step 2: Replace `main/dev_a_systems.gd`**

```gdscript
extends Node
## Dev A's systems and UI are added here (inventory, placement, temperature...).
## Only Dev A edits this file.

var inventory: InventorySystem
var placement: PlacementController
var temperature: TemperatureSystem


func _ready() -> void:
	inventory = InventorySystem.new()
	inventory.name = "InventorySystem"
	add_child(inventory)

	placement = PlacementController.new()
	placement.name = "PlacementController"
	placement.inventory = inventory
	add_child(placement)

	temperature = TemperatureSystem.new()
	temperature.name = "TemperatureSystem"
	add_child(temperature)

	var bar := InventoryBar.new()
	bar.name = "InventoryBar"
	bar.inventory = inventory
	bar.placement = placement
	Game.ui.add_child(bar)

	var thermometer := Thermometer.new()
	thermometer.name = "Thermometer"
	Game.ui.add_child(thermometer)
```

- [ ] **Step 3: Run unit and smoke tests**

Run: `tools/test.sh && tools/smoke.sh`
Expected: `48 passed, 0 failed`, no `SCRIPT ERROR`, then `SMOKE OK`.

- [ ] **Step 4: Create the temporary verification scene**

`dev/verify.gd` (base rate ×24 so the change is visible in seconds):
```gdscript
extends Node
## TEMPORARY verification harness for plan A3. Do not commit.

var frames := 0


func _ready() -> void:
	Game.eco = Game.eco.duplicate()
	Game.eco.temp_base_rate = 0.05
	add_child(load("res://main/main.tscn").instantiate())


func _physics_process(_delta: float) -> void:
	frames += 1
	if frames % 60 == 0:
		print("t=", frames / 60, " T=", snappedf(Game.temperature, 0.001),
			" coral_cells=", Game.grid.count_cells(func(e): return e is Coral))
	if frames >= 300:
		var thermometer := Game.ui.get_node("Thermometer") as Control
		print("thermometer rect: ", thermometer.get_global_rect())
		get_tree().quit()
```

`dev/verify.tscn`:
```ini
[gd_scene format=3]

[ext_resource type="Script" path="res://dev/verify.gd" id="1"]

[node name="Verify" type="Node"]
script = ExtResource("1")
```

- [ ] **Step 5: Run it headless**

Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --path . res://dev/verify.tscn 2>&1 | grep -E "^t=|thermometer"`
Expected: `coral_cells=14` (Level01: 1+2+3+4+4) on every line until a coral crumbles; `T` grows by about `0.029` per second (`0.05 × (1 − 0.42)`), e.g. `t=1 T=0.029`, `t=2 T=0.058` …; the thermometer rect has `S: (90.0, 226.0)` and its `P.x` is `screen width − 106` (e.g. `1174.0` for a 1280-wide window) — i.e. fully on screen at the top right.

- [ ] **Step 6: Manual check in the editor**

Press F5: the thermometer sits at the top right showing `26.0 °C`; after a minute it reads about `26.4 °C` (60 s × 1/480 × 0.58 of the 6 °C range, with 14 coral cells). Place a 2×2 coral: the rise visibly slows (16 → 18 cells). Let corals die: it speeds up. It never goes down.

- [ ] **Step 7: Delete the temporary files and commit**

```bash
rm -rf dev
git add ui/a_thermometer.gd main/dev_a_systems.gd
git commit -m "Add thermometer UI and wire temperature system"
```

---

### Task 5: Integrate into main (git flow)

- [ ] **Step 1: Merge `main` into the branch and re-verify**

```bash
git fetch origin && git merge origin/main
tools/test.sh && tools/smoke.sh
```
Expected: `48 passed, 0 failed` (more if Dev B's tests are already on `main`), no `SCRIPT ERROR` line in the output, then `SMOKE OK`. Open the project in the Godot editor and press F5: no errors in the Output panel.

- [ ] **Step 2: Merge to `main`, push, delete the branch**

```bash
BR="$(git branch --show-current)"
git switch main && git pull origin main
git merge "$BR" && git push origin main
git branch -d "$BR"
```

Then tell Dev B: `Game.temperature` now rises; fish speed and threat intervals react through `Game.by_temperature()` (contract #1).
