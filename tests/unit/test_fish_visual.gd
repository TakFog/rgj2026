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


func test_selection_outline_is_neutral_while_wandering() -> void:
	assert_true(FishVisual.outline_color(FishBrain.State.WANDER).is_equal_approx(FishVisual.SELECT_COLOR))
	assert_true(FishVisual.outline_color(FishBrain.State.ORDERED).is_equal_approx(FishVisual.SELECT_COLOR))


func test_selection_outline_colours_eating_and_eggs() -> void:
	assert_true(FishVisual.outline_color(FishBrain.State.EATING).is_equal_approx(FishVisual.ACTIVITY_COLOR_FOOD))
	assert_true(FishVisual.outline_color(FishBrain.State.FERTILIZING).is_equal_approx(FishVisual.ACTIVITY_COLOR_EGGS))
	assert_true(FishVisual.outline_color(FishBrain.State.SEEKING_FOOD).is_equal_approx(FishVisual.ACTIVITY_COLOR_FOOD))
	assert_true(FishVisual.outline_color(FishBrain.State.SEEKING_NEST).is_equal_approx(FishVisual.ACTIVITY_COLOR_EGGS))


func test_badge_appears_only_for_food_and_eggs() -> void:
	assert_false(FishVisual.shows_activity(FishBrain.State.WANDER))
	assert_false(FishVisual.shows_activity(FishBrain.State.ORDERED))
	assert_false(FishVisual.shows_activity(FishBrain.State.IDLE))
	assert_true(FishVisual.shows_activity(FishBrain.State.EATING))
	assert_true(FishVisual.shows_activity(FishBrain.State.FERTILIZING))
	assert_true(FishVisual.shows_activity(FishBrain.State.SEEKING_FOOD))
	assert_true(FishVisual.shows_activity(FishBrain.State.SEEKING_NEST))


func test_progress_ring_only_for_timed_actions() -> void:
	assert_true(FishVisual.is_activity_timed(FishBrain.State.EATING))
	assert_true(FishVisual.is_activity_timed(FishBrain.State.FERTILIZING))
	assert_false(FishVisual.is_activity_timed(FishBrain.State.SEEKING_FOOD))
	assert_false(FishVisual.is_activity_timed(FishBrain.State.SEEKING_NEST))


func test_badge_shows_algae_while_eating_and_eggs_while_laying() -> void:
	assert_true(FishVisual.activity_texture(FishBrain.State.EATING) == FishVisual.ACTIVITY_ICON_FOOD)
	assert_true(FishVisual.activity_texture(FishBrain.State.FERTILIZING) == FishVisual.ACTIVITY_ICON_EGGS)
	assert_true(FishVisual.activity_texture(FishBrain.State.SEEKING_FOOD) == FishVisual.ACTIVITY_ICON_FOOD)
	assert_true(FishVisual.activity_texture(FishBrain.State.SEEKING_NEST) == FishVisual.ACTIVITY_ICON_EGGS)
