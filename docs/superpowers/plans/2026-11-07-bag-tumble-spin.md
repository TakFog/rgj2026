# Plastic Bag Tumble Spin Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the plastic bag's sprite tumble around its own centre with a varying, randomly directed spin, and drop its ground shadow — purely cosmetic.

**Architecture:** A small seeded model (`core/tumble_spin.gd`, mirroring `DriftMotion`) produces the sprite angle; `Threat` gains a no-op `_animate_body(delta)` hook plus a `show_shadow` flag so subclasses can animate their sprite and hide their shadow without touching the gameplay loop; `PlasticBag` wires both up. Nothing in movement, collision or damage changes.

**Tech Stack:** Godot 4.7.2, GDScript, headless unit tests via `tools/test.sh`.

**Spec:** `docs/superpowers/specs/2026-11-07-bag-tumble-spin-design.md`

## Global Constraints

- Work only on branch `TakFog/bag-tumble-spin` (`gh api user -q .login` = `TakFog`); never on `main`.
- Never stage `project.godot` or `export_presets.cfg`; stage files by explicit path and check `git diff --cached --stat` before every commit.
- Commit messages in English.
- No gameplay change: `heading`, `speed`, `radius`, `_turn_scale`, `_steer_inward`, `_on_contact` and `destroy` stay byte-for-byte as they are.
- `bag_spin_speed` default `1.5` rad/s in `data/balance_actors.gd`; `data/balance_actors.tres` is left untouched (it stores only non-default values).
- CO2 clouds and cyclones keep their ground shadows (`show_shadow` defaults to `true`).
- No debug-overlay entry: this is not a feature flag.

## Review Focus

- A bag created without `setup()` (debug placement, future code) must not crash when the visual animates — `_spin`/`_body` guarded.
- `bag_spin_speed = 0` (designer off-switch) must freeze the bag cleanly, never produce NaN or errors.
- A long frame hitch must not snap the bag into a wild spin: per-step angle change stays within `max_speed × delta`.
- CO2 clouds and cyclones must still show their ground shadow after the flag lands — only bags lose theirs.
- The bag's collision footprint and path must stay identical while the sprite spins.

---

### Task 1: Tumble spin model

**Files:**
- Create: `core/tumble_spin.gd`
- Test: `tests/unit/test_tumble_spin.gd`

**Interfaces:**
- Consumes: `RandomNumberGenerator`.
- Produces: `class_name TumbleSpin extends RefCounted`; `TumbleSpin.new(p_max_speed: float, rng: RandomNumberGenerator)`; `var max_speed: float`; `var angle: float` (current angle, radians, wrapped to `[-PI, PI]`); `var rate: float` (current angular velocity, signed rad/s); `func step(delta: float) -> float` returning the new `angle`.

- [ ] **Step 1: Write the failing test `tests/unit/test_tumble_spin.gd`**

```gdscript
extends TestCase


func _spin(seed_value: int, max_speed := 1.0) -> TumbleSpin:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return TumbleSpin.new(max_speed, rng)


func test_zero_speed_freezes_the_angle() -> void:
	var spin := _spin(1, 0.0)
	var angle := spin.step(0.1)
	for i in 50:
		assert_almost(spin.step(0.25), angle)
	assert_almost(spin.rate, 0.0)


func test_step_never_exceeds_max_speed() -> void:
	var spin := _spin(5, 1.0)
	var angle := spin.angle
	for i in 400:
		var next := spin.step(0.05)
		assert_true(absf(wrapf(next - angle, -PI, PI)) <= 1.0 * 0.05 + 0.000001,
				"step %d moved %f" % [i, wrapf(next - angle, -PI, PI)])
		angle = next


func test_rate_stays_within_max_speed() -> void:
	var spin := _spin(7, 2.0)
	for i in 400:
		spin.step(0.05)
		assert_true(absf(spin.rate) <= 2.0 + 0.000001, "rate %f" % spin.rate)


func test_angle_stays_wrapped() -> void:
	var spin := _spin(9, 4.0)
	for i in 400:
		assert_true(absf(spin.step(0.05)) <= PI + 0.000001)


func test_both_directions_occur_across_seeds() -> void:
	var seen_positive := false
	var seen_negative := false
	for seed_value in range(1, 21):
		var spin := _spin(seed_value, 1.0)
		for i in 200:
			spin.step(0.05)
			seen_positive = seen_positive or spin.rate > 0.0
			seen_negative = seen_negative or spin.rate < 0.0
	assert_true(seen_positive, "no clockwise spin")
	assert_true(seen_negative, "no counter-clockwise spin")


func test_speed_varies_between_stall_and_spin() -> void:
	var spin := _spin(3, 1.0)
	var slowest := 1.0
	var fastest := 0.0
	for i in 400:
		spin.step(0.05)
		slowest = minf(slowest, absf(spin.rate))
		fastest = maxf(fastest, absf(spin.rate))
	assert_true(slowest < 0.3, "never nearly stopped, slowest %f" % slowest)
	assert_true(fastest > 0.5, "never really spun, fastest %f" % fastest)


func test_direction_reverses() -> void:
	var spin := _spin(3, 1.0)
	var reversed := false
	for i in 400:
		var before := signf(spin.rate)
		spin.step(0.05)
		if before != 0.0 and signf(spin.rate) == -before:
			reversed = true
	assert_true(reversed, "never changed direction")


func test_same_seed_gives_the_same_angles() -> void:
	var a := _spin(11, 1.5)
	var b := _spin(11, 1.5)
	for i in 200:
		assert_almost(a.step(0.05), b.step(0.05))
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `tools/test.sh`
Expected: FAIL — `TumbleSpin` is not declared / `Could not find type "TumbleSpin"`.

- [ ] **Step 3: Implement `core/tumble_spin.gd`**

```gdscript
class_name TumbleSpin
extends RefCounted
## Cosmetic tumble of a sprite floating in the current (plastic bag): the angle
## turns in a random direction, its rate wandering between a near stall and
## max_speed and sometimes reversing. Purely visual — it never drives gameplay.

