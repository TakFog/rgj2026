# Fish Reproduction Instinct Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Adult fish that are not hungry, have not reproduced for a while, and notice an empty nest nearby swim to it and fertilize it on their own.

**Architecture:** `FishBrain` gains a pure `SEEKING_NEST` state and a reproduction cooldown, mirroring the existing `SEEKING_FOOD` drive. The `Fish` node searches for the nearest reachable empty nest through `ReefPathfinder`, follows the route, and keeps its existing collision/abort rules. All values are `BalanceActors` exports, and the effective cooldown is clamped to at least twice `BalanceEcosystem.nest_hatch_seconds`.

**Tech Stack:** Godot 4.7.2, GDScript, headless test runner (`tools/test.sh`, `tools/smoke.sh`).

**Spec:** `docs/superpowers/specs/2026-11-07-fish-reproduction-instinct-design.md`

## Global Constraints

- Work on branch `TakFog/fish-reproduction-instinct`; never implement on `main`.
- Never stage `project.godot` or `export_presets.cfg`; that local change stays untouched.
- All tunables live in `data/balance_actors.gd`; defaults may be overridden in `data/balance_actors.tres`.
- Effective reproduction cooldown must always be `max(reproduce_cooldown_seconds, 2 × nest_hatch_seconds)`.
- Player orders always override autonomous drives.
- Hunger wins over reproduction: at hunger ratio `>= seek_food_threshold` the fish abandons a nest.
- GDD is written in Italian; code comments, tests and commit messages in English.
- After every task run `tools/test.sh`; the output must have `0 failed` and no `SCRIPT ERROR`/`Parse Error`.
- GDScript test assertions: `assert_eq`, `assert_true`, `assert_false`, `assert_almost`.

## Review Focus

- A freshly spawned or newly mature fish must **not** instantly seek a nest: the cooldown starts full (`test_waits_for_reproduce_cooldown`).
- A hungry fish must never seek a nest; it must eat first (`test_hungry_adult_does_not_seek_nest`).
- A nest that gained eggs or was removed while the fish was swimming must not be fertilized or retried every frame (`test_nest_reached_without_empty_nest_abandons`, `test_nest_lost_waits_before_retrying`).
- A player order during a nest seek must win (`test_order_cancels_nest_seek`).
- A nest outside the notice radius or with no reachable route must not cause per-frame pathfinding (`test_nearest_occupant_respects_max_distance`, `test_nest_seek_blocked_returns_to_wander_with_retry`).
- A designer setting `reproduce_cooldown_seconds` below twice the hatch time must still get the safe value (`test_effective_cooldown_is_twice_hatch_at_least`).

---

### Task 1: Distance-limited `nearest_occupant`

**Files:**
- Modify: `core/reef_pathfinder.gd`
- Test: `tests/unit/test_reef_pathfinder.gd`

**Interfaces:**
- Produces: `ReefPathfinder.nearest_occupant(from: Vector2, predicate: Callable, max_distance: float = INF) -> Dictionary`. Existing two-argument calls keep working. `max_distance` is a straight-line limit from `from` to the occupant's cell centre; the chosen occupant is still the first matching one found by path-length BFS.

- [ ] **Step 1: Write the failing test**

Add to `tests/unit/test_reef_pathfinder.gd`:

```gdscript
func _is_pad(o: Object) -> bool:
	return o.get_meta(&"kind") == &"pad"


func test_nearest_occupant_respects_max_distance() -> void:
	grid.occupy([Vector2i(4, 0)], pad)
	assert_true(finder.nearest_occupant(_c(0, 0), _is_pad, CELL * 2.5).is_empty(),
			"a nest outside the notice radius is ignored")
	var result := finder.nearest_occupant(_c(0, 0), _is_pad, CELL * 4.5)
	assert_true(result.get("occupant") == pad)
```

- [ ] **Step 2: Run tests to verify the new test fails**

