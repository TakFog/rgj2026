extends TestCase
## Inventory drag-and-drop: release decision and the touch fingertip lift.


func test_a_press_that_does_not_move_is_a_click() -> void:
	assert_eq(PlacementController.drop_result(0.0, true, true), PlacementController.DropResult.IGNORED)
	assert_eq(
		PlacementController.drop_result(PlacementController.DRAG_DEAD_ZONE - 0.1, true, false),
		PlacementController.DropResult.IGNORED)


func test_a_drag_released_outside_the_reef_cancels() -> void:
	assert_eq(
		PlacementController.drop_result(PlacementController.DRAG_DEAD_ZONE, false, false),
		PlacementController.DropResult.CANCEL)


func test_a_drag_released_on_an_invalid_cell_keeps_placing() -> void:
	assert_eq(
		PlacementController.drop_result(PlacementController.DRAG_DEAD_ZONE, true, false),
		PlacementController.DropResult.KEEP)


func test_a_drag_released_on_a_valid_cell_places() -> void:
	assert_eq(
		PlacementController.drop_result(PlacementController.DRAG_DEAD_ZONE, true, true),
		PlacementController.DropResult.PLACE)


func test_touch_drag_lifts_the_ghost_above_the_finger() -> void:
	assert_eq(
		PlacementController.drag_lift(true, true),
		Vector2(0.0, -PlacementController.TOUCH_DRAG_LIFT))


func test_mouse_drag_and_tap_preview_do_not_lift() -> void:
	assert_eq(PlacementController.drag_lift(false, true), Vector2.ZERO)
	assert_eq(PlacementController.drag_lift(true, false), Vector2.ZERO)


func test_drag_from_a_refilling_slot_is_ignored() -> void:
	var inventory := InventorySystem.new()
	inventory.model = InventoryModel.new(
		Game.eco, RandomNumberGenerator.new(), func() -> int: return 0)
	var placement := PlacementController.new()
	placement.inventory = inventory
	placement.begin_drag(0)
	assert_eq(placement.active_slot, -1)
	placement.free()
	inventory.free()


func test_disarming_a_drag_stops_tracking() -> void:
	var placement := PlacementController.new()
	placement._dragging = true
	placement._disarm_drag()
	assert_false(placement._dragging)
	placement.free()


func test_a_lifted_touch_drag_can_still_reach_the_bottom_row() -> void:
	var previous_grid := Game.grid
	var previous_projection := Game.projection
	Game.grid = GridModel.new(Vector2i(20, 20), 32.0)
	Game.projection = ViewProjection.from_settings(Game.VIEW_SETTINGS)
	var last_row := Vector2i(5, 19)
	var finger := Game.projection.to_screen(Game.grid.cell_to_world(last_row)) \
			+ Vector2(0.0, PlacementController.TOUCH_DRAG_LIFT)
	var dropped := PlacementController.pointer_cell(finger, true, true)
	Game.grid = previous_grid
	Game.projection = previous_projection
	assert_eq(dropped, last_row)


func test_a_cancelled_touch_release_does_not_place() -> void:
	var placement := PlacementController.new()
	placement.active_slot = 0
	placement._dragging = true
	var event := InputActions.mouse_event(MOUSE_BUTTON_LEFT, false)
	event.pressed = false
	event.canceled = true
	placement._input(event)
	assert_false(placement._dragging)
	assert_eq(placement.active_slot, 0, "a cancelled gesture leaves placement active")
	placement.free()


func test_focus_loss_disarms_the_drag() -> void:
	var placement := PlacementController.new()
	placement.active_slot = 0
	placement._dragging = true
	placement._notification(PlacementController.NOTIFICATION_WM_WINDOW_FOCUS_OUT)
	assert_false(placement._dragging)
	placement._dragging = true
	placement._notification(PlacementController.NOTIFICATION_APPLICATION_FOCUS_OUT)
	assert_false(placement._dragging)
	placement.free()


func test_a_new_press_disarms_a_stale_drag() -> void:
	var placement := PlacementController.new()
	placement.active_slot = 0
	placement._dragging = true
	var event := InputActions.mouse_event(MOUSE_BUTTON_LEFT, false)
	event.pressed = true
	placement._input(event)
	assert_false(placement._dragging)
	placement.free()
