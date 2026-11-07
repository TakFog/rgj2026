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
## Snapshot taken by plan_from(): 1 per solid cell (row-major over the grid).
var _solid_cells := PackedByteArray()
## Snapshot taken by plan_from(): 1 per walkable vertex (row-major over the
## vertex range, `_margin` vertices beyond the island on every side).
var _walkable := PackedByteArray()
var _vertex_columns := 0
var _vertex_rows := 0
## Per vertex index (see _index()): path length in cells from the start vertex
## (INF if unreached) and the previous vertex index on that path (-1 if none).
var _dist := PackedFloat64Array()
var _parent := PackedInt32Array()
## Reached vertex indices, in the order they were first reached (ties in
## exit_path() go to the first one).
var _reached := PackedInt32Array()
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
	_dist.resize(_walkable.size())
	_dist.fill(INF)
	_parent.resize(_walkable.size())
	_parent.fill(-1)
	_reached.clear()
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
	return INF if vertex == null else _dist[_index(vertex)] * _grid.cell_size


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
	var best_index := -1
	for index in _reached:
		if _is_off_island(_vertex_at(index)) and (best_index == -1 or _dist[index] < _dist[best_index]):
			best_index = index
	if best_index == -1:
		return PackedVector2Array()
	var best := _vertex_at(best_index)
	var path := _smooth(_backtrack(best))
	var exit_point := _vertex_to_world(best)
	var outward := (exit_point - _grid.world_size() * 0.5).normalized()
	path.append(exit_point + outward * run_out)
	return path


## Straight route away from the island centre, `run_out` units long, ignoring
## obstacles: for open water off the island, or an actor walled in by corals.
## Falls back to `heading` (then RIGHT) when standing on the centre.
static func straight_exit(from: Vector2, island: Rect2, heading: Vector2, run_out: float) -> PackedVector2Array:
	var outward := (from - island.get_center()).normalized()
	if outward.is_zero_approx():
		outward = heading.normalized() if not heading.is_zero_approx() else Vector2.RIGHT
	return PackedVector2Array([from + outward * run_out])


## Whether `vertex` is walkable (its 2×2 surrounding cells are free).
func is_walkable(vertex: Vector2i) -> bool:
	if not _in_range(vertex):
		return false
	return _walkable[_index(vertex)] == 1


## Takes the solid-cell snapshot and derives the walkable-vertex mask from it:
## a solid cell blocks its 4 corner vertices.
func _snapshot() -> void:
	var size := _grid.size
	_solid_cells.resize(size.x * size.y)
	_solid_cells.fill(0)
	_vertex_columns = size.x + 2 * _margin + 1
	_vertex_rows = size.y + 2 * _margin + 1
	_walkable.resize(_vertex_columns * _vertex_rows)
	_walkable.fill(1)
	for x in size.x:
		for y in size.y:
			var occupant := _grid.occupant(Vector2i(x, y))
			if occupant == null or not _is_solid.call(occupant):
				continue
			_solid_cells[y * size.x + x] = 1
			var corner := (y + _margin) * _vertex_columns + x + _margin
			_walkable[corner] = 0
			_walkable[corner + 1] = 0
			_walkable[corner + _vertex_columns] = 0
			_walkable[corner + _vertex_columns + 1] = 0


## Whether the cell containing world `point` is solid (outside the island never is).
func _solid_at(point: Vector2) -> bool:
	var x := floori(point.x / _grid.cell_size)
	var y := floori(point.y / _grid.cell_size)
	if x < 0 or y < 0 or x >= _grid.size.x or y >= _grid.size.y:
		return false
	return _solid_cells[y * _grid.size.x + x] == 1


## Index of an in-range vertex in the snapshot arrays (row-major).
func _index(vertex: Vector2i) -> int:
	return (vertex.y + _margin) * _vertex_columns + vertex.x + _margin


func _vertex_at(index: int) -> Vector2i:
	var row := floori(float(index) / _vertex_columns)
	return Vector2i(index - row * _vertex_columns - _margin, row - _margin)


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
	# Rare (the start is squeezed against corals): scan the mask, cheap per vertex.
	var best: Variant = null
	var best_distance := INF
	for x in range(low.x, high.x + 1):
		for y in range(low.y, high.y + 1):
			var vertex := Vector2i(x, y)
			if _walkable[_index(vertex)] == 0:
				continue
			var distance := _vertex_to_world(vertex).distance_squared_to(point)
			if distance < best_distance:
				best = vertex
				best_distance = distance
	return best