Run: `tools/test.sh`
Expected: `test_nearest_occupant_respects_max_distance` fails (too many arguments / no distance filtering).

- [ ] **Step 3: Add the optional limit**

In `nearest_occupant`, change the signature to accept `max_distance := INF`. When a candidate matches `predicate`, return it only if `_grid.cell_to_world(next).distance_to(from) <= max_distance`; otherwise keep traversing (the cell may be passable, e.g. a nest). Leave the solidity/queue logic unchanged.

- [ ] **Step 4: Run tests to verify they pass**

Run: `tools/test.sh`
Expected: all tests pass, `0 failed`, no script errors.

- [ ] **Step 5: Commit**

```bash
git add core/reef_pathfinder.gd tests/unit/test_reef_pathfinder.gd
git commit -m "Limit nearest occupant search by distance"
```

---

### Task 2: `FishBrain` reproduction drive

**Files:**
- Modify: `core/fish_brain.gd`
- Modify: `data/balance_actors.gd`
- Test: `tests/unit/test_fish_brain.gd`

**Interfaces:**
- Consumes: `BalanceActors.seek_food_threshold`, `seek_retry_seconds` (existing), and the new `BalanceActors.reproduce_cooldown_seconds`.
- Produces:
  - `FishBrain.State.SEEKING_NEST`
  - `var reproduce_cooldown_seconds: float`
  - `FishBrain.new(cfg, adult, p_reproduce_cooldown_seconds := -1.0)` — negative means "use `cfg.reproduce_cooldown_seconds`"
  - `static func effective_reproduce_cooldown(cfg: BalanceActors, hatch_seconds: float) -> float`
  - `wants_to_seek_nest() -> bool`
  - `seek_nest(nest: Object) -> void`
  - `nest_seek_failed() -> void`
  - `nest_reached(empty_nest: Object) -> void`
  - `nest_lost()` also handles `SEEKING_NEST`

- [ ] **Step 1: Add the balance export**

In `data/balance_actors.gd`, in the `Fish` group, add:

```gdscript
## Minimum seconds between two autonomous fertilizations. The Fish node clamps
## it to at least twice the nest hatching time.
@export var reproduce_cooldown_seconds := 40.0
```

- [ ] **Step 2: Write the failing tests**

Update `_make_brain` in `tests/unit/test_fish_brain.gd` to accept an optional cooldown and pass it through:

```gdscript
func _make_brain(adult: bool, reproduce_cooldown := -1.0) -> FishBrain:
	var b := FishBrain.new(cfg, adult, reproduce_cooldown)
	# keep the existing signal wiring below
```

Add these tests:

