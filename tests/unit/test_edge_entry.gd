extends TestCase

const SIZE := Vector2(640, 640)


func test_points_lie_on_world_edge_and_inward_points_inside() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	var rect := Rect2(Vector2.ZERO, SIZE)
	for i in 200:
		var entry := EdgeEntry.random(rng, SIZE, 0.5)
		var on_x_edge := is_equal_approx(entry.point.x, 0.0) or is_equal_approx(entry.point.x, SIZE.x)
		var on_y_edge := is_equal_approx(entry.point.y, 0.0) or is_equal_approx(entry.point.y, SIZE.y)
		assert_true(on_x_edge or on_y_edge, str(entry.point))
		assert_true(rect.grow(0.001).has_point(entry.point), str(entry.point))
		assert_true(rect.has_point(entry.point + entry.inward), "inward %s at %s" % [entry.inward, entry.point])


func test_heading_stays_within_spread_of_inward() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in 200:
		var entry := EdgeEntry.random(rng, SIZE, 0.5)
		var dir := Vector2.from_angle(entry.heading)
		assert_true(dir.dot(entry.inward) >= cos(0.5) - 0.0001, "heading %s inward %s" % [entry.heading, entry.inward])


func test_zero_spread_heads_straight_in() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	for i in 20:
		var entry := EdgeEntry.random(rng, SIZE, 0.0)
		assert_almost(Vector2.from_angle(entry.heading), entry.inward)


func test_same_seed_gives_same_entry() -> void:
	var a := RandomNumberGenerator.new()
	var b := RandomNumberGenerator.new()
	a.seed = 99
	b.seed = 99
	var first := EdgeEntry.random(a, SIZE, 0.5)
	var second := EdgeEntry.random(b, SIZE, 0.5)
	assert_almost(first.point, second.point)
	assert_almost(first.heading, second.heading)
