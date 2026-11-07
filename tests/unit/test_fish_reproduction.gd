extends TestCase
## Integration: an adult fish with an empty nest nearby finds it and fertilizes
## it on its own, without a player order.

var _laid := false
var _seeked := false
var _world: Node2D
var _view: Node2D
var _old_grid: GridModel
var _old_world: Node2D
var _old_view: Node2D
var _old_factory: EntityFactory
var _old_cooldown: float
var _old_hatch: float
var _old_radius: float


func before_each() -> void:
	_laid = false
	_seeked = false
	_old_grid = Game.grid
	_old_world = Game.world
	_old_view = Game.view
	_old_factory = Game.factory
	_old_cooldown = Game.actors.reproduce_cooldown_seconds
	_old_hatch = Game.eco.nest_hatch_seconds
	_old_radius = Game.actors.reproduce_nest_radius


func after_each() -> void:
	if _world != null:
		_world.free()
	if _view != null:
		_view.free()
	Game.grid = _old_grid
	Game.world = _old_world
	Game.view = _old_view
	Game.factory = _old_factory
	Game.actors.reproduce_cooldown_seconds = _old_cooldown
	Game.eco.nest_hatch_seconds = _old_hatch
	Game.actors.reproduce_nest_radius = _old_radius


func test_fish_seeks_and_fertilizes_a_nearby_empty_nest() -> void:
	Game.grid = GridModel.new(Vector2i(8, 4), 32.0)
	_world = Node2D.new()
	_view = Node2D.new()
	Engine.get_main_loop().root.add_child(_world)
	Engine.get_main_loop().root.add_child(_view)
	Game.world = _world
	Game.view = _view
	Game.factory = EntityFactory.new()

	# Effective cooldown = max(0, 2 x 1) = 2 s, so the fish seeks soon.
	Game.eco.nest_hatch_seconds = 1.0
	Game.actors.reproduce_cooldown_seconds = 0.0
	Game.actors.reproduce_nest_radius = 1000.0

	var nest := Game.factory.spawn_nest(Vector2i(5, 2))
	nest.fertilized.connect(func() -> void: _laid = true)
	var fish := Game.factory.spawn_fish(Game.grid.cell_to_world(Vector2i(0, 2)), true)

	# Let the physics server register the new shapes, then step the fish
	# deterministically so the test stays fast and independent of frame rate.
	await Engine.get_main_loop().process_frame
	for i in 1200:
		fish._physics_process(1.0 / 60.0)
		if fish.brain.state == FishBrain.State.SEEKING_NEST:
			_seeked = true
		if _laid:
			break

	assert_true(_seeked, "the fish never entered SEEKING_NEST")
	assert_true(_laid, "the fish never fertilized the nest")
