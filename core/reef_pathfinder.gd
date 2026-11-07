class_name ReefPathfinder
extends RefCounted
## Grid route planning for fish over GridModel (corals, algae and nests live on
## the grid; fish move freely between them). Pure: no scene access.
## The A* grid is rebuilt from GridModel on every query: the map is small and
## changes constantly (algae spread), so there is nothing to keep in sync.

var _grid: GridModel
## `is_solid(occupant: Object) -> bool`: whether a grid occupant blocks fish.
var _is_solid: Callable
var _astar := AStarGrid2D.new()


func _init(grid: GridModel, is_solid: Callable) -> void:
	_grid = grid
	_is_solid = is_solid
	_astar.region = Rect2i(Vector2i.ZERO, grid.size)
	_astar.cell_size = Vector2.ONE * grid.cell_size
	_astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	_astar.update()


## Waypoints (world units) from `from` to `to`: cell centres, ending exactly at
## `to`. If `to` is inside a solid cell or sealed off, the route ends in the
## reachable cell closest to it and the last segment still aims at `to`, so the
## fish touches whatever is there. Starting inside a solid cell: just `[to]`.
func find_path(from: Vector2, to: Vector2) -> PackedVector2Array:
	_refresh()
	var start := _clamp_cell(_grid.world_to_cell(from))
	var goal := _clamp_cell(_grid.world_to_cell(to))
	if start == goal or _astar.is_point_solid(start):
		return PackedVector2Array([to])
	var path := _cells_to_world(_astar.get_id_path(start, goal, true))
	if path.is_empty():
		return PackedVector2Array([to])
	if _grid.world_to_cell(path[path.size() - 1]) == goal:
		path[path.size() - 1] = to
	else:
		path.append(to)
	return path


## Nearest occupant (by path length) for which `predicate(occupant) -> bool`.
## Returns `{occupant, path}` where the path ends at the centre of the touched
## occupant cell, or `{}` if none is reachable.
func nearest_occupant(from: Vector2, predicate: Callable) -> Dictionary:
	_refresh()
	var start := _clamp_cell(_grid.world_to_cell(from))
	if _astar.is_point_solid(start):
		return {}
	var visited := {start: true}
	var queue: Array[Vector2i] = [start]
	var head := 0
	while head < queue.size():
		var cell := queue[head]
		head += 1
		for next in _grid.neighbors4(cell):
			if not _grid.in_bounds(next) or visited.has(next):
				continue
			visited[next] = true
			var occupant := _grid.occupant(next)
			if occupant != null and predicate.call(occupant):
				return {"occupant": occupant, "path": _path_to_touch(start, cell, next)}
			if not _astar.is_point_solid(next):
				queue.append(next)
	return {}


func _path_to_touch(start: Vector2i, stand: Vector2i, touch: Vector2i) -> PackedVector2Array:
	var path := PackedVector2Array()
	if stand != start:
		path = _cells_to_world(_astar.get_id_path(start, stand))
	path.append(_grid.cell_to_world(touch))
	return path


func _refresh() -> void:
	for x in _grid.size.x:
		for y in _grid.size.y:
			var cell := Vector2i(x, y)
			var occupant := _grid.occupant(cell)
			_astar.set_point_solid(cell, occupant != null and _is_solid.call(occupant))


func _clamp_cell(cell: Vector2i) -> Vector2i:
	return cell.clamp(Vector2i.ZERO, _grid.size - Vector2i.ONE)


func _cells_to_world(cells: Array[Vector2i]) -> PackedVector2Array:
	var path := PackedVector2Array()
	for cell in cells:
		path.append(_grid.cell_to_world(cell))
	return path