```gdscript
func test_waits_for_reproduce_cooldown() -> void:
	var ready := _make_brain(true, 5.0)
	assert_false(ready.wants_to_seek_nest(), "not ready right after creation")
	ready.tick(5.1)
	assert_true(ready.wants_to_seek_nest())


func test_juvenile_never_seeks_nest() -> void:
	assert_false(_make_brain(false, 0.0).wants_to_seek_nest())


func test_hungry_adult_does_not_seek_nest() -> void:
	var ready := _make_brain(true, 0.0)
	ready.tick(30.0) # 30 / 45 = 67 % > seek_food_threshold
	assert_false(ready.wants_to_seek_nest())


func test_seek_nest_holds_target() -> void:
	var ready := _make_brain(true, 0.0)
	ready.seek_nest(nest)
	assert_eq(ready.state, FishBrain.State.SEEKING_NEST)
	assert_true(ready.nest == nest)
	assert_true(ready.wants_to_move())
	assert_false(ready.wants_to_seek_nest())


func test_nest_reached_starts_fertilizing_and_restarts_cooldown() -> void:
	var ready := _make_brain(true, 5.0)
	ready.tick(5.1)
	ready.seek_nest(nest)
	ready.nest_reached(nest)
	assert_eq(ready.state, FishBrain.State.FERTILIZING)
	ready.tick(3.1)
	assert_eq(ready.state, FishBrain.State.WANDER)
	assert_eq(fertilized, [nest])
	assert_false(ready.wants_to_seek_nest(), "cooldown restarted after success")


func test_nest_reached_without_empty_nest_abandons() -> void:
	var ready := _make_brain(true, 0.0)
	ready.seek_nest(nest)
	ready.nest_reached(null)
	assert_eq(ready.state, FishBrain.State.WANDER)
	assert_false(ready.wants_to_seek_nest(), "waits before retrying")


func test_nest_lost_waits_before_retrying() -> void:
	var ready := _make_brain(true, 0.0)
	ready.seek_nest(nest)
	ready.nest_lost()
	assert_eq(ready.state, FishBrain.State.WANDER)
	assert_false(ready.wants_to_seek_nest())
	ready.tick(cfg.seek_retry_seconds + 0.1)
	assert_true(ready.wants_to_seek_nest())


func test_hungry_fish_abandons_nest() -> void:
	var ready := _make_brain(true, 0.0)
	ready.seek_nest(nest)
	ready.tick(cfg.starve_seconds * cfg.seek_food_threshold + 0.1)
	assert_eq(ready.state, FishBrain.State.WANDER)
	assert_true(ready.nest == null, "hunger has priority over reproduction")


func test_order_cancels_nest_seek() -> void:
	var ready := _make_brain(true, 0.0)
	ready.seek_nest(nest)
	ready.order(Vector2(10, 0))
	assert_eq(ready.state, FishBrain.State.ORDERED)
	assert_true(ready.nest == null)


func test_nest_seek_blocked_returns_to_wander_with_retry() -> void:
	var ready := _make_brain(true, 0.0)
	ready.seek_nest(nest)
	ready.blocked_by_other()
	assert_eq(ready.state, FishBrain.State.WANDER)
	assert_false(ready.wants_to_seek_nest())


func test_effective_cooldown_is_twice_hatch_at_least() -> void:
	var cfg2 := BalanceActors.new()
	cfg2.reproduce_cooldown_seconds = 40.0
	assert_almost(FishBrain.effective_reproduce_cooldown(cfg2, 25.0), 50.0)
	assert_almost(FishBrain.effective_reproduce_cooldown(cfg2, 10.0), 40.0)
```

- [ ] **Step 3: Run tests to verify they fail**

Run: `tools/test.sh`
Expected: the new tests fail because `SEEKING_NEST`, the constructor argument and the new methods do not exist.

- [ ] **Step 4: Implement the brain rules**

In `core/fish_brain.gd`:

- Append `SEEKING_NEST` to the `State` enum.
- Add `reproduce_cooldown_seconds`, `_reproduce_cooldown` and `_nest_seek_cooldown`.
- In `_init`, resolve a negative third argument to `_cfg.reproduce_cooldown_seconds`, store it in `reproduce_cooldown_seconds`, and start `_reproduce_cooldown` at that value.
- Add `static func effective_reproduce_cooldown(cfg, hatch_seconds) -> float` returning `maxf(cfg.reproduce_cooldown_seconds, hatch_seconds * 2.0)`.
- In `tick`: decrement both cooldowns; if the state is `SEEKING_NEST` and `hunger_ratio() >= _cfg.seek_food_threshold`, call `nest_lost()`.
- `wants_to_move()` includes `SEEKING_NEST`.
- `wants_to_seek_nest()`: not dead, adult, `WANDER`, hunger ratio `< _cfg.seek_food_threshold`, `_reproduce_cooldown <= 0.0`, `_nest_seek_cooldown <= 0.0`.
- `seek_nest(nest)`: ignore unless not dead, adult and `WANDER`; enter `SEEKING_NEST` and set `self.nest`.
- `nest_reached(empty_nest)`: only from `SEEKING_NEST`; if `empty_nest != null` and adult, enter `FERTILIZING` with `_timer = _cfg.fertilize_seconds`; otherwise call `nest_lost()`.
- `nest_seek_failed()`: set `_nest_seek_cooldown = _cfg.seek_retry_seconds`.
- `nest_lost()`: `FERTILIZING` → `WANDER` as today; `SEEKING_NEST` → `WANDER` plus `nest_seek_failed()`.
- `blocked_by_other()`: while `SEEKING_NEST`, go to `WANDER` and `nest_seek_failed()`.
- In `_finish_timed_state` for `FERTILIZING`, reset `_reproduce_cooldown = reproduce_cooldown_seconds` before leaving the state.
- Do not change `blocked_by_algae`, `arrived` or `food_lost` semantics.

