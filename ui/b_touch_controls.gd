class_name TouchControls
extends Control
## On-screen buttons for touch builds (Platform.is_touch), standing in for the
## keys a phone does not have: Pausa (Space) and Annulla (right click / Esc).
## Bottom-right corner, clear of the inventory, score and thermometer.
## Only created in touch builds; the web build never sees it.
## Pausable: hidden behind the pause menu, which has its own Riprendi button.

const BUTTON_SIZE := Vector2(150, 64)
const MARGIN := 20.0
const SEPARATION := 12

var commander: FishCommander
var pause: PauseController
var _cancel_btn: Button


## Annulla is offered only when there is something to cancel.
static func cancel_visible(placing: bool, has_selection: bool) -> bool:
	return placing or has_selection


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", SEPARATION)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(row)

	_cancel_btn = _button("Annulla", _on_cancel_pressed)
	_cancel_btn.visible = false
	row.add_child(_cancel_btn)
	row.add_child(_button("Pausa", _on_pause_pressed))

	row.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	row.grow_vertical = Control.GROW_DIRECTION_BEGIN
	row.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT, Control.PRESET_MODE_MINSIZE, int(MARGIN))


func _process(_delta: float) -> void:
	var has_selection := commander != null and is_instance_valid(commander.selected)
	_cancel_btn.visible = cancel_visible(Game.placing, has_selection)


func _button(text: String, handler: Callable) -> Button:
	var button := SeaStyle.menu_button(text)
	button.custom_minimum_size = BUTTON_SIZE
	# Touch has no keyboard focus to show, and focus would let Space press it.
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(handler)
	return button


## Sends the same cancel action as right click, so placement and the fish
## commander react (and sound) exactly as they do on desktop and web.
func _on_cancel_pressed() -> void:
	var event := InputEventAction.new()
	event.action = InputActions.CANCEL
	event.pressed = true
	Input.parse_input_event(event)


## Pauses directly: the pause key is ignored while placing (it would cancel).
func _on_pause_pressed() -> void:
	if pause != null:
		pause.set_paused(true)
