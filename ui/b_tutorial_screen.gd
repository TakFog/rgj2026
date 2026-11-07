class_name TutorialScreen
extends ColorRect
## Full-screen tutorial between the menu and the run. Three hand-animated
## vignettes use the game's own art and oblique view. The run stays paused
## behind it; only the front end starts the run when the player leaves.
## Works while the tree is paused.

signal run_started
signal closed
## A tutorial button was pressed (used by the audio system).
signal button_pressed

enum Mode { START, REVIEW }
enum InputAction { NONE, NEXT, PRIMARY }

const SECONDS_PER_STEP := 6.0
const BUTTON_SIZE := Vector2(180.0, 60.0)
## Content width of the card; TutorialStage fills it edge to edge.
const CONTENT_WIDTH := 900.0

var _mode := Mode.START
var _sequence: TutorialSequence
var _stage: TutorialStage
var _caption: Label
var _dots: Array[Panel] = []
var _skip: Button
var _primary: Button
var _elapsed := 0.0


static func primary_label(mode: Mode) -> String:
	return "Inizia" if mode == Mode.START else "Indietro"


static func skip_visible(mode: Mode) -> bool:
	return mode == Mode.START


static func starts_run(mode: Mode) -> bool:
	return mode == Mode.START


## Esc is both CANCEL and PAUSE: cancel wins, so Esc goes back/skips and Space
## (pause only) advances the vignette.
static func action_for(is_cancel: bool, is_pause: bool) -> InputAction:
	if is_cancel:
		return InputAction.PRIMARY
	if is_pause:
		return InputAction.NEXT
	return InputAction.NONE


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	color = Color(0.02, 0.05, 0.1, 0.94)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_sequence = TutorialSequence.new()

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", SeaStyle.panel_box())
	center.add_child(card)

	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(CONTENT_WIDTH, 0.0)
	box.add_theme_constant_override("separation", 18)
	card.add_child(box)

	var title := Label.new()
	title.text = "COME FUNZIONA IL REEF"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 34)
	title.add_theme_color_override("font_color", SeaStyle.SAND_COLOR)
	box.add_child(title)

	var divider := ColorRect.new()
	divider.color = Color(SeaStyle.RIM_COLOR, 0.35)
	divider.custom_minimum_size = Vector2(0, 2)
	divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(divider)

	_stage = TutorialStage.new(Game.VIEW_SETTINGS.x_axis, Game.VIEW_SETTINGS.y_axis)
	box.add_child(_stage)

	_caption = Label.new()
	_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_caption.add_theme_font_size_override("font_size", 22)
	_caption.add_theme_color_override("font_color", SeaStyle.CAPTION_COLOR)
	_caption.custom_minimum_size = Vector2(0, 56)
	_caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(_caption)

	box.add_child(_build_dots())

	var actions := HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	actions.add_theme_constant_override("separation", 16)
	box.add_child(actions)

	_skip = _button("Salta")
	_skip.pressed.connect(_on_skip_pressed)
	actions.add_child(_skip)

	_primary = _button("Inizia")
	SeaStyle.style_highlighted_button(_primary)
	_primary.pressed.connect(_on_primary_pressed)
	actions.add_child(_primary)


## Shows the tutorial in START (after Play) or REVIEW (from the menu).
func open(mode: Mode) -> void:
	_mode = mode
	_sequence.reset()
	_elapsed = 0.0
	visible = true
	_skip.visible = skip_visible(mode)
	_primary.text = primary_label(mode)
	_show_current()


func close() -> void:
	visible = false
	_stage.stop()


func _process(delta: float) -> void:
	if not visible:
		return
	_elapsed += delta
	if _elapsed >= SECONDS_PER_STEP:
		_next_step()


func _next_step() -> void:
	_sequence.advance()
	_elapsed = 0.0
	_show_current()


func _show_current() -> void:
	_stage.show_step(_sequence.index)
	_caption.text = _sequence.caption()
	for i in _dots.size():
		_dots[i].add_theme_stylebox_override("panel", _dot_style(i == _sequence.index))


func _on_primary_pressed() -> void:
	button_pressed.emit()
	if starts_run(_mode):
		run_started.emit()
	else:
		closed.emit()


func _on_skip_pressed() -> void:
	button_pressed.emit()
	if starts_run(_mode):
		run_started.emit()


## Mouse cancel must be caught in _input: the full-screen card consumes pointer
## events in the GUI before _unhandled_input can see them.
func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventMouseButton and event.is_action_pressed(InputActions.CANCEL):
		var viewport := get_viewport()
		if viewport != null:
			viewport.set_input_as_handled()
		_on_primary_pressed()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	match action_for(event.is_action_pressed(InputActions.CANCEL), event.is_action_pressed(InputActions.PAUSE)):
		InputAction.PRIMARY:
			get_viewport().set_input_as_handled()
			_on_primary_pressed()
		InputAction.NEXT:
			get_viewport().set_input_as_handled()
			_next_step()


func _build_dots() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 10)
	for i in _sequence.count():
		var dot := Panel.new()
		dot.custom_minimum_size = Vector2(10, 10)
		dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_dots.append(dot)
		row.add_child(dot)
	return row


func _dot_style(active: bool) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = SeaStyle.SAND_COLOR if active else Color(SeaStyle.RIM_COLOR, 0.35)
	box.set_corner_radius_all(5)
	box.anti_aliasing = true
	return box


func _button(text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = BUTTON_SIZE
	button.add_theme_font_size_override("font_size", 24)
	SeaStyle.style_button(button)
	return button