## How fast the rate eases toward its current target, per second.
const RATE_CHANGE := 2.5
## Shortest / longest time, in seconds, a spin target is kept before re-rolling.
const SPIN_SECONDS_MIN := 0.2
const SPIN_SECONDS_MAX := 0.6
## A stall target lasts longer than a spin one, so the bag really comes to a
## near-stop before it picks up the current again.
const STALL_SECONDS_MIN := 0.6
const STALL_SECONDS_MAX := 1.2
## Chance a new target is a stall (rate eased to 0) instead of a spin.
const STALL_CHANCE := 0.3

var max_speed: float
## Current angle, radians, wrapped to [-PI, PI].
var angle := 0.0
## Current angular velocity, signed radians per second.
var rate := 0.0

var _rng: RandomNumberGenerator
var _target := 0.0
var _time_to_retarget := 0.0
```

`_init(p_max_speed: float, rng: RandomNumberGenerator)`: store both, start `angle` at `_rng.randf_range(-PI, PI)`; if `max_speed > 0.0`, start `rate` at `_rng.randf_range(0.3, 1.0) * max_speed` with a random sign and call `_pick_target()`.

`step(delta: float) -> float`: return `angle` unchanged when `max_speed <= 0.0`; otherwise count `_time_to_retarget` down and call `_pick_target()` when it reaches 0, ease `rate = lerpf(rate, _target, clampf(RATE_CHANGE * delta, 0.0, 1.0))`, then `angle = wrapf(angle + rate * delta, -PI, PI)` and return it.

`_pick_target() -> void`: with probability `STALL_CHANCE` the target is `0.0` and `_time_to_retarget = _rng.randf_range(STALL_SECONDS_MIN, STALL_SECONDS_MAX)`; otherwise `_target = _rng.randf_range(0.2, 1.0) * max_speed` with a random sign and `_time_to_retarget = _rng.randf_range(SPIN_SECONDS_MIN, SPIN_SECONDS_MAX)`.

- [ ] **Step 4: Run the tests to verify they pass**

Run: `tools/test.sh`
Expected: `... 0 failed`, including every `test_tumble_spin.gd` case.

- [ ] **Step 5: Commit**

```bash
git add core/tumble_spin.gd core/tumble_spin.gd.uid tests/unit/test_tumble_spin.gd tests/unit/test_tumble_spin.gd.uid
git commit -m "feat: add tumble spin model for drifting sprites"
```

(`.uid` files are generated by the editor/headless import; stage them if present.)

---

### Task 2: Threat hook, shadow flag and bag wiring

**Files:**
- Modify: `entities/threats/threat.gd` (visual and physics hook only)
- Modify: `entities/threats/plastic_bag.gd`
- Modify: `data/balance_actors.gd:98-102`
- Test: `tests/unit/test_threat_visuals.gd`

**Interfaces:**
- Consumes: `TumbleSpin.new(max_speed, rng)` and its `step(delta) -> float` from Task 1; `Threat.setup(entry, rng)`.
- Produces: `Threat.show_shadow: bool` (default `true`); `Threat._body: Node2D` (the floating body, null before `_ready`); `Threat._animate_body(delta: float) -> void` (virtual no-op); `BalanceActors.bag_spin_speed: float`.

- [ ] **Step 1: Write the failing test `tests/unit/test_threat_visuals.gd`**

```gdscript
extends TestCase


