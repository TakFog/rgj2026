class_name MainMenuScreen
extends ColorRect
## Main menu overlay shown at game start (GDD §9, roadmap: title screen).
## Title top centre ("BalanSea"), Play under it, Credits bottom right,
## Exit bottom left (Exit hidden in web builds). Works while the tree is
## paused; clicking Play unpauses the game and hides the menu.

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

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	_menu_panel = _build_menu_panel()
	center.add_child(_menu_panel)
	_credits_panel = _build_credits_panel()
	_credits_panel.visible = false
	center.add_child(_credits_panel)

	# Auto-open when the menu enters the tree (game start). Calling open()
	# from DevBSystems would race: Game.ui is not in the tree yet when
	# DevBSystems._ready runs, so _ready here hasn't fired yet.
	open()


func _build_menu_panel() -> Control:
	var panel := Control.new()
	panel.name = "MenuPanel"
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	# Title top centre.
	var title := Label.new()
	title.text = "BalanSea"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 48)
	title.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	title.offset_top = 70
	panel.add_child(title)

	# Play button under the title, centred.
	var play := CenterContainer.new()
	play.name = "PlayColumn"
	play.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	play.offset_top = 150
	var play_btn := _button("Gioca")
	play_btn.pressed.connect(_on_play_pressed)
	play.add_child(play_btn)
	panel.add_child(play)

	# Bottom bar: Exit bottom left, Credits bottom right.
	var bottom := Control.new()
	bottom.name = "BottomBar"
	bottom.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	bottom.offset_bottom = 60
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 24)
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bottom.add_child(row)

	var exit_btn := _button("Esci")
	exit_btn.pressed.connect(_on_exit_pressed)
	# Web builds cannot quit the host page, so the exit button is hidden there.
	if OS.has_feature("web"):
		exit_btn.visible = false
	row.add_child(exit_btn)

	var spacer := Control.new()
	spacer.set_h_size_flags(Control.SIZE_EXPAND)
	row.add_child(spacer)

	var credits_btn := _button("Crediti")
	credits_btn.pressed.connect(_on_credits_pressed)
	row.add_child(credits_btn)

	panel.add_child(bottom)
	return panel


func _build_credits_panel() -> Control:
	var panel := VBoxContainer.new()
	panel.name = "CreditsPanel"
	panel.add_theme_constant_override("separation", 16)
	panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	panel.offset_top = 70

	var credits := Label.new()
	credits.text = "BalanSea\n\nUn gestionale di barriera corallina.\nTema del game jam: SUBIRE.\n\nRealizzato con Godot 4.7.2."
	credits.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	credits.add_theme_font_size_override("font_size", 24)
	panel.add_child(credits)

	var back := CenterContainer.new()
	var back_btn := _button("Indietro")
	back_btn.pressed.connect(_on_back_pressed)
	back.add_child(back_btn)
	panel.add_child(back)

	return panel


func _button(text: String) -> Button:
	var btn := Button.new()
	btn.text = text
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
