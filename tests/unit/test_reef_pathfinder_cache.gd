extends TestCase
## The pathfinder caches its A* grid until GridModel.version changes, and
## finders with the same share key on one grid share that cache.

const CELL := 32.0

var grid: GridModel
var rock: Object


func before_each() -> void:
	grid = GridModel.new(Vector2i(6, 6), CELL)
	rock = RefCounted.new()


func _always_solid(_occupant: Object) -> bool:
	return true


func _c(x: int, y: int) -> Vector2:
	return grid.cell_to_world(Vector2i(x, y))


func test_occupy_and_release_bump_version() -> void:
	var before := grid.version
	grid.occupy([Vector2i(1, 1)], rock)
	assert_true(grid.version > before, "occupy bumps the version")
	var occupied := grid.version
	grid.release([Vector2i(1, 1)])
	assert_true(grid.version > occupied, "release bumps the version")


func test_cached_grid_follows_grid_changes() -> void:
	var finder := ReefPathfinder.new(grid, _always_solid)
	assert_true(finder.is_clear(_c(0, 1), _c(4, 1)), "open water first")
	grid.occupy([Vector2i(2, 1)], rock)
	assert_false(finder.is_clear(_c(0, 1), _c(4, 1)), "sees the new rock")
	grid.release([Vector2i(2, 1)])
	assert_true(finder.is_clear(_c(0, 1), _c(4, 1)), "sees the rock gone")


func test_finders_with_same_key_share_one_grid() -> void:
	var a := ReefPathfinder.new(grid, _always_solid, 0.0, &"school")
	var b := ReefPathfinder.new(grid, _always_solid, 0.0, &"school")
	ReefPathfinder.new(grid, _always_solid)
	assert_eq(grid.derived.size(), 1, "one shared entry; unkeyed finders keep their own")
	assert_true(a.is_clear(_c(0, 1), _c(4, 1)))
	grid.occupy([Vector2i(2, 1)], rock)
	assert_false(b.is_clear(_c(0, 1), _c(4, 1)), "the shared grid is refreshed by whoever queries")
	assert_false(a.is_clear(_c(0, 1), _c(4, 1)))
