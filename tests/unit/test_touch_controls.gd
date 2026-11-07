extends TestCase
## Touch controls (Android build): only on touch, mouse/keyboard (web) untouched.


func test_touch_only_on_android_or_with_the_debug_flag() -> void:
	assert_true(Platform.uses_touch(true, PackedStringArray()))
	assert_true(Platform.uses_touch(false, PackedStringArray([Platform.TOUCH_ARG])))
	assert_false(Platform.uses_touch(false, PackedStringArray()))
	assert_false(Platform.uses_touch(false, PackedStringArray(["--smoke-play"])))


func test_headless_test_run_is_not_touch() -> void:
	assert_false(Platform.is_touch(), "tests run as a desktop (mouse) build")


func test_first_tap_only_previews() -> void:
	assert_false(PlacementController.touch_tap_confirms(PlacementController.NO_CELL, Vector2i(3, 4)))


func test_tap_on_the_previewed_cell_confirms() -> void:
	assert_true(PlacementController.touch_tap_confirms(Vector2i(3, 4), Vector2i(3, 4)))


func test_tap_elsewhere_moves_the_preview() -> void:
	assert_false(PlacementController.touch_tap_confirms(Vector2i(3, 4), Vector2i(5, 4)))


func test_mouse_builds_keep_mouse_placement() -> void:
	var placement := PlacementController.new()
	assert_false(placement.touch_mode)
	placement.free()


func test_cancel_button_only_when_something_to_cancel() -> void:
	assert_false(TouchControls.cancel_visible(false, false))
	assert_true(TouchControls.cancel_visible(true, false))
	assert_true(TouchControls.cancel_visible(false, true))


func test_third_finger_toggles_debug_only_on_touch() -> void:
	var third := InputEventScreenTouch.new()
	third.index = 2
	third.pressed = true
	assert_true(Platform.is_debug_touch(third, true))
	assert_false(Platform.is_debug_touch(third, false))
	var first := InputEventScreenTouch.new()
	first.index = 0
	first.pressed = true
	assert_false(Platform.is_debug_touch(first, true))
	third.pressed = false
	assert_false(Platform.is_debug_touch(third, true))


func test_fish_touch_radius_is_wider_than_mouse() -> void:
	assert_true(Game.actors.fish_touch_radius > Game.actors.fish_click_radius)


func test_touch_mouse_bindings_accept_taps() -> void:
	# Taps arrive as clicks from the emulation device (-1).
	assert_eq(InputActions.mouse_event(MOUSE_BUTTON_LEFT, true).device, InputActions.ALL_DEVICES)


func test_mouse_bindings_unchanged_outside_touch() -> void:
	# Exactly the binding a plain new event gives, as before the Android port.
	assert_eq(InputActions.mouse_event(MOUSE_BUTTON_LEFT, false).device, InputEventMouseButton.new().device)
	assert_eq(InputActions.mouse_event(MOUSE_BUTTON_RIGHT, false).button_index, MOUSE_BUTTON_RIGHT)


func test_no_preview_before_the_first_tap() -> void:
	var placement := PlacementController.new()
	var cells: Array[Vector2i] = placement.preview_cells(PlacementController.NO_CELL)
	assert_true(cells.is_empty())
	placement.free()
