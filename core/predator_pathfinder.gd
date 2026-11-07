class_name PredatorPathfinder
extends RefCounted
## Route planning for the big predator fish (issue #3). Pure: no scene access.
## The predator is wider than a cell, so it moves on grid *corners* (vertices)
## instead of cell centres: a vertex is walkable only when the 2×2 cells around
## it are free. A one-cell corridor between corals therefore has no walkable
## vertex and the predator cannot enter it; a two-cell corridor can be crossed.
## The vertex grid extends `margin` cells beyond the island (open seabed, no
## obstacles), so the predator can enter from and leave to the outside.
##
## Usage: plan_from(position) once (Dijkstra over every reachable vertex), then
## query reach_cost() / path_to() / exit_path() for as many targets as needed.

const SAMPLE_FRACTION := 0.25
const DIAGONAL_COST := 1.4142135
const DIRECTIONS: Array[Vector2i] = [
	Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
	Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1)]

var _grid: GridModel
## `is_solid(occupant: Object) -> bool`: whether a grid occupant blocks the predator.
var _is_solid: Callable
## Half-width (world units) of the corridor a straight shortcut must keep free.
var _clearance: float
var _margin: int
var _solid := {} # Vector2i cell -> true, snapshot taken by plan_from()
var _dist := {} # Vector2i vertex -> path length in cells from the start vertex
var _parent := {} # Vector2i vertex -> Vector2i previous vertex
var _from := Vector2.ZERO


func _init(grid: GridModel, is_solid: Callable, clearance: float, margin := 2) -> void:
	_grid = grid
	_is_solid = is_solid
	_clearance = clearance
	_margin = margin


## Computes the distance to every vertex reachable from `from` (world units).
## Returns false if the predator is stuck (no walkable vertex at all).
func plan_from(from: Vector2) -> bool:
	_snapshot()
	_dist.clear()
	_parent.clear()
	_from = from
	var start: Variant = _nearest_walkable(from)
	if start == null:
		return false
	_dijkstra(start)
	return true


## Path length (world units) to stand within `reach` of `target`, or INF if no
## reachable vertex is close enough (e.g. the target hides in a narrow corridor).
func reach_cost(target: Vector2, reach: float) -> float:
	var vertex: Variant = _best_vertex_near(target, reach)
	return INF if vertex == null else float(_dist[vertex]) * _grid.cell_size


## Smoothed waypoints (world units, excluding the start) to the reachable vertex
## within `reach` of `target` that is closest along the route. Empty if none.
func path_to(target: Vector2, reach: float) -> PackedVector2Array:
	var vertex: Variant = _best_vertex_near(target, reach)
	if vertex == null:
		return PackedVector2Array()
	return _smooth(_backtrack(vertex))


## Smoothed waypoints to the nearest reachable vertex off the island, followed by
## a point `run_out` units further out (away from the island centre). Empty if
## the predator is sealed in.
func exit_path(run_out: float) -> PackedVector2Array:
	var best: Variant = null
	for vertex: Vector2i in _dist:
		if _is_off_island(vertex) and (best == null or _dist[vertex] < _dist[best]):
			best = vertex
	if best == null:
		return PackedVector2Array()
	var path := _smooth(_backtrack(best))
	var exit_point := _vertex_to_world(best)
	var outward := (exit_point - _grid.world_size() * 0.5).normalized()
	path.append(exit_point + outward * run_out)
	return path


## Whether `vertex` is walkable (its 2×2 surrounding cells are free).
func is_walkable(vertex: Vector2i) -> bool:
	if not _in_range(vertex):
		return false
	for offset in [Vector2i(-1, -1), Vector2i(0, -1), Vector2i(-1, 0), Vector2i(0, 0)]:
		if _solid.has(vertex + offset):
			return false
	return true


func _snapshot() -> void:
	_solid.clear()
	for x in _grid.size.x:
		for y in _grid.size.y:
			var cell := Vector2i(x, y)
			var occupant := _grid.occupant(cell)
			if occupant != null and _is_solid.call(occupant):
				_solid[cell] = true


func _in_range(vertex: Vector2i) -> bool:
	return vertex.x >= -_margin and vertex.y >= -_margin \
		and vertex.x <= _grid.size.x + _margin and vertex.y <= _grid.size.y + _margin


func _is_off_island(vertex: Vector2i) -> bool:
	return vertex.x < 0 or vertex.y < 0 or vertex.x > _grid.size.x or vertex.y > _grid.size.y


func _vertex_to_world(vertex: Vector2i) -> Vector2:
	return Vector2(vertex) * _grid.cell_size


