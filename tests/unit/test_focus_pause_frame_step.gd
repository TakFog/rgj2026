extends TestCase

const GameScript := preload("res://autoload/game.gd")


func _game() -> Node:
	var game: Node = GameScript.new()
	autofree(game)
	return game


func test_frame_step_passes_normal_delta() -> void:
	assert_eq(_game().frame_step(0.016), 0.016)


func test_frame_step_caps_long_hitch() -> void:
	assert_eq(_game().frame_step(60.0), GameScript.MAX_FRAME_STEP)


func test_focus_out_pauses_live_run() -> void:
	assert_true(PauseController.pauses_on_focus_out(false, false))


func test_focus_out_ignored_when_already_paused() -> void:
	# Main menu, tutorial and an open pause menu all keep the tree paused.
	assert_false(PauseController.pauses_on_focus_out(true, false))


func test_focus_out_ignored_after_game_over() -> void:
	assert_false(PauseController.pauses_on_focus_out(false, true))
