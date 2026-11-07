class_name MainMenuScreen
extends ColorRect
## Main menu overlay shown at game start (GDD §9, roadmap: title screen).
## Title top centre, Play centred under it, Credits bottom right, Exit bottom
## left (Exit hidden in web builds). Works while the tree is paused; clicking
## Play unpauses the game and hides the menu.

const BUTTON_SIZE := Vector2(180.0, 60.0)
const SCREEN_MARGIN := 24.0
const TITLE_TOP := 70.0
const PLAY_TOP := 170.0

signal play_pressed
signal exit_pressed

var _menu_panel: Control
var _credits_panel: Control


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

	# Auto-open when the menu enters the tree (game start). Calling open()
	# from DevBSystems would race: Game.ui is not in the tree yet when
	# DevBSystems._ready runs, so _ready here hasn't fired yet.
	open()


func _build_menu_panel() -> Control:
	var panel := Control.new()
	panel.name = "MenuPanel"
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Title across the top centre.
	var title := Label.new()
	title.text = "BalanSea"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 48)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(title)
	title.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	title.offset_top = TITLE_TOP
	title.offset_bottom = TITLE_TOP + 80

	# Play, centred horizontally under the title.
	var play_btn := _button("Gioca")
	play_btn.pressed.connect(_on_play_pressed)
	panel.add_child(play_btn)
	play_btn.set_anchors_preset(Control.PRESET_CENTER_TOP)
	play_btn.offset_left = -BUTTON_SIZE.x * 0.5
	play_btn.offset_right = BUTTON_SIZE.x * 0.5
	play_btn.offset_top = PLAY_TOP
	play_btn.offset_bottom = PLAY_TOP + BUTTON_SIZE.y

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
	return btn


func _on_play_pressed() -> void:
	close()
	play_pressed.emit()


func _on_credits_pressed() -> void:
	_menu_panel.visible = false
	_credits_panel.visible = true


func _on_back_pressed() -> void:
	_credits_panel.visible = false
	_menu_panel.visible = true


func _on_exit_pressed() -> void:
	exit_pressed.emit()


## The run is paused behind the menu, so swallow the pause key: otherwise
## Space/Esc would unpause the game underneath the still-visible menu.
func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed(InputActions.PAUSE):
		get_viewport().set_input_as_handled()


## Show the menu and pause the game behind it. Called when the run starts.
func open() -> void:
	visible = true
	_credits_panel.visible = false
	_menu_panel.visible = true
	get_tree().paused = true


## Hide the menu and resume the game.
func close() -> void:
	visible = false
	get_tree().paused = false
