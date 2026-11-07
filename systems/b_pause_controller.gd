class_name PauseController
extends Node
## Space/Esc toggles pause (GDD §9). Ignored while placing — Esc must reach the
## placement controller to cancel (roadmap contract #8) — and after game over.
## Esc also yields to the fish commander while a fish is selected (deselect first).
## PROCESS_MODE_ALWAYS so it can unpause.

## Used by the audio system (systems/b_audio.gd).
signal pause_toggled(paused: bool)
## A pause-menu button was pressed (used by the audio system).
signal button_pressed

var monitor: PopulationMonitor
var commander: FishCommander
var overlay: Control
var _pause_box: Control
var _settings_panel: SettingsPanel


## True when a pause press must be left to another handler: anything while
## placing, and Esc (also bound to cancel) while a fish is selected.
static func yields_to_cancel(is_cancel: bool, placing: bool, has_selection: bool) -> bool:
	return placing or (is_cancel and has_selection)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	overlay = _build_overlay()
	Game.ui.add_child(overlay)


func _unhandled_input(event: InputEvent) -> void:
	if _settings_panel != null and _settings_panel.visible:
		return
	if not event.is_action_pressed(InputActions.PAUSE):
		return
	var has_selection := not get_tree().paused and commander != null \
			and is_instance_valid(commander.selected)
	if yields_to_cancel(event.is_action_pressed(InputActions.CANCEL), Game.placing, has_selection):
		return
	if monitor != null and monitor.is_over:
		return
	set_paused(not get_tree().paused)
	get_viewport().set_input_as_handled()


func set_paused(value: bool) -> void:
	get_tree().paused = value
	if value:
		_show_pause()
	overlay.visible = value
	pause_toggled.emit(value)


func _build_overlay() -> Control:
	var root := ColorRect.new()
	root.name = "PauseOverlay"
	root.color = Color(0, 0, 0, 0.5)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.visible = false

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(center)

	_pause_box = VBoxContainer.new()
	_pause_box.add_theme_constant_override("separation", 16)
	center.add_child(_pause_box)

	var label := Label.new()
	label.text = "PAUSA"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 40)
	_pause_box.add_child(label)

	var hint := Label.new()
	hint.text = "Spazio per riprendere"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 24)
	_pause_box.add_child(hint)

	_add_button("Impostazioni", _on_settings_pressed)
	_add_button("Ricomincia", _on_restart_pressed)
	var exit_btn := _add_button("Esci", _on_exit_pressed)
	# Web builds cannot quit the host page, so the exit button is hidden there.
	exit_btn.visible = not OS.has_feature("web")

	_settings_panel = SettingsPanel.new()
	_settings_panel.visible = false
	_settings_panel.closed.connect(_on_settings_closed)
	_settings_panel.button_pressed.connect(func() -> void: button_pressed.emit())
	root.add_child(_settings_panel)
	return root


func _add_button(text: String, handler: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(220, 60)
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	button.add_theme_font_size_override("font_size", 24)
	button.pressed.connect(handler)
	_pause_box.add_child(button)
	return button


func _on_settings_pressed() -> void:
	button_pressed.emit()
	_pause_box.visible = false
	_settings_panel.open()


func _on_restart_pressed() -> void:
	button_pressed.emit()
	get_tree().paused = false
	get_tree().reload_current_scene()


func _on_exit_pressed() -> void:
	button_pressed.emit()
	get_tree().quit()


func _on_settings_closed() -> void:
	_pause_box.visible = true


func _show_pause() -> void:
	if _settings_panel != null:
		_settings_panel.close()
	if _pause_box != null:
		_pause_box.visible = true
