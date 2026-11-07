extends TestCase
## The fish bar shows fullness (full = fed), like the predator's satiety bar.


func test_bar_is_full_when_fed() -> void:
	assert_almost(FishVisual.fullness_ratio(0.0), 1.0)


func test_bar_is_empty_when_starving() -> void:
	assert_almost(FishVisual.fullness_ratio(1.0), 0.0)


func test_bar_shrinks_as_hunger_grows() -> void:
	assert_true(FishVisual.fullness_ratio(0.25) > FishVisual.fullness_ratio(0.5))
	assert_true(FishVisual.fullness_ratio(0.5) > FishVisual.fullness_ratio(0.75))


func test_ratio_is_clamped() -> void:
	assert_almost(FishVisual.fullness_ratio(-0.5), 1.0)
	assert_almost(FishVisual.fullness_ratio(1.5), 0.0)


func test_bar_is_green_when_fed_and_red_when_starving() -> void:
	assert_true(FishVisual.bar_color(0.0).is_equal_approx(FishVisual.BAR_FULL))
	assert_true(FishVisual.bar_color(1.0).is_equal_approx(FishVisual.BAR_EMPTY))


func test_bar_colour_moves_from_green_to_red() -> void:
	var mid := FishVisual.bar_color(0.5)
	assert_false(mid.is_equal_approx(FishVisual.BAR_FULL))
	assert_false(mid.is_equal_approx(FishVisual.BAR_EMPTY))


func test_warning_appears_above_the_bar_threshold() -> void:
	assert_almost(FishVisual.warning_threshold(0.5), 0.75)
	assert_false(FishVisual.shows_warning(0.74, 0.5))
	assert_true(FishVisual.shows_warning(0.75, 0.5))
	assert_true(FishVisual.shows_warning(0.9, 0.5))


func test_warning_threshold_is_clamped() -> void:
	assert_almost(FishVisual.warning_threshold(0.9), 1.0)
	assert_almost(FishVisual.warning_threshold(-0.5), 0.0)
