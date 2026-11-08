# Inventory Drag-and-Drop Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let the player press an inventory card, drag it onto the reef and release to place it, with the same gesture on mouse and Android touch.

**Architecture:** `PlacementController` owns the drag state and the pure release decision. `InventoryBar` starts placement and arms the drag from each card's `button_down`. The existing placement ghost follows the pointer; on release the controller places, keeps placing, or cancels. No new input actions or project settings.

**Tech Stack:** Godot 4.7.2, GDScript, Compatibility renderer, custom headless test runner.

**Spec:** `docs/superpowers/specs/2026-11-08-drag-and-drop-design.md`

## Global Constraints

- Godot 4.7.2 stable, GDScript, Compatibility renderer.
- Touch-only behaviour is gated on `Platform.is_touch()`; web keeps its current controls.
- No changes to `project.godot` or `export_presets.cfg`.
- `tools/lint.sh` must report zero errors and zero GDScript warnings; `tools/test.sh` and `tools/smoke.sh` must pass.
- Commit messages in English, explicit paths only, never on `main`.
- Do not merge this branch.

## Review Focus

- A plain click/tap on a card must select it, not count as a zero-length drag that cancels placement.
- A disabled (empty/refilling) card must never start a drag.
- Releasing outside the reef must return the item to the inventory, not consume it.
- Losing focus mid-drag (which opens the pause menu) must not leave a stale drag that places an item on the next click.
- A touch drag near the bottom edge must still reach the last row even though the ghost is lifted above the finger.

---

### Task 1: Pure drag release decision and touch lift

**Files:**
- Modify: `systems/a_placement_controller.gd` (constants block, around lines 15-23)
- Test: `tests/unit/test_drag_and_drop.gd` (create)

**Interfaces:**
- Consumes: nothing.
- Produces:
  - `enum DropResult { IGNORED, PLACE, KEEP, CANCEL }`
  - `const DRAG_DEAD_ZONE := 10.0`
  - `const TOUCH_DRAG_LIFT := 40.0`
  - `static func drop_result(moved_px: float, inside: bool, valid: bool) -> DropResult`
  - `static func drag_lift(touch: bool, dragging: bool) -> Vector2`

- [ ] **Step 1: Write the failing tests**

Create `tests/unit/test_drag_and_drop.gd`:

```gdscript
extends TestCase
## Inventory drag-and-drop: release decision and the touch fingertip lift.


func test_a_press_that_does_not_move_is_a_click() -> void:
	assert_eq(PlacementController.drop_result(0.0, true, true), PlacementController.DropResult.IGNORED)
	assert_eq(
		PlacementController.drop_result(PlacementController.DRAG_DEAD_ZONE - 0.1, true, false),
		PlacementController.DropResult.IGNORED)


func test_a_drag_released_outside_the_reef_cancels() -> void:
	assert_eq(
		PlacementController.drop_result(PlacementController.DRAG_DEAD_ZONE, false, false),
		PlacementController.DropResult.CANCEL)


func test_a_drag_released_on_an_invalid_cell_keeps_placing() -> void:
	assert_eq(
		PlacementController.drop_result(PlacementController.DRAG_DEAD_ZONE, true, false),
		PlacementController.DropResult.KEEP)


func test_a_drag_released_on_a_valid_cell_places() -> void:
	assert_eq(
		PlacementController.drop_result(PlacementController.DRAG_DEAD_ZONE, true, true),
		PlacementController.DropResult.PLACE)


func test_touch_drag_lifts_the_ghost_above_the_finger() -> void:
	assert_eq(
		PlacementController.drag_lift(true, true),
		Vector2(0.0, -PlacementController.TOUCH_DRAG_LIFT))


func test_mouse_drag_and_tap_preview_do_not_lift() -> void:
	assert_eq(PlacementController.drag_lift(false, true), Vector2.ZERO)
	assert_eq(PlacementController.drag_lift(true, false), Vector2.ZERO)
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `tools/test.sh`

Expected: FAIL — `Invalid call. Nonexistent function 'drop_result' in base 'GDScript'` (or the enum/constants are missing).

- [ ] **Step 3: Implement the helpers in `systems/a_placement_controller.gd`**

Add below the existing `NO_CELL` constant:

```gdscript
## What releasing a drag does.
enum DropResult {
	IGNORED, ## Moved less than the dead zone: it was a click/tap, placement stays active.
	PLACE, ## Released on a valid cell: place the item.
	KEEP, ## Released on an invalid cell inside the reef: keep placing it.
	CANCEL, ## Released outside the reef: cancel and return the item.
}

