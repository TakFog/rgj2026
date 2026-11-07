class_name GridModel
extends RefCounted
## Logical placement grid for static entities (corals, algae, nests).
## One static entity per cell. Cell (0,0) is the top-left of the world;
## world coordinates are logical units (top-down), not screen pixels.

const NEIGHBORS_4: Array[Vector2i] = [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]

var size: Vector2i
var cell_size: float
var _cells: Dictionary = {} # Vector2i -> Object


func _init(p_size: Vector2i, p_cell_size: float) -> void:
	size = p_size
	cell_size = p_cell_size


func in_bounds(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < size.x and cell.y < size.y


func is_free(cell: Vector2i) -> bool:
	return in_bounds(cell) and not _cells.has(cell)


func are_free(cells: Array[Vector2i]) -> bool:
	for cell in cells:
		if not is_free(cell):
			return false
	return true


## Returns the entity occupying `cell`, or null.
func occupant(cell: Vector2i) -> Object:
	return _cells.get(cell)


## Marks `cells` as occupied by `entity`. All cells must be free.
func occupy(cells: Array[Vector2i], entity: Object) -> void:
	assert(are_free(cells), "GridModel.occupy: cells not free %s" % [cells])
	for cell in cells:
		_cells[cell] = entity


func release(cells: Array[Vector2i]) -> void:
	for cell in cells:
		_cells.erase(cell)


## Number of occupied cells whose occupant satisfies `predicate(occupant) -> bool`.
func count_cells(predicate: Callable) -> int:
	var count := 0
	for entity in _cells.values():
		if predicate.call(entity):
			count += 1
	return count


## World position of the cell centre.
func cell_to_world(cell: Vector2i) -> Vector2:
	return (Vector2(cell) + Vector2(0.5, 0.5)) * cell_size


func world_to_cell(point: Vector2) -> Vector2i:
	return Vector2i(floori(point.x / cell_size), floori(point.y / cell_size))


func world_size() -> Vector2:
	return Vector2(size) * cell_size


## The 4 orthogonal neighbours (may be out of bounds; callers check).
func neighbors4(cell: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for offset in NEIGHBORS_4:
		result.append(cell + offset)
	return result
