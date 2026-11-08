extends TestCase
## The painted title screen's hotspots must stay on the painting at any size.


func test_art_box_fits_16_by_9_without_cropping() -> void:
	var box := MenuHotspots.art_box(Vector2(1280, 720))
	assert_almost(box.size.y, 720.0)
	assert_almost(box.size.x, 720.0 * MenuHotspots.ART_SIZE.x / MenuHotspots.ART_SIZE.y)
	assert_almost(box.position, Vector2((1280.0 - box.size.x) * 0.5, 0.0))


func test_art_box_fits_a_portrait_viewport() -> void:
	var box := MenuHotspots.art_box(Vector2(700, 1100))
	assert_almost(box.size.x, 700.0)
	assert_almost(box.size.y, 700.0 * MenuHotspots.ART_SIZE.y / MenuHotspots.ART_SIZE.x)
	assert_almost(box.position.y, (1100.0 - box.size.y) * 0.5)


func test_art_box_is_empty_for_an_empty_viewport() -> void:
	assert_eq(MenuHotspots.art_box(Vector2.ZERO), Rect2())
	assert_eq(MenuHotspots.hotspot_rect(Vector2.ZERO, "play"), Rect2())


func test_every_hotspot_lies_inside_the_art() -> void:
	for key: String in MenuHotspots.RECTS:
		var rect: Rect2 = MenuHotspots.RECTS[key]
		assert_true(rect.position.x >= 0.0 and rect.position.y >= 0.0, key)
		assert_true(rect.end.x <= 1.0 and rect.end.y <= 1.0, key)
		assert_true(rect.size.x > 0.0 and rect.size.y > 0.0, key)


func test_hotspots_do_not_overlap() -> void:
	var keys := MenuHotspots.RECTS.keys()
	for i in keys.size():
		for j in range(i + 1, keys.size()):
			var a: Rect2 = MenuHotspots.RECTS[keys[i]]
			var b: Rect2 = MenuHotspots.RECTS[keys[j]]
			assert_false(a.intersects(b), "%s overlaps %s" % [keys[i], keys[j]])


func test_focus_order() -> void:
	assert_eq(MenuHotspots.RECTS.keys(),
		["play", "settings", "tutorial", "exit", "credits"])


func test_hotspot_rect_follows_the_art_box() -> void:
	var viewport := Vector2(1280, 720)
	var art := MenuHotspots.art_box(viewport)
	var fraction: Rect2 = MenuHotspots.RECTS["play"]
	var rect := MenuHotspots.hotspot_rect(viewport, "play")
	assert_almost(rect.position, art.position + art.size * fraction.position)
	assert_almost(rect.size, art.size * fraction.size)


func test_hotspot_region_is_in_texture_pixels() -> void:
	var fraction: Rect2 = MenuHotspots.RECTS["play"]
	var region := MenuHotspots.hotspot_region("play")
	assert_almost(region.position, fraction.position * MenuHotspots.ART_SIZE)
	assert_almost(region.size, fraction.size * MenuHotspots.ART_SIZE)


func test_every_hotspot_has_a_pill_shape() -> void:
	assert_eq(MenuHotspots.PILL_CORNERS.keys(), MenuHotspots.RECTS.keys())


func test_pill_corners_follow_their_hotspot() -> void:
	for key: String in MenuHotspots.PILL_CORNERS:
		var corners: Array = MenuHotspots.PILL_CORNERS[key]
		assert_eq(corners.size(), 4, key)
		var top_left: Vector2 = corners[0]
		var top_right: Vector2 = corners[1]
		var bottom_right: Vector2 = corners[2]
		var bottom_left: Vector2 = corners[3]
		# Top and bottom edges stay on the hotspot's top and bottom.
		assert_almost(top_left.y, 0.0, 0.001, key)
		assert_almost(top_right.y, 0.0, 0.001, key)
		assert_almost(bottom_right.y, 1.0, 0.001, key)
		assert_almost(bottom_left.y, 1.0, 0.001, key)
		# The painted pills are parallelograms: both edges have the same
		# width and are sheared by the same amount.
		assert_almost(top_right.x - top_left.x, bottom_right.x - bottom_left.x, 0.01, key)
		assert_almost(top_left.x - bottom_left.x, top_right.x - bottom_right.x, 0.01, key)
		# A bounding box must contain the pill, not the other way round.
		assert_true(top_left.x > -0.1 and top_left.x < 0.3, key)
		assert_true(bottom_left.x > -0.1 and bottom_left.x < 0.3, key)
		assert_true(top_right.x > 0.9 and top_right.x < 1.1, key)
		assert_true(bottom_right.x > 0.7 and bottom_right.x < 1.0, key)
