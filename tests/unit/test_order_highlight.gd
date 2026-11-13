extends TestCase
## Hover/click ring for the fish order: it wraps the item's cell, uses the same
## colours as the fish's activity badge, and widens by one pixel on click.

func test_ring_wraps_the_whole_cell() -> void:
	assert_almost(OrderHighlight.ring_radius(32.0), 32.0 * OrderHighlight.RADIUS_CELLS)
	assert_true(OrderHighlight.RADIUS_CELLS > 0.71, "the cell corners sit ~0.71 cells out")


func test_ring_colours_match_the_fish_badge() -> void:
	assert_true(OrderHighlight.color_for(OrderHighlight.ALGAE).is_equal_approx(
			FishVisual.ACTIVITY_COLOR_FOOD))
	assert_true(OrderHighlight.color_for(OrderHighlight.NEST).is_equal_approx(
			FishVisual.ACTIVITY_COLOR_EGGS))


func test_unknown_kind_falls_back_to_white() -> void:
	assert_true(OrderHighlight.color_for(&"coral").is_equal_approx(Color.WHITE))


func test_click_starts_one_pixel_wider() -> void:
	assert_almost(OrderHighlight.width_at(OrderHighlight.CLICK_SECONDS),
			OrderHighlight.WIDTH + OrderHighlight.CLICK_BONUS)
	assert_almost(OrderHighlight.width_at(0.0), OrderHighlight.WIDTH)


func test_click_width_fades_back_to_normal() -> void:
	var mid := OrderHighlight.width_at(OrderHighlight.CLICK_SECONDS * 0.5)
	assert_true(mid > OrderHighlight.WIDTH)
	assert_true(mid < OrderHighlight.WIDTH + OrderHighlight.CLICK_BONUS)


func test_click_flash_fades_out() -> void:
	assert_almost(OrderHighlight.click_alpha(OrderHighlight.CLICK_SECONDS), 1.0)
	assert_almost(OrderHighlight.click_alpha(0.0), 0.0)
	assert_true(OrderHighlight.click_alpha(OrderHighlight.CLICK_SECONDS * 0.5) < 1.0)


func test_hover_ring_breathes_but_stays_visible() -> void:
	for sample in [0.0, 0.5, 1.0, 2.5]:
		var alpha := OrderHighlight.hover_alpha(sample)
		assert_true(alpha >= OrderHighlight.MIN_ALPHA - 0.001)
		assert_true(alpha <= 1.0)
	assert_false(is_equal_approx(OrderHighlight.hover_alpha(0.0), OrderHighlight.hover_alpha(0.5)))