- [ ] **Step 5: Run tests to verify they pass**

Run: `tools/test.sh`
Expected: all tests pass, `0 failed`, no script errors.

- [ ] **Step 6: Commit**

```bash
git add core/fish_brain.gd data/balance_actors.gd tests/unit/test_fish_brain.gd
git commit -m "Add reproduction instinct state and cooldown to fish brain"
```

---

### Task 3: Fish node search, movement and debug overlay

**Files:**
- Modify: `entities/fish/fish.gd`
- Modify: `data/balance_actors.gd`
- Modify: `core/debug_overlay.gd`
- Test: `tests/unit/test_ui_localization.gd`

**Interfaces:**
- Consumes: `FishBrain.effective_reproduce_cooldown()`, `wants_to_seek_nest()`, `seek_nest()`, `nest_seek_failed()`, `nest_reached()`, `ReefPathfinder.nearest_occupant(..., max_distance)`.
- Produces: `BalanceActors.reproduce_nest_radius` and the F3 label `"CERCA NIDO"` for `SEEKING_NEST`.

- [ ] **Step 1: Write the failing overlay test**

Add to `tests/unit/test_ui_localization.gd` next to the other fish state assertions:

```gdscript
assert_eq(overlay._state_name(FishBrain.State.SEEKING_NEST), "CERCA NIDO")
```

- [ ] **Step 2: Run tests to verify the new assertion fails**

Run: `tools/test.sh`
Expected: `test_ui_localization` fails because the state name is `"?"`.

- [ ] **Step 3: Add the radius export and the overlay label**

In `data/balance_actors.gd`, next to `reproduce_cooldown_seconds`, add:

```gdscript
## Straight-line distance (world units) within which an empty nest is noticed.
@export var reproduce_nest_radius := 128.0
```

In `core/debug_overlay.gd` `_state_name`, add:

```gdscript
FishBrain.State.SEEKING_NEST: return "CERCA NIDO"
```

- [ ] **Step 4: Wire the Fish node**

In `entities/fish/fish.gd`:

- In `_ready`, construct the brain with
  `FishBrain.new(Game.actors, adult, FishBrain.effective_reproduce_cooldown(Game.actors, Game.eco.nest_hatch_seconds))`.
- In the `WANDER` branch of `_physics_process`, after the food check, add
  `elif brain.wants_to_seek_nest(): _seek_nest()`.
- Add `SEEKING_NEST` to the `ORDERED, SEEKING_FOOD` movement branch.
- Add `_seek_nest()`: call
  `_pathfinder.nearest_occupant(global_position, _is_empty_nest, Game.actors.reproduce_nest_radius)`;
  on an empty result call `brain.nest_seek_failed()`; otherwise reset
  `_replans_left = MAX_REPLANS`, call `brain.seek_nest(result["occupant"])`
  and store `result["path"]` in `_path`.
