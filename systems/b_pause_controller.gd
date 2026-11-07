class_name PauseController
extends Node
## Space/Esc toggles pause (GDD §9). Ignored while placing — Esc must reach the
## placement controller to cancel (roadmap contract #8) — and after game over.
## PROCESS_MODE_ALWAYS so it can unpause.

var monitor: PopulationMonitor
var overlay: Control


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	overlay = _build_overlay()
	Game.ui.add_child(overlay)


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed(InputActions.PAUSE):
		return
	if Game.placing or (monitor != null and monitor.is_over):
		return
	set_paused(not get_tree().paused)
	get_viewport().set_input_as_handled()


func set_paused(value: bool) -> void:
	get_tree().paused = value
	overlay.visible = value


func _build_overlay() -> Control:
	var root := ColorRect.new()
	root.name = "PauseOverlay"
	root.color = Color(0, 0, 0, 0.5)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.visible = false
	var label := Label.new()
	label.text = "PAUSA\nSpazio per riprendere"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 40)
	root.add_child(label)
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return root
