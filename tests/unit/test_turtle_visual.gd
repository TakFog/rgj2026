extends TestCase
## The turtle art faces left: it is mirrored when swimming right and tilted
## toward its heading like the fish.

## The nose in texture space, relative to the body centre (the art faces left).
const HEAD := Vector2.LEFT
const MAX_TILT_DEG := TurtleVisual.MAX_TILT_DEG


func test_swimming_right_mirrors_the_left_facing_art() -> void:
	assert_almost(TurtleVisual.facing(Vector2.RIGHT) * HEAD, Vector2.RIGHT)


func test_swimming_left_keeps_the_art_unmirrored() -> void:
	assert_almost(TurtleVisual.facing(Vector2.LEFT) * HEAD, Vector2.LEFT)


func test_horizontal_headings_stay_level() -> void:
	assert_almost(TurtleVisual.facing(Vector2.RIGHT) * HEAD, Vector2.RIGHT)
	assert_almost(TurtleVisual.facing(Vector2.LEFT) * HEAD, Vector2.LEFT)


func test_tilt_follows_the_heading() -> void:
	var up_right := Vector2.from_angle(deg_to_rad(-20.0))
	assert_almost(TurtleVisual.facing(up_right) * HEAD, up_right)
	var down_left := Vector2.from_angle(deg_to_rad(160.0))
	assert_almost(TurtleVisual.facing(down_left) * HEAD, down_left)


func test_tilt_is_clamped_toward_the_heading() -> void:
	var limit := deg_to_rad(MAX_TILT_DEG)
	assert_almost(TurtleVisual.facing(Vector2.DOWN) * HEAD, Vector2.from_angle(limit))
	assert_almost(TurtleVisual.facing(Vector2.UP) * HEAD, Vector2.from_angle(-limit))
	assert_almost(TurtleVisual.facing(Vector2(-1, -1).normalized()) * HEAD,
		Vector2.from_angle(PI + limit))
	assert_almost(TurtleVisual.facing(Vector2(-1, 1).normalized()) * HEAD,
		Vector2.from_angle(PI - limit))


func test_zero_heading_faces_right_and_stays_level() -> void:
	assert_almost(TurtleVisual.facing(Vector2.ZERO) * HEAD, Vector2.RIGHT)