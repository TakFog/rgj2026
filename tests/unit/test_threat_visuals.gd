extends TestCase



func _entry(seed_value := 7) -> EdgeEntry:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var visible := PackedVector2Array([
		Vector2(-10, -10), Vector2(110, -10), Vector2(110, 110), Vector2(-10, 110)])
	return EdgeEntry.random(rng, visible, Rect2(Vector2.ZERO, Vector2(100, 100)))


func test_setup_does_not_advance_the_spawn_rng() -> void:
	# The tumble is cosmetic: it must not eat draws from the RNG that also
	# steers the bag and positions every later spawn.
	var spawn_rng := RandomNumberGenerator.new()
	spawn_rng.seed = 42
	var before := spawn_rng.state
	var bag := PlasticBag.new()
	autofree(bag)
	bag.setup(_entry(), spawn_rng)
	assert_eq(spawn_rng.state, before)


func test_bag_visual_is_the_body_alone() -> void:
	# Projection is stubbed so a shadow, if one appeared, would really be built.
	var previous := Game.projection
	Game.projection = ViewProjection.from_settings(Game.VIEW_SETTINGS)
	var bag := PlasticBag.new()
	autofree(bag)
	var visual := bag._make_visual()
	autofree(visual)
	Game.projection = previous
	assert_eq(visual.get_child_count(), 1, "bag visual must have no shadow")
	assert_true(visual.get_child(0) is Sprite2D)
	assert_true(bag._body == visual.get_child(0), "_body must be the floating sprite")


func test_cyclone_visual_uses_the_swirl_shader() -> void:
	# The shadow is drawn by CycloneVisual itself; the children are the funnel
	# and the orbiting spray.
	var previous := Game.projection
	Game.projection = ViewProjection.from_settings(Game.VIEW_SETTINGS)
	var cyclone := Cyclone.new()
	autofree(cyclone)
	var visual := cyclone._make_visual()
	autofree(visual)
	Game.projection = previous
	assert_true(visual is CycloneVisual, "cyclone must use its own visual")
	assert_eq(visual.get_child_count(), 2, "funnel plus spray")
	assert_true(cyclone._body is Sprite2D)
	assert_true((cyclone._body as Sprite2D).material is ShaderMaterial,
		"the funnel must use the swirl shader")


func test_bag_without_setup_does_not_crash_when_animating() -> void:
	var bag := PlasticBag.new()
	autofree(bag)
	autofree(bag._make_visual())
	bag._animate_body(0.1)
	assert_true(true, "reached without a script error")
