class_name GameOverScreen
extends ColorRect
## Full-screen game-over overlay (GDD §3, roadmap contract #11): one sea card,
## matching the pause menu, with the title, the survival time and a Restart
## button. Works while the tree is paused.

const CAPTION := "Tempo di sopravvivenza"
const TITLE := "L'equilibrio si è interrotto"

## Used by the audio system (systems/b_audio.gd).
signal restart_pressed

var _time: Label


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	color = Color(0.02, 0.05, 0.1, 0.85)
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
	box.add_theme_constant_override("separation", 16)
	card.add_child(box)

	_add_label(box, TITLE, 40, SeaStyle.SAND_COLOR)

	var divider := ColorRect.new()
	divider.color = Color(SeaStyle.RIM_COLOR, 0.35)
	divider.custom_minimum_size = Vector2(0, 2)
	divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(divider)

	# Caption and time sit tight together, as one block.
	var score := VBoxContainer.new()
	score.add_theme_constant_override("separation", 0)
	box.add_child(score)
	_add_label(score, CAPTION, 24, SeaStyle.CAPTION_COLOR)
	_time = _add_label(score, Hud.format_time(0.0), 48, Color.WHITE)

	var restart := Button.new()
	restart.text = "Ricomincia"
	restart.custom_minimum_size = Vector2(220, 60)
	restart.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	restart.add_theme_font_size_override("font_size", 24)
	SeaStyle.style_highlighted_button(restart)
	restart.pressed.connect(_on_restart_pressed)
	box.add_child(restart)


func show_result(_population: StringName, score_seconds: float) -> void:
	_time.text = Hud.format_time(score_seconds)
	visible = true


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
