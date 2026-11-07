extends TestCase


func test_pause_when_nothing_to_cancel() -> void:
	assert_false(PauseController.yields_to_cancel(true, false, false))


func test_esc_yields_to_placement() -> void:
	assert_true(PauseController.yields_to_cancel(true, true, false))


func test_esc_yields_to_fish_selection() -> void:
	assert_true(PauseController.yields_to_cancel(true, false, true))


func test_space_pauses_with_fish_selected() -> void:
	assert_false(PauseController.yields_to_cancel(false, false, true))


func test_space_ignored_while_placing() -> void:
	assert_true(PauseController.yields_to_cancel(false, true, false))
