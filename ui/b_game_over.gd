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

	var restart := SeaStyle.menu_button("Ricomincia")
	restart.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	SeaStyle.style_highlighted_button(restart)
	restart.pressed.connect(_on_restart_pressed)
	box.add_child(restart)
	_restart = restart


func show_result(population: StringName, score_seconds: float, counts: Dictionary = {}) -> void:
	_cause.text = cause_text(population)
	_time.text = Hud.format_time(score_seconds)
	var is_record := UserSettings.submit_best(score_seconds)
	var best := UserSettings.best_seconds()
	_record.text = "Nuovo record!" if is_record else "Record: %s" % Hud.format_time(best)
	_record.add_theme_color_override("font_color",
			SeaStyle.SAND_COLOR if is_record else SeaStyle.CAPTION_COLOR)
	_counts.text = format_counts(counts)
	_counts.visible = not _counts.text.is_empty()
	visible = true
	# Keyboard/gamepad players can restart without the mouse.
	_restart.grab_focus.call_deferred()


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
