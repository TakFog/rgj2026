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
