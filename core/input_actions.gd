class_name InputActions
extends RefCounted
## Registers the input map in code (avoids hand-editing project.godot).

const COMMAND := &"command" # left click: select fish / give order / confirm placement
const CANCEL := &"cancel" # right click or Esc: cancel placement / deselect
const PAUSE := &"pause" # Space or Esc (Esc only when nothing to cancel)
const DEBUG_OVERLAY := &"debug_overlay" # F3
## One action per inventory slot, bound to the 1-4 keys (number row and keypad).
const SLOTS: Array[StringName] = [&"slot_1", &"slot_2", &"slot_3", &"slot_4"]
## InputMap device id matching every device. Touch builds need it: taps reach
## the game as mouse clicks from the emulation device (-1), which a binding
## made with a new event's default device would not match.
const ALL_DEVICES := -1


static func register() -> void:
	_add_mouse(COMMAND, MOUSE_BUTTON_LEFT)
	_add_mouse(CANCEL, MOUSE_BUTTON_RIGHT)
	_add_key(CANCEL, KEY_ESCAPE)
	_add_key(PAUSE, KEY_SPACE)
	_add_key(PAUSE, KEY_ESCAPE)
	_add_key(DEBUG_OVERLAY, KEY_F3)
	for i in SLOTS.size():
		_add_key(SLOTS[i], KEY_1 + i)
		_add_key(SLOTS[i], KEY_KP_1 + i)


static func _ensure(action: StringName) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)


static func _add_key(action: StringName, keycode: Key) -> void:
	_ensure(action)
	var event := InputEventKey.new()
	event.physical_keycode = keycode
	InputMap.action_add_event(action, event)


static func _add_mouse(action: StringName, button: MouseButton) -> void:
	_ensure(action)
	InputMap.action_add_event(action, mouse_event(button, Platform.is_touch()))


## Mouse binding for `button`. Mouse builds (web included) keep the default
## device binding they always had; touch builds also accept clicks emulated from taps.
static func mouse_event(button: MouseButton, touch: bool) -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.button_index = button
	if touch:
		event.device = ALL_DEVICES
	return event
