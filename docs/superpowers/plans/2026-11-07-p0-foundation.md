# Phase 0 — Shared Foundation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the skeleton both developers depend on: headless test runner, grid model, oblique view projection, balance resources, the `Game` service autoload, entity contracts (stub Coral/Algae/Nest/Fish), the entity factory, the fixed Level01 map and the Main scene.

**Architecture:** Gameplay runs in a hidden top-down logical `World` (Godot 2D physics, square cells). Every entity mirrors itself into a y-sorted screen-space `View` through `ViewFollower`, which applies the `ViewProjection` affine transform (oblique `/__/` by default). Pure logic lives in `RefCounted` classes under `core/` and is unit-tested headless; nodes are thin adapters. Entities are script classes instantiated in code by `EntityFactory` (no `.tscn` per entity, so there are no scene merge conflicts).

**Tech Stack:** Godot 4.7.2 (GDScript, Compatibility renderer), custom headless test runner (`tests/run_tests.gd`), bash helper scripts.

**Executed by:** both developers together (pair), before any track starts. See `2026-11-07-00-roadmap.md`.

---

## Conventions used by every plan

- Godot binary: `/Applications/Godot.app/Contents/MacOS/Godot` (override with `GODOT=...`).
- Run unit tests: `tools/test.sh` → prints `N passed, 0 failed`, exit code 0.
- Run smoke test (boots Main for 300 frames headless, fails on any error): `tools/smoke.sh` → prints `SMOKE OK`.
- Unit tests live in `tests/unit/test_*.gd`, extend `TestCase`, and every `test_*` method runs on a fresh instance after `before_each()`.
- All world measures are **logical units** (GDD §4). Never use screen pixels in gameplay code.
- Indentation: tabs (matches `.editorconfig`).
- Git flow from `CLAUDE.md`: work on `<gh-username>/<feature>`, merge `origin/main` into it, verify, then merge to `main`. Commit messages in English, no AI attribution.

## File map

| File | Responsibility | Owner after P0 |
|---|---|---|
| `tests/test_case.gd` | Assertion base class | shared |
| `tests/run_tests.gd` | Headless runner | shared |
| `tools/test.sh`, `tools/smoke.sh` | CLI helpers | shared |
| `core/layers.gd` | Physics layer bits | shared (frozen) |
| `core/groups.gd` | Group names | shared (frozen) |
| `core/grid_model.gd` | Cell occupancy, cell↔world | shared (A may extend) |
| `core/view_projection.gd` | World↔screen affine projection | shared (frozen) |
| `core/input_actions.gd` | Input map registration | shared |
| `data/view_settings.gd/.tres` | Projection parameters | designer |
| `data/balance_ecosystem.gd/.tres` | Dev A tunables | Dev A |
| `data/balance_actors.gd/.tres` | Dev B tunables | Dev B |
| `data/coral_shapes.gd` | Coral footprints | Dev A |
| `autoload/game.gd` | `Game` service locator | shared (frozen) |
| `entities/view_follower.gd` | Screen visual tracking a world node | shared |
| `entities/placeholder_shape.gd` | Flat-colour projected placeholder art | shared |
| `entities/cell_shapes.gd` | Per-cell collision helper | shared |
| `entities/entity_factory.gd` | Only entity spawner | shared (frozen signatures) |
| `entities/coral/coral.gd`, `algae/algae.gd`, `nest/nest.gd` | Stubs honouring the contract | Dev A |
| `entities/fish/fish.gd` | Stub honouring the contract | Dev B |
| `levels/level_01.gd` | Fixed starting map | Dev A |
| `main/main.gd`, `main/main.tscn`, `main/ground.gd` | Node tree, walls, seabed | Dev A |
| `main/dev_a_systems.gd` | Dev A systems/UI entry point | Dev A |
| `main/dev_b_systems.gd` | Dev B systems/UI entry point | Dev B |
| `project.godot` | Main scene, autoload, viewport, layer names | shared (announce changes) |

> Deviation from GDD §10, agreed for parallel work: entities are script classes (not `.tscn`), the level is a data script (`levels/level_01.gd`) instead of `Level01.tscn`, the projection class is `ViewProjection` (the `View` name is taken by the screen node), and balance is split in two resources (one per developer).

---

### Task 1: Feature branch and headless test runner

**Files:**
- Create: `tests/test_case.gd`, `tests/run_tests.gd`, `tools/test.sh`, `tools/smoke.sh`, `tests/unit/test_sanity.gd`

- [ ] **Step 1: Create the feature branch**

```bash
git switch main && git pull origin main
git switch -c "$(gh api user -q .login)/p0-foundation"
```

- [ ] **Step 2: Create `tests/test_case.gd`**

```gdscript
class_name TestCase
extends RefCounted
## Base class for unit tests. Methods whose name starts with `test_` are run
## by tests/run_tests.gd, each on a fresh instance.

var failures: Array[String] = []


## Called before every test method. Override to build fixtures.
func before_each() -> void:
	pass


func assert_true(value: bool, msg: String = "") -> void:
	if not value:
		failures.append("expected true. %s" % msg)


func assert_false(value: bool, msg: String = "") -> void:
	if value:
		failures.append("expected false. %s" % msg)


func assert_eq(actual: Variant, expected: Variant, msg: String = "") -> void:
	if not (typeof(actual) == typeof(expected) and actual == expected):
		failures.append("expected %s (%s), got %s (%s). %s" % [
			str(expected), type_string(typeof(expected)),
			str(actual), type_string(typeof(actual)), msg])


func assert_almost(actual: Variant, expected: Variant, eps: float = 0.001, msg: String = "") -> void:
	var ok := false
	if actual is float or actual is int:
		ok = absf(float(actual) - float(expected)) <= eps
	elif actual is Vector2:
		ok = (actual as Vector2).distance_to(expected) <= eps
	if not ok:
		failures.append("expected ~%s, got %s. %s" % [str(expected), str(actual), msg])
```

- [ ] **Step 3: Create `tests/run_tests.gd`**

