extends TestCase


func test_pick_nearest_within_radius() -> void:
	var points := PackedVector2Array([Vector2(0, 0), Vector2(30, 0)])
	assert_eq(FishCommander.pick_nearest(points, Vector2(20, 0), 24.0), 1)


func test_pick_none_outside_radius() -> void:
	var points := PackedVector2Array([Vector2(0, 0), Vector2(30, 0)])
	assert_eq(FishCommander.pick_nearest(points, Vector2(100, 100), 24.0), -1)


func test_pick_none_when_empty() -> void:
	assert_eq(FishCommander.pick_nearest(PackedVector2Array(), Vector2.ZERO, 24.0), -1)


func test_free_algae_is_an_order_target() -> void:
	var algae := Algae.new()
	algae.setup(Vector2i(1, 1))
	autofree(algae)
	assert_eq(FishCommander.target_kind(algae, null), OrderHighlight.ALGAE)


func test_corals_are_not_order_targets() -> void:
	var coral := Coral.new()
	autofree(coral)
	assert_eq(FishCommander.target_kind(coral, null), &"")


func test_empty_nest_is_an_order_target() -> void:
	var nest := Nest.new()
	autofree(nest)
	nest.setup(Vector2i(1, 1))
	nest._cycle = NestCycle.new(Game.eco.nest_hatch_seconds, Game.eco.nest_hatch_count)
	assert_eq(FishCommander.target_kind(nest, null), OrderHighlight.NEST)


func test_busy_nest_is_not_an_order_target() -> void:
	var nest := Nest.new()
	autofree(nest)
	nest.setup(Vector2i(1, 1))
	nest._cycle = NestCycle.new(Game.eco.nest_hatch_seconds, Game.eco.nest_hatch_count)
	var fish := Fish.new()
	autofree(fish)
	fish.brain = FishBrain.new(Game.actors, true, -1.0)
	fish.brain.state = FishBrain.State.FERTILIZING
	fish.brain.nest = nest
	nest.breeder = fish
	assert_eq(FishCommander.target_kind(nest, fish), &"")
