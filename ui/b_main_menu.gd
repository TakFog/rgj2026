class_name MainMenuScreen
extends ColorRect
## Main menu overlay shown at game start (GDD §9, roadmap: title screen).
## Title at one quarter of the screen height, Play at the centre of the
## screen, Credits bottom right, Exit bottom left (Exit hidden in web builds).
## Works while the tree is paused; clicking Play unpauses and hides the menu.

const BUTTON_SIZE := Vector2(180.0, 60.0)
const SCREEN_MARGIN := 24.0
const TITLE_HEIGHT := 80.0
const TITLE_Y_FRACTION := 0.25

signal play_pressed
signal exit_pressed
## Play was pressed: the front end shows the tutorial, then starts the run.
signal play_requested
## The "Come si gioca" button was pressed.
signal tutorial_requested
## Any menu button was pressed (used by the audio system).
signal button_pressed

## Set by Restart just before reloading the scene: the reloaded menu then
## starts the run straight away instead of showing the title screen.
## Static, so it survives reload_current_scene().
static var _skip_next_open := false

var _menu_panel: Control
var _credits_panel: Control
var _settings_panel: SettingsPanel


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	color = Color(0.02, 0.05, 0.1, 0.85)
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = true

	# Panels fill the screen and position their buttons with anchors, so they
	# are added directly instead of into a centring container.
	_menu_panel = _build_menu_panel()
	add_child(_menu_panel)
	_credits_panel = _build_credits_panel()
	_credits_panel.visible = false
	add_child(_credits_panel)
	_settings_panel = SettingsPanel.new()
	_settings_panel.visible = false
	_settings_panel.closed.connect(_on_settings_closed)
	_settings_panel.button_pressed.connect(func() -> void: button_pressed.emit())
	add_child(_settings_panel)

	# Auto-open when the menu enters the tree (game start). Calling open()
	# from DevBSystems would race: Game.ui is not in the tree yet when
	# DevBSystems._ready runs, so _ready here hasn't fired yet.
	if _skip_next_open:
		_skip_next_open = false
		_start_without_menu()
	else:
		open()


## Restarts the run, skipping the title screen. Used by the pause menu and the
## game-over screen.
static func restart_run(tree: SceneTree) -> void:
	_skip_next_open = true
	tree.paused = false
	tree.reload_current_scene()


## Like pressing Play, without the click: deferred so the music node and the
## other listeners are in the tree when play_pressed fires.
func _start_without_menu() -> void:
	close()
	play_pressed.emit.call_deferred()


func _build_menu_panel() -> Control:
	var panel := Control.new()
	panel.name = "MenuPanel"
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Title across the full width, vertically centred on 1/4 of the screen.
	var title := Label.new()
	title.text = "BalanSea"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 48)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(title)
	title.anchor_left = 0.0
	title.anchor_right = 1.0
	title.anchor_top = TITLE_Y_FRACTION
	title.anchor_bottom = TITLE_Y_FRACTION
	title.offset_left = 0.0
	title.offset_right = 0.0
	title.offset_top = -TITLE_HEIGHT * 0.5
	title.offset_bottom = TITLE_HEIGHT * 0.5

	# Play, centred both horizontally and vertically.
	var play_btn := _button("Gioca")
	play_btn.pressed.connect(_on_play_pressed)
	panel.add_child(play_btn)
	play_btn.set_anchors_preset(Control.PRESET_CENTER)
	play_btn.offset_left = -BUTTON_SIZE.x * 0.5
	play_btn.offset_right = BUTTON_SIZE.x * 0.5
	play_btn.offset_top = -BUTTON_SIZE.y * 0.5
	play_btn.offset_bottom = BUTTON_SIZE.y * 0.5

	# Settings, just below Play.
	var settings_btn := _button("Impostazioni")
	settings_btn.add_theme_font_size_override("font_size", 22)
	settings_btn.pressed.connect(_on_settings_pressed)
	panel.add_child(settings_btn)
	settings_btn.set_anchors_preset(Control.PRESET_CENTER)
	settings_btn.offset_left = -BUTTON_SIZE.x * 0.5
	settings_btn.offset_right = BUTTON_SIZE.x * 0.5
	settings_btn.offset_top = BUTTON_SIZE.y * 0.5 + 16.0
	settings_btn.offset_bottom = BUTTON_SIZE.y * 1.5 + 16.0

	# How to play, just below Settings.
	var tutorial_btn := _button("Come si gioca")
	tutorial_btn.add_theme_font_size_override("font_size", 22)
	tutorial_btn.pressed.connect(_on_tutorial_pressed)
	panel.add_child(tutorial_btn)
	tutorial_btn.set_anchors_preset(Control.PRESET_CENTER)
	tutorial_btn.offset_left = -BUTTON_SIZE.x * 0.5
	tutorial_btn.offset_right = BUTTON_SIZE.x * 0.5
	tutorial_btn.offset_top = BUTTON_SIZE.y * 1.5 + 32.0
	tutorial_btn.offset_bottom = BUTTON_SIZE.y * 2.5 + 32.0

	# Exit, bottom left of the screen.
	var exit_btn := _button("Esci")
	exit_btn.pressed.connect(_on_exit_pressed)
	# Web builds cannot quit the host page, so the exit button is hidden there.
	if OS.has_feature("web"):
		exit_btn.visible = false
	panel.add_child(exit_btn)
	exit_btn.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	exit_btn.offset_left = SCREEN_MARGIN
	exit_btn.offset_right = SCREEN_MARGIN + BUTTON_SIZE.x
	exit_btn.offset_top = -SCREEN_MARGIN - BUTTON_SIZE.y
	exit_btn.offset_bottom = -SCREEN_MARGIN

	# Credits, bottom right of the screen.
	var credits_btn := _button("Crediti")
	credits_btn.pressed.connect(_on_credits_pressed)
	panel.add_child(credits_btn)
	credits_btn.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	credits_btn.offset_left = -SCREEN_MARGIN - BUTTON_SIZE.x
	credits_btn.offset_right = -SCREEN_MARGIN
	credits_btn.offset_top = -SCREEN_MARGIN - BUTTON_SIZE.y
	credits_btn.offset_bottom = -SCREEN_MARGIN

	return panel


