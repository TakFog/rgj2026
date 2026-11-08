class_name PauseController
extends Node
## Space/Esc toggles pause (GDD §9). Ignored while placing — Esc must reach the
## placement controller to cancel (roadmap contract #8) — and after game over.
## Esc also yields to the fish commander while a fish is selected (deselect first).
## PROCESS_MODE_ALWAYS so it can unpause.
## Losing focus (hidden browser tab, alt-tab) opens the pause menu mid-run.

## Used by the audio system (systems/b_audio.gd).
signal pause_toggled(paused: bool)
## A pause-menu button was pressed (used by the audio system).
signal button_pressed

var monitor: PopulationMonitor
var commander: FishCommander
var overlay: Control
var _pause_box: Control
var _pause_items: VBoxContainer
var _settings_panel: SettingsPanel
var _resume_btn: Button


## True when a pause press must be left to another handler: anything while
## placing, and Esc (also bound to cancel) while a fish is selected.
static func yields_to_cancel(is_cancel: bool, placing: bool, has_selection: bool) -> bool:
	return placing or (is_cancel and has_selection)


## True when losing focus must open the pause menu: only during a live run.
## The main menu, the tutorial and game over already pause the tree.
static func pauses_on_focus_out(tree_paused: bool, run_over: bool) -> bool:
	return not tree_paused and not run_over


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	overlay = _build_overlay()
	Game.ui.add_child(overlay)


func _notification(what: int) -> void:
	if what != NOTIFICATION_APPLICATION_FOCUS_OUT and what != NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		return
	if not is_inside_tree() or overlay == null:
		return
	if pauses_on_focus_out(get_tree().paused, monitor != null and monitor.is_over):
		# Placement and fish selection stay as they are; the menu just covers them.
		set_paused(true)


func _unhandled_input(event: InputEvent) -> void:
	if _settings_panel != null and _settings_panel.visible:
		return
	if not event.is_action_pressed(InputActions.PAUSE):
		return
	var has_selection := not get_tree().paused and commander != null \
			and is_instance_valid(commander.selected)
	# While paused (e.g. focus lost mid-placement) placement can't see the key,
	# so Space/Esc must resume instead of being left to it.
	if not get_tree().paused \
			and yields_to_cancel(event.is_action_pressed(InputActions.CANCEL), Game.placing, has_selection):
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
	if value and _resume_btn != null:
		# Keyboard/gamepad navigation starts on Resume.
		_resume_btn.grab_focus()
	pause_toggled.emit(value)


func _build_overlay() -> Control:
	var root := ColorRect.new()
	root.name = "PauseOverlay"
	root.color = SeaStyle.OVERLAY_COLOR
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.visible = false

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(center)

	# The pause menu is one sea card, matching the settings panel.
	_pause_box = PanelContainer.new()
	_pause_box.add_theme_stylebox_override("panel", SeaStyle.panel_box())
	center.add_child(_pause_box)

	_pause_items = VBoxContainer.new()
	_pause_items.add_theme_constant_override("separation", SeaStyle.MENU_SEPARATION)
	_pause_box.add_child(_pause_items)

	var label := Label.new()
	label.text = "PAUSA"
	SeaStyle.style_title(label)
	_pause_items.add_child(label)
	_pause_items.add_child(SeaStyle.divider())

	_resume_btn = _add_button("Riprendi", _on_resume_pressed)
	SeaStyle.style_highlighted_button(_resume_btn)
	_add_button("Impostazioni", _on_settings_pressed)
	_add_button("Ricomincia livello", _on_restart_pressed)
	_add_button("Torna al menu", _on_menu_pressed)
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
	var button := SeaStyle.menu_button(text)
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	button.pressed.connect(handler)
	_pause_items.add_child(button)
	return button


## Unpausing already emits pause_toggled, which plays the click, so no
## button_pressed here (it would play the click twice).
func _on_resume_pressed() -> void:
	set_paused(false)


func _on_settings_pressed() -> void:
	button_pressed.emit()
	_pause_box.visible = false
	_settings_panel.open()


func _on_restart_pressed() -> void:
	button_pressed.emit()
	MainMenuScreen.restart_run(get_tree())


## Leaves the run; the title screen (and the level chooser) come back.
func _on_menu_pressed() -> void:
	button_pressed.emit()
	MainMenuScreen.restart_to_menu(get_tree())


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
