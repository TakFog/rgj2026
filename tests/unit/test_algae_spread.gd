extends TestCase

var grid: GridModel
var rng: RandomNumberGenerator
var coral := RefCounted.new()
var other := RefCounted.new()


func before_each() -> void:
	grid = GridModel.new(Vector2i(5, 5), 32.0)
	rng = RandomNumberGenerator.new()
	rng.seed = 42


func _is_coral(entity: Object) -> bool:
	return entity == coral


func _never_covered(_cell: Vector2i) -> bool:
	return false


func _covers_2_3(cell: Vector2i) -> bool:
	return cell == Vector2i(2, 3)


func _block(cells: Array[Vector2i]) -> void:
	grid.occupy(cells, other)


func test_spawns_in_the_only_free_neighbour() -> void:
	_block([Vector2i(2, 1), Vector2i(1, 2), Vector2i(3, 2)])
	var result := AlgaeSpread.attempt(Vector2i(2, 2), grid, rng, _is_coral, _never_covered)
	assert_eq(result["outcome"], AlgaeSpread.Outcome.SPAWN)
	assert_eq(result["cell"], Vector2i(2, 3))


func test_damages_coral_when_it_is_the_only_option() -> void:
	_block([Vector2i(2, 1), Vector2i(1, 2), Vector2i(3, 2)])
	grid.occupy([Vector2i(2, 3)], coral)
	var result := AlgaeSpread.attempt(Vector2i(2, 2), grid, rng, _is_coral, _never_covered)
	assert_eq(result["outcome"], AlgaeSpread.Outcome.DAMAGE_CORAL)
	assert_eq(result["target"], coral)


func test_blocked_when_no_neighbour_is_usable() -> void:
	_block([Vector2i(2, 1), Vector2i(1, 2), Vector2i(3, 2), Vector2i(2, 3)])
	var result := AlgaeSpread.attempt(Vector2i(2, 2), grid, rng, _is_coral, _never_covered)
	assert_eq(result["outcome"], AlgaeSpread.Outcome.BLOCKED)


func test_out_of_map_neighbours_are_skipped() -> void:
	_block([Vector2i(1, 0)])
	var result := AlgaeSpread.attempt(Vector2i(0, 0), grid, rng, _is_coral, _never_covered)
	assert_eq(result["outcome"], AlgaeSpread.Outcome.SPAWN)
	assert_eq(result["cell"], Vector2i(0, 1))


func test_cells_covered_by_actors_are_skipped() -> void:
	_block([Vector2i(2, 1), Vector2i(1, 2), Vector2i(3, 2)])
	var result := AlgaeSpread.attempt(Vector2i(2, 2), grid, rng, _is_coral, _covers_2_3)
	assert_eq(result["outcome"], AlgaeSpread.Outcome.BLOCKED)


func test_random_order_reaches_every_neighbour() -> void:
	var seen := {}
	for s in 64:
		rng.seed = s
		var result := AlgaeSpread.attempt(Vector2i(2, 2), grid, rng, _is_coral, _never_covered)
		seen[result["cell"]] = true
	assert_eq(seen.size(), 4)


func test_next_interval_stays_within_jitter() -> void:
	for i in 50:
		var value := AlgaeSpread.next_interval(10.0, 0.2, rng)
		assert_true(value >= 8.0 and value <= 12.0, str(value))


func test_cap_blocks_spawn() -> void:
	var result := AlgaeSpread.attempt(Vector2i(2, 2), grid, rng, _is_coral, _never_covered)
	assert_eq(result["outcome"], AlgaeSpread.Outcome.SPAWN)
	assert_eq(AlgaeSpread.apply_cap(result, true)["outcome"], AlgaeSpread.Outcome.BLOCKED)
	assert_eq(AlgaeSpread.apply_cap(result, false)["outcome"], AlgaeSpread.Outcome.SPAWN)


func test_cap_still_damages_coral() -> void:
	_block([Vector2i(2, 1), Vector2i(1, 2), Vector2i(3, 2)])
	grid.occupy([Vector2i(2, 3)], coral)
	var result := AlgaeSpread.apply_cap(AlgaeSpread.attempt(Vector2i(2, 2), grid, rng, _is_coral, _never_covered), true)
	assert_eq(result["outcome"], AlgaeSpread.Outcome.DAMAGE_CORAL)
	assert_eq(result["target"], coral)
