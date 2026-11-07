class_name GameOverScreen
extends ColorRect
## Full-screen game-over overlay: which population collapsed, survival time and
## a Restart button (GDD §3, roadmap contract #11). Works while the tree is paused.

## Used by the audio system (systems/b_audio.gd).
signal restart_pressed

var _title: Label
var _score: Label


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	color = Color(0.02, 0.05, 0.1, 0.85)
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false
	var center := CenterContainer.new()
	add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 16)
	center.add_child(box)
	_title = _add_label(box, 40)
	_score = _add_label(box, 28)
	var restart := Button.new()
	restart.text = "Ricomincia"
	restart.add_theme_font_size_override("font_size", 28)
	restart.pressed.connect(_on_restart_pressed)
	box.add_child(restart)


func show_result(population: StringName, score_seconds: float) -> void:
	_title.text = "Ecosistema collassato: %s a zero" % Hud.display_name(population)
	_score.text = "Sei sopravvissuto %s" % Hud.format_time(score_seconds)
	visible = true


func _add_label(parent: Control, font_size: int) -> Label:
	var label := Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	parent.add_child(label)
	return label


func _on_restart_pressed() -> void:
	restart_pressed.emit()
	get_tree().paused = false
	get_tree().reload_current_scene()