## The walkable vertex nearest to `point`: the rounded one if free, else the
## closest walkable vertex overall. Null if none is walkable.
func _nearest_walkable(point: Vector2) -> Variant:
	var low := Vector2i(-_margin, -_margin)
	var high := _grid.size + Vector2i(_margin, _margin)
	var rounded := Vector2i((point / _grid.cell_size).round()).clamp(low, high)
	if is_walkable(rounded):
		return rounded
	var best: Variant = null
	var best_distance := INF
	for x in range(low.x, high.x + 1):
		for y in range(low.y, high.y + 1):
			var vertex := Vector2i(x, y)
			var distance := _vertex_to_world(vertex).distance_squared_to(point)
			if distance < best_distance and is_walkable(vertex):
				best = vertex
				best_distance = distance
	return best


func _dijkstra(start: Vector2i) -> void:
	var heap := _MinHeap.new()
	_dist[start] = 0.0
	heap.push(0.0, start)
	while not heap.is_empty():
		var entry := heap.pop()
		var cost: float = entry[0]
		var vertex: Vector2i = entry[1]
		if cost > _dist[vertex]:
			continue
		for direction in DIRECTIONS:
			var next := vertex + direction
			if not is_walkable(next):
				continue
			var diagonal := direction.x != 0 and direction.y != 0
			if diagonal and not (is_walkable(vertex + Vector2i(direction.x, 0)) and is_walkable(vertex + Vector2i(0, direction.y))):
				continue
			var next_cost := cost + (DIAGONAL_COST if diagonal else 1.0)
			if next_cost < _dist.get(next, INF):
				_dist[next] = next_cost
				_parent[next] = vertex
				heap.push(next_cost, next)


func _best_vertex_near(target: Vector2, reach: float) -> Variant:
	var low := Vector2i(((target - Vector2.ONE * reach) / _grid.cell_size).floor())
	var high := Vector2i(((target + Vector2.ONE * reach) / _grid.cell_size).ceil())
	var best: Variant = null
	for x in range(low.x, high.x + 1):
		for y in range(low.y, high.y + 1):
			var vertex := Vector2i(x, y)
			if not _dist.has(vertex) or _vertex_to_world(vertex).distance_to(target) > reach:
				continue
			if best == null or _dist[vertex] < _dist[best]:
				best = vertex
	return best


func _backtrack(vertex: Vector2i) -> PackedVector2Array:
	var reversed: Array[Vector2i] = [vertex]
	while _parent.has(reversed[-1]):
		reversed.append(_parent[reversed[-1]])
	var path := PackedVector2Array()
	for i in range(reversed.size() - 1, -1, -1):
		path.append(_vertex_to_world(reversed[i]))
	return path


## String pulling from the planning position: from each kept point, jump to
## the farthest waypoint in clear sight (with the predator's clearance).
func _smooth(path: PackedVector2Array) -> PackedVector2Array:
	var result := PackedVector2Array()
	var anchor := _from
	var i := 0
	while i < path.size():
		var farthest := i
		for j in range(path.size() - 1, i, -1):
			if _is_clear(anchor, path[j]):
				farthest = j
				break
		result.append(path[farthest])
		anchor = path[farthest]
		i = farthest + 1
	return result


func _is_clear(a: Vector2, b: Vector2) -> bool:
	var offset := (b - a).orthogonal().normalized() * _clearance
	var steps := maxi(1, ceili(a.distance_to(b) / (_grid.cell_size * SAMPLE_FRACTION)))
	for i in steps + 1:
		var point := a.lerp(b, float(i) / steps)
		for probe in [point, point + offset, point - offset]:
			if _solid.has(_grid.world_to_cell(probe)):
				return false
	return true


## Minimal binary heap of [cost, vertex] pairs.
class _MinHeap:
	var _items: Array = []

	func is_empty() -> bool:
		return _items.is_empty()

	func push(cost: float, value: Variant) -> void:
		_items.append([cost, value])
		var i := _items.size() - 1
		while i > 0:
			var parent := (i - 1) >> 1
			if _items[parent][0] <= _items[i][0]:
				break
			var swap: Array = _items[parent]
			_items[parent] = _items[i]
			_items[i] = swap
			i = parent

	func pop() -> Array:
		var top: Array = _items[0]
		var last: Array = _items.pop_back()
		if not _items.is_empty():
			_items[0] = last
			var i := 0
			while true:
				var smallest := i
				for child in [2 * i + 1, 2 * i + 2]:
					if child < _items.size() and _items[child][0] < _items[smallest][0]:
						smallest = child
				if smallest == i:
					break
				var swap: Array = _items[smallest]
				_items[smallest] = _items[i]
				_items[i] = swap
				i = smallest
		return top
