extends TestCase
## Hover/click rim for the fish order: it hugs the item's sprite silhouette,
## uses the same colours as the fish's activity badge, and widens by one pixel
## on click.

func test_kind_of_items() -> void:
	var algae := Algae.new()
	autofree(algae)
	assert_eq(OrderHighlight.kind_of(algae), OrderHighlight.ALGAE)
	var nest := Nest.new()
	autofree(nest)
	assert_eq(OrderHighlight.kind_of(nest), OrderHighlight.NEST)
	assert_eq(OrderHighlight.kind_of(null), &"")


func test_rim_colours_match_the_fish_badge() -> void:
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


func test_hover_rim_breathes_but_stays_visible() -> void:
	for sample in [0.0, 0.5, 1.0, 2.5]:
		var alpha := OrderHighlight.hover_alpha(sample)
		assert_true(alpha >= OrderHighlight.MIN_ALPHA - 0.001)
		assert_true(alpha <= 1.0)
	assert_false(is_equal_approx(OrderHighlight.hover_alpha(0.0), OrderHighlight.hover_alpha(0.5)))
