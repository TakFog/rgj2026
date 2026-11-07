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

var inventory: InventorySystem
var active_slot := -1

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
	if not inventory.model.is_ready(slot):
		return
	active_slot = slot
	_ghost_cells = []
	_ghost_elapsed = GHOST_REFRESH_SECONDS # show the preview immediately
	Game.placing = true
	placement_started.emit()


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


func _physics_process(delta: float) -> void:
	if active_slot < 0:
		return
	var cells := footprint(Game.grid.world_to_cell(Game.mouse_world()))
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


func _unhandled_input(event: InputEvent) -> void:
	if active_slot < 0:
		return
	if event.is_action_pressed(InputActions.COMMAND):
		try_place_at(Game.grid.world_to_cell(Game.mouse_world()))
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(InputActions.CANCEL):
		cancel()
		placement_cancelled.emit()
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
