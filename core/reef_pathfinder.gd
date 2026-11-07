class_name ReefPathfinder
extends RefCounted
## Grid route planning for fish over GridModel (corals, algae and nests live on
## the grid; fish move freely between them). Pure: no scene access.
## The A* grid is rebuilt from GridModel only when the grid changed since the
## last query (`GridModel.version`). Finders built with the same `share_key`
## on the same grid share one A* grid, so a school of fish rebuilds it once.
## Routes are smoothed: waypoints the fish can skip in a straight line (with
## `clearance` to spare on both sides) are dropped, so it never zigzags along
## the grid in open water.

## Sampling step along a shortcut, as a fraction of the cell size.
const SAMPLE_FRACTION := 0.25
## Smoothing looks at most this many waypoints ahead for a shortcut, which
## bounds the sight-line checks on long routes through maze-like reefs (an
## open-water route on the 20x20 reef is at most 20 waypoints).
const MAX_LOOKAHEAD := 24


## A* grid mirroring the solidity of a GridModel at `version`.
class Snapshot:
	extends RefCounted
	var astar := AStarGrid2D.new()
	var version := -1


var _grid: GridModel
## `is_solid(occupant: Object) -> bool`: whether a grid occupant blocks fish.
## Must depend only on the occupant itself (not on time or other state): the
## result is cached until the grid changes.
var _is_solid: Callable
## Half-width (world units) of the corridor a straight shortcut must keep free.
var _clearance: float
var _snapshot: Snapshot
var _astar: AStarGrid2D


## Finders given the same non-empty `share_key` on the same grid share their
## A* grid: they must use the same `is_solid` rule.
func _init(grid: GridModel, is_solid: Callable, clearance := 0.0, share_key := &"") -> void:
	_grid = grid
	_is_solid = is_solid
	_clearance = clearance
	var key := "reef_pathfinder/" + share_key
	if share_key != &"" and grid.derived.has(key):
		_snapshot = grid.derived[key]
	else:
		_snapshot = Snapshot.new()
		_snapshot.astar.region = Rect2i(Vector2i.ZERO, grid.size)
		_snapshot.astar.cell_size = Vector2.ONE * grid.cell_size
		_snapshot.astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
		_snapshot.astar.update()
		if share_key != &"":
			grid.derived[key] = _snapshot
	_astar = _snapshot.astar


## Waypoints (world units) from `from` to `to` (excluding `from`): smoothed
## cell centres, ending exactly at `to`. If `to` is inside a solid cell or sealed
## off, the route ends in the reachable cell closest to it and the last segment
## still aims at `to`, so the fish touches whatever is there. Starting inside a
## solid cell: just `[to]`.
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
	return _smooth(from, path)


## Nearest occupant (by path length) for which `predicate(occupant) -> bool`.
## Returns `{occupant, path}` where the (smoothed) path ends at the centre of
## the touched occupant cell, or `{}` if none is reachable.
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
		for offset in GridModel.NEIGHBORS_4:
			var next := cell + offset
			if not _grid.in_bounds(next) or visited.has(next):
				continue
			visited[next] = true
			var occupant := _grid.occupant(next)
			if occupant != null and predicate.call(occupant):
				return {"occupant": occupant, "path": _smooth(from, _path_to_touch(start, cell, next))}
			if not _astar.is_point_solid(next):
				queue.append(next)
	return {}


func _path_to_touch(start: Vector2i, stand: Vector2i, touch: Vector2i) -> PackedVector2Array:
	var path := PackedVector2Array()
	if stand != start:
		path = _cells_to_world(_astar.get_id_path(start, stand))
	path.append(_grid.cell_to_world(touch))
	return path


## Clear straight line between two points, `clearance` wide on each side.
## Only grid occupants count: the map border is left to physics. The cell of
## `b` itself is ignored when `touch_b` (the route ends by bumping into it).
func is_clear(a: Vector2, b: Vector2, touch_b := false) -> bool:
	_refresh()
	return _is_clear(a, b, touch_b)


func _is_clear(a: Vector2, b: Vector2, touch_b: bool) -> bool:
	var offset := (b - a).orthogonal().normalized() * _clearance
	var skip := _grid.world_to_cell(b) if touch_b else Vector2i(-1, -1)
	var steps := maxi(1, ceili(a.distance_to(b) / (_grid.cell_size * SAMPLE_FRACTION)))
	for i in steps + 1:
		var point := a.lerp(b, float(i) / steps)
		if _solid_at(point, skip) or _solid_at(point + offset, skip) or _solid_at(point - offset, skip):
			return false
	return true


## String pulling: from each kept point, jump to the farthest waypoint in
## clear sight (at most MAX_LOOKAHEAD ahead). The start point `from` itself is
## not part of the result.
func _smooth(from: Vector2, path: PackedVector2Array) -> PackedVector2Array:
	var result := PackedVector2Array()
	var anchor := from
	var i := 0
	while i < path.size():
		var farthest := i
		for j in range(mini(path.size() - 1, i + MAX_LOOKAHEAD), i, -1):
			if _is_clear(anchor, path[j], j == path.size() - 1):
				farthest = j
				break
		result.append(path[farthest])
		anchor = path[farthest]
		i = farthest + 1
	return result


func _solid_at(point: Vector2, skip: Vector2i) -> bool:
	var cell := _grid.world_to_cell(point)
	return cell != skip and _grid.in_bounds(cell) and _astar.is_point_solid(cell)


func _refresh() -> void:
	if _snapshot.version == _grid.version:
		return
	_snapshot.version = _grid.version
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
