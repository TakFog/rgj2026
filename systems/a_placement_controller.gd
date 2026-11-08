class_name PlacementController
extends Node
## Places inventory items on the grid (GDD §5.1). While active, Game.placing is
## true and this node owns the command/cancel input (roadmap contract #8).

## Emitted when an item is picked from the inventory to start placing it.
signal placement_started
## Emitted after a successful placement, with the kind of the placed item.
signal placement_finished(kind: StringName)
## Emitted when the player cancels placement (right click / Esc).
signal placement_cancelled
## Emitted when a click cannot place the item (blocked or out of bounds).
signal placement_failed

const VALID_COLOR := Color(0.3, 1.0, 0.4, 0.45)
const INVALID_COLOR := Color(1.0, 0.25, 0.25, 0.45)
## While the mouse is still, re-check the preview at 10 Hz instead of every
## physics frame: the only thing that can change then is a fish or threat
## swimming over a cell. The ghost still follows the mouse every frame, and a
## cell change revalidates immediately, so placement stays responsive.
const GHOST_REFRESH_SECONDS := 0.1
## Touch preview origin before the first tap on the reef: no ghost is shown.
const NO_CELL := Vector2i(-(1 << 30), -(1 << 30))

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

var inventory: InventorySystem
var active_slot := -1
## Touch builds (Platform.is_touch) have no hover: the ghost sits where the
## player last tapped or dragged, and a second tap on that cell confirms it.
## Mouse builds (web included) keep following the mouse and place on click.
var touch_mode := Platform.is_touch()
var _touch_origin := NO_CELL
## True while the player holds an inventory card down to drag it onto the reef.
var _dragging := false
## Viewport position where the card was pressed, to tell a click from a drag.
var _drag_origin_screen := Vector2.ZERO

var _ghost: Node2D
var _ghost_cells: Array[Vector2i] = []
var _ghost_valid := false
var _ghost_elapsed := GHOST_REFRESH_SECONDS


func _ready() -> void:
	_ghost = Node2D.new()
	_ghost.name = "PlacementGhost"
	_ghost.z_index = 100
	_ghost.draw.connect(_draw_ghost)
	Game.view.add_child(_ghost)


## Starts placing the item of `slot`. Ignored if the slot is refilling.
func begin(slot: int) -> void:
	_disarm_drag()
	if not inventory.model.is_ready(slot):
		return
	active_slot = slot
	_ghost_cells = []
	_touch_origin = NO_CELL
	_ghost_elapsed = GHOST_REFRESH_SECONDS # show the preview immediately
	Game.placing = true
	placement_started.emit()


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


func cancel() -> void:
	_disarm_drag()
	active_slot = -1
	_touch_origin = NO_CELL
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
		placement_failed.emit()
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
	placement_finished.emit(item["kind"])
	return true


## Touch placement: a tap on the cell already previewed confirms it; any other
## tap only moves the preview there.
static func touch_tap_confirms(previewed: Vector2i, tapped: Vector2i) -> bool:
	return previewed != NO_CELL and previewed == tapped


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


## Cell under `pointer_screen`, lifted above the fingertip while dragging on
## touch. Static so the edge behaviour is unit-testable.
static func pointer_cell(pointer_screen: Vector2, touch: bool, dragging: bool) -> Vector2i:
	var point := pointer_screen + drag_lift(touch, dragging)
	return Game.grid.world_to_cell(Game.projection.to_world(point))


## Cell under the real pointer.
func _pointer_cell() -> Vector2i:
	return pointer_cell(Game.view.get_global_mouse_position(), touch_mode, _dragging)


## Cell the ghost is anchored to: the mouse, or the last tap/drag on touch.
func _preview_origin() -> Vector2i:
	if touch_mode:
		return _touch_origin
	return _pointer_cell()


## Cells the ghost covers at `origin`; none before the first touch tap.
func preview_cells(origin: Vector2i) -> Array[Vector2i]:
	if origin == NO_CELL:
		return []
	return footprint(origin)


func _physics_process(delta: float) -> void:
	if active_slot < 0:
		return
	var origin := _preview_origin()
	var cells := preview_cells(origin)
	if cells != _ghost_cells:
		# The mouse entered another cell (or the item changed): follow it and
		# revalidate at once, exactly like the original every-frame preview.
		_ghost_cells = cells
		_ghost_valid = can_place(_ghost_cells)
		_ghost_elapsed = 0.0
		_ghost.queue_redraw()
		return
	# The mouse is still: only actors moving over the cells can invalidate it.
	_ghost_elapsed += delta
	if _ghost_elapsed < GHOST_REFRESH_SECONDS:
		return
	_ghost_elapsed = 0.0
	var valid := can_place(_ghost_cells)
	if valid != _ghost_valid:
		_ghost_valid = valid
		_ghost.queue_redraw()


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
	if button == null or button.button_index != MOUSE_BUTTON_LEFT:
		return
	if button.pressed:
		# A release was missed (e.g. the tree paused mid-drag): never let the
		# stale drag place the item on this new press.
		_disarm_drag()
		return
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


func _unhandled_input(event: InputEvent) -> void:
	# 1-4 pick the matching inventory slot, even while another item is being
	# placed (pressing another number switches to it).
	for i in InputActions.SLOTS.size():
		if event.is_action_pressed(InputActions.SLOTS[i]):
			if i < inventory.model.slots.size():
				begin(i)
				get_viewport().set_input_as_handled()
			return
	if active_slot < 0:
		return
	if touch_mode and _handle_touch(event):
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed(InputActions.COMMAND):
		try_place_at(Game.grid.world_to_cell(Game.mouse_world()))
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(InputActions.CANCEL):
		cancel()
		placement_cancelled.emit()
		get_viewport().set_input_as_handled()


## Touch placement input. Returns true when `event` was used.
func _handle_touch(event: InputEvent) -> bool:
	var tapped := Game.grid.world_to_cell(Game.mouse_world())
	if event.is_action_pressed(InputActions.COMMAND):
		if touch_tap_confirms(_touch_origin, tapped):
			try_place_at(tapped)
		else:
			_touch_origin = tapped
		return true
	# Dragging a finger over the reef drags the preview along.
	var motion := event as InputEventMouseMotion
	if motion != null and motion.button_mask & MOUSE_BUTTON_MASK_LEFT and _touch_origin != NO_CELL:
		_touch_origin = _pointer_cell()
		return true
	return false


func _draw_ghost() -> void:
	var color := VALID_COLOR if _ghost_valid else INVALID_COLOR
	var half := Game.grid.cell_size * 0.5
	for cell in _ghost_cells:
		var c := Game.grid.cell_to_world(cell)
		var corners := PackedVector2Array([
			c + Vector2(-half, -half), c + Vector2(half, -half),
			c + Vector2(half, half), c + Vector2(-half, half)])
		_ghost.draw_colored_polygon(Game.projection.project_polygon(corners, Vector2.ZERO), color)
