extends TestCase
## The loaded mode survives the scene rebuild: a campaign index or the endless
## sandbox pseudo-index.

func before_each() -> void:
	LevelSession.reset()


func after_each() -> void:
	LevelSession.reset()


func test_starts_on_the_first_campaign_level() -> void:
	assert_false(LevelSession.is_sandbox())
	assert_eq(LevelSession.current_index, 0)
	assert_eq(LevelSession.current().level_name, LevelCatalog.at(0).level_name)


func test_selecting_a_campaign_level_reports_the_change_once() -> void:
	assert_true(LevelSession.select(2))
	assert_eq(LevelSession.current_index, 2)
	assert_false(LevelSession.is_sandbox())
	assert_false(LevelSession.select(2))


func test_selecting_the_sandbox_reports_the_change_once() -> void:
	assert_true(LevelSession.select_sandbox())
	assert_true(LevelSession.is_sandbox())
	assert_true(LevelSession.current().endless)
	assert_false(LevelSession.select_sandbox())


func test_switching_back_to_a_campaign_level_leaves_the_sandbox() -> void:
	LevelSession.select_sandbox()
	assert_true(LevelSession.select(1))
	assert_false(LevelSession.is_sandbox())
	assert_eq(LevelSession.current_index, 1)


func test_clamp_keeps_the_sandbox_and_clamps_campaign_indices() -> void:
	LevelSession.select_sandbox()
	assert_eq(LevelSession.clamp_current(), LevelSession.SANDBOX_INDEX)
	assert_true(LevelSession.is_sandbox())

	LevelSession.current_index = 99
	assert_eq(LevelSession.clamp_current(), LevelCatalog.COUNT - 1)

	LevelSession.current_index = -5
	assert_eq(LevelSession.clamp_current(), 0)
