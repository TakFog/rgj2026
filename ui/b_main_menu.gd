class_name MainMenuScreen
extends ColorRect
## Main menu overlay shown at game start (GDD §9, roadmap: title screen).
## The whole screen is the artist's painted menu; its five painted buttons are
## invisible hotspots (MenuHotspots), so the art is the interface. Works while
## the tree is paused; clicking Gioca unpauses and hides the menu.

## The painted menu: the master is `video/MENU.png`, this is the web-sized copy.
const MENU_TEXTURE: Texture2D = preload("res://assets/ui/menu.png")
## How much the hover/focus glow brightens a painted button.
const GLOW_ALPHA := 0.22
## How much further it brightens while the button is held down.
const GLOW_ALPHA_PRESSED := 0.4

## Player-facing name and credits, kept in one place so the credits panel and
## the rest of the UI cannot drift apart.
const GAME_TITLE := "BalanSea"
const CREDITS_TEXT := "Un gestionale di barriera corallina.\nSviluppato durante la Rome Game Jam 2026 a tema SUBIRE.\n\nFlavio De Benedictis — Developer\nLorenzo Patané — Developer\nMaria Elena Papale — Artist\nMateusz Kulesza — Music, Developer"
## User command-line argument (after `--`) that skips the title screen and
## starts a run straight away, so tools/smoke.sh exercises real gameplay.
const SMOKE_PLAY_ARG := "--smoke-play"

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
var _play_button: Button
## The painting, fitted and centred on screen; its hotspots are its children.
var _art_box: Control
## Hotspot key (see MenuHotspots.RECTS) -> its invisible Button.
var _hotspots: Dictionary = {}
## Shared additive material that makes the glow brighten the painted shape.
var _glow_material: CanvasItemMaterial


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	color = SeaStyle.OVERLAY_COLOR
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
	_settings_panel.flat_buttons = true
	_settings_panel.visible = false
	_settings_panel.closed.connect(_on_settings_closed)
	_settings_panel.button_pressed.connect(func() -> void: button_pressed.emit())
	add_child(_settings_panel)

	# Auto-open when the menu enters the tree (game start). Calling open()
	# from DevBSystems would race: Game.ui is not in the tree yet when
	# DevBSystems._ready runs, so _ready here hasn't fired yet.
	if _skip_next_open or OS.get_cmdline_user_args().has(SMOKE_PLAY_ARG):
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
	# The painting is refitted whenever the window changes size.
	panel.resized.connect(_layout_art)

	_art_box = Control.new()
	_art_box.name = "ArtBox"
	_art_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(_art_box)

	var art := TextureRect.new()
	art.name = "Art"
	art.texture = MENU_TEXTURE
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_SCALE
	art.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_art_box.add_child(art)
	art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_glow_material = CanvasItemMaterial.new()
	_glow_material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD

	# One invisible hotspot per painted button, in MenuHotspots focus order.
	var handlers := {
		"play": _on_play_pressed,
		"tutorial": _on_tutorial_pressed,
		"settings": _on_settings_pressed,
		"credits": _on_credits_pressed,
		"exit": _on_exit_pressed,
	}
	for key: String in MenuHotspots.RECTS:
		var button := _build_hotspot(key, handlers[key])
		_hotspots[key] = button
		_art_box.add_child(button)
	_play_button = _hotspots["play"]

	_layout_art()
	return panel


## An invisible button sitting exactly on one painted button. Hover and focus
## brighten the painted shape by re-drawing its region of the art additively:
## the art's transparent background stays transparent, so only the pill lights
## up.
func _build_hotspot(key: String, handler: Callable) -> Button:
	var button := Button.new()
	button.name = "Hotspot_" + key
	button.focus_mode = Control.FOCUS_ALL
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	for item in ["normal", "hover", "pressed", "focus", "disabled"]:
		button.add_theme_stylebox_override(item, StyleBoxEmpty.new())
	button.pressed.connect(handler)

	var glow := TextureRect.new()
	var region := AtlasTexture.new()
	region.atlas = MENU_TEXTURE
	region.region = MenuHotspots.hotspot_region(key)
	glow.texture = region
	glow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	glow.stretch_mode = TextureRect.STRETCH_SCALE
	glow.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	glow.material = _glow_material
	glow.modulate = Color(1, 1, 1, GLOW_ALPHA)
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	glow.visible = false
	button.add_child(glow)
	glow.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	button.mouse_entered.connect(func() -> void: glow.visible = true)
	button.mouse_exited.connect(func() -> void: glow.visible = false)
	button.focus_entered.connect(func() -> void: glow.visible = true)
	button.focus_exited.connect(func() -> void: glow.visible = false)
	button.button_down.connect(
		func() -> void: glow.modulate = Color(1, 1, 1, GLOW_ALPHA_PRESSED))
	button.button_up.connect(
		func() -> void: glow.modulate = Color(1, 1, 1, GLOW_ALPHA))
	return button


## Fit the painting (and therefore its hotspots) into the window, centred.
func _layout_art() -> void:
	var art := MenuHotspots.art_box(size)
	_art_box.position = art.position
	_art_box.size = art.size
	for key: String in _hotspots:
		var rect := MenuHotspots.hotspot_rect(size, key)
		var button: Button = _hotspots[key]
		button.position = rect.position - art.position
		button.size = rect.size


func _build_credits_panel() -> Control:
	var panel := Control.new()
	panel.name = "CreditsPanel"
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.add_child(center)

	# Credits use the same sea card as pause, settings and game over.
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", SeaStyle.panel_box())
	center.add_child(card)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", SeaStyle.MENU_SEPARATION)
	card.add_child(box)

	var title := Label.new()
	title.text = GAME_TITLE
	SeaStyle.style_title(title)
	box.add_child(title)
	box.add_child(SeaStyle.divider())

	var credits := Label.new()
	credits.text = CREDITS_TEXT
	SeaStyle.style_body(credits)
	box.add_child(credits)

	var back_btn := _button("Indietro")
	back_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	back_btn.pressed.connect(_on_back_pressed)
	box.add_child(back_btn)

	return panel


func _button(text: String) -> Button:
	return SeaStyle.menu_button(text, true)


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
	_play_button.grab_focus.call_deferred()


func _on_credits_pressed() -> void:
	button_pressed.emit()
	_menu_panel.visible = false
	_credits_panel.visible = true


func _on_back_pressed() -> void:
	button_pressed.emit()
	_credits_panel.visible = false
	_menu_panel.visible = true
	_play_button.grab_focus.call_deferred()


func _on_exit_pressed() -> void:
	button_pressed.emit()
	exit_pressed.emit()


## The run is paused behind the menu, so swallow the pause key: otherwise
## Space/Esc would unpause the game underneath the still-visible menu.
## On the credits screen, Esc goes back to the menu.
func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	var cancel := event.is_action_pressed(InputActions.CANCEL)
	if cancel or event.is_action_pressed(InputActions.PAUSE):
		get_viewport().set_input_as_handled()
		if cancel and _credits_panel.visible:
			_on_back_pressed()


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
	# Keyboard/gamepad players can start without the mouse.
	_play_button.grab_focus.call_deferred()


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