- Add `_is_empty_nest(occupant: Object) -> bool`: `occupant is Nest and (occupant as Nest).is_empty()`.
- In `_on_path_end`, add a `SEEKING_NEST` case calling `brain.nest_reached(_empty_nest_under())`; keep `ORDERED → arrived` and the rest `food_lost`.
- In `_check_targets_still_exist`, treat `SEEKING_NEST` like `FERTILIZING`: if the target is no longer alive or no longer empty, call `brain.nest_lost()`.
- In `_move`, only route an algae collision to `blocked_by_algae` when the state is `ORDERED` or `SEEKING_FOOD`; a fish seeking a nest slides or re-plans instead of eating.
- In `_replan`, add a `SEEKING_NEST` case that re-plans to `(brain.nest as Node2D).global_position` and returns.
- Keep all existing order, feeding and fertilizing behaviour unchanged.

- [ ] **Step 5: Run unit tests and the smoke test**

Run: `tools/test.sh && tools/smoke.sh`
Expected: all tests pass (`0 failed`, no script errors), then `SMOKE OK`.

- [ ] **Step 6: Manual check in the editor (F5)**

Place a nest, keep one adult fish fed by ordering it onto algae, then let it wander. With the defaults it waits 40 s; to see it sooner, temporarily set `reproduce_cooldown_seconds = 5` and `nest_hatch_seconds = 2.5` in the Inspector (5 ≥ 2 × 2.5), then revert both files before committing. Expected: F3 shows `CERCA NIDO` while it swims to the nest, then `FECONDA`; the nest turns to eggs. A hungry fish never switches to `CERCA NIDO`.

- [ ] **Step 7: Commit**

```bash
git add entities/fish/fish.gd data/balance_actors.gd core/debug_overlay.gd tests/unit/test_ui_localization.gd
git commit -m "Make fish seek nearby empty nests on their own"
```

---

### Task 4: Update the GDD

**Files:**
- Modify: `docs/GDD.md` §5.4

- [ ] **Step 1: Update the WANDER and FERTILIZING bullets**

In §5.4, replace the `WANDER` sentence that says a wandering fish never fertilizes with the new rule: if it is adult, not hungry (hunger below `seek_food_threshold`), an empty nest is within `reproduce_nest_radius` (128 units) and at least `reproduce_cooldown_seconds` (40 s, never less than twice `nest_hatch_seconds`) have passed since the last fertilization, it switches to `SEEKING_NEST`.

- [ ] **Step 2: Add the SEEKING_NEST bullet**

After the `SEEKING_FOOD` bullet, add an Italian `SEEKING_NEST` bullet covering: route to the nearest reachable empty nest within the radius; on arrival → `FERTILIZING`; if the nest is fertilized by another fish or disappears, back to `WANDER` and retry after `seek_retry_seconds`; if hunger reaches 50 % en route, abandon the nest because hunger has priority; player orders always win.

- [ ] **Step 3: Note the cooldown reset**

In the `FERTILIZING` bullet, state that a successful fertilization restarts the reproduction cooldown, and a cancelled one does not.

- [ ] **Step 4: Commit**

```bash
git add docs/GDD.md
git commit -m "Document autonomous fish reproduction in the GDD"
```

---

### Task 5: Integrate and verify the branch

**Files:** none (verification only)

- [ ] **Step 1: Bring `main` into the feature branch**

```bash
git fetch origin
git merge origin/main
```

Resolve conflicts on the feature branch if any.

- [ ] **Step 2: Run the full verification**

```bash
tools/test.sh
tools/smoke.sh
```

Expected: all tests pass (`0 failed`, no `SCRIPT ERROR`/`Parse Error`), then `SMOKE OK`. Open the project in Godot and press F5 once: no errors in Output.

- [ ] **Step 3: Check what will be merged**

```bash
git diff --stat main...HEAD
```

Expected: only the files from this plan; `project.godot` and `export_presets.cfg` are not included.

- [ ] **Step 4: Merge into `main` and push**

```bash
git switch main && git pull origin main
git merge TakFog/fish-reproduction-instinct
git push origin main
```

Keep the feature branch (do not delete it).
