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
