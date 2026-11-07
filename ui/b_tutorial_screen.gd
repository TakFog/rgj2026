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

## Replay the selected interaction after this many seconds.
const LOOP_SECONDS := 5.8
const SCREEN_MARGIN := 24.0
const RIGHT_COLUMN_MIN_WIDTH := 340.0
const CAPTION_FONT_SIZE := 24

var _mode := Mode.START
var _stage: TutorialStage
var _caption: Label
var _skip: Button
var _primary: Button
var _elapsed := 0.0
var _selected_index := 0
var _chips: Array[Button] = []
var _chip_rows: Array[int] = []


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
	title.text = "Come si gioca"
	SeaStyle.style_title(title)
	box.add_child(title)
	box.add_child(SeaStyle.divider())

	var intro := Label.new()
	intro.text = "Scegli un'interazione per vederla."
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

	# Right: the complete GDD §8 interaction reference.
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.custom_minimum_size.x = RIGHT_COLUMN_MIN_WIDTH
	right.add_theme_constant_override("separation", 8)
	content.add_child(right)

	var list_title := Label.new()
	list_title.text = "Interazioni"
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
	for group in _grouped_rows():
		rows.add_child(_build_group(group))

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
	_elapsed = 0.0
	visible = true
	_skip.visible = skip_visible(mode)
	_primary.text = primary_label(mode)
	_select_interaction(0)


func close() -> void:
	visible = false
	_stage.stop()


func _process(delta: float) -> void:
	if not visible:
		return
	_elapsed += delta
	if _elapsed >= LOOP_SECONDS:
		_elapsed = 0.0
		_stage.show_interaction(TutorialInteractions.ROWS[_selected_index])


## Selects one interaction: rebuilds the stage and refreshes the chip highlight.
func _select_interaction(index: int) -> void:
	if index < 0 or index >= TutorialInteractions.ROWS.size():
		return
	_selected_index = index
	_elapsed = 0.0
	var row := TutorialInteractions.ROWS[index]
	_stage.show_interaction(row)
	_caption.text = "%s → %s: %s" % [row["agent"], row["target"], row["short"]]
	_refresh_chips()


func _select_next() -> void:
	_select_interaction((_selected_index + 1) % TutorialInteractions.ROWS.size())


func _on_chip_pressed(index: int) -> void:
	button_pressed.emit()
	_select_interaction(index)


func _refresh_chips() -> void:
	for i in _chips.size():
		if _chip_rows[i] == _selected_index:
			SeaStyle.style_highlighted_button(_chips[i])
		else:
			SeaStyle.style_button(_chips[i])


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
			_select_next()


## Preserves the source order while grouping rows by their agent.
func _grouped_rows() -> Array[Dictionary]:
	var groups: Array[Dictionary] = []
	var by_label := {}
	for i in TutorialInteractions.ROWS.size():
		var row := TutorialInteractions.ROWS[i]
		var label: String = row["group"]
		if not by_label.has(label):
			var group := {
				"label": label,
				"agent_id": row["agent_id"],
				"color": row["color"],
				"rows": [],
			}
			by_label[label] = group
			groups.append(group)
		var current: Dictionary = by_label[label]
		current["rows"].append({"row": row, "index": i})
	return groups


func _build_group(group: Dictionary) -> Control:
	var section := VBoxContainer.new()
	section.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	section.add_theme_constant_override("separation", 5)
	section.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	section.add_child(header)

	var icon := TextureRect.new()
	icon.texture = TutorialIcons.texture(StringName(group["agent_id"]))
	icon.custom_minimum_size = Vector2(26, 26)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_child(icon)

	var label := Label.new()
	label.text = group["label"]
	label.add_theme_font_size_override("font_size", 19)
	label.add_theme_color_override("font_color", group.get("color", SeaStyle.SAND_COLOR))
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_child(label)

	var chips := HFlowContainer.new()
	chips.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	chips.add_theme_constant_override("h_separation", 6)
	chips.add_theme_constant_override("v_separation", 6)
	chips.mouse_filter = Control.MOUSE_FILTER_IGNORE
	section.add_child(chips)

	for entry in group["rows"]:
		chips.add_child(_build_chip(entry["row"], entry["index"]))
	return section


## A target chip: target icon + the short effect. The tooltip spells out the
## full pair for players who want the exact wording.
func _build_chip(row: Dictionary, index: int) -> Button:
	var chip := Button.new()
	chip.text = row["short"]
	chip.tooltip_text = "%s → %s: %s" % [row["agent"], row["target"], row["short"]]
	chip.icon = TutorialIcons.texture(StringName(row["target_id"]))
	chip.expand_icon = true
	chip.add_theme_constant_override("icon_max_width", 26)
	chip.custom_minimum_size = Vector2(196, 46)
	chip.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	chip.alignment = HORIZONTAL_ALIGNMENT_LEFT
	chip.add_theme_font_size_override("font_size", 15)
	chip.focus_mode = Control.FOCUS_NONE
	chip.pressed.connect(_on_chip_pressed.bind(index))
	SeaStyle.style_button(chip)
	_chips.append(chip)
	_chip_rows.append(index)
	return chip
