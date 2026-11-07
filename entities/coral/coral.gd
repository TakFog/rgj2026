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
