# A1 — Coral Oxygen and Algae Spread Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the static ecosystem alive (GDD M1): corals lose oxygen on contact damage, regenerate slowly and crumble at 0; algae spread every few seconds into neighbouring cells and suffocate the corals they bump into; CO2 absorbed by an algae triggers an immediate expansion.

**Architecture:** Two pure, unit-tested rule classes — `CoralOxygen` (oxygen value, damage, regen, depletion) and `AlgaeSpread` (one expansion attempt over the 4 neighbours in random order, jittered interval) — driven by the existing `Coral` and `Algae` nodes from P0. `CellProbe` answers "is a fish or threat over this cell?" with a physics shape query (roadmap contract #2), so algae never grow on top of moving actors. Randomness is injected (`RandomNumberGenerator` with a seed, predicate `Callable`s) so tests are deterministic.

**Tech Stack:** Godot 4.7.2, GDScript, headless test runner from P0 (`tools/test.sh`, `tools/smoke.sh`).

**Owner:** Dev A. **Depends on:** P0 merged on `main`. **Runs in parallel with:** B1 (fish).

---

## Context for the engineer

- Read `docs/GDD.md` §5.2 (coral), §5.3 (algae), §8 (interaction table) and `docs/superpowers/plans/2026-11-07-00-roadmap.md` (ownership + contracts #1, #2, #3, #6).
- World units are logical (cell = 32 units). The grid (`Game.grid`, a `GridModel`) holds at most one static entity per cell.
- `destroy()` must stay idempotent and remove the node from its group immediately (P0 contract) — Dev B's population counters rely on it.
- Physics rule: never add/remove collision objects or run shape queries inside a physics callback (`body_entered`, etc.). That is why `on_co2_absorbed()` defers its work and `Coral.destroy()` uses `set_deferred` for the collision layer.
- Temperature is `0.0` until A3, so `Game.by_temperature(cold, hot)` returns the cold value for now.

> **Test runner caveat:** the P0 runner keeps counting other tests when a test script fails to compile, so always also check that the output has **no `SCRIPT ERROR` line**. A quick way: `tools/test.sh 2>&1 | grep -c "SCRIPT ERROR"` must print `0`.

## File map

| File | Action | Responsibility |
|---|---|---|
| `core/coral_oxygen.gd` | Create | `CoralOxygen`: damage, regen, single `depleted` signal |
| `core/algae_spread.gd` | Create | `AlgaeSpread`: expansion attempt rules + jittered interval |
| `core/cell_probe.gd` | Create | `CellProbe.is_covered_by_actor(cell)` (contract #2) |
| `entities/coral/coral.gd` | Modify (full replace) | Use `CoralOxygen`, regen tint, crumble animation |
| `entities/algae/algae.gd` | Modify (full replace) | Growth timer, expansion, cap, `on_co2_absorbed()` |
| `tests/unit/test_coral_oxygen.gd` | Create | 5 tests |
| `tests/unit/test_algae_spread.gd` | Create | 7 tests |
| `dev/verify.gd`, `dev/verify.tscn` | Temporary | Accelerated live check, **never committed** |

Expected test totals: P0 has 15 → 20 after Task 2 → 27 after Task 4.

---

### Task 1: Feature branch

- [ ] **Step 1: Create the feature branch from an up-to-date `main`**

```bash
git switch main && git pull origin main
git switch -c "$(gh api user -q .login)/a1-coral-algae"
```

---

### Task 2: CoralOxygen rules

**Files:**
- Create: `core/coral_oxygen.gd`
- Test: `tests/unit/test_coral_oxygen.gd`

- [ ] **Step 1: Write the failing tests**

```gdscript
extends TestCase

var oxygen: CoralOxygen
var depleted_count := 0


func before_each() -> void:
	oxygen = CoralOxygen.new(100.0, 0.5)
	depleted_count = 0
	oxygen.depleted.connect(_on_depleted)


func _on_depleted() -> void:
	depleted_count += 1


func test_starts_full() -> void:
	assert_almost(oxygen.value, 100.0)
	assert_almost(oxygen.ratio(), 1.0)


func test_damage_is_instant() -> void:
	oxygen.damage(35.0)
	assert_almost(oxygen.value, 65.0)
	assert_false(oxygen.dead)


func test_regen_is_capped() -> void:
	oxygen.damage(10.0)
	oxygen.tick(4.0)
	assert_almost(oxygen.value, 92.0)
	oxygen.tick(100.0)
	assert_almost(oxygen.value, 100.0)


func test_depletes_once_at_zero() -> void:
	oxygen.damage(60.0)
	oxygen.damage(60.0)
	oxygen.damage(10.0)
	assert_true(oxygen.dead)
	assert_almost(oxygen.value, 0.0)
	assert_eq(depleted_count, 1)


func test_dead_coral_does_not_regenerate() -> void:
	oxygen.damage(100.0)
	oxygen.tick(10.0)
	assert_almost(oxygen.value, 0.0)
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `tools/test.sh 2>&1 | grep -m1 "SCRIPT ERROR" -A1`
Expected: a `SCRIPT ERROR` mentioning `CoralOxygen` not declared (test_coral_oxygen.gd).

- [ ] **Step 3: Implement `core/coral_oxygen.gd`**

```gdscript
class_name CoralOxygen
extends RefCounted
## Oxygen of one coral (GDD §5.2): instant damage, slow regen, dies at 0.

signal depleted

var max_oxygen: float
var regen_per_sec: float
var value: float
var dead := false


func _init(p_max_oxygen: float, p_regen_per_sec: float) -> void:
	max_oxygen = p_max_oxygen
	regen_per_sec = p_regen_per_sec
	value = p_max_oxygen


## Instant damage. Emits `depleted` once when oxygen reaches 0.
func damage(amount: float) -> void:
	if dead:
		return
	value = maxf(value - amount, 0.0)
	if value <= 0.0:
		dead = true
		depleted.emit()


## Slow regeneration, capped at max_oxygen. Dead corals do not regenerate.
func tick(delta: float) -> void:
	if dead:
		return
	value = minf(value + regen_per_sec * delta, max_oxygen)


func ratio() -> float:
	return value / max_oxygen
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `tools/test.sh`
Expected: `20 passed, 0 failed`, no `SCRIPT ERROR` line.

- [ ] **Step 5: Commit**

```bash
git add core/coral_oxygen.gd tests/unit/test_coral_oxygen.gd
git commit -m "Add coral oxygen rules with regen and depletion"
```

---

### Task 3: Coral node uses CoralOxygen (regen tint and crumble)

**Files:**
- Modify (replace the whole file): `entities/coral/coral.gd`

Behaviour: oxygen regenerates every frame (pausable `_process`); all cells tint from pink (full) to grey (suffocated); at 0 oxygen the coral **dies for gameplay immediately** (leaves `corals` group, frees its grid cells, disables collisions, emits `destroyed`) and then **crumbles visually** for 0.6 s (fade + vertical squash) before `queue_free()`. `oxygen` stays a readable property (contract), now backed by `CoralOxygen`. A cyclone calling `destroy()` gets the same crumble.

- [ ] **Step 1: Replace `entities/coral/coral.gd`**

```gdscript
class_name Coral
extends StaticBody2D
## Coral: multi-cell static obstacle with oxygen. It only "suffers" (GDD §5.2).
## CONTRACT (used by Dev B threats): cells, oxygen, apply_oxygen_damage(), destroy().

signal destroyed

const HEALTHY_COLOR := Color(1.0, 0.45, 0.55)
const SUFFOCATED_COLOR := Color(0.45, 0.42, 0.42)
const CRUMBLE_SECONDS := 0.6

var shape_id: StringName
var origin_cell: Vector2i
var cells: Array[Vector2i] = []
var oxygen: float:
	get:
		return _oxygen.value if _oxygen else 0.0

var _oxygen: CoralOxygen
var _visuals: Array[PlaceholderShape] = []
var _followers: Array[ViewFollower] = []
var _dead := false


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
	_oxygen = CoralOxygen.new(Game.eco.coral_max_oxygen, Game.eco.coral_regen_per_sec)
	_oxygen.depleted.connect(destroy)
	_build_visuals()


## One follower per cell so each cell y-sorts on its own (GDD §4.1).
func _build_visuals() -> void:
	for cell in cells:
		var marker := Marker2D.new()
		marker.position = Vector2(cell - origin_cell) * Game.grid.cell_size
		add_child(marker)
		var visual := PlaceholderShape.cell(Game.grid.cell_to_world(cell), HEALTHY_COLOR)
		_visuals.append(visual)
		_followers.append(ViewFollower.attach(marker, visual))


func _process(delta: float) -> void:
	if _dead:
		return
	_oxygen.tick(delta)
	var tint := SUFFOCATED_COLOR.lerp(HEALTHY_COLOR, _oxygen.ratio())
	for visual in _visuals:
		visual.color = tint


## Instant damage on contact. Kills the coral at 0 oxygen.
func apply_oxygen_damage(amount: float) -> void:
	if _dead:
		return
	_oxygen.damage(amount)


## Dies immediately for gameplay (group, grid, collisions), then crumbles visually.
func destroy() -> void:
	if _dead:
		return
	_dead = true
	remove_from_group(Groups.CORALS)
	Game.grid.release(cells)
	set_deferred("collision_layer", 0)
	destroyed.emit()
	_crumble()


func _crumble() -> void:
	var tween := create_tween().set_parallel(true)
	for follower in _followers:
		tween.tween_property(follower, "modulate:a", 0.0, CRUMBLE_SECONDS)
		tween.tween_property(follower, "scale", Vector2(1.0, 0.3), CRUMBLE_SECONDS)
	tween.chain().tween_callback(queue_free)
```

- [ ] **Step 2: Run unit and smoke tests**

Run: `tools/test.sh && tools/smoke.sh`
Expected: `20 passed, 0 failed`, no `SCRIPT ERROR`, then `SMOKE OK`.

- [ ] **Step 3: Commit**

```bash
git add entities/coral/coral.gd
git commit -m "Regenerate coral oxygen and crumble corals at zero"
```

---

### Task 4: AlgaeSpread rules

**Files:**
- Create: `core/algae_spread.gd`
- Test: `tests/unit/test_algae_spread.gd`

Rules (GDD §5.3): try the 4 orthogonal neighbours in random order; out of map → next; empty and not covered by an actor → SPAWN; coral → DAMAGE_CORAL (stop); anything else (algae, nest, covered by fish/threat) → next; none usable → BLOCKED (the algae retries at its next interval). Predicates are injected so the rules stay testable without a scene.

- [ ] **Step 1: Write the failing tests**

Note: tests use methods (not lambdas stored in member variables) as callables — lambdas that capture `self` in member initialisers leak the test instance.

```gdscript
extends TestCase

var grid: GridModel
var rng: RandomNumberGenerator
var coral := RefCounted.new()
var other := RefCounted.new()


func before_each() -> void:
	grid = GridModel.new(Vector2i(5, 5), 32.0)
	rng = RandomNumberGenerator.new()
	rng.seed = 42


func _is_coral(entity: Object) -> bool:
	return entity == coral


func _never_covered(_cell: Vector2i) -> bool:
	return false


func _covers_2_3(cell: Vector2i) -> bool:
	return cell == Vector2i(2, 3)


func _block(cells: Array[Vector2i]) -> void:
	grid.occupy(cells, other)


func test_spawns_in_the_only_free_neighbour() -> void:
	_block([Vector2i(2, 1), Vector2i(1, 2), Vector2i(3, 2)])
	var result := AlgaeSpread.attempt(Vector2i(2, 2), grid, rng, _is_coral, _never_covered)
	assert_eq(result["outcome"], AlgaeSpread.Outcome.SPAWN)
	assert_eq(result["cell"], Vector2i(2, 3))


func test_damages_coral_when_it_is_the_only_option() -> void:
	_block([Vector2i(2, 1), Vector2i(1, 2), Vector2i(3, 2)])
	grid.occupy([Vector2i(2, 3)], coral)
	var result := AlgaeSpread.attempt(Vector2i(2, 2), grid, rng, _is_coral, _never_covered)
	assert_eq(result["outcome"], AlgaeSpread.Outcome.DAMAGE_CORAL)
	assert_eq(result["target"], coral)


func test_blocked_when_no_neighbour_is_usable() -> void:
	_block([Vector2i(2, 1), Vector2i(1, 2), Vector2i(3, 2), Vector2i(2, 3)])
	var result := AlgaeSpread.attempt(Vector2i(2, 2), grid, rng, _is_coral, _never_covered)
	assert_eq(result["outcome"], AlgaeSpread.Outcome.BLOCKED)


func test_out_of_map_neighbours_are_skipped() -> void:
	_block([Vector2i(1, 0)])
	var result := AlgaeSpread.attempt(Vector2i(0, 0), grid, rng, _is_coral, _never_covered)
	assert_eq(result["outcome"], AlgaeSpread.Outcome.SPAWN)
	assert_eq(result["cell"], Vector2i(0, 1))


func test_cells_covered_by_actors_are_skipped() -> void:
	_block([Vector2i(2, 1), Vector2i(1, 2), Vector2i(3, 2)])
	var result := AlgaeSpread.attempt(Vector2i(2, 2), grid, rng, _is_coral, _covers_2_3)
	assert_eq(result["outcome"], AlgaeSpread.Outcome.BLOCKED)


func test_random_order_reaches_every_neighbour() -> void:
	var seen := {}
	for s in 64:
		rng.seed = s
		var result := AlgaeSpread.attempt(Vector2i(2, 2), grid, rng, _is_coral, _never_covered)
		seen[result["cell"]] = true
	assert_eq(seen.size(), 4)


func test_next_interval_stays_within_jitter() -> void:
	for i in 50:
		var value := AlgaeSpread.next_interval(10.0, 0.2, rng)
		assert_true(value >= 8.0 and value <= 12.0, str(value))
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `tools/test.sh 2>&1 | grep -m1 "SCRIPT ERROR" -A1`
Expected: a `SCRIPT ERROR` mentioning `AlgaeSpread` not declared.

- [ ] **Step 3: Implement `core/algae_spread.gd`**

```gdscript
class_name AlgaeSpread
extends RefCounted
## Pure rules of one algae expansion attempt (GDD §5.3).

enum Outcome { SPAWN, DAMAGE_CORAL, BLOCKED }


## Tries the 4 neighbours of `origin` in random order:
## - empty and not covered by an actor -> SPAWN there
## - occupied by a coral -> DAMAGE_CORAL (that coral)
## - anything else (out of map, algae, nest, covered by fish/threat) -> next
## Returns { "outcome": Outcome, "cell": Vector2i, "target": Object }.
## `is_coral(occupant) -> bool`, `is_covered(cell) -> bool` are injected for testability.
static func attempt(origin: Vector2i, grid: GridModel, rng: RandomNumberGenerator,
		is_coral: Callable, is_covered: Callable) -> Dictionary:
	var candidates := grid.neighbors4(origin)
	_shuffle(candidates, rng)
	for cell in candidates:
		if not grid.in_bounds(cell):
			continue
		var occupant := grid.occupant(cell)
		if occupant == null:
			if is_covered.call(cell):
				continue
			return {"outcome": Outcome.SPAWN, "cell": cell, "target": null}
		if is_coral.call(occupant):
			return {"outcome": Outcome.DAMAGE_CORAL, "cell": cell, "target": occupant}
	return {"outcome": Outcome.BLOCKED, "cell": origin, "target": null}


## Base interval randomised by ±jitter (e.g. 0.2 = ±20%).
static func next_interval(base: float, jitter: float, rng: RandomNumberGenerator) -> float:
	return base * rng.randf_range(1.0 - jitter, 1.0 + jitter)


## Fisher-Yates shuffle driven by `rng` (deterministic with a seed).
static func _shuffle(cells: Array[Vector2i], rng: RandomNumberGenerator) -> void:
	for i in range(cells.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp := cells[i]
		cells[i] = cells[j]
		cells[j] = tmp
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `tools/test.sh`
Expected: `27 passed, 0 failed`, no `SCRIPT ERROR` line.

- [ ] **Step 5: Commit**

```bash
git add core/algae_spread.gd tests/unit/test_algae_spread.gd
git commit -m "Add algae spread rules"
```

---

### Task 5: CellProbe (roadmap contract #2)

**Files:**
- Create: `core/cell_probe.gd`

A physics query, so it is verified live in Task 6 (and reused by A2's placement). The probe square is 2 units smaller than the cell on each side so a fish merely touching the cell edge does not block it.

- [ ] **Step 1: Create `core/cell_probe.gd`**

```gdscript
class_name CellProbe
extends RefCounted
## Physics queries about grid cells (roadmap contract #2).
## Call from _physics_process or deferred code, never inside physics callbacks.

## Shrinks the probe so actors merely touching a cell edge do not count.
const MARGIN := 2.0


## True if a fish (body) or a threat (area) overlaps `cell`.
static func is_covered_by_actor(cell: Vector2i) -> bool:
	var rect := RectangleShape2D.new()
	rect.size = Vector2.ONE * (Game.grid.cell_size - MARGIN * 2.0)
	var params := PhysicsShapeQueryParameters2D.new()
	params.shape = rect
	params.transform = Transform2D(0.0, Game.grid.cell_to_world(cell))
	params.collision_mask = Layers.FISH | Layers.THREAT
	params.collide_with_bodies = true
	params.collide_with_areas = true
	var space := Game.world.get_world_2d().direct_space_state
	return not space.intersect_shape(params, 1).is_empty()
```

- [ ] **Step 2: Run tests (class must compile)**

Run: `tools/test.sh`
Expected: `27 passed, 0 failed`, no `SCRIPT ERROR` line.

- [ ] **Step 3: Commit**

```bash
git add core/cell_probe.gd
git commit -m "Add CellProbe to detect actors over a grid cell"
```

---

### Task 6: Algae node grows, suffocates corals and absorbs CO2

**Files:**
- Modify (replace the whole file): `entities/algae/algae.gd`
- Temporary: `dev/verify.gd`, `dev/verify.tscn`

Behaviour: each algae has its own RNG and timer. The timer runs in `_physics_process` (so `CellProbe` queries are safe) and is reset to `AlgaeSpread.next_interval(Game.by_temperature(cold, hot), jitter)`. When it fires: if the `algae` group already has `algae_max_count` members the attempt is skipped; otherwise SPAWN → `Game.factory.spawn_algae(cell)`, DAMAGE_CORAL → `coral.apply_oxygen_damage(algae_coral_damage)`, BLOCKED → nothing. `on_co2_absorbed()` runs one attempt deferred (Dev B calls it from an `Area2D` signal).

- [ ] **Step 1: Replace `entities/algae/algae.gd`**

```gdscript
class_name Algae
extends StaticBody2D
## Algae: single-cell obstacle that spreads and suffocates corals (GDD §5.3).
## CONTRACT (used by Dev B fish/threats): cell, on_co2_absorbed(), destroy().

signal destroyed

var cell: Vector2i

var _rng := RandomNumberGenerator.new()
var _time_to_grow := 0.0


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
	_rng.randomize()
	_reset_timer()


func _physics_process(delta: float) -> void:
	_time_to_grow -= delta
	if _time_to_grow <= 0.0:
		_reset_timer()
		try_expand()


## One expansion attempt (GDD §5.3). Skipped when the algae cap is reached.
func try_expand() -> void:
	if is_queued_for_deletion():
		return
	if get_tree().get_nodes_in_group(Groups.ALGAE).size() >= Game.eco.algae_max_count:
		return
	var result := AlgaeSpread.attempt(cell, Game.grid, _rng, _is_coral, CellProbe.is_covered_by_actor)
	match result["outcome"]:
		AlgaeSpread.Outcome.SPAWN:
			Game.factory.spawn_algae(result["cell"])
		AlgaeSpread.Outcome.DAMAGE_CORAL:
			(result["target"] as Coral).apply_oxygen_damage(Game.eco.algae_coral_damage)


## Called by a CO2 cloud that touches this algae: the cloud is absorbed and the
## algae expands immediately. Deferred: B3 calls this from a physics callback.
func on_co2_absorbed() -> void:
	try_expand.call_deferred()


func destroy() -> void:
	if is_queued_for_deletion():
		return
	remove_from_group(Groups.ALGAE)
	Game.grid.release([cell])
	destroyed.emit()
	queue_free()


func _reset_timer() -> void:
	var base := Game.by_temperature(Game.eco.algae_growth_interval_cold, Game.eco.algae_growth_interval_hot)
	_time_to_grow = AlgaeSpread.next_interval(base, Game.eco.algae_growth_jitter, _rng)


func _is_coral(entity: Object) -> bool:
	return entity is Coral
```

- [ ] **Step 2: Run unit and smoke tests**

Run: `tools/test.sh && tools/smoke.sh`
Expected: `27 passed, 0 failed`, no `SCRIPT ERROR`, then `SMOKE OK`.

- [ ] **Step 3: Create the temporary accelerated verification scene**

`dev/verify.gd` (growth every ~0.1 s, 30 damage per hit):
```gdscript
extends Node
## TEMPORARY verification harness for plan A1. Do not commit.

var frames := 0


func _ready() -> void:
	Game.eco = Game.eco.duplicate()
	Game.eco.algae_growth_interval_cold = 0.1
	Game.eco.algae_coral_damage = 30.0
	add_child(load("res://main/main.tscn").instantiate())


func _physics_process(_delta: float) -> void:
	frames += 1
	if frames % 60 == 0:
		var corals := get_tree().get_nodes_in_group(Groups.CORALS)
		var oxygen := corals.map(func(c): return snappedf(c.oxygen, 0.1))
		print("t=", frames / 60, " algae=", get_tree().get_nodes_in_group(Groups.ALGAE).size(),
			" corals=", corals.size(), " oxygen=", oxygen)
	if frames >= 600:
		get_tree().quit()
```

`dev/verify.tscn`:
```ini
[gd_scene format=3]

[ext_resource type="Script" path="res://dev/verify.gd" id="1"]

[node name="Verify" type="Node"]
script = ExtResource("1")
```

- [ ] **Step 4: Run it headless**

Run: `/Applications/Godot.app/Contents/MacOS/Godot --headless --path . res://dev/verify.tscn 2>&1 | grep "^t="`
Expected (exact numbers vary with randomness):
- by `t=1` `algae=200` (cap reached, never above 200);
- `corals` drops from 5 to 1–3 as smothered corals crumble;
- the oxygen of surviving corals increases by `0.5` per line (regen), e.g. `oxygen=[10.1]`, `[10.6]`, `[11.1]`…;
- no `SCRIPT ERROR` / `ERROR:` lines (`... 2>&1 | grep -c ERROR` prints `0`).

- [ ] **Step 5: Manual check in the editor (normal speed)**

Press F5 and watch for ~60 s: every ~10–14 s an algae adds a green cell next to itself; an algae next to a coral makes the coral greyer instead of spreading onto it; a coral that reaches grey crumbles (fades and squashes) and its cells become free; algae never appear on a cell where a fish is swimming.

- [ ] **Step 6: Delete the temporary files and commit**

```bash
rm -rf dev
git add entities/algae/algae.gd
git commit -m "Grow algae over time, suffocate corals and absorb CO2"
```

---

### Task 7: Integrate into main (git flow)

- [ ] **Step 1: Merge `main` into the branch and re-verify**

```bash
git fetch origin && git merge origin/main
tools/test.sh && tools/smoke.sh
```
Expected: `27 passed, 0 failed` (more if Dev B's tests are already on `main`), no `SCRIPT ERROR` line in the output, then `SMOKE OK`. Open the project in the Godot editor and press F5: no errors in the Output panel.

- [ ] **Step 2: Merge to `main`, push, delete the branch**

```bash
BR="$(git branch --show-current)"
git switch main && git pull origin main
git merge "$BR" && git push origin main
git branch -d "$BR"
```

Then tell Dev B: `CellProbe` is on `main`; `Algae.on_co2_absorbed()` and coral crumbling are live (contracts #2, #3, #6).
