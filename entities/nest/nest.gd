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
