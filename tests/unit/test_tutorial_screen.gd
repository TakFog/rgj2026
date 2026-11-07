extends TestCase


func test_start_mode_offers_start_and_skip() -> void:
	assert_eq(TutorialScreen.primary_label(TutorialScreen.Mode.START), "Inizia")
	assert_true(TutorialScreen.skip_visible(TutorialScreen.Mode.START))
	assert_true(TutorialScreen.starts_run(TutorialScreen.Mode.START))


func test_review_mode_only_goes_back() -> void:
	assert_eq(TutorialScreen.primary_label(TutorialScreen.Mode.REVIEW), "Indietro")
	assert_false(TutorialScreen.skip_visible(TutorialScreen.Mode.REVIEW))
	assert_false(TutorialScreen.starts_run(TutorialScreen.Mode.REVIEW))


func test_input_mapping() -> void:
	assert_eq(TutorialScreen.action_for(true, true), TutorialScreen.InputAction.PRIMARY)
	assert_eq(TutorialScreen.action_for(false, true), TutorialScreen.InputAction.NEXT)
	assert_eq(TutorialScreen.action_for(false, false), TutorialScreen.InputAction.NONE)
