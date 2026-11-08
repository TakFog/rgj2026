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


func test_cyclone_visual_uses_the_animated_sheet() -> void:
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
	var sprite := cyclone._body as Sprite2D
	assert_eq(sprite.texture, Cyclone.TEXTURE, "the funnel must use the cyclone spritesheet")
	assert_eq(sprite.hframes, CycloneVisual.FRAMES, "the funnel must cycle the whole sheet")


func test_cyclone_funnel_advances_through_the_frames() -> void:
	var previous := Game.projection
	Game.projection = ViewProjection.from_settings(Game.VIEW_SETTINGS)
	var cyclone := Cyclone.new()
	autofree(cyclone)
	var visual := cyclone._make_visual()
	autofree(visual)
	Game.projection = previous
	var sprite := cyclone._body as Sprite2D
	var start := sprite.frame
	visual._process(0.2)
	assert_true(sprite.frame != start, "the funnel must advance through the sheet")


func test_cyclone_funnel_anchor_comes_from_the_whole_sheet() -> void:
	var previous := Game.projection
	Game.projection = ViewProjection.from_settings(Game.VIEW_SETTINGS)
	var cyclone := Cyclone.new()
	autofree(cyclone)
	var visual := cyclone._make_visual()
	autofree(visual)
	Game.projection = previous
	var sprite := cyclone._body as Sprite2D
	var anchor := sprite.offset
	# The union bottom keeps the tip on the shadow; per-frame bounds would move
	# the funnel vertically as the frames change.
	var used := Cyclone.TEXTURE.get_image().get_used_rect()
	assert_almost(anchor.y, -(used.end.y - Cyclone.TEXTURE.get_height() * 0.5))
	for i in CycloneVisual.FRAMES:
		visual._process(1.0 / CycloneVisual.FRAME_FPS)
		assert_eq(sprite.offset, anchor, "the funnel must not drift while the frames change")


func test_cyclone_start_frames_are_randomised() -> void:
	var previous := Game.projection
	Game.projection = ViewProjection.from_settings(Game.VIEW_SETTINGS)
	var frames := {}
	for i in 32:
		var cyclone := Cyclone.new()
		autofree(cyclone)
		var visual := cyclone._make_visual()
		autofree(visual)
		var sprite := cyclone._body as Sprite2D
		assert_true(sprite.frame >= 0 and sprite.frame < CycloneVisual.FRAMES)
		frames[sprite.frame] = true
	Game.projection = previous
	assert_true(frames.size() > 1, "cyclones must not all start on the same frame")


func test_cyclone_sheet_is_nine_web_safe_square_frames() -> void:
	# CycloneVisual.FRAMES arrives with the animation in the next task; the
	# sheet's own frame count keeps this task independently testable.
	assert_eq(Cyclone.TEXTURE.get_width(), Cyclone.TEXTURE.get_height() * 9,
		"the sheet must be 9 square frames")
	assert_true(Cyclone.TEXTURE.get_width() <= 4096, "the sheet must fit WebGL2's texture width")


func test_bag_without_setup_does_not_crash_when_animating() -> void:
	var bag := PlasticBag.new()
	autofree(bag)
	autofree(bag._make_visual())
	bag._animate_body(0.1)
	assert_true(true, "reached without a script error")
