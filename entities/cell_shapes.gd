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
