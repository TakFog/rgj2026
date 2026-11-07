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


func test_right_click_skips_in_start_mode() -> void:
	var screen := _open_screen(TutorialScreen.Mode.START)
	var started := [false]
	screen.run_started.connect(func() -> void: started[0] = true)

	assert_true(_has_script_method(screen, "_input"), "mouse cancel must be handled before the GUI")
	if not _has_script_method(screen, "_input"):
		_close_screen(screen)
		return
	screen._input(_right_click())

	assert_true(started[0], "right click must skip/start")
	_close_screen(screen)


func test_auto_advance_moves_to_the_next_interaction() -> void:
	var screen := _open_screen(TutorialScreen.Mode.REVIEW)
	assert_eq(screen.get("_selected_index"), 0)
	screen._process(TutorialScreen.LOOP_SECONDS + 0.1)
	assert_eq(screen.get("_selected_index"), 1)
	_close_screen(screen)


func test_right_click_goes_back_in_review_mode() -> void:
	var screen := _open_screen(TutorialScreen.Mode.REVIEW)
	var closed := [false]
	screen.closed.connect(func() -> void: closed[0] = true)

	assert_true(_has_script_method(screen, "_input"), "mouse cancel must be handled before the GUI")
	if not _has_script_method(screen, "_input"):
		_close_screen(screen)
		return
	screen._input(_right_click())

	assert_true(closed[0], "right click must go back")
	_close_screen(screen)


func _has_script_method(object: Object, method_name: String) -> bool:
	for method in object.get_script().get_script_method_list():
		if method["name"] == method_name:
			return true
	return false


func _open_screen(mode: TutorialScreen.Mode) -> TutorialScreen:
	InputActions.register()
	var tree := Engine.get_main_loop() as SceneTree
	var screen := TutorialScreen.new()
	tree.root.add_child(screen)
	# _ready only runs on add_child once the tree itself is ready.
	if not screen.is_node_ready():
		screen._ready()
	screen.open(mode)
	return screen


func _close_screen(screen: TutorialScreen) -> void:
	screen.close()
	screen.free()


func _right_click() -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_RIGHT
	event.pressed = true
	return event
