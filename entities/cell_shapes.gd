class_name CellShapes
extends RefCounted
## Helpers for static entities built out of grid cells.


## Adds one square CollisionShape2D per cell to `body`, positioned relative to
## the body (which must already sit at `Game.grid.cell_to_world(origin)`).
static func add_collision(body: CollisionObject2D, cells: Array[Vector2i], origin: Vector2i) -> void:
	var size := Game.grid.cell_size
	for cell in cells:
		var rect := RectangleShape2D.new()
		rect.size = Vector2(size, size)
		var shape := CollisionShape2D.new()
		shape.shape = rect
		shape.position = Vector2(cell - origin) * size
		body.add_child(shape)


## Attaches a cell entity's art to the y-sorted screen view, sorting it by the
## back edge of its cell instead of the cell centre: the art stands up from the
## cell, so an actor standing on the cell (or anything nearer the camera) must
## be drawn in front of it, while art behind the cell stays behind. The entity
## keeps its logical position; the visual is shifted back to stay on the cell.
static func attach_sorted_by_back_edge(entity: Node2D, visual: Node2D) -> void:
	var anchor := Marker2D.new()
	anchor.position = Vector2(0.0, -Game.grid.cell_size * 0.5)
	entity.add_child(anchor)
	visual.position = Game.projection.to_screen(entity.position) \
			- Game.projection.to_screen(entity.position + anchor.position)
	ViewFollower.attach(anchor, visual, true)