func test_bag_has_no_shadow() -> void:
	assert_false(PlasticBag.new().show_shadow)


func test_co2_cloud_and_cyclone_keep_their_shadow() -> void:
	assert_true(Co2Cloud.new().show_shadow)
	assert_true(Cyclone.new().show_shadow)


func test_bag_without_setup_does_not_crash_when_animating() -> void:
	var bag := PlasticBag.new()
	bag._animate_body(0.1)
	assert_true(true, "reached without a script error")
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `tools/test.sh`
Expected: FAIL on all three (no `show_shadow` property; `_animate_body` not found).

- [ ] **Step 3: Add the hook and shadow flag to `entities/threats/threat.gd`**

- Next to `var texture: Texture2D`, add `var show_shadow := true` documented as "Whether the ground shadow is drawn under the body (bags float, so they skip it)."
- Add the member `var _body: Node2D` alongside the other private members.
- In `_make_visual()`, wrap the existing `root.add_child(PlaceholderShape.circle(position, radius, Color(0, 0, 0, 0.3)))` line in `if show_shadow:` and, after the sprite/circle body is built, assign `_body = body` before `root.add_child(body)`.
- In `_physics_process`, right after `position += Vector2.from_angle(heading) * speed * delta`, call `_animate_body(delta)`. Leave every other line of that function untouched.
- Add the virtual hook at the end of the file, before `destroy` or after `_make_visual`:

```gdscript
## Cosmetic per-frame animation of the floating body (default: none). Must not
## touch heading, position or collision.
func _animate_body(_delta: float) -> void:
	pass
```

- [ ] **Step 4: Add `bag_spin_speed` to `data/balance_actors.gd`**

After `@export var bag_turn_noise := 2.0`:

```gdscript
## Cosmetic tumble of the bag sprite around its centre, in radians per second
## (peak). 0 freezes the bag. Never affects movement.
@export var bag_spin_speed := 1.5
```

- [ ] **Step 5: Wire the bag in `entities/threats/plastic_bag.gd`**

Add `show_shadow = false` in `_init()` next to the other assignments, add `var _spin: TumbleSpin`, and add:

```gdscript
## The tumble is cosmetic: it shares the spawn RNG only so a seeded run looks
## the same every time, and never feeds back into the heading.
func setup(entry: EdgeEntry, rng: RandomNumberGenerator) -> void:
	super.setup(entry, rng)
	_spin = TumbleSpin.new(Game.actors.bag_spin_speed, rng)


func _animate_body(delta: float) -> void:
	if _spin == null or _body == null:
		return
	_body.rotation = _spin.step(delta)
```

- [ ] **Step 6: Run the tests to verify they pass**

Run: `tools/test.sh`
Expected: all pass, `0 failed`.

- [ ] **Step 7: Boot the game headless**

Run: `tools/smoke.sh`
Expected: `SMOKE OK`.

- [ ] **Step 8: Commit**

```bash
git add entities/threats/threat.gd entities/threats/plastic_bag.gd data/balance_actors.gd tests/unit/test_threat_visuals.gd tests/unit/test_threat_visuals.gd.uid
git commit -m "feat: tumble the plastic bag sprite and drop its shadow"
```

---

### Task 3: Document, verify in game and commit

**Files:**
- Modify: `docs/GDD.md` (§7.2 Busta di plastica)

- [ ] **Step 1: Note the effect in the GDD**

Under "### 7.2 Busta di plastica" add one bullet: `- Puramente estetico: la sprite ruota attorno al suo centro con verso e velocità casuali, come una busta nella corrente, e non ha ombra a terra.`

- [ ] **Step 2: Run the full test suite**

Run: `tools/test.sh`
Expected: `0 failed`.

- [ ] **Step 3: Boot the main scene and look at a bag in game**

Run the project in the editor, wait for a bag spawn (or temporarily spawn one from the debug overlay if it exposes a spawner), and check: the sprite turns slowly and unevenly, sometimes nearly stopping and reversing, pivots on its own centre, and has no shadow while the CO2 cloud and cyclone still do.

- [ ] **Step 4: Merge latest `main` and rerun checks**

```bash
git fetch origin && git merge origin/main
tools/test.sh && tools/smoke.sh
```

Expected: clean merge (resolve conflicts on the feature branch), tests and smoke OK.

- [ ] **Step 5: Commit the GDD line and plan**

```bash
git add docs/GDD.md docs/superpowers/plans/2026-11-07-bag-tumble-spin.md docs/superpowers/specs/2026-11-07-bag-tumble-spin-design.md
git diff --cached --stat
git commit -m "docs: describe the plastic bag tumble and shadow removal"
```