func _build_credits_panel() -> Control:
	var panel := Control.new()
	panel.name = "CreditsPanel"
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.add_child(center)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 16)
	center.add_child(box)

	var credits := Label.new()
	credits.text = "BalanSea\n\nUn gestionale di barriera corallina.\nTema del game jam: SUBIRE.\n\nRealizzato con Godot 4.7.2."
	credits.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	credits.add_theme_font_size_override("font_size", 24)
	box.add_child(credits)

	var back_btn := _button("Indietro")
	back_btn.pressed.connect(_on_back_pressed)
	box.add_child(back_btn)

	return panel


func _button(text: String) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = BUTTON_SIZE
	btn.add_theme_font_size_override("font_size", 28)
	SeaStyle.style_button(btn)
	return btn


func _on_play_pressed() -> void:
	button_pressed.emit()
	hide_for_tutorial()
	play_requested.emit()


func _on_tutorial_pressed() -> void:
	button_pressed.emit()
	hide_for_tutorial()
	tutorial_requested.emit()


func _on_settings_pressed() -> void:
	button_pressed.emit()
	_menu_panel.visible = false
	_settings_panel.open()


func _on_settings_closed() -> void:
	_menu_panel.visible = true


func _on_credits_pressed() -> void:
	button_pressed.emit()
	_menu_panel.visible = false
	_credits_panel.visible = true


func _on_back_pressed() -> void:
	button_pressed.emit()
	_credits_panel.visible = false
	_menu_panel.visible = true


func _on_exit_pressed() -> void:
	button_pressed.emit()
	exit_pressed.emit()


## The run is paused behind the menu, so swallow the pause key: otherwise
## Space/Esc would unpause the game underneath the still-visible menu.
func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed(InputActions.PAUSE):
		get_viewport().set_input_as_handled()


## Play / How-to-play hides the menu but leaves the run paused for the tutorial.
func hide_for_tutorial() -> void:
	visible = false
	_settings_panel.close()


## Show the menu and pause the game behind it. Called when the run starts.
func open() -> void:
	visible = true
	_credits_panel.visible = false
	_settings_panel.close()
	_menu_panel.visible = true
	_set_gameplay_hud_visible(false)
	get_tree().paused = true


## Hide the menu and resume the game.
func close() -> void:
	visible = false
	_settings_panel.close()
	_set_gameplay_hud_visible(true)
	get_tree().paused = false


## The thermometer and inventory cards would show through the translucent
## backdrop, so they are hidden while the menu is up.
func _set_gameplay_hud_visible(value: bool) -> void:
	for node in get_tree().get_nodes_in_group(Groups.GAMEPLAY_HUD):
		if node is CanvasItem:
			(node as CanvasItem).visible = value
