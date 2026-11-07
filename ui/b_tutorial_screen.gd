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

## Advance to the next interaction once the longest vignette has faded out.
const LOOP_SECONDS := TutorialStage.TIMELINE_SECONDS
const SCREEN_MARGIN := 24.0
const RIGHT_COLUMN_MIN_WIDTH := 340.0
const CAPTION_FONT_SIZE := 22
## Theme entries SeaStyle sets on a button; chips share one copy of each look.
const CHIP_STYLE_STATES: Array[StringName] = [
	&"normal", &"hover", &"pressed", &"hover_pressed", &"disabled", &"focus",
]
const CHIP_COLOR_STATES: Array[StringName] = [
	&"font_color", &"font_hover_color", &"font_focus_color", &"font_pressed_color",
	&"font_hover_pressed_color", &"font_disabled_color",
]

var _mode := Mode.START
var _stage: TutorialStage
var _caption: Label
var _skip: Button
var _primary: Button
var _elapsed := 0.0
var _selected_index := 0
var _chips: Array[Button] = []
var _chip_rows: Array[int] = []
var _scroll: ScrollContainer
## Chip looks, built once and shared by every chip: {"styles", "colors"}.
var _chip_normal: Dictionary = {}
var _chip_highlighted: Dictionary = {}
var _highlighted_chip: Button


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
	SeaStyle.style_body(intro)
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
	list_title.add_theme_font_size_override("font_size", 20)
	list_title.add_theme_color_override("font_color", SeaStyle.SAND_COLOR)
	right.add_child(list_title)

	_scroll = ScrollContainer.new()
	_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	right.add_child(_scroll)
	SeaStyle.style_scrollbar(_scroll.get_v_scroll_bar())

	_chip_normal = _chip_look(false)
	_chip_highlighted = _chip_look(true)
	var rows := VBoxContainer.new()
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rows.add_theme_constant_override("separation", 6)
	rows.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_scroll.add_child(rows)
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
		_select_next()


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


## Only the previous and the new selection are restyled.
func _refresh_chips() -> void:
	var selected: Button = null
	var at := _chip_rows.find(_selected_index)
	if at >= 0:
		selected = _chips[at]
	if selected != _highlighted_chip:
		if _highlighted_chip != null:
			_apply_chip_look(_highlighted_chip, _chip_normal)
		if selected != null:
			_apply_chip_look(selected, _chip_highlighted)
		_highlighted_chip = selected
	if selected != null and _scroll != null and _scroll.is_inside_tree():
		_scroll.ensure_control_visible(selected)


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
	label.add_theme_font_size_override("font_size", 17)
	label.add_theme_color_override("font_color", group.get("color", SeaStyle.SAND_COLOR))
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_child(label)

	var chips := HFlowContainer.new()
	chips.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	chips.add_theme_constant_override("h_separation", 5)
	chips.add_theme_constant_override("v_separation", 5)
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
	chip.add_theme_constant_override("icon_max_width", 24)
	chip.custom_minimum_size = Vector2(184, 42)
	chip.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	chip.alignment = HORIZONTAL_ALIGNMENT_LEFT
	chip.add_theme_font_size_override("font_size", 14)
	chip.focus_mode = Control.FOCUS_NONE
	chip.pressed.connect(_on_chip_pressed.bind(index))
	chip.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_apply_chip_look(chip, _chip_normal)
	_chips.append(chip)
	_chip_rows.append(index)
	return chip


## Captures SeaStyle's (highlighted) button look once, so chips can share it.
func _chip_look(highlighted: bool) -> Dictionary:
	var template := Button.new()
	if highlighted:
		SeaStyle.style_highlighted_button(template)
	else:
		SeaStyle.style_button(template)
	var styles := {}
	for state in CHIP_STYLE_STATES:
		styles[state] = template.get_theme_stylebox(state)
	var colors := {}
	for state in CHIP_COLOR_STATES:
		colors[state] = template.get_theme_color(state)
	template.free()
	return {"styles": styles, "colors": colors}


func _apply_chip_look(chip: Button, look: Dictionary) -> void:
	var styles: Dictionary = look["styles"]
	for state: StringName in styles:
		chip.add_theme_stylebox_override(state, styles[state])
	var colors: Dictionary = look["colors"]
	for state: StringName in colors:
		chip.add_theme_color_override(state, colors[state])