```gdscript
extends SceneTree
## Minimal headless test runner.
## Usage: tools/test.sh  (or: godot --headless --path . -s res://tests/run_tests.gd)
## Runs every `test_*` method of every tests/unit/test_*.gd script.

const TEST_DIR := "res://tests/unit"


func _initialize() -> void:
	var passed := 0
	var failed := 0
	for path in _collect_test_files():
		var script: GDScript = load(path)
		for method in script.get_script_method_list():
			var test_name: String = method["name"]
			if not test_name.begins_with("test_"):
				continue
			var test: TestCase = script.new()
			test.before_each()
			test.call(test_name)
			if test.failures.is_empty():
				passed += 1
			else:
				failed += 1
				for failure in test.failures:
					printerr("FAIL %s::%s - %s" % [path.get_file(), test_name, failure])
	print("%d passed, %d failed" % [passed, failed])
	quit(1 if failed > 0 else 0)


func _collect_test_files() -> Array[String]:
	var files: Array[String] = []
	for file in DirAccess.get_files_at(TEST_DIR):
		if file.begins_with("test_") and file.ends_with(".gd"):
			files.append("%s/%s" % [TEST_DIR, file])
	files.sort()
	return files
```

- [ ] **Step 4: Create `tools/test.sh` and `tools/smoke.sh`, make them executable**

`tools/test.sh`:
```bash
#!/usr/bin/env bash
# Runs all unit tests headless. Override the binary with GODOT=/path/to/godot.
set -euo pipefail
GODOT="${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}"
cd "$(dirname "$0")/.."
"$GODOT" --headless --path . --import >/dev/null 2>&1 || true
"$GODOT" --headless --path . -s res://tests/run_tests.gd
```

`tools/smoke.sh`:
```bash
#!/usr/bin/env bash
# Boots the main scene headless for ~5 s of frames and fails on any script error.
set -euo pipefail
GODOT="${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}"
cd "$(dirname "$0")/.."
"$GODOT" --headless --path . --import >/dev/null 2>&1 || true
OUT="$("$GODOT" --headless --path . --quit-after 300 2>&1)"
if grep -E "SCRIPT ERROR|Parse Error|ERROR:" <<<"$OUT"; then
	echo "SMOKE FAILED"
	exit 1
fi
echo "SMOKE OK"
```

```bash
chmod +x tools/test.sh tools/smoke.sh
```

- [ ] **Step 5: Write a failing sanity test** in `tests/unit/test_sanity.gd`

```gdscript
extends TestCase


func test_runner_reports_failures() -> void:
	assert_eq(1 + 1, 3)
```

- [ ] **Step 6: Run it and verify the runner fails**

Run: `tools/test.sh; echo "exit=$?"`
Expected: `FAIL test_sanity.gd::test_runner_reports_failures - expected 3 (int), got 2 (int).`, `0 passed, 1 failed`, `exit=1`

- [ ] **Step 7: Fix the expectation to `2` and run again**

Run: `tools/test.sh; echo "exit=$?"`
Expected: `1 passed, 0 failed`, `exit=0`

- [ ] **Step 8: Delete the sanity test and commit**

```bash
rm tests/unit/test_sanity.gd
git add tests tools
git commit -m "Add headless GDScript test runner and smoke script"
```

---

### Task 2: Physics layers and group names

**Files:**
- Create: `core/layers.gd`, `core/groups.gd`
- Modify: `project.godot` (add `[layer_names]`)

- [ ] **Step 1: Create `core/layers.gd`**

```gdscript
class_name Layers
extends RefCounted
## 2D physics layer bits. Must match [layer_names] in project.godot.

const WALL := 1
const CORAL := 2
const ALGAE := 4
const FISH := 8
const NEST := 16
const THREAT := 32
```

- [ ] **Step 2: Create `core/groups.gd`**

```gdscript
class_name Groups
extends RefCounted
## Scene-tree group names. GameState counts populations through these groups.

const CORALS := &"corals"
const ALGAE := &"algae"
const FISH := &"fish"
const NESTS := &"nests"
const THREATS := &"threats"
```

- [ ] **Step 3: Add layer names to `project.godot`** (insert before `[physics]`)

```ini
[layer_names]

2d_physics/layer_1="wall"
2d_physics/layer_2="coral"
2d_physics/layer_3="algae"
2d_physics/layer_4="fish"
2d_physics/layer_5="nest"
2d_physics/layer_6="threat"
```

- [ ] **Step 4: Commit**

```bash
git add core project.godot
git commit -m "Add physics layer and group constants"
```

---

### Task 3: GridModel

**Files:**
- Create: `core/grid_model.gd`
- Test: `tests/unit/test_grid_model.gd`

- [ ] **Step 1: Write the failing tests**

```gdscript
extends TestCase

var grid: GridModel


func before_each() -> void:
	grid = GridModel.new(Vector2i(4, 3), 32.0)


func test_in_bounds() -> void:
	assert_true(grid.in_bounds(Vector2i(0, 0)))
	assert_true(grid.in_bounds(Vector2i(3, 2)))
	assert_false(grid.in_bounds(Vector2i(4, 0)))
	assert_false(grid.in_bounds(Vector2i(0, -1)))


func test_out_of_bounds_is_not_free() -> void:
	assert_false(grid.is_free(Vector2i(-1, 0)))


func test_occupy_and_release() -> void:
	var entity := RefCounted.new()
	var cells: Array[Vector2i] = [Vector2i(1, 1), Vector2i(2, 1)]
	grid.occupy(cells, entity)
	assert_false(grid.is_free(Vector2i(1, 1)))
	assert_eq(grid.occupant(Vector2i(2, 1)), entity)
	assert_false(grid.are_free(cells))
	grid.release(cells)
	assert_true(grid.are_free(cells))
	assert_eq(grid.occupant(Vector2i(1, 1)), null)


func test_cell_world_conversion() -> void:
	assert_almost(grid.cell_to_world(Vector2i(1, 2)), Vector2(48, 80))
	assert_eq(grid.world_to_cell(Vector2(48, 80)), Vector2i(1, 2))
	assert_eq(grid.world_to_cell(Vector2(31.9, 0)), Vector2i(0, 0))
	assert_eq(grid.world_to_cell(Vector2(-0.1, 0)), Vector2i(-1, 0))


func test_world_size() -> void:
	assert_almost(grid.world_size(), Vector2(128, 96))


func test_neighbors4() -> void:
	var n := grid.neighbors4(Vector2i(0, 0))
	assert_eq(n.size(), 4)
	assert_true(n.has(Vector2i(1, 0)))
	assert_true(n.has(Vector2i(0, -1)))


func test_count_cells_with_predicate() -> void:
	var a := RefCounted.new()
	var b := RefCounted.new()
	var cells_a: Array[Vector2i] = [Vector2i(0, 0), Vector2i(1, 0)]
	var cells_b: Array[Vector2i] = [Vector2i(3, 2)]
	grid.occupy(cells_a, a)
	grid.occupy(cells_b, b)
	assert_eq(grid.count_cells(func(e): return e == a), 2)
	assert_eq(grid.count_cells(func(e): return true), 3)
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `tools/test.sh`
Expected: script error `Identifier "GridModel" not declared` / non-zero exit.

- [ ] **Step 3: Implement `core/grid_model.gd`**

```gdscript
class_name GridModel
extends RefCounted
## Logical placement grid for static entities (corals, algae, nests).
## One static entity per cell. Cell (0,0) is the top-left of the world;
## world coordinates are logical units (top-down), not screen pixels.