func _dijkstra(start: Vector2i) -> void:
	var columns := _vertex_columns
	var rows := _vertex_rows
	var heap := _MinHeap.new()
	var start_index := _index(start)
	_dist[start_index] = 0.0
	_reached.append(start_index)
	heap.push(0.0, start_index)
	while not heap.is_empty():
		var cost := heap.top_cost()
		var index := heap.pop()
		if cost > _dist[index]:
			continue
		# Hot loop: index arithmetic on the mask, no helper calls.
		var row := floori(float(index) / columns)
		var column := index - row * columns
		for direction in DIRECTIONS:
			var x := column + direction.x
			var y := row + direction.y
			if x < 0 or y < 0 or x >= columns or y >= rows:
				continue
			var next_index := y * columns + x
			if _walkable[next_index] == 0:
				continue
			var diagonal := direction.x != 0 and direction.y != 0
			if diagonal and (_walkable[row * columns + x] == 0 or _walkable[y * columns + column] == 0):
				continue
			var next_cost := cost + (DIAGONAL_COST if diagonal else 1.0)
			if next_cost < _dist[next_index]:
				if is_inf(_dist[next_index]):
					_reached.append(next_index)
				_dist[next_index] = next_cost
				_parent[next_index] = index
				heap.push(next_cost, next_index)


func _best_vertex_near(target: Vector2, reach: float) -> Variant:
	if _dist.is_empty():
		return null # plan_from() never called
	var low := Vector2i(((target - Vector2.ONE * reach) / _grid.cell_size).floor())
	var high := Vector2i(((target + Vector2.ONE * reach) / _grid.cell_size).ceil())
	var best: Variant = null
	for x in range(low.x, high.x + 1):
		for y in range(low.y, high.y + 1):
			var vertex := Vector2i(x, y)
			if not _in_range(vertex) or is_inf(_dist[_index(vertex)]) \
					or _vertex_to_world(vertex).distance_to(target) > reach:
				continue
			if best == null or _dist[_index(vertex)] < _dist[_index(best)]:
				best = vertex
	return best


func _backtrack(vertex: Vector2i) -> PackedVector2Array:
	var reversed := PackedInt32Array([_index(vertex)])
	while _parent[reversed[-1]] != -1:
		reversed.append(_parent[reversed[-1]])
	var path := PackedVector2Array()
	for i in range(reversed.size() - 1, -1, -1):
		path.append(_vertex_to_world(_vertex_at(reversed[i])))
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
		if _solid_at(point) or _solid_at(point + offset) or _solid_at(point - offset):
			return false
	return true


## Minimal binary min-heap of vertex indices by cost, in parallel arrays (no
## per-operation allocations).
class _MinHeap:
	var _costs := PackedFloat64Array()
	var _values := PackedInt32Array()

	func is_empty() -> bool:
		return _values.is_empty()

	func top_cost() -> float:
		return _costs[0]

	func push(cost: float, value: int) -> void:
		_costs.append(cost)
		_values.append(value)
		var i := _values.size() - 1
		while i > 0:
			var parent := (i - 1) >> 1
			if _costs[parent] <= _costs[i]:
				break
			_swap(parent, i)
			i = parent

	func pop() -> int:
		var top := _values[0]
		var last := _values.size() - 1
		_costs[0] = _costs[last]
		_values[0] = _values[last]
		_costs.resize(last)
		_values.resize(last)
		var i := 0
		while true:
			var smallest := i
			var left := 2 * i + 1
			var right := left + 1
			if left < last and _costs[left] < _costs[smallest]:
				smallest = left
			if right < last and _costs[right] < _costs[smallest]:
				smallest = right
			if smallest == i:
				break
			_swap(smallest, i)
			i = smallest
		return top

	func _swap(a: int, b: int) -> void:
		var cost := _costs[a]
		_costs[a] = _costs[b]
		_costs[b] = cost
		var value := _values[a]
		_values[a] = _values[b]
		_values[b] = value