## Screen pixels the pointer must travel before a press becomes a drag. Keeps a
## plain click/tap on a card from being treated as a zero-length drag.
const DRAG_DEAD_ZONE := 10.0
## Touch drags lift the ghost this many screen pixels above the fingertip, so
## the finger does not cover it. About two rows at the default camera zoom.
const TOUCH_DRAG_LIFT := 40.0
```

Add the two static functions near `touch_tap_confirms`:

```gdscript
## What a drag release does. `moved_px` is the pointer travel since the card
## was pressed, `inside` is whether the drop cell is on the reef and `valid`
## is whether the item can be placed there.
static func drop_result(moved_px: float, inside: bool, valid: bool) -> DropResult:
	if moved_px < DRAG_DEAD_ZONE:
		return DropResult.IGNORED
	if not inside:
		return DropResult.CANCEL
	return DropResult.PLACE if valid else DropResult.KEEP


## Screen-space offset applied to the pointer while dragging on touch.
static func drag_lift(touch: bool, dragging: bool) -> Vector2:
	if touch and dragging:
		return Vector2(0.0, -TOUCH_DRAG_LIFT)
	return Vector2.ZERO
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `tools/test.sh`

Expected: PASS, including all `test_drag_and_drop.gd` tests.

- [ ] **Step 5: Commit**

```bash
git add systems/a_placement_controller.gd tests/unit/test_drag_and_drop.gd
git commit -m "Add drag-drop release decision and touch lift"
```

---

### Task 2: Wire card press, drag tracking and release

**Files:**
- Modify: `systems/a_placement_controller.gd`
- Modify: `ui/a_inventory_bar.gd:22`
- Modify: `README.md` (Controls and Android tables)
- Modify: `docs/android.md` ("What differs on Android" table)
- Test: `tests/unit/test_drag_and_drop.gd`

**Interfaces:**
- Consumes: `DropResult`, `drop_result()`, `drag_lift()` from Task 1; existing `begin(slot)`, `can_place(cells)`, `footprint(origin)`, `try_place_at(origin)`, `cancel()`.
- Produces:
  - `func begin_drag(slot: int) -> void`
  - `func _notification(what: int) -> void`
  - `func _input(event: InputEvent) -> void`
  - `func _finish_drag() -> void`
  - `static func pointer_cell(pointer_screen: Vector2, touch: bool, dragging: bool) -> Vector2i`
  - `func _pointer_cell() -> Vector2i`
  - `func _disarm_drag() -> void`

- [ ] **Step 1: Write the failing tests**

Append to `tests/unit/test_drag_and_drop.gd`:

```gdscript
func test_drag_from_a_refilling_slot_is_ignored() -> void:
	var inventory := InventorySystem.new()
	inventory.model = InventoryModel.new(
		Game.eco, RandomNumberGenerator.new(), func() -> int: return 0)
	var placement := PlacementController.new()
	placement.inventory = inventory
	placement.begin_drag(0)
	assert_eq(placement.active_slot, -1)
	placement.free()
	inventory.free()


func test_disarming_a_drag_stops_tracking() -> void:
	var placement := PlacementController.new()
	placement._dragging = true
	placement._disarm_drag()
	assert_false(placement._dragging)
	placement.free()


func test_a_lifted_touch_drag_can_still_reach_the_bottom_row() -> void:
	var previous_grid := Game.grid
	var previous_projection := Game.projection
	Game.grid = GridModel.new(Vector2i(20, 20), 32.0)
	Game.projection = ViewProjection.from_settings(Game.VIEW_SETTINGS)
	var last_row := Vector2i(5, 19)
	var finger := Game.projection.to_screen(Game.grid.cell_to_world(last_row)) \
			+ Vector2(0.0, PlacementController.TOUCH_DRAG_LIFT)
	var dropped := PlacementController.pointer_cell(finger, true, true)
	Game.grid = previous_grid
	Game.projection = previous_projection
	assert_eq(dropped, last_row)
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `tools/test.sh`

Expected: FAIL — `Invalid call. Nonexistent function 'begin_drag'` and `_disarm_drag`.

- [ ] **Step 3: Implement the drag state in `systems/a_placement_controller.gd`**

Add state next to `_touch_origin`:

```gdscript
## True while the player holds an inventory card down to drag it onto the reef.
var _dragging := false
## Viewport position where the card was pressed, to tell a click from a drag.
var _drag_origin_screen := Vector2.ZERO
```

In `begin()`, as the first line, reset any drag from a previous press:

```gdscript
	_disarm_drag()
```

Keep the readiness check, `_touch_origin = NO_CELL` and the rest unchanged.

In `cancel()`, add `_disarm_drag()`.

Add after `begin()`:

```gdscript
## Starts placing `slot` and arms drag tracking. Called when an inventory card
## is pressed; a release after moving past DRAG_DEAD_ZONE drops the item.
func begin_drag(slot: int) -> void:
	begin(slot)
	if active_slot != slot:
		return
	_dragging = true
	_drag_origin_screen = get_viewport().get_mouse_position()


