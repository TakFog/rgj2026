extends TestCase

const CELL := 32.0
const RADIUS := 22.0

var grid: GridModel
var finder: PredatorPathfinder
var rock: Object
var pad: Object


func before_each() -> void:
	grid = GridModel.new(Vector2i(10, 10), CELL)
	rock = _tagged(&"rock")
	pad = _tagged(&"pad")
	finder = PredatorPathfinder.new(grid, func(o: Object) -> bool: return o.get_meta(&"kind") != &"pad", RADIUS)


func _tagged(kind: StringName) -> Object:
	var o := RefCounted.new()
	o.set_meta(&"kind", kind)
	return o


func _c(x: int, y: int) -> Vector2:
	return grid.cell_to_world(Vector2i(x, y))


func _wall_column(x: int, from_y: int, to_y: int) -> void:
	for y in range(from_y, to_y + 1):
		grid.occupy([Vector2i(x, y)], rock)


func test_open_water_cost_is_about_straight_distance() -> void:
	finder.plan_from(_c(1, 1))
	var target := _c(8, 1)
	var cost := finder.reach_cost(target, RADIUS + 10.0)
	assert_true(cost < target.distance_to(_c(1, 1)), "stands within reach, so cheaper than the full distance")
	assert_true(cost > 4.0 * CELL, "but still has to swim most of the way")


func test_open_water_path_is_straight() -> void:
	finder.plan_from(_c(1, 1))
	var path := finder.path_to(_c(8, 1), RADIUS + 10.0)
	assert_eq(path.size(), 1, "no zigzag in open water")
	assert_true(path[0].distance_to(_c(8, 1)) <= RADIUS + 10.0)


## Two walls with a one-cell gap between them: a fish fits, the predator not.
func test_one_cell_corridor_is_closed() -> void:
	_wall_column(4, 0, 9)
	_wall_column(6, 0, 9)
	finder.plan_from(_c(1, 5))
	assert_true(is_inf(finder.reach_cost(_c(5, 5), RADIUS + 10.0)), "fish deep in the corridor is safe")


## A wall across the island (the predator can still go around it through the
## open seabed): a two-cell gap is a shortcut, a one-cell gap is not.
func test_two_cell_gap_is_a_shortcut_one_cell_gap_is_not() -> void:
	_wall_column(5, 0, 9)
	finder.plan_from(_c(1, 5))
	var around := finder.reach_cost(_c(8, 5), RADIUS + 10.0)
	assert_false(is_inf(around), "goes around the wall through the open seabed")
	grid.release([Vector2i(5, 5)])
	finder.plan_from(_c(1, 5))
	assert_almost(finder.reach_cost(_c(8, 5), RADIUS + 10.0), around, 0.01, "one-cell gap: still around")
	grid.release([Vector2i(5, 4)])
	finder.plan_from(_c(1, 5))
	var through := finder.reach_cost(_c(8, 5), RADIUS + 10.0)
	assert_true(through < 7.0 * CELL, "two-cell gap: straight through (%s)" % through)
	assert_true(through < around)


func test_non_solid_occupants_do_not_block() -> void:
	for y in 10:
		grid.occupy([Vector2i(5, y)], pad)
	finder.plan_from(_c(1, 5))
	var path := finder.path_to(_c(8, 5), RADIUS + 10.0)
	assert_eq(path.size(), 1, "nests are swum over")


func test_starts_from_outside_the_island() -> void:
	assert_true(finder.plan_from(Vector2(-300, 160)))
	var path := finder.path_to(_c(5, 5), RADIUS + 10.0)
	assert_false(path.is_empty())
	assert_true(path[path.size() - 1].distance_to(_c(5, 5)) <= RADIUS + 10.0)


func test_exit_path_leaves_the_island() -> void:
	finder.plan_from(_c(2, 5))
	var path := finder.exit_path(200.0)
	assert_false(path.is_empty())
	var last := path[path.size() - 1]
	assert_false(Rect2(Vector2.ZERO, Vector2(10, 10) * CELL).has_point(last), "ends off the island")
	assert_true(last.x < 0.0, "through the nearest (left) border")


func test_sealed_in_has_no_exit() -> void:
	for x in range(2, 9):
		grid.occupy([Vector2i(x, 2), Vector2i(x, 8)], rock)
	for y in range(3, 8):
		grid.occupy([Vector2i(2, y), Vector2i(8, y)], rock)
	finder.plan_from(_c(5, 5))
	assert_true(finder.exit_path(200.0).is_empty())


func test_path_never_crosses_solid_cells() -> void:
	_wall_column(5, 0, 7)
	finder.plan_from(_c(2, 2))
	var path := finder.path_to(_c(8, 2), RADIUS + 10.0)
	var previous := _c(2, 2)
	for point in path:
		for i in 41:
			var cell := grid.world_to_cell(previous.lerp(point, i / 40.0))
			assert_true(grid.occupant(cell) == null, "crossed solid cell %s" % [cell])
		previous = point
