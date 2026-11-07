class_name InventoryBar
extends HBoxContainer
## Bottom-centre inventory slots with a radial refill indicator (GDD §9).
## Pausable: no placing while the game is paused.

const SLOT_SIZE := Vector2(96, 72)
const LABELS := {
	InventoryModel.CORAL: "Coral",
	InventoryModel.ALGAE: "Algae",
	InventoryModel.NEST: "Nest",
}

var inventory: InventorySystem
var placement: PlacementController
var _buttons: Array[Button] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	add_theme_constant_override("separation", 12)
	for i in inventory.model.slots.size():
		var button := Button.new()
		button.custom_minimum_size = SLOT_SIZE
		button.focus_mode = Control.FOCUS_NONE
		button.pressed.connect(placement.begin.bind(i))
		button.draw.connect(_draw_refill.bind(button, i))
		add_child(button)
		_buttons.append(button)
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	grow_vertical = Control.GROW_DIRECTION_BEGIN
	set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM, Control.PRESET_MODE_MINSIZE, 16)


func _process(_delta: float) -> void:
	for i in _buttons.size():
		var button := _buttons[i]
		var item := inventory.model.item(i)
		button.disabled = item.is_empty()
		button.text = _label(item)
		button.modulate = Color(1.4, 1.4, 0.8) if placement.active_slot == i else Color.WHITE
		button.queue_redraw()


func _label(item: Dictionary) -> String:
	if item.is_empty():
		return ""
	var text: String = LABELS[item["kind"]]
	if item["kind"] == InventoryModel.CORAL:
		text += "\n" + String(item["shape_id"])
	return text


func _draw_refill(button: Button, index: int) -> void:
	var ratio := inventory.model.refill_ratio(index)
	if ratio >= 1.0:
		return
	var center := button.size * 0.5
	var radius := minf(button.size.x, button.size.y) * 0.3
	button.draw_arc(center, radius, 0.0, TAU, 32, Color(1, 1, 1, 0.15), 6.0)
	button.draw_arc(center, radius, -PI / 2.0, -PI / 2.0 + TAU * ratio, 32, Color(1, 1, 1, 0.8), 6.0)
