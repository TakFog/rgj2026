extends TestCase


func test_pick_nearest_within_radius() -> void:
	var points := PackedVector2Array([Vector2(0, 0), Vector2(30, 0)])
	assert_eq(FishCommander.pick_nearest(points, Vector2(20, 0), 24.0), 1)


func test_pick_none_outside_radius() -> void:
	var points := PackedVector2Array([Vector2(0, 0), Vector2(30, 0)])
	assert_eq(FishCommander.pick_nearest(points, Vector2(100, 100), 24.0), -1)


func test_pick_none_when_empty() -> void:
	assert_eq(FishCommander.pick_nearest(PackedVector2Array(), Vector2.ZERO, 24.0), -1)
