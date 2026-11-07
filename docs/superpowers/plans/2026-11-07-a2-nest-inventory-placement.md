# A2 — Nest Cycle, Inventory and Placement Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give the player their tools (GDD M3 nest half + M4 inventory/placement): nests hatch juvenile fish after being fertilized; a 4-slot inventory refills each used slot after 8 s with a weighted random item (rarer nests when you already have some); the player places corals, algae and nests on the grid with a green/red ghost preview.

**Architecture:** Two pure rule classes — `NestCycle` (EMPTY → EGGS → hatch) and `InventoryModel` (slots, per-slot refill timers, weighted draw with injected RNG and nest counter) — unit-tested headless. Thin nodes drive them: the P0 `Nest` node, `InventorySystem` (ticks the model), `PlacementController` (ghost preview + input ownership while `Game.placing`, roadmap contract #8) and the `InventoryBar` UI. Everything is wired in `main/dev_a_systems.gd`.

**Tech Stack:** Godot 4.7.2, GDScript, headless test runner from P0.

**Owner:** Dev A. **Depends on:** P0 and A1 merged (`CellProbe`). **Runs in parallel with:** B2. Fish hatching uses the frozen `Game.factory.spawn_fish(position, adult)` contract, so it works with either the P0 fish stub or B1's real fish.

---

## Context for the engineer

- Read `docs/GDD.md` §5.1 (inventory), §5.5 (nest), §9 (UI) and the roadmap contracts #4, #5, #8, #10, #12.
- `Game.placing` is written **only** by `PlacementController`. While it is true, Dev B's fish commander ignores clicks; this controller handles `command` (left click: place) and `cancel` (right click/Esc) in `_unhandled_input` and marks the event handled, so Esc cancels placement before it can pause the game.
- The game cannot be paused into placing: `InventoryBar` is `PROCESS_MODE_PAUSABLE` (the UI layer itself is `ALWAYS`), and the placement controller is a pausable gameplay node.
- `CellProbe` uses the physics space: the ghost validity is computed in `_physics_process`.
- A coral item's origin is the hovered cell; its footprint comes from `CoralShapes.cells_at(shape_id, origin)`.
- Nests count only on the map for the game-over rule (B2), but the nest draw weight uses map **and** inventory: `nest_base_weight / (1 + nests_on_map + nests_in_inventory)`.

> **Test runner caveat:** the P0 runner keeps counting other tests when a test script fails to compile, so always also check that the output has **no `SCRIPT ERROR` line**. A quick way: `tools/test.sh 2>&1 | grep -c "SCRIPT ERROR"` must print `0`.

## File map

| File | Action | Responsibility |
|---|---|---|
| `core/nest_cycle.gd` | Create | `NestCycle` state machine + `hatched(count)` signal |
| `core/inventory_model.gd` | Create | `InventoryModel` slots, refill, weighted draw |
| `entities/nest/nest.gd` | Modify (full replace) | Drive `NestCycle`, colour by state, hatch juveniles |
| `systems/a_inventory_system.gd` | Create | `InventorySystem` node owning/ticking the model |
| `systems/a_placement_controller.gd` | Create | `PlacementController`: ghost, validity, input |
| `ui/a_inventory_bar.gd` | Create | `InventoryBar`: 4 slot buttons + radial refill |
| `main/dev_a_systems.gd` | Modify (full replace) | Wire the systems and UI |
| `tests/unit/test_nest_cycle.gd` | Create | 6 tests |
| `tests/unit/test_inventory_model.gd` | Create | 8 tests |
| `dev/verify.gd`, `dev/verify.tscn` | Temporary | Live check, **never committed** |

Expected test totals: 27 after A1 → 33 after Task 2 → 41 after Task 4.

---

### Task 1: Feature branch

- [ ] **Step 1: Create the feature branch from an up-to-date `main`**

```bash
git switch main && git pull origin main
git switch -c "$(gh api user -q .login)/a2-nest-inventory-placement"
```

---

### Task 2: NestCycle rules

**Files:**
- Create: `core/nest_cycle.gd`
- Test: `tests/unit/test_nest_cycle.gd`

- [ ] **Step 1: Write the failing tests**

```gdscript
extends TestCase

var cycle: NestCycle
var hatched_counts: Array[int] = []


func before_each() -> void:
	cycle = NestCycle.new(20.0, 3)
	hatched_counts = []
	cycle.hatched.connect(_on_hatched)


func _on_hatched(count: int) -> void:
	hatched_counts.append(count)


func test_starts_empty_without_eggs() -> void:
	assert_eq(cycle.state, NestCycle.State.EMPTY)
	assert_almost(cycle.eggs_time_left(), -1.0)


func test_fertilize_starts_the_timer() -> void:
	assert_true(cycle.fertilize())
	assert_eq(cycle.state, NestCycle.State.EGGS)
	assert_almost(cycle.eggs_time_left(), 20.0)


func test_cannot_fertilize_twice() -> void:
	cycle.fertilize()
	cycle.tick(5.0)
	assert_false(cycle.fertilize())
	assert_almost(cycle.eggs_time_left(), 15.0)


func test_hatches_once_after_hatch_seconds() -> void:
	cycle.fertilize()
	cycle.tick(19.0)
	assert_eq(hatched_counts.size(), 0)
	cycle.tick(1.5)
	cycle.tick(30.0)
	assert_eq(hatched_counts, [3] as Array[int])
	assert_eq(cycle.state, NestCycle.State.EMPTY)


func test_kill_eggs_cancels_hatching() -> void:
	cycle.fertilize()
	cycle.tick(10.0)
	cycle.kill_eggs()
	cycle.tick(30.0)
	assert_eq(hatched_counts.size(), 0)
	assert_almost(cycle.eggs_time_left(), -1.0)


func test_can_be_fertilized_again_after_hatching() -> void:
	cycle.fertilize()
	cycle.tick(20.0)
	assert_true(cycle.fertilize())
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `tools/test.sh 2>&1 | grep -m1 "SCRIPT ERROR" -A1`
Expected: a `SCRIPT ERROR` mentioning `NestCycle`.

- [ ] **Step 3: Implement `core/nest_cycle.gd`**

```gdscript
class_name NestCycle
extends RefCounted
## Nest life cycle (GDD §5.5): EMPTY -> (fertilize) -> EGGS -> hatch -> EMPTY.

signal hatched(count: int)

enum State { EMPTY, EGGS }

var hatch_seconds: float
var hatch_count: int
var state := State.EMPTY
var _time_left := 0.0


func _init(p_hatch_seconds: float, p_hatch_count: int) -> void:
	hatch_seconds = p_hatch_seconds
	hatch_count = p_hatch_count


## Starts the eggs. Returns false (and does nothing) if the nest already has eggs.
func fertilize() -> bool:
	if state != State.EMPTY:
		return false
	state = State.EGGS
	_time_left = hatch_seconds
	return true


## CO2: the eggs die and the nest becomes empty.
func kill_eggs() -> void:
	state = State.EMPTY
	_time_left = 0.0


func tick(delta: float) -> void:
	if state != State.EGGS:
		return
	_time_left -= delta
	if _time_left <= 0.0:
		state = State.EMPTY
		_time_left = 0.0
		hatched.emit(hatch_count)


## Seconds until hatching, or -1.0 if there are no eggs.
func eggs_time_left() -> float:
	return _time_left if state == State.EGGS else -1.0
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `tools/test.sh`
Expected: `33 passed, 0 failed`, no `SCRIPT ERROR` line.

- [ ] **Step 5: Commit**

```bash
git add core/nest_cycle.gd tests/unit/test_nest_cycle.gd
git commit -m "Add nest egg cycle rules"
```

---

### Task 3: Nest node hatches juveniles

**Files:**
- Modify (replace the whole file): `entities/nest/nest.gd`

Contract kept: `cell`, `is_empty()`, `has_eggs()`, `fertilize()`, `kill_eggs()`, `eggs_time_left()`, `destroy()`, `destroyed`. The P0 `enum State` is replaced by `NestCycle.State`; `state` remains a read-only property. Hatching spawns `nest_hatch_count` juveniles (`adult = false`) in a small ring around the nest centre, deferred so it never runs inside a physics callback.

- [ ] **Step 1: Replace `entities/nest/nest.gd`**

```gdscript
class_name Nest
extends Area2D
## Nest: single-cell area fish swim over (GDD §5.5).
## CONTRACT (used by Dev B fish/threats): cell, is_empty(), has_eggs(),
## fertilize(), kill_eggs(), eggs_time_left(), destroy().

signal destroyed

const EMPTY_COLOR := Color(0.95, 0.85, 0.4)
const EGGS_COLOR := Color(1.0, 0.55, 0.2)
## Juveniles appear around the nest centre, this far apart (world units).
const HATCH_SPREAD := 8.0

var cell: Vector2i
var state: int:
	get:
		return _cycle.state if _cycle else NestCycle.State.EMPTY

var _cycle: NestCycle
var _visual: PlaceholderShape


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
	_cycle = NestCycle.new(Game.eco.nest_hatch_seconds, Game.eco.nest_hatch_count)
	_cycle.hatched.connect(_on_hatched)
	_visual = PlaceholderShape.cell(position, EMPTY_COLOR)
	ViewFollower.attach(self, _visual)


func _process(delta: float) -> void:
	_cycle.tick(delta)
	_visual.color = EGGS_COLOR if has_eggs() else EMPTY_COLOR


func is_empty() -> bool:
	return _cycle.state == NestCycle.State.EMPTY


func has_eggs() -> bool:
	return _cycle.state == NestCycle.State.EGGS


## Called by a fish that stayed on the nest for fertilize_seconds.
func fertilize() -> void:
	_cycle.fertilize()


## Called by CO2: eggs die, nest becomes empty.
func kill_eggs() -> void:
	_cycle.kill_eggs()


## Seconds until the eggs hatch, or -1.0 if there are no eggs.
func eggs_time_left() -> float:
	return _cycle.eggs_time_left()


func destroy() -> void:
	if is_queued_for_deletion():
		return
	remove_from_group(Groups.NESTS)
	Game.grid.release([cell])
	destroyed.emit()
	queue_free()


func _on_hatched(count: int) -> void:
	for i in count:
		var offset := Vector2.from_angle(TAU * i / count) * HATCH_SPREAD
		Game.factory.spawn_fish.call_deferred(position + offset, false)
```

- [ ] **Step 2: Run unit and smoke tests**

Run: `tools/test.sh && tools/smoke.sh`
Expected: `33 passed, 0 failed`, no `SCRIPT ERROR`, then `SMOKE OK`.

- [ ] **Step 3: Commit**

```bash
git add entities/nest/nest.gd
git commit -m "Hatch juvenile fish from fertilized nests"
```

---

### Task 4: InventoryModel rules

**Files:**
- Create: `core/inventory_model.gd`
- Test: `tests/unit/test_inventory_model.gd`

Items are dictionaries `{ "kind": &"coral"|&"algae"|&"nest", "shape_id": StringName }` (`shape_id` is `&""` except for corals); an empty slot is `{}`. The run starts with all slots full (`fill_all()`). Using a slot (`take`) starts **that slot's** refill timer; other slots are untouched.

- [ ] **Step 1: Write the failing tests**

```gdscript
extends TestCase

var eco: BalanceEcosystem
var rng: RandomNumberGenerator
var nests_on_map := 0
var inventory: InventoryModel


func before_each() -> void:
	eco = BalanceEcosystem.new()
	rng = RandomNumberGenerator.new()
	rng.seed = 7
	nests_on_map = 0
	inventory = InventoryModel.new(eco, rng, _count_nests_on_map)


func _count_nests_on_map() -> int:
	return nests_on_map


func _only(kind: StringName) -> void:
	eco.weight_coral = 1.0 if kind == InventoryModel.CORAL else 0.0
	eco.weight_algae = 1.0 if kind == InventoryModel.ALGAE else 0.0
	eco.nest_base_weight = 1.0 if kind == InventoryModel.NEST else 0.0


func test_has_configured_slot_count_and_starts_empty() -> void:
	assert_eq(inventory.slots.size(), 4)
	assert_false(inventory.is_ready(0))


func test_fill_all_fills_every_slot() -> void:
	inventory.fill_all()
	for i in 4:
		assert_true(inventory.is_ready(i))


func test_take_empties_slot_and_refills_after_timer() -> void:
	_only(InventoryModel.ALGAE)
	inventory.fill_all()
	var taken := inventory.take(1)
	assert_eq(taken["kind"], InventoryModel.ALGAE)
	assert_false(inventory.is_ready(1))
	inventory.tick(4.0)
	assert_almost(inventory.refill_ratio(1), 0.5)
	assert_false(inventory.is_ready(1))
	inventory.tick(4.1)
	assert_true(inventory.is_ready(1))
	assert_almost(inventory.refill_ratio(1), 1.0)


func test_other_slots_are_not_affected_by_a_refill() -> void:
	inventory.fill_all()
	var before := inventory.item(0)
	inventory.take(2)
	inventory.tick(10.0)
	assert_eq(inventory.item(0), before)


func test_coral_items_carry_a_known_shape() -> void:
	_only(InventoryModel.CORAL)
	var item := inventory.draw()
	assert_eq(item["kind"], InventoryModel.CORAL)
	assert_true(CoralShapes.ids().has(item["shape_id"]))


func test_nest_weight_drops_with_nests_on_map_and_in_inventory() -> void:
	assert_almost(inventory.nest_weight(), 20.0)
	nests_on_map = 1
	assert_almost(inventory.nest_weight(), 10.0)
	_only(InventoryModel.NEST)
	inventory.fill_all()
	eco.nest_base_weight = 20.0
	assert_almost(inventory.nest_weight(), 20.0 / 6.0)


func test_draw_follows_weights_roughly() -> void:
	var counts := {InventoryModel.CORAL: 0, InventoryModel.ALGAE: 0, InventoryModel.NEST: 0}
	nests_on_map = 1 # nest weight 10 -> 50 / 40 / 10 of 100
	for i in 2000:
		counts[inventory.draw()["kind"]] += 1
	assert_almost(counts[InventoryModel.CORAL] / 2000.0, 0.5, 0.05)
	assert_almost(counts[InventoryModel.ALGAE] / 2000.0, 0.4, 0.05)
	assert_almost(counts[InventoryModel.NEST] / 2000.0, 0.1, 0.05)


func test_changed_is_emitted_on_take() -> void:
	inventory.fill_all()
	var emitted := [0]
	inventory.changed.connect(func(): emitted[0] += 1)
	inventory.take(0)
	assert_eq(emitted[0], 1)
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `tools/test.sh 2>&1 | grep -m1 "SCRIPT ERROR" -A1`
Expected: a `SCRIPT ERROR` mentioning `InventoryModel`.

- [ ] **Step 3: Implement `core/inventory_model.gd`**

Keep the weights in typed local variables: `var roll := ...` cannot infer its type from untyped array elements and fails to parse.

```gdscript
class_name InventoryModel
extends RefCounted
## Fixed-slot inventory with timed per-slot refill and weighted draws (GDD §5.1).
## An item is a Dictionary: { "kind": StringName, "shape_id": StringName }.
## An empty slot holds an empty Dictionary.

signal changed

const CORAL := &"coral"
const ALGAE := &"algae"
const NEST := &"nest"

var slots: Array[Dictionary] = []
var _refill_left: Array[float] = []
var _eco: BalanceEcosystem
var _rng: RandomNumberGenerator
var _nests_on_map: Callable


## `nests_on_map() -> int` is injected so the model stays testable without a scene.
func _init(eco: BalanceEcosystem, rng: RandomNumberGenerator, nests_on_map: Callable) -> void:
	_eco = eco
	_rng = rng
	_nests_on_map = nests_on_map
	for i in eco.inventory_slots:
		slots.append({})
		_refill_left.append(0.0)


## Fills every empty slot immediately (start of a run).
func fill_all() -> void:
	for i in slots.size():
		if slots[i].is_empty():
			slots[i] = draw()
	changed.emit()


func is_ready(index: int) -> bool:
	return not slots[index].is_empty()


func item(index: int) -> Dictionary:
	return slots[index]


## Removes the item from the slot and starts that slot's refill timer.
func take(index: int) -> Dictionary:
	var taken := slots[index]
	slots[index] = {}
	_refill_left[index] = _eco.slot_refill_seconds
	changed.emit()
	return taken


func tick(delta: float) -> void:
	var refilled := false
	for i in slots.size():
		if not slots[i].is_empty():
			continue
		_refill_left[i] -= delta
		if _refill_left[i] <= 0.0:
			slots[i] = draw()
			refilled = true
	if refilled:
		changed.emit()


## 0.0 right after use, 1.0 when the slot is full.
func refill_ratio(index: int) -> float:
	if is_ready(index):
		return 1.0
	return clampf(1.0 - _refill_left[index] / _eco.slot_refill_seconds, 0.0, 1.0)


func nests_in_inventory() -> int:
	var count := 0
	for slot in slots:
		if slot.get("kind") == NEST:
			count += 1
	return count


## nest_base_weight / (1 + nests on map + nests in inventory).
func nest_weight() -> float:
	return _eco.nest_base_weight / (1.0 + _nests_on_map.call() + nests_in_inventory())


## Weighted random item. Corals get a random shape.
func draw() -> Dictionary:
	var coral_weight := _eco.weight_coral
	var algae_weight := _eco.weight_algae
	var roll := _rng.randf() * (coral_weight + algae_weight + nest_weight())
	if roll < coral_weight:
		var ids := CoralShapes.ids()
		return {"kind": CORAL, "shape_id": ids[_rng.randi_range(0, ids.size() - 1)]}
	if roll < coral_weight + algae_weight:
		return {"kind": ALGAE, "shape_id": &""}
	return {"kind": NEST, "shape_id": &""}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `tools/test.sh`
Expected: `41 passed, 0 failed`, no `SCRIPT ERROR` line.

- [ ] **Step 5: Commit**

```bash
git add core/inventory_model.gd tests/unit/test_inventory_model.gd
git commit -m "Add inventory model with timed refill and weighted draws"
```

---

### Task 5: InventorySystem and PlacementController

**Files:**
- Create: `systems/a_inventory_system.gd`, `systems/a_placement_controller.gd`

- [ ] **Step 1: Create `systems/a_inventory_system.gd`**

```gdscript
class_name InventorySystem
extends Node
## Owns the InventoryModel and advances its refill timers (pausable).

var model: InventoryModel


func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	model = InventoryModel.new(Game.eco, rng, _nests_on_map)
	model.fill_all()


func _process(delta: float) -> void:
	model.tick(delta)


func _nests_on_map() -> int:
	return get_tree().get_nodes_in_group(Groups.NESTS).size()
```

- [ ] **Step 2: Create `systems/a_placement_controller.gd`**

The ghost is a `Node2D` added to `Game.view` with `z_index = 100`, drawing each footprint cell as a projected parallelogram (green = valid, red = invalid). `try_place_at(origin)` is public so it can be driven without a mouse (verification harness, future tutorial).

```gdscript
class_name PlacementController
extends Node
## Places inventory items on the grid (GDD §5.1). While active, Game.placing is
## true and this node owns the command/cancel input (roadmap contract #8).

signal placement_finished

const VALID_COLOR := Color(0.3, 1.0, 0.4, 0.45)
const INVALID_COLOR := Color(1.0, 0.25, 0.25, 0.45)

var inventory: InventorySystem
var active_slot := -1

var _ghost: Node2D
var _ghost_cells: Array[Vector2i] = []
var _ghost_valid := false


func _ready() -> void:
	_ghost = Node2D.new()
	_ghost.name = "PlacementGhost"
	_ghost.z_index = 100
	_ghost.draw.connect(_draw_ghost)
	Game.view.add_child(_ghost)


## Starts placing the item of `slot`. Ignored if the slot is refilling.
func begin(slot: int) -> void:
	if not inventory.model.is_ready(slot):
		return
	active_slot = slot
	Game.placing = true


func cancel() -> void:
	active_slot = -1
	Game.placing = false
	_ghost_cells = []
	_ghost.queue_redraw()


## Cells the active item would cover with its origin at `origin`.
func footprint(origin: Vector2i) -> Array[Vector2i]:
	var item := inventory.model.item(active_slot)
	if item["kind"] == InventoryModel.CORAL:
		return CoralShapes.cells_at(item["shape_id"], origin)
	return [origin]


## In bounds, free on the grid and not covered by a fish or threat.
func can_place(cells: Array[Vector2i]) -> bool:
	if not Game.grid.are_free(cells):
		return false
	for cell in cells:
		if CellProbe.is_covered_by_actor(cell):
			return false
	return true


## Places the active item at `origin` if valid. Returns true on success.
func try_place_at(origin: Vector2i) -> bool:
	if active_slot < 0:
		return false
	var cells := footprint(origin)
	if not can_place(cells):
		return false
	var item := inventory.model.take(active_slot)
	match item["kind"]:
		InventoryModel.CORAL:
			Game.factory.spawn_coral(item["shape_id"], origin)
		InventoryModel.ALGAE:
			Game.factory.spawn_algae(origin)
		InventoryModel.NEST:
			Game.factory.spawn_nest(origin)
	cancel()
	placement_finished.emit()
	return true


func _physics_process(_delta: float) -> void:
	if active_slot < 0:
		return
	_ghost_cells = footprint(Game.grid.world_to_cell(Game.mouse_world()))
	_ghost_valid = can_place(_ghost_cells)
	_ghost.queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if active_slot < 0:
		return
	if event.is_action_pressed(InputActions.COMMAND):
		try_place_at(Game.grid.world_to_cell(Game.mouse_world()))
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(InputActions.CANCEL):
		cancel()
		get_viewport().set_input_as_handled()


func _draw_ghost() -> void:
	var color := VALID_COLOR if _ghost_valid else INVALID_COLOR
	var half := Game.grid.cell_size * 0.5
	for cell in _ghost_cells:
		var c := Game.grid.cell_to_world(cell)
		var corners := PackedVector2Array([
			c + Vector2(-half, -half), c + Vector2(half, -half),
			c + Vector2(half, half), c + Vector2(-half, half)])
		_ghost.draw_colored_polygon(Game.projection.project_polygon(corners, Vector2.ZERO), color)
```

- [ ] **Step 3: Run tests (classes must compile)**

Run: `tools/test.sh`
Expected: `41 passed, 0 failed`, no `SCRIPT ERROR` line.

- [ ] **Step 4: Commit**

```bash
git add systems
git commit -m "Add inventory system and grid placement controller"
```

---

### Task 6: Inventory bar UI and wiring

**Files:**
- Create: `ui/a_inventory_bar.gd`
- Modify (replace the whole file): `main/dev_a_systems.gd`
- Temporary: `dev/verify.gd`, `dev/verify.tscn`

- [ ] **Step 1: Create `ui/a_inventory_bar.gd`**

Bottom-centre row of 4 buttons. Each shows the item ("Coral" + shape name, "Algae", "Nest"); an empty slot is disabled and draws a radial arc that fills up as it refills; the slot being placed is highlighted. Anchoring is applied **after** the buttons are added, otherwise the container has no size yet and ends up off-centre.

```gdscript
class_name InventoryBar
extends HBoxContainer
## Bottom-centre inventory slots with a radial refill indicator (GDD §9).
## Pausable: no placing while the game is paused.

const SLOT_SIZE := Vector2(96, 72)
const LABELS := {
	InventoryModel.CORAL: "Coral",
	InventoryModel.ALGAE: "Algae",
	InventoryModel.NEST: "Nest",
}

var inventory: InventorySystem
var placement: PlacementController
var _buttons: Array[Button] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	add_theme_constant_override("separation", 12)
	for i in inventory.model.slots.size():
		var button := Button.new()
		button.custom_minimum_size = SLOT_SIZE
		button.focus_mode = Control.FOCUS_NONE
		button.pressed.connect(placement.begin.bind(i))
		button.draw.connect(_draw_refill.bind(button, i))
		add_child(button)
		_buttons.append(button)
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	grow_vertical = Control.GROW_DIRECTION_BEGIN
	set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM, Control.PRESET_MODE_MINSIZE, 16)


func _process(_delta: float) -> void:
	for i in _buttons.size():
		var button := _buttons[i]
		var item := inventory.model.item(i)
		button.disabled = item.is_empty()
		button.text = _label(item)
		button.modulate = Color(1.4, 1.4, 0.8) if placement.active_slot == i else Color.WHITE
		button.queue_redraw()


func _label(item: Dictionary) -> String:
	if item.is_empty():
		return ""
	var text: String = LABELS[item["kind"]]
	if item["kind"] == InventoryModel.CORAL:
		text += "\n" + String(item["shape_id"])
	return text


func _draw_refill(button: Button, index: int) -> void:
	var ratio := inventory.model.refill_ratio(index)
	if ratio >= 1.0:
		return
	var center := button.size * 0.5
	var radius := minf(button.size.x, button.size.y) * 0.3
	button.draw_arc(center, radius, 0.0, TAU, 32, Color(1, 1, 1, 0.15), 6.0)
	button.draw_arc(center, radius, -PI / 2.0, -PI / 2.0 + TAU * ratio, 32, Color(1, 1, 1, 0.8), 6.0)
```

- [ ] **Step 2: Replace `main/dev_a_systems.gd`**

```gdscript
extends Node
## Dev A's systems and UI are added here (inventory, placement, temperature...).
## Only Dev A edits this file.

var inventory: InventorySystem
var placement: PlacementController


func _ready() -> void:
	inventory = InventorySystem.new()
	inventory.name = "InventorySystem"
	add_child(inventory)

	placement = PlacementController.new()
	placement.name = "PlacementController"
	placement.inventory = inventory
	add_child(placement)

	var bar := InventoryBar.new()
	bar.name = "InventoryBar"
	bar.inventory = inventory
	bar.placement = placement
	Game.ui.add_child(bar)
```

- [ ] **Step 3: Run unit and smoke tests**

Run: `tools/test.sh && tools/smoke.sh`
Expected: `41 passed, 0 failed`, no `SCRIPT ERROR`, then `SMOKE OK`.

- [ ] **Step 4: Create the temporary verification scene**

`dev/verify.gd` (hatching shortened to 1 s):
```gdscript
extends Node
## TEMPORARY verification harness for plan A2. Do not commit.

var frames := 0
var nest: Nest


func _ready() -> void:
	Game.eco = Game.eco.duplicate()
	Game.eco.nest_hatch_seconds = 1.0
	add_child(load("res://main/main.tscn").instantiate())


func _physics_process(_delta: float) -> void:
	frames += 1
	if frames == 5:
		var dev_a := get_node("Main/DevASystems")
		var placement: PlacementController = dev_a.placement
		var model: InventoryModel = dev_a.inventory.model
		print("slots ready: ", range(4).map(func(i): return model.is_ready(i)))
		placement.begin(0)
		print("placing=", Game.placing)
		print("on coral cell (4,4): ", placement.try_place_at(Vector2i(4, 4)))
		print("on fish cell (9,6): ", placement.try_place_at(Vector2i(9, 6)))
		print("on free cell (1,1): ", placement.try_place_at(Vector2i(1, 1)),
			" placing=", Game.placing, " slot0 ready=", model.is_ready(0))
		nest = get_tree().get_nodes_in_group(Groups.NESTS)[0]
		nest.fertilize()
		print("eggs time left: ", nest.eggs_time_left())
	if frames == 90:
		var fish := get_tree().get_nodes_in_group(Groups.FISH)
		print("fish: ", fish.size(), " adults: ", fish.filter(func(f): return f.is_adult()).size(),
			" nest empty: ", nest.is_empty())
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

Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --path . res://dev/verify.tscn 2>&1 | grep -v "^Godot Engine"`
Expected (slot 0 may be a coral, so the free-cell result is `true` unless the random shape overlaps something at (1,1) — the default shapes all fit):
```
slots ready: [true, true, true, true]
placing=true
on coral cell (4,4): false
on fish cell (9,6): false
on free cell (1,1): true placing=false slot0 ready=false
eggs time left: 1.0
fish: 6 adults: 3 nest empty: true
```
(`on fish cell (9,6)` is `false` because a Level01 fish sits on that free grid cell: this proves `CellProbe` blocks placement.)

- [ ] **Step 6: Manual check in the editor**

Press F5:
1. Four slots at the bottom centre show items.
2. Click a slot: the grid lines appear and a ghost follows the mouse, green on free cells, red over corals, algae, the nest, a fish, or when a coral shape sticks out of the map.
3. Left click on green places the item; that slot greys out, its radial fills over 8 s and a new item appears. Left click on red does nothing.
4. Right click or Esc cancels (grid lines disappear) without consuming the item.
5. Place a nest, order nothing: it stays yellow. (Fertilization is tested with B1; you can call `fertilize()` from the remote scene tree to see it turn orange and hatch 3 small fish after 20 s.)

- [ ] **Step 7: Delete the temporary files and commit**

```bash
rm -rf dev
git add ui/a_inventory_bar.gd main/dev_a_systems.gd
git commit -m "Add inventory bar UI and wire Dev A systems"
```

---

### Task 7: Integrate into main (git flow)

- [ ] **Step 1: Merge `main` into the branch and re-verify**

```bash
git fetch origin && git merge origin/main
tools/test.sh && tools/smoke.sh
```
Expected: `41 passed, 0 failed` (more if Dev B's tests are already on `main`), no `SCRIPT ERROR` line in the output, then `SMOKE OK`. Open the project in the Godot editor and press F5: no errors in the Output panel.

- [ ] **Step 2: Merge to `main`, push, delete the branch**

```bash
BR="$(git branch --show-current)"
git switch main && git pull origin main
git merge "$BR" && git push origin main
git branch -d "$BR"
```

Then tell Dev B: `Game.placing` is live (contract #8), `Nest.eggs_time_left()` returns real values (contract #10), `kill_eggs()` cancels hatching (contract #5).
