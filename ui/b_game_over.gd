class_name GameOverScreen
extends ColorRect
## Full-screen game-over overlay (GDD §3, roadmap contract #11): one sea card,
## matching the pause menu, with the title, the survival time and a Restart
## button. Works while the tree is paused.

const CAPTION := "Tempo di sopravvivenza"
const TITLE := "L'equilibrio si è interrotto"
const CRITICAL_COLOR := Color(0.96, 0.52, 0.47)
## Order used for the final population summary.
const COUNT_ORDER: Array[StringName] = [&"corals", &"algae", &"fish", &"nests"]
## Why the reef collapsed, keyed by the population that hit zero.
const CAUSES := {
	&"corals": "I coralli si sono sgretolati.",
	&"algae": "Le alghe si sono estinte.",
	&"fish": "I pesci sono morti di fame.",
	&"nests": "Non è rimasto nessun nido.",
}

## Used by the audio system (systems/b_audio.gd).
signal restart_pressed
signal menu_pressed

var _level: Label
var _time: Label
var _cause: Label
var _record: Label
var _counts: Label
var _restart: Button


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

	_add_label(box, TITLE, SeaStyle.TITLE_FONT_SIZE, SeaStyle.SAND_COLOR)
	box.add_child(SeaStyle.divider())

	_level = _add_label(box, "", SeaStyle.BODY_FONT_SIZE, SeaStyle.CAPTION_COLOR)
	_level.visible = false
	_cause = _add_label(box, "", SeaStyle.BODY_FONT_SIZE, CRITICAL_COLOR)

	# Caption and time sit tight together, as one block.
	var score := VBoxContainer.new()
	score.add_theme_constant_override("separation", 0)
	box.add_child(score)
	_add_label(score, CAPTION, SeaStyle.BODY_FONT_SIZE, SeaStyle.CAPTION_COLOR)
	_time = _add_label(score, Hud.format_time(0.0), SeaStyle.HERO_TITLE_FONT_SIZE, Color.WHITE)
	_record = _add_label(score, "", 18, SeaStyle.CAPTION_COLOR)

	_counts = _add_label(box, "", 16, Color(SeaStyle.CAPTION_COLOR, 0.8))
	_counts.visible = false

	var restart := SeaStyle.menu_button("Riprova livello")
	restart.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	SeaStyle.style_highlighted_button(restart)
	restart.pressed.connect(_on_restart_pressed)
	box.add_child(restart)
	_restart = restart

	var menu := SeaStyle.menu_button("Torna al menu")
	menu.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	menu.pressed.connect(_on_menu_pressed)
	box.add_child(menu)


## `level_index` >= 0 turns on the level label and the per-level record.
func show_result(population: StringName, score_seconds: float, counts: Dictionary = {},
		level_index := -1, level_name := "") -> void:
	_cause.text = cause_text(population)
	_time.text = Hud.format_time(score_seconds)
	if level_index >= 0:
		_level.text = "Livello %d/%d — %s" % [
			level_index + 1, LevelCatalog.COUNT, level_name]
		_level.visible = true
		_record.text = _record_text(
			UserSettings.submit_level_best(level_index, score_seconds),
			UserSettings.level_best_seconds(level_index))
	else:
		_level.visible = false
		_record.text = _record_text(
			UserSettings.submit_best(score_seconds), UserSettings.best_seconds())
	_counts.text = format_counts(counts)
	_counts.visible = not _counts.text.is_empty()
	visible = true
	# Keyboard/gamepad players can restart without the mouse.
	_restart.grab_focus.call_deferred()


## Record line shared by the global and the per-level record.
func _record_text(is_record: bool, best: float) -> String:
	_record.add_theme_color_override("font_color",
			SeaStyle.SAND_COLOR if is_record else SeaStyle.CAPTION_COLOR)
	return "Nuovo record!" if is_record else "Record: %s" % Hud.format_time(best)


## Player-facing reason for a collapse, keyed by the population at zero.
static func cause_text(population: StringName) -> String:
	return CAUSES.get(population, "La barriera si è fermata.")


## One-line final population summary, in COUNT_ORDER.
static func format_counts(counts: Dictionary) -> String:
	var text := ""
	for population in COUNT_ORDER:
		if not counts.has(population):
			continue
		if not text.is_empty():
			text += "  ·  "
		text += "%s %d" % [Hud.display_name(population), counts[population]]
	return text


func _add_label(parent: Control, text: String, font_size: int, font_color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", font_color)
	parent.add_child(label)
	return label


func _on_restart_pressed() -> void:
	restart_pressed.emit()
	MainMenuScreen.restart_run(get_tree())


func _on_menu_pressed() -> void:
	menu_pressed.emit()
	MainMenuScreen.restart_to_menu(get_tree())


## Esc/Space retry the level, like the primary button (the pause controller
## ignores keys after game over, so nothing else would handle them).
func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed(InputActions.CANCEL) or event.is_action_pressed(InputActions.PAUSE):
		get_viewport().set_input_as_handled()
		_on_restart_pressed()
