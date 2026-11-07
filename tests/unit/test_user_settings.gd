extends TestCase

const TEST_PATH := "user://test_settings.cfg"


func before_each() -> void:
	_delete_test_file()


func _delete_test_file() -> void:
	if FileAccess.file_exists(TEST_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_PATH))


func test_tutorial_is_unseen_by_default() -> void:
	assert_false(UserSettings.tutorial_seen(TEST_PATH))
	_delete_test_file()


func test_mark_tutorial_seen_round_trips() -> void:
	UserSettings.mark_tutorial_seen(TEST_PATH)
	assert_true(UserSettings.tutorial_seen(TEST_PATH))
	_delete_test_file()


func test_marking_seen_keeps_the_audio_section() -> void:
	var config := ConfigFile.new()
	config.set_value(UserSettings.SECTION, UserSettings.MUSIC_KEY, -12.0)
	config.set_value(UserSettings.SECTION, UserSettings.EFFECTS_KEY, -4.0)
	assert_eq(config.save(TEST_PATH), OK)

	UserSettings.mark_tutorial_seen(TEST_PATH)

	var reloaded := ConfigFile.new()
	assert_eq(reloaded.load(TEST_PATH), OK)
	assert_almost(float(reloaded.get_value(UserSettings.SECTION, UserSettings.MUSIC_KEY, 0.0)), -12.0)
	assert_almost(float(reloaded.get_value(UserSettings.SECTION, UserSettings.EFFECTS_KEY, 0.0)), -4.0)
	_delete_test_file()


func test_best_score_is_zero_by_default() -> void:
	assert_almost(UserSettings.best_seconds(TEST_PATH), 0.0)
	_delete_test_file()


func test_submit_best_keeps_the_highest_score() -> void:
	assert_true(UserSettings.submit_best(42.0, TEST_PATH))
	assert_almost(UserSettings.best_seconds(TEST_PATH), 42.0)
	assert_false(UserSettings.submit_best(30.0, TEST_PATH))
	assert_almost(UserSettings.best_seconds(TEST_PATH), 42.0)
	assert_true(UserSettings.submit_best(60.0, TEST_PATH))
	assert_almost(UserSettings.best_seconds(TEST_PATH), 60.0)
	_delete_test_file()


func test_submit_best_keeps_the_audio_section() -> void:
	var config := ConfigFile.new()
	config.set_value(UserSettings.SECTION, UserSettings.MUSIC_KEY, -12.0)
	assert_eq(config.save(TEST_PATH), OK)

	assert_true(UserSettings.submit_best(10.0, TEST_PATH))

	var reloaded := ConfigFile.new()
	assert_eq(reloaded.load(TEST_PATH), OK)
	assert_almost(float(reloaded.get_value(UserSettings.SECTION, UserSettings.MUSIC_KEY, 0.0)), -12.0)
	_delete_test_file()
