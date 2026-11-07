class_name SettingsPanel
extends Control
## Music/effects group volume panel, reused by the title screen and the pause
## menu. Values are user preferences (core/user_settings.gd), separate from the
## designer mix in data/audio_settings.tres. Works while the tree is paused.

signal closed
## The Back button was pressed (used by the audio system for its click).
signal button_pressed

const LABEL_WIDTH := 90.0
const SLIDER_WIDTH := 260.0
const VALUE_WIDTH := 56.0

var _music_slider: HSlider
var _effects_slider: HSlider
var _music_value: Label
var _effects_value: Label
## Slider values last loaded or written, so close() only writes real changes
## (user:// is IndexedDB on web).
var _saved_music := -1.0
var _saved_effects := -1.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	# The whole panel is one sea card, like the HUD inventory cards.
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", SeaStyle.panel_box())
	center.add_child(card)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", SeaStyle.MENU_SEPARATION)
	card.add_child(box)

	var title := Label.new()
	title.text = "Impostazioni"
	SeaStyle.style_title(title)
	box.add_child(title)
	box.add_child(SeaStyle.divider())

	_music_slider = _add_volume_row(box, "Musica")
	_effects_slider = _add_volume_row(box, "Effetti")

	var back := SeaStyle.menu_button("Indietro")
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	back.pressed.connect(_on_back_pressed)
	box.add_child(back)

	_reload()


func _add_volume_row(parent: VBoxContainer, text: String) -> HSlider:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	parent.add_child(row)

	var label := Label.new()
	label.text = text
	label.custom_minimum_size.x = LABEL_WIDTH
	label.add_theme_font_size_override("font_size", SeaStyle.BODY_FONT_SIZE)
	label.add_theme_color_override("font_color", SeaStyle.CAPTION_COLOR)
	row.add_child(label)

	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 100.0
	slider.step = 1.0
	slider.custom_minimum_size.x = SLIDER_WIDTH
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	SeaStyle.style_slider(slider)
	slider.value_changed.connect(_on_slider_changed)
	slider.drag_ended.connect(func(_changed: bool) -> void: _save())
	row.add_child(slider)

	var value := Label.new()
	value.custom_minimum_size.x = VALUE_WIDTH
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value.add_theme_font_size_override("font_size", SeaStyle.BODY_FONT_SIZE)
	value.add_theme_color_override("font_color", SeaStyle.SAND_COLOR)
	row.add_child(value)

	if _music_value == null:
		_music_value = value
	else:
		_effects_value = value
	return slider


## Shows the panel with the saved levels, applying them to the buses.
func open() -> void:
	_reload()
	visible = true


func close() -> void:
	_save()
	visible = false


## Loads user levels into the sliders and applies them.
func _reload() -> void:
	if _music_slider == null or _effects_slider == null:
		return
	_music_slider.set_value_no_signal(UserSettings.percent_from_db(UserSettings.music_db()))
	_effects_slider.set_value_no_signal(UserSettings.percent_from_db(UserSettings.effects_db()))
	_saved_music = _music_slider.value
	_saved_effects = _effects_slider.value
	_update_labels()
	_apply()


func _on_slider_changed(_value: float) -> void:
	_update_labels()
	_apply()


func _update_labels() -> void:
	_music_value.text = "%d%%" % roundi(_music_slider.value)
	_effects_value.text = "%d%%" % roundi(_effects_slider.value)


func _apply() -> void:
	# Make sure both group buses exist before setting their levels.
	Game.AUDIO_SETTINGS.music_bus()
	AudioSettings.effects_bus()
	UserSettings.apply(
		UserSettings.db_from_percent(_music_slider.value),
		UserSettings.db_from_percent(_effects_slider.value))


func _save() -> void:
	if _music_slider == null or _effects_slider == null:
		return
	if _music_slider.value == _saved_music and _effects_slider.value == _saved_effects:
		return
	_saved_music = _music_slider.value
	_saved_effects = _effects_slider.value
	UserSettings.save(
		UserSettings.db_from_percent(_music_slider.value),
		UserSettings.db_from_percent(_effects_slider.value))


func _on_back_pressed() -> void:
	button_pressed.emit()
	close()
	closed.emit()


## Right click must be caught in _input: the full-rect panel consumes pointer
## events in the GUI before _unhandled_input can see them.
func _input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	if event is InputEventMouseButton and event.is_action_pressed(InputActions.CANCEL):
		var viewport := get_viewport()
		if viewport != null:
			viewport.set_input_as_handled()
		_on_back_pressed()


## Esc closes the panel instead of reaching the pause handler.
func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed(InputActions.CANCEL):
		get_viewport().set_input_as_handled()
		_on_back_pressed()