const NEIGHBORS_4: Array[Vector2i] = [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]

var size: Vector2i
var cell_size: float
var _cells: Dictionary = {} # Vector2i -> Object


func _init(p_size: Vector2i, p_cell_size: float) -> void:
	size = p_size
	cell_size = p_cell_size


func in_bounds(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < size.x and cell.y < size.y


func is_free(cell: Vector2i) -> bool:
	return in_bounds(cell) and not _cells.has(cell)


func are_free(cells: Array[Vector2i]) -> bool:
	for cell in cells:
		if not is_free(cell):
			return false
	return true


## Returns the entity occupying `cell`, or null.
func occupant(cell: Vector2i) -> Object:
	return _cells.get(cell)


## Marks `cells` as occupied by `entity`. All cells must be free.
func occupy(cells: Array[Vector2i], entity: Object) -> void:
	assert(are_free(cells), "GridModel.occupy: cells not free %s" % [cells])
	for cell in cells:
		_cells[cell] = entity


func release(cells: Array[Vector2i]) -> void:
	for cell in cells:
		_cells.erase(cell)


## Number of occupied cells whose occupant satisfies `predicate(occupant) -> bool`.
func count_cells(predicate: Callable) -> int:
	var count := 0
	for entity in _cells.values():
		if predicate.call(entity):
			count += 1
	return count


## World position of the cell centre.
func cell_to_world(cell: Vector2i) -> Vector2:
	return (Vector2(cell) + Vector2(0.5, 0.5)) * cell_size


func world_to_cell(point: Vector2) -> Vector2i:
	return Vector2i(floori(point.x / cell_size), floori(point.y / cell_size))


func world_size() -> Vector2:
	return Vector2(size) * cell_size


## The 4 orthogonal neighbours (may be out of bounds; callers check).
func neighbors4(cell: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for offset in NEIGHBORS_4:
		result.append(cell + offset)
	return result
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `tools/test.sh`
Expected: `7 passed, 0 failed`

- [ ] **Step 5: Commit**

```bash
git add core/grid_model.gd tests/unit/test_grid_model.gd
git commit -m "Add GridModel for static entity cell occupancy"
```

---

### Task 4: ViewSettings and ViewProjection

**Files:**
- Create: `data/view_settings.gd`, `data/view_settings.tres`, `core/view_projection.gd`
- Test: `tests/unit/test_view_projection.gd`

- [ ] **Step 1: Write the failing tests**

```gdscript
extends TestCase


func test_oblique_projection() -> void:
	var p := ViewProjection.new(Vector2(1, 0), Vector2(-0.5, 0.5), 1.0)
	assert_almost(p.to_screen(Vector2(10, 0)), Vector2(10, 0))
	assert_almost(p.to_screen(Vector2(0, 10)), Vector2(-5, 5))


func test_round_trip() -> void:
	var p := ViewProjection.new(Vector2(1, 0), Vector2(-0.5, 0.5), 1.5)
	var world := Vector2(123.4, 56.7)
	assert_almost(p.to_world(p.to_screen(world)), world)


func test_top_down_is_scale_only() -> void:
	var p := ViewProjection.new(Vector2(1, 0), Vector2(0, 1), 2.0)
	assert_almost(p.to_screen(Vector2(3, 4)), Vector2(6, 8))


func test_project_polygon_is_relative_to_anchor() -> void:
	var p := ViewProjection.new(Vector2(1, 0), Vector2(0, 1), 1.0)
	var poly := p.project_polygon(PackedVector2Array([Vector2(10, 10), Vector2(12, 10)]), Vector2(10, 10))
	assert_almost(poly[0], Vector2.ZERO)
	assert_almost(poly[1], Vector2(2, 0))


func test_from_settings_resource() -> void:
	var settings: ViewSettings = load("res://data/view_settings.tres")
	var p := ViewProjection.from_settings(settings)
	assert_almost(p.to_screen(Vector2(0, 2)), Vector2(-1.25, 1.25))
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `tools/test.sh`
Expected: errors about `ViewProjection` / `ViewSettings` not declared.

- [ ] **Step 3: Create `data/view_settings.gd`**

```gdscript
class_name ViewSettings
extends Resource
## Camera projection parameters, tuned by the designer (GDD §4.1).

@export var x_axis := Vector2(1, 0)
@export var y_axis := Vector2(-0.5, 0.5)
@export var pixels_per_unit := 1.25
```

- [ ] **Step 4: Create `data/view_settings.tres`**

```ini
[gd_resource type="Resource" script_class="ViewSettings" format=3]

[ext_resource type="Script" path="res://data/view_settings.gd" id="1"]

[resource]
script = ExtResource("1")
x_axis = Vector2(1, 0)
y_axis = Vector2(-0.5, 0.5)
pixels_per_unit = 1.25
```

- [ ] **Step 5: Implement `core/view_projection.gd`**

```gdscript
class_name ViewProjection
extends RefCounted
## Affine projection from the logical top-down world to screen space.
## screen = world.x * x_axis + world.y * y_axis (scaled by pixels_per_unit).
## Default oblique "/__/" view: x_axis = (1, 0), y_axis = (-0.5, 0.5).

var _to_screen: Transform2D
var _to_world: Transform2D


func _init(x_axis: Vector2, y_axis: Vector2, pixels_per_unit: float, origin: Vector2 = Vector2.ZERO) -> void:
	_to_screen = Transform2D(x_axis * pixels_per_unit, y_axis * pixels_per_unit, origin)
	_to_world = _to_screen.affine_inverse()


static func from_settings(settings: ViewSettings) -> ViewProjection:
	return ViewProjection.new(settings.x_axis, settings.y_axis, settings.pixels_per_unit)


func to_screen(world: Vector2) -> Vector2:
	return _to_screen * world


func to_world(screen: Vector2) -> Vector2:
	return _to_world * screen


## Projects a world-space polygon (e.g. a cell's 4 corners) to screen space,
## relative to the projection of `anchor`. Used to draw shapes around a ViewFollower.
func project_polygon(points: PackedVector2Array, anchor: Vector2) -> PackedVector2Array:
	var result := PackedVector2Array()
	var anchor_screen := to_screen(anchor)
	for point in points:
		result.append(to_screen(point) - anchor_screen)
	return result
```

- [ ] **Step 6: Run tests to verify they pass**

Run: `tools/test.sh`
Expected: `12 passed, 0 failed`

- [ ] **Step 7: Commit**

```bash
git add core/view_projection.gd data/view_settings.* tests/unit/test_view_projection.gd
git commit -m "Add parametric oblique view projection"
```

---

### Task 5: Balance resources and coral shapes

**Files:**
- Create: `data/balance_ecosystem.gd/.tres`, `data/balance_actors.gd/.tres`, `data/coral_shapes.gd`
- Test: `tests/unit/test_coral_shapes.gd`

- [ ] **Step 1: Write the failing tests**

```gdscript
extends TestCase


func test_cells_are_offset_from_origin() -> void:
	var cells := CoralShapes.cells_at(&"domino", Vector2i(3, 4))
	assert_eq(cells.size(), 2)
	assert_true(cells.has(Vector2i(3, 4)))
	assert_true(cells.has(Vector2i(4, 4)))


func test_all_shapes_include_origin() -> void:
	for id in CoralShapes.ids():
		assert_true(CoralShapes.cells_at(id, Vector2i.ZERO).has(Vector2i.ZERO), str(id))


func test_balance_resources_load_with_defaults() -> void:
	var eco: BalanceEcosystem = load("res://data/balance_ecosystem.tres")
	var actors: BalanceActors = load("res://data/balance_actors.tres")
	assert_eq(eco.grid_size, Vector2i(20, 20))
	assert_almost(actors.collapse_grace_seconds, 10.0)
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `tools/test.sh`
Expected: errors about `CoralShapes` / `BalanceEcosystem` not declared.

- [ ] **Step 3: Create `data/balance_ecosystem.gd`** (all Dev A tunables from the GDD)

```gdscript
class_name BalanceEcosystem
extends Resource
## Tunables owned by Dev A (grid, corals, algae, nests, inventory, temperature).
## Values from GDD; tweak in data/balance_ecosystem.tres.

@export_group("Grid")
@export var grid_size := Vector2i(20, 20)
@export var cell_size := 32.0

@export_group("Coral")
@export var coral_max_oxygen := 100.0
@export var coral_regen_per_sec := 0.5

@export_group("Algae")
@export var algae_growth_interval_cold := 12.0
@export var algae_growth_interval_hot := 4.0
@export var algae_growth_jitter := 0.2
@export var algae_max_count := 200
@export var algae_coral_damage := 10.0

@export_group("Nest")
@export var nest_hatch_seconds := 20.0
@export var nest_hatch_count := 3

@export_group("Inventory")
@export var inventory_slots := 4
@export var slot_refill_seconds := 8.0
@export var weight_coral := 50.0
@export var weight_algae := 40.0
@export var nest_base_weight := 20.0

@export_group("Temperature")
## Normalised temperature per second with no corals: reaches 1.0 in ~8 minutes.
@export var temp_base_rate := 1.0 / 480.0
@export var temp_slow_per_cell := 0.03
@export var temp_max_slowdown := 0.6
@export var temp_display_min_c := 26.0
@export var temp_display_max_c := 32.0
```

- [ ] **Step 4: Create `data/balance_actors.gd`** (all Dev B tunables from the GDD)

```gdscript
class_name BalanceActors
extends Resource
## Tunables owned by Dev B (fish, threats, collapse rules).
## Values from GDD; tweak in data/balance_actors.tres.

@export_group("Fish")
@export var fish_radius := 10.0
@export var fish_click_radius := 24.0
@export var fish_speed := 60.0
## Speed multiplier at temperature 1.0 (linear from 1.0 at temperature 0).
@export var fish_speed_hot_factor := 0.5
@export var fish_wander_min_seconds := 1.5
@export var fish_wander_max_seconds := 4.0
@export var idle_after_order_seconds := 2.0
@export var eat_seconds := 3.0
@export var fertilize_seconds := 3.0
@export var starve_seconds := 60.0
@export var hunger_bar_threshold := 0.5
@export var maturity_seconds := 45.0

@export_group("Collapse")
@export var collapse_grace_seconds := 10.0

@export_group("Threats")
@export var threat_warning_seconds := 2.5
@export var co2_radius := 60.0
@export var co2_speed := 40.0
## Max random heading change in radians per second.
@export var co2_turn_noise := 0.6
@export var co2_interval_cold := 30.0
@export var co2_interval_hot := 8.0
@export var co2_coral_damage := 50.0
@export var bag_radius := 16.0
@export var bag_speed := 20.0
@export var bag_turn_noise := 2.0
@export var bag_interval := 40.0
@export var bag_coral_damage := 35.0
@export var cyclone_radius := 40.0
@export var cyclone_speed := 160.0
@export var cyclone_interval_cold := 90.0
@export var cyclone_interval_hot := 30.0
```

- [ ] **Step 5: Create the two `.tres` files** (empty overrides; defaults come from the scripts, designers tweak them in the Inspector)

`data/balance_ecosystem.tres`:
```ini
[gd_resource type="Resource" script_class="BalanceEcosystem" format=3]

[ext_resource type="Script" path="res://data/balance_ecosystem.gd" id="1"]

[resource]
script = ExtResource("1")
```

`data/balance_actors.tres`:
```ini
[gd_resource type="Resource" script_class="BalanceActors" format=3]

[ext_resource type="Script" path="res://data/balance_actors.gd" id="1"]

[resource]
script = ExtResource("1")
```

- [ ] **Step 6: Create `data/coral_shapes.gd`**

```gdscript
class_name CoralShapes
extends RefCounted
## Coral footprints as cell offsets from the coral origin cell (GDD §5.2).

const SHAPES := {
	&"single": [Vector2i(0, 0)],
	&"domino": [Vector2i(0, 0), Vector2i(1, 0)],
	&"ell": [Vector2i(0, 0), Vector2i(0, 1), Vector2i(1, 1)],
	&"square": [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)],
	&"tee": [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(1, 1)],
}


static func ids() -> Array[StringName]:
	var result: Array[StringName] = []
	for id in SHAPES.keys():
		result.append(id)
	return result


## Absolute cells covered by shape `id` placed with its origin at `origin`.
static func cells_at(id: StringName, origin: Vector2i) -> Array[Vector2i]:
	assert(SHAPES.has(id), "Unknown coral shape %s" % id)
	var result: Array[Vector2i] = []
	for offset in SHAPES[id]:
		result.append(origin + offset)
	return result
```

- [ ] **Step 7: Run tests to verify they pass**

Run: `tools/test.sh`
Expected: `15 passed, 0 failed`

- [ ] **Step 8: Commit**

```bash
git add data tests/unit/test_coral_shapes.gd
git commit -m "Add balance resources and coral shapes"
```

---

### Task 6: Input actions and the Game autoload

**Files:**
- Create: `core/input_actions.gd`, `autoload/game.gd`
- Modify: `project.godot` (autoload, viewport size)

- [ ] **Step 1: Create `core/input_actions.gd`**

```gdscript
class_name InputActions
extends RefCounted
## Registers the input map in code (avoids hand-editing project.godot).

const COMMAND := &"command" # left click: select fish / give order / confirm placement
const CANCEL := &"cancel" # right click or Esc: cancel placement / deselect
const PAUSE := &"pause" # Space or Esc (Esc only when nothing to cancel)
const DEBUG_OVERLAY := &"debug_overlay" # F3


static func register() -> void:
	_add_mouse(COMMAND, MOUSE_BUTTON_LEFT)
	_add_mouse(CANCEL, MOUSE_BUTTON_RIGHT)
	_add_key(CANCEL, KEY_ESCAPE)
	_add_key(PAUSE, KEY_SPACE)
	_add_key(PAUSE, KEY_ESCAPE)
	_add_key(DEBUG_OVERLAY, KEY_F3)


static func _ensure(action: StringName) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)


static func _add_key(action: StringName, keycode: Key) -> void:
	_ensure(action)
	var event := InputEventKey.new()
	event.physical_keycode = keycode
	InputMap.action_add_event(action, event)


static func _add_mouse(action: StringName, button: MouseButton) -> void:
	_ensure(action)
	var event := InputEventMouseButton.new()
	event.button_index = button
	InputMap.action_add_event(action, event)
```

- [ ] **Step 2: Create `autoload/game.gd`**

`Game` is the shared contract between the two tracks. Fields set by Main: `world`, `view`, `ui`, `factory`. `temperature` is written only by Dev A's `TemperatureSystem` (stays `0.0` until phase 3). `placing` is written only by Dev A's placement controller and read by Dev B's fish commander.

```gdscript
extends Node
## Global service locator (autoload "Game"). Shared contract: change only
## after telling the other developer.

signal temperature_changed(value: float)

const ECOSYSTEM: BalanceEcosystem = preload("res://data/balance_ecosystem.tres")
const ACTORS: BalanceActors = preload("res://data/balance_actors.tres")
const VIEW_SETTINGS: ViewSettings = preload("res://data/view_settings.tres")

var eco: BalanceEcosystem = ECOSYSTEM
var actors: BalanceActors = ACTORS
var grid: GridModel
var projection: ViewProjection
## Logical physics world (top-down). Set by Main. Entities live here.
var world: Node2D
## Y-sorted screen-space node holding all visuals. Set by Main.
var view: Node2D
## UI CanvasLayer. Set by Main.
var ui: CanvasLayer
var factory: EntityFactory
## True while the player is placing an inventory item (fish orders are ignored).
var placing := false
## Normalised temperature 0..1. Written only by Dev A's TemperatureSystem.
var temperature := 0.0:
	set(value):
		temperature = value
		temperature_changed.emit(value)

var _actions_registered := false


func _ready() -> void:
	if not _actions_registered:
		InputActions.register()
		_actions_registered = true
	reset()


## Fresh state for a new run. Called by Main._ready (also after a restart).
func reset() -> void:
	grid = GridModel.new(eco.grid_size, eco.cell_size)
	projection = ViewProjection.from_settings(VIEW_SETTINGS)
	placing = false
	temperature = 0.0
	get_tree().paused = false


## Mouse position in logical world coordinates.
func mouse_world() -> Vector2:
	return projection.to_world(view.get_global_mouse_position())


## Linear interpolation by current temperature (cold value at 0, hot value at 1).
func by_temperature(cold: float, hot: float) -> float:
	return lerpf(cold, hot, clampf(temperature, 0.0, 1.0))
```

- [ ] **Step 3: Register the autoload and the viewport in `project.godot`**

Add after the `[application]` section:

```ini
[autoload]

Game="*res://autoload/game.gd"
```

and in `[display]` add:

```ini
window/size/viewport_width=1280
window/size/viewport_height=720
```

- [ ] **Step 4: Run tests (they must still pass with the autoload loaded)**

Run: `tools/test.sh`
Expected: `15 passed, 0 failed`

- [ ] **Step 5: Commit**

```bash
git add core/input_actions.gd autoload project.godot
git commit -m "Add Game service autoload and input actions"
```

---

### Task 7: Visual helpers (ViewFollower, PlaceholderShape, CellShapes)

**Files:**
- Create: `entities/view_follower.gd`, `entities/placeholder_shape.gd`, `entities/cell_shapes.gd`

These need a live scene tree, so they are verified by the smoke test and screenshot in Task 9.

- [ ] **Step 1: Create `entities/view_follower.gd`**

```gdscript
class_name ViewFollower
extends Node2D
## Screen-space visual that tracks a logical-world node through the projection.
## Lives under Game.view (y-sorted); freed automatically with its target.

var target: Node2D


## Creates a follower for `p_target`, parents `visual` to it and adds it to Game.view.
static func attach(p_target: Node2D, visual: Node2D) -> ViewFollower:
	var follower := ViewFollower.new()
	follower.target = p_target
	follower.add_child(visual)
	Game.view.add_child(follower)
	follower.sync_position()
	p_target.tree_exiting.connect(follower.queue_free)
	return follower


func _process(_delta: float) -> void:
	if is_instance_valid(target):
		sync_position()


func sync_position() -> void:
	position = Game.projection.to_screen(target.global_position)
```

- [ ] **Step 2: Create `entities/placeholder_shape.gd`**

```gdscript
class_name PlaceholderShape
extends Node2D
## Flat-colour placeholder visual drawn in screen space (until real art lands).
## Build with the static helpers so world shapes are projected correctly.

var polygon := PackedVector2Array()
var color := Color.WHITE:
	set(value):
		color = value
		queue_redraw()


## A full grid cell centred on `center_world`.
static func cell(center_world: Vector2, p_color: Color) -> PlaceholderShape:
	var half := Game.grid.cell_size * 0.5
	var corners := PackedVector2Array([
		center_world + Vector2(-half, -half), center_world + Vector2(half, -half),
		center_world + Vector2(half, half), center_world + Vector2(-half, half)])
	return _make(Game.projection.project_polygon(corners, center_world), p_color)


## A circle of `radius` world units centred on `center_world` (an ellipse on screen).
static func circle(center_world: Vector2, radius: float, p_color: Color) -> PlaceholderShape:
	var points := PackedVector2Array()
	for i in 16:
		points.append(center_world + Vector2.from_angle(TAU * i / 16.0) * radius)
	return _make(Game.projection.project_polygon(points, center_world), p_color)


static func _make(p_polygon: PackedVector2Array, p_color: Color) -> PlaceholderShape:
	var shape := PlaceholderShape.new()
	shape.polygon = p_polygon
	shape.color = p_color
	return shape


func _draw() -> void:
	draw_colored_polygon(polygon, color)
```

- [ ] **Step 3: Create `entities/cell_shapes.gd`**

```gdscript
class_name CellShapes
extends RefCounted
## Helpers for static entities built out of grid cells.


## Adds one square CollisionShape2D per cell to `body`, positioned relative to
## the body (which must already sit at `Game.grid.cell_to_world(origin)`).
static func add_collision(body: CollisionObject2D, cells: Array[Vector2i], origin: Vector2i) -> void:
	var size := Game.grid.cell_size
	for cell in cells:
		var rect := RectangleShape2D.new()
		rect.size = Vector2(size, size)
		var shape := CollisionShape2D.new()
		shape.shape = rect
		shape.position = Vector2(cell - origin) * size
		body.add_child(shape)
```

- [ ] **Step 4: Commit**

```bash
git add entities/view_follower.gd entities/placeholder_shape.gd entities/cell_shapes.gd
git commit -m "Add view follower and placeholder visuals"
```

---

### Task 8: Entity contract stubs and EntityFactory

**Files:**
- Create: `entities/coral/coral.gd`, `entities/algae/algae.gd`, `entities/nest/nest.gd`, `entities/fish/fish.gd`, `entities/entity_factory.gd`

**The contract (frozen; both tracks code against it):**

| Entity | Group | Layer | Public API |
|---|---|---|---|
| `Coral` (StaticBody2D) | `corals` | CORAL | `cells`, `oxygen`, `apply_oxygen_damage(amount)`, `destroy()`, signal `destroyed` |
| `Algae` (StaticBody2D) | `algae` | ALGAE | `cell`, `on_co2_absorbed()`, `destroy()`, signal `destroyed` |
| `Nest` (Area2D) | `nests` | NEST | `cell`, `is_empty()`, `has_eggs()`, `fertilize()`, `kill_eggs()`, `eggs_time_left()`, `destroy()`, signal `destroyed` |
| `Fish` (CharacterBody2D) | `fish` | FISH (mask WALL\|CORAL\|ALGAE) | `setup(world_position, adult)`, `is_adult()`, `destroy()`, signal `destroyed` |

Rules: `destroy()` is idempotent, removes the node from its group **immediately** (so population counts are correct in the same frame), releases its grid cells, emits `destroyed`, then `queue_free()`s. Only `EntityFactory` instantiates entities.

- [ ] **Step 1: Create `entities/coral/coral.gd`**

```gdscript
class_name Coral
extends StaticBody2D
## Coral: multi-cell static obstacle with oxygen. It only "suffers" (GDD §5.2).
## CONTRACT (used by Dev B threats): cells, apply_oxygen_damage(), destroy().

signal destroyed

var shape_id: StringName
var origin_cell: Vector2i
var cells: Array[Vector2i] = []
var oxygen := 0.0


func setup(p_shape_id: StringName, p_origin_cell: Vector2i) -> void:
	shape_id = p_shape_id
	origin_cell = p_origin_cell
	cells = CoralShapes.cells_at(shape_id, origin_cell)


func _ready() -> void:
	position = Game.grid.cell_to_world(origin_cell)
	collision_layer = Layers.CORAL
	collision_mask = 0
	add_to_group(Groups.CORALS)
	Game.grid.occupy(cells, self)
	CellShapes.add_collision(self, cells, origin_cell)
	oxygen = Game.eco.coral_max_oxygen
	_build_visuals()


## One follower per cell so each cell y-sorts on its own (GDD §4.1).
func _build_visuals() -> void:
	for cell in cells:
		var marker := Marker2D.new()
		marker.position = Vector2(cell - origin_cell) * Game.grid.cell_size
		add_child(marker)
		ViewFollower.attach(marker, PlaceholderShape.cell(Game.grid.cell_to_world(cell), Color(1.0, 0.45, 0.55)))


## Instant damage on contact. Kills the coral at 0 oxygen.
func apply_oxygen_damage(amount: float) -> void:
	if is_queued_for_deletion():
		return
	oxygen = maxf(oxygen - amount, 0.0)
	if oxygen <= 0.0:
		destroy()


func destroy() -> void:
	if is_queued_for_deletion():
		return
	remove_from_group(Groups.CORALS)
	Game.grid.release(cells)
	destroyed.emit()
	queue_free()
```

- [ ] **Step 2: Create `entities/algae/algae.gd`**

```gdscript
class_name Algae
extends StaticBody2D
## Algae: single-cell obstacle that spreads and suffocates corals (GDD §5.3).
## CONTRACT (used by Dev B fish/threats): cell, on_co2_absorbed(), destroy().

signal destroyed

var cell: Vector2i


func setup(p_cell: Vector2i) -> void:
	cell = p_cell


func _ready() -> void:
	position = Game.grid.cell_to_world(cell)
	collision_layer = Layers.ALGAE
	collision_mask = 0
	add_to_group(Groups.ALGAE)
	Game.grid.occupy([cell], self)
	CellShapes.add_collision(self, [cell], cell)
	ViewFollower.attach(self, PlaceholderShape.cell(position, Color(0.3, 0.8, 0.35)))


## Called by a CO2 cloud that touches this algae: the cloud is absorbed and the
## algae expands immediately. Implemented by Dev A in the algae plan.
func on_co2_absorbed() -> void:
	pass


func destroy() -> void:
	if is_queued_for_deletion():
		return
	remove_from_group(Groups.ALGAE)
	Game.grid.release([cell])
	destroyed.emit()
	queue_free()
```

- [ ] **Step 3: Create `entities/nest/nest.gd`**

```gdscript
class_name Nest
extends Area2D
## Nest: single-cell area fish swim over (GDD §5.5).
## CONTRACT (used by Dev B fish/threats): cell, is_empty(), has_eggs(),
## fertilize(), kill_eggs(), eggs_time_left(), destroy().

signal destroyed

enum State { EMPTY, EGGS }

var cell: Vector2i
var state := State.EMPTY


func setup(p_cell: Vector2i) -> void:
	cell = p_cell


func _ready() -> void:
	position = Game.grid.cell_to_world(cell)
	collision_layer = Layers.NEST
	collision_mask = 0
	monitoring = false
	monitorable = true
	add_to_group(Groups.NESTS)
	Game.grid.occupy([cell], self)
	CellShapes.add_collision(self, [cell], cell)
	ViewFollower.attach(self, PlaceholderShape.cell(position, Color(0.95, 0.85, 0.4)))


func is_empty() -> bool:
	return state == State.EMPTY


func has_eggs() -> bool:
	return state == State.EGGS


## Called by a fish that stayed on the nest for fertilize_seconds.
func fertilize() -> void:
	if is_empty():
		state = State.EGGS


## Called by CO2: eggs die, nest becomes empty.
func kill_eggs() -> void:
	state = State.EMPTY


## Seconds until the eggs hatch, or -1.0 if there are no eggs.
func eggs_time_left() -> float:
	return -1.0


func destroy() -> void:
	if is_queued_for_deletion():
		return
	remove_from_group(Groups.NESTS)
	Game.grid.release([cell])
	destroyed.emit()
	queue_free()
```

- [ ] **Step 4: Create `entities/fish/fish.gd`**

```gdscript
class_name Fish
extends CharacterBody2D
## Fish: free-moving actor (GDD §5.4). Stub until Dev B's fish plan.
## CONTRACT (used by Dev A nest, Dev B threats): setup(), is_adult(), destroy().

signal destroyed

var adult := true


func setup(world_position: Vector2, p_adult: bool) -> void:
	position = world_position
	adult = p_adult


func _ready() -> void:
	collision_layer = Layers.FISH
	collision_mask = Layers.WALL | Layers.CORAL | Layers.ALGAE
	add_to_group(Groups.FISH)
	var circle := CircleShape2D.new()
	circle.radius = Game.actors.fish_radius
	var shape := CollisionShape2D.new()
	shape.shape = circle
	add_child(shape)
	ViewFollower.attach(self, PlaceholderShape.circle(position, Game.actors.fish_radius, Color(0.3, 0.7, 1.0)))


func is_adult() -> bool:
	return adult


func destroy() -> void:
	if is_queued_for_deletion():
		return
	remove_from_group(Groups.FISH)
	destroyed.emit()
	queue_free()
```

- [ ] **Step 5: Create `entities/entity_factory.gd`**

```gdscript
class_name EntityFactory
extends RefCounted
## The only place that instantiates gameplay entities. Adds them under Game.world.


func spawn_coral(shape_id: StringName, origin_cell: Vector2i) -> Coral:
	var coral := Coral.new()
	coral.setup(shape_id, origin_cell)
	Game.world.add_child(coral)
	return coral


func spawn_algae(cell: Vector2i) -> Algae:
	var algae := Algae.new()
	algae.setup(cell)
	Game.world.add_child(algae)
	return algae


func spawn_nest(cell: Vector2i) -> Nest:
	var nest := Nest.new()
	nest.setup(cell)
	Game.world.add_child(nest)
	return nest


func spawn_fish(world_position: Vector2, adult: bool) -> Fish:
	var fish := Fish.new()
	fish.setup(world_position, adult)
	Game.world.add_child(fish)
	return fish
```

- [ ] **Step 6: Run tests (class names must resolve)**

Run: `tools/test.sh`
Expected: `15 passed, 0 failed`

- [ ] **Step 7: Commit**

```bash
git add entities
git commit -m "Add entity contract stubs and entity factory"
```

---

### Task 9: Level01, Main scene and seabed

**Files:**
- Create: `levels/level_01.gd`, `main/main.gd`, `main/main.tscn`, `main/ground.gd`, `main/dev_a_systems.gd`, `main/dev_b_systems.gd`
- Modify: `project.godot` (main scene)

- [ ] **Step 1: Create `levels/level_01.gd`** (GDD §4: 5 corals, 5 algae, 1 nest, 3 adult fish)

```gdscript
class_name Level01
extends RefCounted
## Fixed starting map (GDD §4). Cells are in a 20x20 grid.

const CORALS := [
	[&"single", Vector2i(4, 4)],
	[&"domino", Vector2i(13, 3)],
	[&"ell", Vector2i(3, 13)],
	[&"square", Vector2i(14, 14)],
	[&"tee", Vector2i(8, 9)],
]
const ALGAE: Array[Vector2i] = [
	Vector2i(6, 4), Vector2i(7, 5), Vector2i(12, 6), Vector2i(5, 15), Vector2i(16, 12),
]
const NESTS: Array[Vector2i] = [Vector2i(10, 15)]
## Fish positions in cells (spawned at the cell centre, as adults).
const FISH: Array[Vector2i] = [Vector2i(9, 6), Vector2i(11, 12), Vector2i(6, 10)]


static func populate(factory: EntityFactory) -> void:
	for entry in CORALS:
		factory.spawn_coral(entry[0], entry[1])
	for cell in ALGAE:
		factory.spawn_algae(cell)
	for cell in NESTS:
		factory.spawn_nest(cell)
	for cell in FISH:
		factory.spawn_fish(Game.grid.cell_to_world(cell), true)
```

- [ ] **Step 2: Create `main/ground.gd`**

```gdscript
extends Node2D
## Draws the seabed parallelogram and, while placing, the grid lines.

const SEABED := Color(0.08, 0.22, 0.35)
const GRID_LINE := Color(1, 1, 1, 0.12)


func _ready() -> void:
	z_index = -100


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var size := Game.grid.world_size()
	var corners := PackedVector2Array([Vector2.ZERO, Vector2(size.x, 0), size, Vector2(0, size.y)])
	draw_colored_polygon(Game.projection.project_polygon(corners, Vector2.ZERO), SEABED)
	if not Game.placing:
		return
	var step := Game.grid.cell_size
	for x in Game.grid.size.x + 1:
		draw_line(Game.projection.to_screen(Vector2(x * step, 0)), Game.projection.to_screen(Vector2(x * step, size.y)), GRID_LINE)
	for y in Game.grid.size.y + 1:
		draw_line(Game.projection.to_screen(Vector2(0, y * step)), Game.projection.to_screen(Vector2(size.x, y * step)), GRID_LINE)
```

- [ ] **Step 3: Create the two per-developer entry points**

`main/dev_a_systems.gd`:
```gdscript
extends Node
## Dev A's systems and UI are added here (inventory, placement, temperature...).
## Only Dev A edits this file.


func _ready() -> void:
	pass
```

`main/dev_b_systems.gd`:
```gdscript
extends Node
## Dev B's systems and UI are added here (fish commander, population monitor,
## threat spawner, HUD...). Only Dev B edits this file.


func _ready() -> void:
	pass
```

- [ ] **Step 4: Create `main/main.gd`**

```gdscript
extends Node
## Builds the node tree described in GDD §10 and loads Level01.
## Main
## ├ World   (logical physics world, hidden)
## ├ Screen  (Ground + y-sorted View + Camera2D)
## ├ DevASystems / DevBSystems
## └ UI      (CanvasLayer)

const DevASystems := preload("res://main/dev_a_systems.gd")
const DevBSystems := preload("res://main/dev_b_systems.gd")
const Ground := preload("res://main/ground.gd")


func _ready() -> void:
	Game.reset()
	var world := Node2D.new()
	world.name = "World"
	world.visible = false
	add_child(world)

	var screen := Node2D.new()
	screen.name = "Screen"
	add_child(screen)
	var ground := Ground.new()
	ground.name = "Ground"
	screen.add_child(ground)
	var view := Node2D.new()
	view.name = "View"
	view.y_sort_enabled = true
	screen.add_child(view)
	var camera := Camera2D.new()
	camera.name = "Camera"
	camera.position = Game.projection.to_screen(Game.grid.world_size() * 0.5)
	screen.add_child(camera)

	var ui := CanvasLayer.new()
	ui.name = "UI"
	ui.process_mode = Node.PROCESS_MODE_ALWAYS

	Game.world = world
	Game.view = view
	Game.ui = ui
	Game.factory = EntityFactory.new()

	_build_walls(world)
	Level01.populate(Game.factory)

	var dev_a := DevASystems.new()
	dev_a.name = "DevASystems"
	add_child(dev_a)
	var dev_b := DevBSystems.new()
	dev_b.name = "DevBSystems"
	add_child(dev_b)
	add_child(ui)


## Four static walls just outside the world rectangle.
func _build_walls(world: Node2D) -> void:
	var size := Game.grid.world_size()
	var thickness := 64.0
	var walls := StaticBody2D.new()
	walls.name = "Walls"
	walls.collision_layer = Layers.WALL
	walls.collision_mask = 0
	var rects := [
		Rect2(-thickness, -thickness, size.x + thickness * 2, thickness), # top
		Rect2(-thickness, size.y, size.x + thickness * 2, thickness), # bottom
		Rect2(-thickness, 0, thickness, size.y), # left
		Rect2(size.x, 0, thickness, size.y), # right
	]
	for rect: Rect2 in rects:
		var shape := RectangleShape2D.new()
		shape.size = rect.size
		var collision := CollisionShape2D.new()
		collision.shape = shape
		collision.position = rect.get_center()
		walls.add_child(collision)
	world.add_child(walls)
```

- [ ] **Step 5: Create `main/main.tscn`**

```ini
[gd_scene format=3]

[ext_resource type="Script" path="res://main/main.gd" id="1"]

[node name="Main" type="Node"]
script = ExtResource("1")
```

- [ ] **Step 6: Set the main scene in `project.godot`** (in `[application]`)

```ini
run/main_scene="res://main/main.tscn"
```

- [ ] **Step 7: Run unit tests and the smoke test**

Run: `tools/test.sh && tools/smoke.sh`
Expected: `15 passed, 0 failed` then `SMOKE OK`

- [ ] **Step 8: Capture a frame and check it visually**

```bash
rm -rf /tmp/shot && mkdir /tmp/shot
/Applications/Godot.app/Contents/MacOS/Godot --path . --write-movie /tmp/shot/f.png --fixed-fps 30 --quit-after 10
open /tmp/shot/f00000009.png
```

Expected: a dark-blue parallelogram seabed slanting `/__/`, fully inside the 1280×720 frame; 5 pink corals (single, domino, L, 2×2 square, T), 5 green algae cells, 1 yellow nest cell, 3 small blue ellipses (fish).

- [ ] **Step 9: Commit**

```bash
git add levels main project.godot
git commit -m "Add Main scene, seabed and fixed Level01 map"
```

---

### Task 10: Integrate into main (git flow)

- [ ] **Step 1: Merge `main` into the branch and re-verify**

```bash
git fetch origin && git merge origin/main
tools/test.sh && tools/smoke.sh
```
Expected: `15 passed, 0 failed`, `SMOKE OK`. Also open the project in the Godot editor once and press F5: no errors in the Output panel.

- [ ] **Step 2: Merge to main, push, delete the branch**

```bash
BR="$(git branch --show-current)"
git switch main && git pull origin main
git merge "$BR" && git push origin main
git branch -d "$BR"
```

After this both developers start their tracks (see roadmap).
