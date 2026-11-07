extends TestCase

const CELL := 32.0

var grid: GridModel
var finder: ReefPathfinder
## Grid occupants: plain objects tagged with a kind (no scene classes needed).
var rock: Object
var weed: Object
var pad: Object


func before_each() -> void:
	grid = GridModel.new(Vector2i(6, 6), CELL)
	rock = _tagged(&"rock")
	weed = _tagged(&"weed")
	pad = _tagged(&"pad")
	finder = ReefPathfinder.new(grid, func(o: Object) -> bool: return o.get_meta(&"kind") != &"pad")


func _tagged(kind: StringName) -> Object:
	var o := RefCounted.new()
	o.set_meta(&"kind", kind)
	return o


func _is_weed(o: Object) -> bool:
	return o.get_meta(&"kind") == &"weed"


func _c(x: int, y: int) -> Vector2:
	return grid.cell_to_world(Vector2i(x, y))


## Cells crossed by the path, excluding the final exact target point.
func _cells(path: PackedVector2Array) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for i in path.size() - 1:
		cells.append(grid.world_to_cell(path[i]))
	return cells


func test_open_grid_ends_at_exact_target() -> void:
	var target := _c(4, 0) + Vector2(5, -3)
	var path := finder.find_path(_c(0, 0), target)
	assert_true(path.size() >= 2)
	assert_almost(path[path.size() - 1], target)
	assert_eq(path.size(), 5, "start cell centre + 3 steps, last replaced by target")


func test_same_cell_goes_straight() -> void:
	var path := finder.find_path(_c(2, 2), _c(2, 2) + Vector2(4, 4))
	assert_eq(path.size(), 1)
	assert_almost(path[0], _c(2, 2) + Vector2(4, 4))


func test_routes_around_a_wall() -> void:
	# Vertical wall at x=2, rows 0..4; the gap is at row 5.
	for y in 5:
		grid.occupy([Vector2i(2, y)], rock)
	var path := finder.find_path(_c(0, 0), _c(4, 0))
	for cell in _cells(path):
		assert_true(grid.is_free(cell), "path crosses solid cell %s" % cell)
	assert_true(_cells(path).has(Vector2i(2, 5)), "must use the gap")


func test_nests_are_passable() -> void:
	for y in 6:
		grid.occupy([Vector2i(2, y)], rock if y != 3 else pad)
	var path := finder.find_path(_c(0, 3), _c(4, 3))
	assert_true(_cells(path).has(Vector2i(2, 3)))


func test_no_diagonal_corner_cutting() -> void:
	grid.occupy([Vector2i(1, 0)], rock)
	var path := finder.find_path(_c(0, 0), _c(1, 1))
	assert_true(_cells(path).has(Vector2i(0, 1)), "must go down first, not cut the rock corner")


func test_solid_goal_ends_next_to_it_then_aims_at_it() -> void:
	grid.occupy([Vector2i(4, 2)], weed)
	var path := finder.find_path(_c(0, 2), _c(4, 2))
	var cells := _cells(path)
	assert_eq(cells[cells.size() - 1], Vector2i(3, 2))
	assert_almost(path[path.size() - 1], _c(4, 2))


func test_sealed_goal_goes_to_closest_reachable_cell() -> void:
	# Box around (4,4): walls at (3,3..5) and (4..5,3).
	for cell in [Vector2i(3, 3), Vector2i(3, 4), Vector2i(3, 5), Vector2i(4, 3), Vector2i(5, 3)]:
		grid.occupy([cell], rock)
	var path := finder.find_path(_c(0, 0), _c(4, 4))
	for cell in _cells(path):
		assert_true(grid.is_free(cell))
		assert_true(cell.x < 3 or cell.y < 3, "never enters the box")
	assert_almost(path[path.size() - 1], _c(4, 4))


func test_starting_inside_solid_goes_straight() -> void:
	grid.occupy([Vector2i(0, 0)], rock)
	var path := finder.find_path(_c(0, 0), _c(3, 3))
	assert_eq(path.size(), 1)


func test_nearest_occupant_by_path_not_by_distance() -> void:
	# Weed A at (2,0) is close in a straight line but behind a wall;
	# weed B at (0,5) is farther but reachable directly.
	var weed_a := _tagged(&"weed")
	var weed_b := _tagged(&"weed")
	grid.occupy([Vector2i(2, 0)], weed_a)
	grid.occupy([Vector2i(0, 5)], weed_b)
	for y in 5:
		grid.occupy([Vector2i(1, y)], rock)
	var result := finder.nearest_occupant(_c(0, 0), _is_weed)
	assert_true(result.get("occupant") == weed_b)
	var path: PackedVector2Array = result["path"]
	assert_almost(path[path.size() - 1], _c(0, 5), 0.001, "path ends at the weed centre")


func test_nearest_occupant_none_reachable() -> void:
	var weed_a := _tagged(&"weed")
	grid.occupy([Vector2i(5, 5)], weed_a)
	for cell in [Vector2i(4, 4), Vector2i(4, 5), Vector2i(5, 4)]:
		grid.occupy([cell], rock)
	assert_true(finder.nearest_occupant(_c(0, 0), _is_weed).is_empty())


func test_nearest_occupant_adjacent() -> void:
	grid.occupy([Vector2i(1, 0)], weed)
	var result := finder.nearest_occupant(_c(0, 0), _is_weed)
	assert_true(result.get("occupant") == weed)
	var path: PackedVector2Array = result["path"]
	assert_eq(path.size(), 1)
	assert_almost(path[0], _c(1, 0))