## Stops tracking the drag without changing the active placement.
func _disarm_drag() -> void:
	_dragging = false
	_drag_origin_screen = Vector2.ZERO
```

Add the pointer helper near `_preview_origin()`:

```gdscript
## Cell under `pointer_screen`, lifted above the fingertip while dragging on
## touch. Static so the edge behaviour is unit-testable.
static func pointer_cell(pointer_screen: Vector2, touch: bool, dragging: bool) -> Vector2i:
	var point := pointer_screen - drag_lift(touch, dragging)
	return Game.grid.world_to_cell(Game.projection.to_world(point))


## Cell under the real pointer.
func _pointer_cell() -> Vector2i:
	return pointer_cell(Game.view.get_global_mouse_position(), touch_mode, _dragging)
```

Change the mouse branch of `_preview_origin()` from
`return Game.grid.world_to_cell(Game.mouse_world())` to
`return _pointer_cell()`.

Add the drag input handler and release logic:

```gdscript
## Drag tracking runs in _input so it still sees motion and the release when a
## Control consumes them. Only active after a card press armed the drag.
func _input(event: InputEvent) -> void:
	if not _dragging or active_slot < 0:
		return
	var motion := event as InputEventMouseMotion
	if motion != null:
		if touch_mode:
			_touch_origin = _pointer_cell()
		return
	var button := event as InputEventMouseButton
	if button != null and button.button_index == MOUSE_BUTTON_LEFT and not button.pressed:
		_finish_drag()


## Decides what the release does: place, keep placing, or cancel and return the
## item. A short press that never left the dead zone is left alone so the
## normal click/tap-to-place flow keeps working.
func _finish_drag() -> void:
	var origin := _pointer_cell()
	var inside := Game.grid.in_bounds(origin)
	var valid := inside and can_place(footprint(origin))
	var moved := get_viewport().get_mouse_position().distance_to(_drag_origin_screen)
	var result := drop_result(moved, inside, valid)
	_disarm_drag()
	if result == DropResult.IGNORED:
		return
	if touch_mode:
		_touch_origin = origin
	if result == DropResult.CANCEL:
		cancel()
		placement_cancelled.emit()
	else:
		try_place_at(origin)


## Losing focus opens the pause menu; drop the drag so a later release cannot
## place the item. Placement itself stays active under the menu.
func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		_disarm_drag()
```

In `_handle_touch()`, change the motion branch to use the lifted cell:

```gdscript
	if motion != null and motion.button_mask & MOUSE_BUTTON_MASK_LEFT and _touch_origin != NO_CELL:
		_touch_origin = _pointer_cell()
		return true
```

- [ ] **Step 4: Start the drag from the card**

In `ui/a_inventory_bar.gd`, replace

```gdscript
		card.pressed.connect(placement.begin.bind(i))
```

with

```gdscript
		# Press starts placement and arms a drag; releasing over the reef places.
		card.button_down.connect(placement.begin_drag.bind(i))
```

- [ ] **Step 5: Run the tests to verify they pass**

Run: `tools/test.sh`

Expected: PASS, including the two new tests.

- [ ] **Step 6: Update the docs**

In `README.md`, add a row to the Controls table:

```markdown
| Drag an inventory card onto the reef | Place it (release on a valid cell) |
```

In the Android table, add:

```markdown
| Drag an inventory card onto the reef | Place it in one gesture (the preview sits above the finger) |
```

In `docs/android.md`, add a row to the "What differs on Android" table:

```markdown
| Click a card, then click the reef | Drag a card onto the reef and release; the preview is lifted above the finger while dragging |
```

- [ ] **Step 7: Run the full checks**

Run: `tools/lint.sh`
Expected: `LINT OK`

Run: `tools/test.sh`
Expected: all tests pass.

Run: `tools/smoke.sh`
Expected: `SMOKE OK`

- [ ] **Step 8: Commit**

```bash
git add systems/a_placement_controller.gd ui/a_inventory_bar.gd tests/unit/test_drag_and_drop.gd README.md docs/android.md
git commit -m "Place inventory items by dragging cards onto the reef"
```

---

## Manual verification

- Desktop: press a card, drag over the reef, release on a valid cell — the item is placed. Press and release the card without moving, then click the reef — the old flow still works.
- Desktop: drag and release on an occupied cell — the red preview stays and the item is not consumed. Drag outside the reef — placement cancels.
- Android (`-- --touch-ui` on desktop, or an APK on a phone): drag a card with a finger; the preview sits above the fingertip, including the bottom row. Releasing places it there.
- Pause or alt-tab mid-drag, resume, then click the reef — no item is placed by the stale drag.
