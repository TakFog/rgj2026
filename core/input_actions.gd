class_name InputActions
extends RefCounted
## Registers the input map in code (avoids hand-editing project.godot).

const COMMAND := &"command" # left click: select fish / give order / confirm placement
const CANCEL := &"cancel" # right click or Esc: cancel placement / deselect
const PAUSE := &"pause" # Space or Esc (Esc only when nothing to cancel)
const DEBUG_OVERLAY := &"debug_overlay" # F3


static func register() -> void:
	_add_mouse(COMMAND, MOUSE_BUTTON_LEFT)
	_add_mouse(CANCEL, MOUSE_BUTTON_RIGHT)
	_add_key(CANCEL, KEY_ESCAPE)
	_add_key(PAUSE, KEY_SPACE)
	_add_key(PAUSE, KEY_ESCAPE)
	_add_key(DEBUG_OVERLAY, KEY_F3)


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
	var event := InputEventMouseButton.new()
	event.button_index = button
	InputMap.action_add_event(action, event)
