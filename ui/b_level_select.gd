class_name LevelSelectScreen
extends ColorRect
## Level chooser shown by Gioca (GDD §9). One card per campaign level with its
## time limit and the mechanic it introduces; cleared levels unlock the next.
## A final card opens the endless Sandbox, the old run with every mechanic on.
## Works while the tree is paused: opening pauses, choosing/closing lets the
## caller decide what happens next.

signal level_chosen(index: int)
## The player pressed Indietro/Esc: back to the title screen.
signal closed
## Any button pressed (used by the audio system).
signal button_pressed

const LOCKED_TEXT := "Bloccato"
const ROW_MIN_SIZE := Vector2(520, 96)
const ROW_FONT_SIZE := 19

var _buttons: Array[Button] = []
var _sandbox_button: Button


## Text of one level card. Static so the wording is unit-testable. Campaign
## cards never show a record: only the endless Sandbox has one.
static func row_text(index: int, level: LevelDefinition, unlocked: bool) -> String:
	var head := "%d. %s — %s" % [index + 1, level.level_name, Hud.format_time(level.duration_seconds)]
	if not unlocked:
		return "%s\n%s" % [head, LOCKED_TEXT]
	return "%s\n%s" % [head, level.mechanic_summary]


## Text of the endless sandbox card. It is always unlocked and shows the global
## survival record (the old run's record), not a per-level one.
static func sandbox_text(level: LevelDefinition, best_seconds: float) -> String:
	var text := "%s\n%s" % [level.level_name, level.mechanic_summary]
	if best_seconds > 0.0:
		text += "  ·  Record %s" % Hud.format_time(best_seconds)
	return text


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

	var title := Label.new()
	title.text = "Scegli il livello"
	SeaStyle.style_title(title)
	box.add_child(title)
	box.add_child(SeaStyle.divider())

	var intro := Label.new()
	intro.text = "Ogni livello aggiunge una nuova pressione alla barriera.\nLa Sandbox è la sfida libera, senza limite di tempo."
	SeaStyle.style_body(intro)
	box.add_child(intro)

	var levels := LevelCatalog.all()
	for index in levels.size():
		var button := SeaStyle.menu_button("")
		button.custom_minimum_size = ROW_MIN_SIZE
		button.add_theme_font_size_override("font_size", ROW_FONT_SIZE)
		button.alignment = HORIZONTAL_ALIGNMENT_CENTER
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.pressed.connect(_on_level_pressed.bind(index))
		box.add_child(button)
		_buttons.append(button)

	# The old endless run, kept as a bonus after the campaign.
	box.add_child(SeaStyle.divider())
	_sandbox_button = SeaStyle.menu_button("")
	_sandbox_button.custom_minimum_size = ROW_MIN_SIZE
	_sandbox_button.add_theme_font_size_override("font_size", ROW_FONT_SIZE)
	_sandbox_button.alignment = HORIZONTAL_ALIGNMENT_CENTER
	_sandbox_button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_sandbox_button.pressed.connect(_on_sandbox_pressed)
	box.add_child(_sandbox_button)

	var back := SeaStyle.menu_button("Indietro")
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	back.pressed.connect(_on_back_pressed)
	box.add_child(back)


## Shows the chooser, refreshes lock states and pauses the run behind it.
func open() -> void:
	_refresh()
	visible = true
	get_tree().paused = true
	_set_gameplay_hud_visible(false)
	_focus_first_unlocked.call_deferred()


## Hides the chooser. The caller unpauses (start a run) or opens the menu.
func close() -> void:
	visible = false
	_set_gameplay_hud_visible(true)


func _refresh() -> void:
	var levels := LevelCatalog.all()
	var unlocked := mini(UserSettings.unlocked_count(), levels.size())
	for index in _buttons.size():
		var button := _buttons[index]
		var level := levels[index]
		button.text = row_text(index, level, index < unlocked)
		button.disabled = index >= unlocked
	# The sandbox has no unlocks and uses the global record of the old run.
	_sandbox_button.text = sandbox_text(LevelCatalog.sandbox(), UserSettings.best_seconds())
	_sandbox_button.disabled = false


func _focus_first_unlocked() -> void:
	for button in _buttons:
		if not button.disabled:
			button.grab_focus()
			return


func _on_level_pressed(index: int) -> void:
	button_pressed.emit()
	level_chosen.emit(index)


func _on_sandbox_pressed() -> void:
	button_pressed.emit()
	level_chosen.emit(LevelSession.SANDBOX_INDEX)


func _on_back_pressed() -> void:
	button_pressed.emit()
	closed.emit()


## Esc/Space must not fall through to the pause controller while this is open.
func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed(InputActions.CANCEL) or event.is_action_pressed(InputActions.PAUSE):
		get_viewport().set_input_as_handled()
		_on_back_pressed()


## The title menu hides the HUD group too; restore it only when the run starts.
func _set_gameplay_hud_visible(value: bool) -> void:
	for node in get_tree().get_nodes_in_group(Groups.GAMEPLAY_HUD):
		if node is CanvasItem:
			(node as CanvasItem).visible = value
