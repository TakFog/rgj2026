extends TestCase

# Sprite whose head points down-right at 45°, centred at (50, 50), 100 px long.
var facing := SpriteFacing.new(Vector2(50, 50), PI / 4.0, 100.0, deg_to_rad(30.0))
var tail := Vector2(50, 50) - Vector2.from_angle(PI / 4.0) * 50.0
var head := Vector2(50, 50) + Vector2.from_angle(PI / 4.0) * 50.0


func test_centre_maps_to_origin() -> void:
	assert_almost(facing.transform(Vector2.RIGHT, 20.0) * Vector2(50, 50), Vector2.ZERO)


func test_swimming_right_is_horizontal_and_scaled() -> void:
	var t := facing.transform(Vector2.RIGHT, 20.0)
	assert_almost(t * head, Vector2(10, 0))
	assert_almost(t * tail, Vector2(-10, 0))


func test_swimming_left_mirrors_the_sprite() -> void:
	var t := facing.transform(Vector2.LEFT, 20.0)
	assert_almost(t * head, Vector2(-10, 0))


func test_mirrored_sprite_stays_upright() -> void:
	# A point above the body (smaller y) stays above when mirrored.
	var above := Vector2(50, 50) + Vector2.from_angle(PI / 4.0 - PI / 2.0) * 10.0
	assert_true((facing.transform(Vector2.LEFT, 100.0) * above).y < 0.0)


func test_tilt_follows_heading_within_limit() -> void:
	var t := facing.transform(Vector2.from_angle(deg_to_rad(20.0)), 20.0)
	assert_almost(t * head, Vector2.from_angle(deg_to_rad(20.0)) * 10.0)


func test_tilt_is_clamped() -> void:
	var t := facing.transform(Vector2.DOWN + Vector2.RIGHT * 0.01, 20.0)
	assert_almost(t * head, Vector2.from_angle(deg_to_rad(30.0)) * 10.0)


func test_tilt_when_swimming_down_left() -> void:
	var t := facing.transform(Vector2.from_angle(deg_to_rad(160.0)), 20.0)
	assert_almost(t * head, Vector2.from_angle(deg_to_rad(160.0)) * 10.0)


func test_zero_heading_faces_right() -> void:
	assert_almost(facing.transform(Vector2.ZERO, 20.0) * head, Vector2(10, 0))
