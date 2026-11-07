extends TestCase
## The turtle's sprite heading must be in screen space: the world→screen
## projection is oblique, so a world-vertical swim is diagonal on screen.

func test_world_vertical_headings_are_projected_to_screen() -> void:
	var previous := Game.projection
	Game.projection = ViewProjection.from_settings(Game.VIEW_SETTINGS)
	var turtle := Turtle.new()
	autofree(turtle)

	turtle._heading = Vector2.DOWN
	var down := turtle._screen_heading()
	turtle._heading = Vector2.UP
	var up := turtle._screen_heading()

	Game.projection = previous

	assert_true(down.x < 0.0, "world down is down-left on screen, got %s" % down)
	assert_true(down.y > 0.0, "world down still points down, got %s" % down)
	assert_true(up.x > 0.0, "world up is up-right on screen, got %s" % up)
	assert_true(up.y < 0.0, "world up still points up, got %s" % up)