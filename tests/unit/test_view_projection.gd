extends TestCase


func test_oblique_projection() -> void:
	var p := ViewProjection.new(Vector2(1, 0), Vector2(-0.5, 0.5), 1.0)
	assert_almost(p.to_screen(Vector2(10, 0)), Vector2(10, 0))
	assert_almost(p.to_screen(Vector2(0, 10)), Vector2(-5, 5))


func test_round_trip() -> void:
	var p := ViewProjection.new(Vector2(1, 0), Vector2(-0.5, 0.5), 1.5)
	var world := Vector2(123.4, 56.7)
	assert_almost(p.to_world(p.to_screen(world)), world)


func test_top_down_is_scale_only() -> void:
	var p := ViewProjection.new(Vector2(1, 0), Vector2(0, 1), 2.0)
	assert_almost(p.to_screen(Vector2(3, 4)), Vector2(6, 8))


func test_project_polygon_is_relative_to_anchor() -> void:
	var p := ViewProjection.new(Vector2(1, 0), Vector2(0, 1), 1.0)
	var poly := p.project_polygon(PackedVector2Array([Vector2(10, 10), Vector2(12, 10)]), Vector2(10, 10))
	assert_almost(poly[0], Vector2.ZERO)
	assert_almost(poly[1], Vector2(2, 0))


func test_from_settings_resource() -> void:
	var settings: ViewSettings = load("res://data/view_settings.tres")
	var p := ViewProjection.from_settings(settings)
	assert_almost(p.to_screen(Vector2(0, 2)), Vector2(-1.25, 1.25))
