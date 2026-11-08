extends TestCase
## Level progression saved in user://: unlock count and per-level records.

const TEST_PATH := "user://test_levels.cfg"


func before_each() -> void:
	_delete_test_file()


func after_each() -> void:
	_delete_test_file()


func _delete_test_file() -> void:
	if FileAccess.file_exists(TEST_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_PATH))


func test_only_the_first_level_is_unlocked_by_default() -> void:
	assert_eq(UserSettings.unlocked_count(TEST_PATH), 1)


func test_clearing_a_level_unlocks_the_next() -> void:
	UserSettings.mark_level_cleared(0, 3, TEST_PATH)
	assert_eq(UserSettings.unlocked_count(TEST_PATH), 2)
	UserSettings.mark_level_cleared(1, 3, TEST_PATH)
	assert_eq(UserSettings.unlocked_count(TEST_PATH), 3)


func test_unlock_count_is_capped_at_the_campaign_size() -> void:
	UserSettings.mark_level_cleared(2, 3, TEST_PATH)
	assert_eq(UserSettings.unlocked_count(TEST_PATH), 3)


func test_clearing_an_old_level_never_locks_a_newer_one() -> void:
	UserSettings.mark_level_cleared(0, 3, TEST_PATH)
	UserSettings.mark_level_cleared(1, 3, TEST_PATH)
	UserSettings.mark_level_cleared(0, 3, TEST_PATH)
	assert_eq(UserSettings.unlocked_count(TEST_PATH), 3)


func test_unlock_all_is_a_debug_shortcut() -> void:
	UserSettings.unlock_all(3, TEST_PATH)
	assert_eq(UserSettings.unlocked_count(TEST_PATH), 3)


func test_level_best_starts_at_zero_and_keeps_the_highest() -> void:
	assert_almost(UserSettings.level_best_seconds(1, TEST_PATH), 0.0)
	assert_true(UserSettings.submit_level_best(1, 42.0, TEST_PATH))
	assert_false(UserSettings.submit_level_best(1, 30.0, TEST_PATH))
	assert_almost(UserSettings.level_best_seconds(1, TEST_PATH), 42.0)
	assert_true(UserSettings.submit_level_best(1, 60.0, TEST_PATH))
	assert_almost(UserSettings.level_best_seconds(1, TEST_PATH), 60.0)


func test_progress_keeps_the_audio_section() -> void:
	var config := ConfigFile.new()
	config.set_value(UserSettings.SECTION, UserSettings.MUSIC_KEY, -12.0)
	assert_eq(config.save(TEST_PATH), OK)

	UserSettings.mark_level_cleared(0, 3, TEST_PATH)
	UserSettings.submit_level_best(0, 10.0, TEST_PATH)

	var reloaded := ConfigFile.new()
	assert_eq(reloaded.load(TEST_PATH), OK)
	assert_almost(float(reloaded.get_value(UserSettings.SECTION, UserSettings.MUSIC_KEY, 0.0)), -12.0)
