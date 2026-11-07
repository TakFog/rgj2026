extends TestCase


func test_cells_are_offset_from_origin() -> void:
	var cells := CoralShapes.cells_at(&"domino", Vector2i(3, 4))
	assert_eq(cells.size(), 2)
	assert_true(cells.has(Vector2i(3, 4)))
	assert_true(cells.has(Vector2i(4, 4)))


func test_all_shapes_include_origin() -> void:
	for id in CoralShapes.ids():
		assert_true(CoralShapes.cells_at(id, Vector2i.ZERO).has(Vector2i.ZERO), str(id))


func test_balance_resources_load_with_defaults() -> void:
	var eco: BalanceEcosystem = load("res://data/balance_ecosystem.tres")
	var actors: BalanceActors = load("res://data/balance_actors.tres")
	assert_eq(eco.grid_size, Vector2i(20, 20))
	assert_almost(actors.collapse_grace_seconds, 10.0)
