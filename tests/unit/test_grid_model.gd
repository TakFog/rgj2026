extends TestCase

var grid: GridModel


func before_each() -> void:
	grid = GridModel.new(Vector2i(4, 3), 32.0)


func test_in_bounds() -> void:
	assert_true(grid.in_bounds(Vector2i(0, 0)))
	assert_true(grid.in_bounds(Vector2i(3, 2)))
	assert_false(grid.in_bounds(Vector2i(4, 0)))
	assert_false(grid.in_bounds(Vector2i(0, -1)))


func test_out_of_bounds_is_not_free() -> void:
	assert_false(grid.is_free(Vector2i(-1, 0)))


func test_occupy_and_release() -> void:
	var entity := RefCounted.new()
	var cells: Array[Vector2i] = [Vector2i(1, 1), Vector2i(2, 1)]
	grid.occupy(cells, entity)
	assert_false(grid.is_free(Vector2i(1, 1)))
	assert_eq(grid.occupant(Vector2i(2, 1)), entity)
	assert_false(grid.are_free(cells))
	grid.release(cells)
	assert_true(grid.are_free(cells))
	assert_eq(grid.occupant(Vector2i(1, 1)), null)


func test_cell_world_conversion() -> void:
	assert_almost(grid.cell_to_world(Vector2i(1, 2)), Vector2(48, 80))
	assert_eq(grid.world_to_cell(Vector2(48, 80)), Vector2i(1, 2))
	assert_eq(grid.world_to_cell(Vector2(31.9, 0)), Vector2i(0, 0))
	assert_eq(grid.world_to_cell(Vector2(-0.1, 0)), Vector2i(-1, 0))


func test_world_size() -> void:
	assert_almost(grid.world_size(), Vector2(128, 96))


func test_neighbors4() -> void:
	var n := grid.neighbors4(Vector2i(0, 0))
	assert_eq(n.size(), 4)
	assert_true(n.has(Vector2i(1, 0)))
	assert_true(n.has(Vector2i(0, -1)))


func test_count_cells_with_predicate() -> void:
	var a := RefCounted.new()
	var b := RefCounted.new()
	var cells_a: Array[Vector2i] = [Vector2i(0, 0), Vector2i(1, 0)]
	var cells_b: Array[Vector2i] = [Vector2i(3, 2)]
	grid.occupy(cells_a, a)
	grid.occupy(cells_b, b)
	assert_eq(grid.count_cells(func(_e): return _e == a), 2)
	assert_eq(grid.count_cells(func(_e): return true), 3)
