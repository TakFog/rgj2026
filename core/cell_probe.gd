class_name CellProbe
extends RefCounted
## Physics queries about grid cells (roadmap contract #2).
## Call from _physics_process or deferred code, never inside physics callbacks.

## Shrinks the probe so actors merely touching a cell edge do not count.
const MARGIN := 2.0

## Reused across calls: placement probes up to 4 cells 10 times a second.
static var _params: PhysicsShapeQueryParameters2D
static var _rect: RectangleShape2D


## True if a fish (body) or a threat (area) overlaps `cell`.
static func is_covered_by_actor(cell: Vector2i) -> bool:
	if _params == null:
		_rect = RectangleShape2D.new()
		_params = PhysicsShapeQueryParameters2D.new()
		_params.shape = _rect
		_params.collision_mask = Layers.FISH | Layers.THREAT
		_params.collide_with_bodies = true
		_params.collide_with_areas = true
	# The cell size is re-read every call: Game.reset() rebuilds the grid.
	var size := Vector2.ONE * (Game.grid.cell_size - MARGIN * 2.0)
	if _rect.size != size:
		_rect.size = size
	_params.transform = Transform2D(0.0, Game.grid.cell_to_world(cell))
	var space := Game.world.get_world_2d().direct_space_state
	return not space.intersect_shape(_params, 1).is_empty()
