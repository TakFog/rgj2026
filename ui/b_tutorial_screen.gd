class_name TutorialScreen
extends ColorRect
## Full-screen tutorial between the menu and the run. The left pane animates
## the three core reactions with the game's own art and oblique view; the right
## pane lists every GDD §8 interaction. The run stays paused behind it; only the
## front end starts the run when the player leaves. Works while the tree is paused.

signal run_started
signal closed
## A tutorial button was pressed (used by the audio system).
signal button_pressed

enum Mode { START, REVIEW }
enum InputAction { NONE, NEXT, PRIMARY }

const SECONDS_PER_STEP := 6.0
const SCREEN_MARGIN := 24.0
const RIGHT_COLUMN_MIN_WIDTH := 340.0
const CAPTION_FONT_SIZE := 24

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
	color = SeaStyle.OVERLAY_COLOR
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_sequence = TutorialSequence.new()

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_%s" % side, int(SCREEN_MARGIN))
	add_child(margin)

	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", SeaStyle.panel_box())
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_child(card)

	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", SeaStyle.MENU_SEPARATION)
	card.add_child(box)

	var title := Label.new()
	title.text = "COME SI GIOCA"
	SeaStyle.style_title(title)
	box.add_child(title)
	box.add_child(SeaStyle.divider())

	var intro := Label.new()
	intro.text = "Il reef reagisce da solo: ogni contatto ha un effetto."
	intro.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	intro.add_theme_font_size_override("font_size", 20)
	intro.add_theme_color_override("font_color", SeaStyle.CAPTION_COLOR)
	box.add_child(intro)

	var content := HBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 24)
	box.add_child(content)

	# Left: the three animated core-loop vignettes.
	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left.size_flags_stretch_ratio = 1.6
	left.add_theme_constant_override("separation", 8)
	content.add_child(left)

	_stage = TutorialStage.new(Game.VIEW_SETTINGS.x_axis, Game.VIEW_SETTINGS.y_axis)
	_stage.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_stage.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left.add_child(_stage)

	_caption = Label.new()
	_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_caption.add_theme_font_size_override("font_size", CAPTION_FONT_SIZE)
	_caption.add_theme_color_override("font_color", SeaStyle.CAPTION_COLOR)
	_caption.custom_minimum_size = Vector2(0, 46)
	_caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_child(_caption)
	left.add_child(_build_dots())

	# Right: the complete GDD §8 interaction reference.
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.custom_minimum_size.x = RIGHT_COLUMN_MIN_WIDTH
	right.add_theme_constant_override("separation", 8)
	content.add_child(right)

	var list_title := Label.new()
	list_title.text = "TUTTE LE INTERAZIONI"
	list_title.add_theme_font_size_override("font_size", 24)
	list_title.add_theme_color_override("font_color", SeaStyle.SAND_COLOR)
	right.add_child(list_title)

	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	right.add_child(scroll)

	var rows := VBoxContainer.new()
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rows.add_theme_constant_override("separation", 6)
	rows.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scroll.add_child(rows)
	for data in TutorialInteractions.ROWS:
		rows.add_child(_interaction_row(data))

	var actions := HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	actions.add_theme_constant_override("separation", 16)
	box.add_child(actions)

	_skip = SeaStyle.menu_button("Salta")
	_skip.pressed.connect(_on_skip_pressed)
	actions.add_child(_skip)

	_primary = SeaStyle.menu_button("Inizia")
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


## One interaction row: coloured agent name, arrow, target and effect.
func _interaction_row(data: Dictionary) -> Control:
	var panel := PanelContainer.new()
	var style := SeaStyle.card_box(0.15, 1)
	style.shadow_size = 0
	style.content_margin_left = 10.0
	style.content_margin_right = 10.0
	style.content_margin_top = 7.0
	style.content_margin_bottom = 7.0
	panel.add_theme_stylebox_override("panel", style)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(row)

	var accent := ColorRect.new()
	accent.color = data.get("color", SeaStyle.RIM_COLOR)
	accent.custom_minimum_size = Vector2(4, 0)
	accent.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(accent)

	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.add_theme_constant_override("separation", 2)
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(text)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 6)
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text.add_child(header)

	var agent := Label.new()
	agent.text = data["agent"]
	agent.add_theme_font_size_override("font_size", 19)
	agent.add_theme_color_override("font_color", SeaStyle.SAND_COLOR)
	agent.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_child(agent)

	var arrow := Label.new()
	arrow.text = "→"
	arrow.add_theme_font_size_override("font_size", 19)
	arrow.add_theme_color_override("font_color", SeaStyle.CAPTION_COLOR)
	arrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_child(arrow)

	var target := Label.new()
	target.text = data["target"]
	target.add_theme_font_size_override("font_size", 19)
	target.add_theme_color_override("font_color", SeaStyle.CAPTION_COLOR)
	target.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_child(target)

	var effect := Label.new()
	effect.text = data["effect"]
	effect.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	effect.add_theme_font_size_override("font_size", 17)
	effect.add_theme_color_override("font_color", SeaStyle.CAPTION_COLOR)
	effect.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	effect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text.add_child(effect)
	return panel


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
