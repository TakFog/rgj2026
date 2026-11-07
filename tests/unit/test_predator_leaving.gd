extends TestCase
## Leaving the island: `left` fires once whatever caused it (hunt timeout,
## sated, scared by the turtle), a scared predator drops its hunting route, and
## an actor walled in by corals still swims away instead of staying forever.

var _view: Node2D
var _previous_view: Node2D
var _previous_grid: GridModel


func before_each() -> void:
	_previous_view = Game.view
	_previous_grid = Game.grid
	Game.grid = GridModel.new(Vector2i(20, 12), 32.0)
	_view = Node2D.new()
	(Engine.get_main_loop() as SceneTree).root.add_child(_view)
	Game.view = _view
	autofree(_view)


func after_each() -> void:
	Game.view = _previous_view
	Game.grid = _previous_grid


## A predator in the middle of the island, driven by hand (no automatic physics).
func _predator() -> Predator:
	var predator := Predator.new()
	predator.position = Game.grid.cell_to_world(Vector2i(10, 6))
	# Before the first frame nodes only get ready on it (with _view busy): wait.
	await (Engine.get_main_loop() as SceneTree).process_frame
	_view.add_child(predator)
	predator.set_physics_process(false)
	return predator


func _turtle() -> Turtle:
	var turtle := Turtle.new()
	turtle.position = Game.grid.cell_to_world(Vector2i(10, 6))
	# Before the first frame nodes only get ready on it (with _view busy): wait.
	await (Engine.get_main_loop() as SceneTree).process_frame
	_view.add_child(turtle)
	turtle.set_physics_process(false)
	return turtle


## Corals on the ring of cells `ring` away (Chebyshev) from cell (10, 6).
func _wall_in(ring: int) -> void:
	var coral := Coral.new()
	autofree(coral)
	for x in range(10 - ring, 10 + ring + 1):
		for y in range(6 - ring, 6 + ring + 1):
			if maxi(absi(x - 10), absi(y - 6)) == ring:
				Game.grid.occupy([Vector2i(x, y)], coral)


func test_scared_predator_emits_left_once_and_drops_its_hunting_route() -> void:
	var predator: Predator = await _predator()
	var fish_spot := Game.grid.cell_to_world(Vector2i(14, 6))
	predator._path = PackedVector2Array([fish_spot])
	var count := [0]
	predator.left.connect(func() -> void: count[0] += 1)

	predator.scare()
	assert_true(predator.debug_path().is_empty(), "the hunting route is dropped at once")
	for i in 5:
		predator._physics_process(1.0 / 60.0)

	assert_eq(count[0], 1, "left fires exactly once")
	var path := predator.debug_path()
	assert_false(path.is_empty(), "an exit route is planned")
	assert_false(fish_spot in path, "it no longer swims to the fish")


func test_sated_predator_emits_left() -> void:
	var predator: Predator = await _predator()
	var count := [0]
	predator.left.connect(func() -> void: count[0] += 1)
	predator.brain.ate(Game.actors.predator_satiety)
	for i in 3:
		predator._physics_process(1.0 / 60.0)
	assert_eq(count[0], 1, "left fires when it leaves sated, not only on hunt timeout")


func test_walled_in_predator_swims_out_over_the_corals() -> void:
	_wall_in(2)
	var predator: Predator = await _predator()
	predator.scare()
	predator._physics_process(1.0 / 60.0)
	assert_true(predator.debug_path().is_empty(), "no exit route through the corals")
	for i in Predator.MAX_EXIT_FAILURES:
		predator._replan_timer = 0.0
		predator._physics_process(1.0 / 60.0)
	assert_eq(predator.collision_mask, 0, "corals no longer block it")
	assert_false(predator.debug_path().is_empty(), "it swims straight out")


func test_walled_in_turtle_swims_out_over_the_corals() -> void:
	_wall_in(2)
	var turtle: Turtle = await _turtle()
	turtle.brain.bag_removed()
	for i in Turtle.MAX_EXIT_FAILURES + 1:
		turtle._replan_timer = 0.0
		turtle._physics_process(1.0 / 60.0)
	assert_eq(turtle.collision_mask, 0, "corals no longer block it")
	assert_false(turtle.debug_path().is_empty(), "it swims straight out")


func test_straight_exit_points_away_from_the_island_centre() -> void:
	var island := Rect2(Vector2.ZERO, Vector2(320, 320))
	var path := PredatorPathfinder.straight_exit(Vector2(100, 160), island, Vector2.DOWN, 600.0)
	assert_eq(path.size(), 1)
	assert_almost(path[0].x, 100.0 - 600.0, 0.01, "left of the centre: swims left")
	assert_almost(path[0].y, 160.0, 0.01)


func test_straight_exit_from_the_centre_follows_the_heading() -> void:
	var island := Rect2(Vector2.ZERO, Vector2(320, 320))
	var path := PredatorPathfinder.straight_exit(Vector2(160, 160), island, Vector2.DOWN, 600.0)
	assert_eq(path[0], Vector2(160, 760))
	path = PredatorPathfinder.straight_exit(Vector2(160, 160), island, Vector2.ZERO, 600.0)
	assert_eq(path[0], Vector2(760, 160), "no heading either: any direction will do")
