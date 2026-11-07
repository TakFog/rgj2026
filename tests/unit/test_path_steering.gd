extends TestCase


func test_turn_is_bounded_by_radius() -> void:
	# Target straight behind, far away: turning radius 10 over 1 unit = 0.1 rad.
	var heading := PathSteering.turn(Vector2.RIGHT, Vector2.LEFT * 1000.0, 1.0, 10.0)
	assert_almost(absf(Vector2.RIGHT.angle_to(heading)), 0.1)
	assert_almost(heading.length(), 1.0)


func test_aligned_heading_stays() -> void:
	assert_almost(PathSteering.turn(Vector2.UP, Vector2.UP * 50.0, 1.0, 10.0), Vector2.UP)


func test_small_angle_snaps_to_target() -> void:
	var to_target := Vector2(100.0, 5.0)
	assert_almost(PathSteering.turn(Vector2.RIGHT, to_target, 1.0, 10.0), to_target.normalized())


func test_turns_toward_target_side() -> void:
	var heading := PathSteering.turn(Vector2.RIGHT, Vector2(0.0, 100.0), 1.0, 10.0)
	assert_true(heading.y > 0.0, "target below: turn down")


func test_swimming_reaches_target_behind_without_orbiting() -> void:
	# Close target behind the fish: the radius shrinks so it still gets there.
	var position := Vector2.ZERO
	var heading := Vector2.RIGHT
	var target := Vector2(-6.0, 3.0)
	var reached := false
	for i in 200:
		var to_target := target - position
		if to_target.length() <= 2.0:
			reached = true
			break
		var step := minf(1.0, to_target.length())
		heading = PathSteering.turn(heading, to_target, step, 16.0)
		position += heading * step
	assert_true(reached, "fish must reach a close target behind it")


func test_zero_distance_target_keeps_heading() -> void:
	assert_almost(PathSteering.turn(Vector2.DOWN, Vector2.ZERO, 1.0, 10.0), Vector2.DOWN)
