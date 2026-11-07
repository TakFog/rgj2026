extends TestCase

const X_AXIS := Vector2(1, 0)
const Y_AXIS := Vector2(-0.5, 0.5)


func test_single_coral_is_one_cell_at_origin() -> void:
	assert_eq(InventoryCard.coral_icon_cells(&"single", X_AXIS, Y_AXIS), [Vector2.ZERO] as Array[Vector2])


func test_coral_cells_follow_the_oblique_view() -> void:
	var cells := InventoryCard.coral_icon_cells(&"ell", X_AXIS, Y_AXIS)
	assert_eq(cells, [Vector2(0, 0), Vector2(-0.5, 0.5), Vector2(0.5, 0.5)] as Array[Vector2])


func test_coral_cells_are_sorted_back_to_front() -> void:
	for id in CoralShapes.ids():
		var cells := InventoryCard.coral_icon_cells(id, X_AXIS, Y_AXIS)
		assert_eq(cells.size(), CoralShapes.SHAPES[id].size(), String(id))
		for i in range(1, cells.size()):
			assert_true(cells[i - 1].y <= cells[i].y, "%s not sorted" % id)


func test_caption_names_each_kind() -> void:
	assert_eq(InventoryCard.caption({"kind": InventoryModel.CORAL, "shape_id": &"tee"}), "Corallo")
	assert_eq(InventoryCard.caption({"kind": InventoryModel.ALGAE, "shape_id": &""}), "Alga")
	assert_eq(InventoryCard.caption({"kind": InventoryModel.NEST, "shape_id": &""}), "Nido")
	assert_eq(InventoryCard.caption({}), "")
