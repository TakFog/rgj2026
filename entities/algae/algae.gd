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
