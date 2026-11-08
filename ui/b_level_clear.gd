class_name LevelClearScreen
extends ColorRect
## Card shown when a level's timer runs out with the reef alive (GDD §3).
## Announces the clear, offers the next level (or the end of the campaign) and
## keeps the tree paused while it is visible. Works while paused.

signal next_requested
signal restart_requested
signal menu_requested
## Any button pressed (used by the audio system).
signal button_pressed

const TITLE_CLEAR := "Livello completato"
const TITLE_CAMPAIGN := "Campagna completata"

var _title: Label
var _level: Label
var _time: Label
var _counts: Label
var _primary: Button
var _menu: Button
var _is_last := false


## Title for a clear. Static so the wording is unit-testable.
static func title_for(is_last: bool) -> String:
	return TITLE_CAMPAIGN if is_last else TITLE_CLEAR


## Main action label: the campaign's last clear returns to the menu.
static func primary_label(is_last: bool) -> String:
	return "Torna al menu" if is_last else "Prossimo livello"


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	color = SeaStyle.OVERLAY_COLOR
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", SeaStyle.panel_box())
	center.add_child(card)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", SeaStyle.MENU_SEPARATION)
	card.add_child(box)

	_title = _add_label(box, "", SeaStyle.TITLE_FONT_SIZE, SeaStyle.SAND_COLOR)
	box.add_child(SeaStyle.divider())
	_level = _add_label(box, "", SeaStyle.BODY_FONT_SIZE, SeaStyle.CAPTION_COLOR)
	_time = _add_label(box, "", SeaStyle.BODY_FONT_SIZE, Color.WHITE)
	_counts = _add_label(box, "", 16, Color(SeaStyle.CAPTION_COLOR, 0.8))

	_primary = SeaStyle.menu_button("")
	_primary.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	SeaStyle.style_highlighted_button(_primary)
	_primary.pressed.connect(_on_primary_pressed)
	box.add_child(_primary)

	var restart := SeaStyle.menu_button("Ricomincia livello")
	restart.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	restart.pressed.connect(_on_restart_pressed)
	box.add_child(restart)

	_menu = SeaStyle.menu_button("Torna al menu")
	_menu.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_menu.pressed.connect(_on_menu_pressed)
	box.add_child(_menu)


## Fills the card for the cleared level and shows it.
func show_result(index: int, level: LevelDefinition, counts: Dictionary, survived_seconds: float) -> void:
	_is_last = index >= LevelCatalog.COUNT - 1
	_title.text = title_for(_is_last)
	_level.text = "Livello %d/%d — %s" % [index + 1, LevelCatalog.COUNT, level.level_name]
	_time.text = "Hai resistito %s su %s" % [
		Hud.format_time(survived_seconds), Hud.format_time(level.duration_seconds)]
	_counts.text = GameOverScreen.format_counts(counts)
	_counts.visible = not _counts.text.is_empty()
	_primary.text = primary_label(_is_last)
	_menu.visible = not _is_last
	visible = true
	_primary.grab_focus.call_deferred()


func _add_label(parent: Control, text: String, font_size: int, font_color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", font_color)
	parent.add_child(label)
	return label


func _on_primary_pressed() -> void:
	button_pressed.emit()
	if _is_last:
		menu_requested.emit()
	else:
		next_requested.emit()


func _on_restart_pressed() -> void:
	button_pressed.emit()
	restart_requested.emit()


func _on_menu_pressed() -> void:
	button_pressed.emit()
	menu_requested.emit()


## The run is over and the pause controller ignores keys, so Esc is a shortcut
## back to the menu instead of leaving the player stuck.
func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed(InputActions.CANCEL) or event.is_action_pressed(InputActions.PAUSE):
		get_viewport().set_input_as_handled()
		_on_menu_pressed()
