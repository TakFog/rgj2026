class_name CellProbe
extends RefCounted
## Physics queries about grid cells (roadmap contract #2).
## Call from _physics_process or deferred code, never inside physics callbacks.

## Shrinks the probe so actors merely touching a cell edge do not count.
const MARGIN := 2.0


## True if a fish (body) or a threat (area) overlaps `cell`.
static func is_covered_by_actor(cell: Vector2i) -> bool:
	var rect := RectangleShape2D.new()
	rect.size = Vector2.ONE * (Game.grid.cell_size - MARGIN * 2.0)
	var params := PhysicsShapeQueryParameters2D.new()
	params.shape = rect
	params.transform = Transform2D(0.0, Game.grid.cell_to_world(cell))
	params.collision_mask = Layers.FISH | Layers.THREAT
	params.collide_with_bodies = true
	params.collide_with_areas = true
	var space := Game.world.get_world_2d().direct_space_state
	return not space.intersect_shape(params, 1).is_empty()
