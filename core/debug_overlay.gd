class_name DebugOverlay
extends Control
## Debug overlay toggled with F3 (GDD §9).
## Draws per-entity debug numbers over everything in screen space:
## coral oxygen/life, nest hatch time, fish state + hunger, turtle state.
## A fixed panel also shows temperature-dependent rates, a manual
## temperature slider, editable debug flags and debug spawn buttons.

signal enabled_changed(enabled: bool)

## One recycled label per tracked element, keyed by instance id (entities)
## or by a fixed name (panel entries).
var _labels: Dictionary = {} # Variant -> Label
var _slider: HSlider
var _panel_bg: ColorRect
## Editable debug/feature toggle buttons, keyed by flag name.
var _flag_buttons: Dictionary = {} # StringName -> Button
## Action buttons (threat spawns, Game Over), keyed by action name.
var _spawn_buttons: Dictionary = {} # String -> Button

const FONT_SIZE := 11
## Debug text does not need 60 updates per second; 10 Hz keeps it readable and
## avoids rebuilding every label (and formatting every string) each frame.
const REFRESH_SECONDS := 0.1
## Pixels above the entity anchor so the text does not sit on the sprite.
const OFFSET := Vector2(0, -14)
## Fixed panel padding from the bottom-right screen corner (the only corner
## free of HUD elements: counters top-left, thermometer top-right, inventory
## bottom-centre).
const PANEL_PAD := 16.0
const PANEL_WIDTH := 190.0
## Inner padding between the panel background and its contents.
const PANEL_INSET := 6.0
const LINE_HEIGHT := FONT_SIZE + 4.0
const SLIDER_HEIGHT := 16.0
## Vertical gap between panel sections and between button rows.
const ROW_GAP := 4.0
## Height of a flag toggle / spawn button row.
const FLAG_ROW_HEIGHT := 20.0
const PANEL_BG := Color(0.0, 0.0, 0.0, 0.55)

const COLOR_CORAL := Color(0.7, 1.0, 0.7)
const COLOR_CORAL_LOW := Color(1.0, 0.5, 0.5)
const COLOR_NEST := Color(1.0, 0.75, 0.35)
const COLOR_NEST_EMPTY := Color(0.55, 0.55, 0.55)
const COLOR_FISH := Color(0.7, 0.85, 1.0)
const COLOR_TURTLE := Color(0.4, 0.9, 0.6)
const COLOR_TEMP := Color(1.0, 1.0, 1.0)
const COLOR_DIM := Color(0.7, 0.7, 0.7)

## Italian labels for the F3 panel's debug flags.
const FLAG_NAMES := {
	"co2_dies_on_coral": "CO2 muore sul corallo",
	"predator_enabled": "Predatore attivo",
	"turtle_enabled": "Tartaruga attiva",
	"show_paths": "Mostra percorsi",
}

const ThreatSpawner := preload("res://systems/b_threat_spawner.gd")

var _enabled := false
var _elapsed := REFRESH_SECONDS
var enabled:
	get: return _enabled
	set(value):
		_enabled = value
		visible = value
		enabled_changed.emit(value)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	Game.debug_mode_changed.connect(_on_debug_mode_changed)
	enabled = Game.debug_mode

	_panel_bg = ColorRect.new()
	_panel_bg.color = PANEL_BG
	_panel_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_panel_bg)

	_slider = HSlider.new()
	_slider.min_value = 0.0
	_slider.max_value = 1.0
	_slider.step = 0.01
	_slider.mouse_filter = Control.MOUSE_FILTER_STOP
	_slider.value_changed.connect(_on_temperature_slider_changed)
	add_child(_slider)

	# Editable feature-flag and debug-view toggle buttons.
	var co2 := _make_flag_button("co2_dies_on_coral", Game.actors.co2_dies_on_coral)
	co2.pressed.connect(_toggle_co2_dies_on_coral)
	add_child(co2)
	_flag_buttons["co2_dies_on_coral"] = co2

	var predator := _make_flag_button("predator_enabled", Game.actors.predator_enabled)
	predator.pressed.connect(_toggle_predator_enabled)
	add_child(predator)
	_flag_buttons["predator_enabled"] = predator

	var turtle := _make_flag_button("turtle_enabled", Game.actors.turtle_enabled)
	turtle.pressed.connect(_toggle_turtle_enabled)
	add_child(turtle)
	_flag_buttons["turtle_enabled"] = turtle

	var paths := _make_flag_button("show_paths", Game.debug_show_paths)
	paths.pressed.connect(_toggle_show_paths)
	add_child(paths)
	_flag_buttons["show_paths"] = paths

	# Threat spawn buttons (debug only).
	var spawn_co2 := _make_action_button("Genera CO2")
	spawn_co2.pressed.connect(_spawn_co2)
	add_child(spawn_co2)
	_spawn_buttons["co2"] = spawn_co2

	var spawn_bag := _make_action_button("Genera busta")
	spawn_bag.pressed.connect(_spawn_bag)
	add_child(spawn_bag)
	_spawn_buttons["bag"] = spawn_bag

	var spawn_cyclone := _make_action_button("Genera ciclone")
	spawn_cyclone.pressed.connect(_spawn_cyclone)
	add_child(spawn_cyclone)
	_spawn_buttons["cyclone"] = spawn_cyclone

	var spawn_predator := _make_action_button("Genera predatore")
	spawn_predator.pressed.connect(_spawn_predator)
	add_child(spawn_predator)
	_spawn_buttons["predator"] = spawn_predator

	var spawn_turtle := _make_action_button("Genera tartaruga")
	spawn_turtle.pressed.connect(_spawn_turtle)
	add_child(spawn_turtle)
	_spawn_buttons["turtle"] = spawn_turtle

	var game_over := _make_action_button("Fine partita")
	game_over.pressed.connect(_force_game_over)
	add_child(game_over)
	_spawn_buttons["game_over"] = game_over


func _on_debug_mode_changed(value: bool) -> void:
	enabled = value
	visible = value
	# Refresh immediately on enable instead of waiting for the next tick.
	_elapsed = REFRESH_SECONDS
	if not value:
		Game.debug_temperature_manual = false
		_clear_labels()


## User dragged the temperature slider: switch to manual mode and apply.
func _on_temperature_slider_changed(value: float) -> void:
	Game.debug_temperature_manual = true
	Game.debug_temperature_value = value


## Toggle the CO2-dies-on-coral feature flag.
func _toggle_co2_dies_on_coral() -> void:
	Game.actors.co2_dies_on_coral = not Game.actors.co2_dies_on_coral


## Toggle the predator-enabled feature flag.
func _toggle_predator_enabled() -> void:
	Game.actors.predator_enabled = not Game.actors.predator_enabled


## Toggle the turtle-enabled feature flag.
func _toggle_turtle_enabled() -> void:
	Game.actors.turtle_enabled = not Game.actors.turtle_enabled


## Toggle the planned-route overlay (see core/path_debug.gd).
func _toggle_show_paths() -> void:
	Game.debug_show_paths = not Game.debug_show_paths


## Spawn a CO2 cloud at a random edge of the visible seabed.
func _spawn_co2() -> void:
	_spawn_threat(ThreatSchedule.Type.CO2)


## Spawn a plastic bag at a random edge of the visible seabed.
func _spawn_bag() -> void:
	_spawn_threat(ThreatSchedule.Type.BAG)


## Spawn a cyclone at a random edge of the visible seabed.
func _spawn_cyclone() -> void:
	_spawn_threat(ThreatSchedule.Type.CYCLONE)


## Spawns a threat of `kind` at a random edge of the visible seabed.
func _spawn_threat(kind: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var entry := EdgeEntry.random(rng, Game.visible_world_polygon(), Rect2(Vector2.ZERO, Game.grid.world_size()))
	ThreatSpawner.spawn(kind, entry, rng)


## Spawn a predator at a random edge of the visible seabed (ignores the
## predator_enabled flag: this is a manual debug spawn).
func _spawn_predator() -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var entry := EdgeEntry.random(rng, Game.visible_world_polygon(), Rect2(Vector2.ZERO, Game.grid.world_size()))
	Game.factory.spawn_predator(entry)


## Spawn a turtle at a random edge of the visible seabed (ignores the
## turtle_enabled flag: this is a manual debug spawn).
func _spawn_turtle() -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var entry := EdgeEntry.random(rng, Game.visible_world_polygon(), Rect2(Vector2.ZERO, Game.grid.world_size()))
	Game.factory.spawn_turtle(entry)


## End the run immediately and show the game-over screen.
func _force_game_over() -> void:
	var monitor := get_tree().get_first_node_in_group(Groups.POPULATION_MONITOR) as PopulationMonitor
	if monitor != null:
		monitor.force_game_over()


func _process(delta: float) -> void:
	if not enabled:
		return
	_elapsed += delta
	if _elapsed < REFRESH_SECONDS:
		return
	_elapsed = 0.0
	_update_labels()
	_sync_slider()


## Total height of the fixed panel contents (without the inset).
func _panel_height() -> float:
	var rows := _flag_buttons.size() + _spawn_buttons.size()
	return (LINE_HEIGHT + SLIDER_HEIGHT + ROW_GAP # temperature + slider
		+ LINE_HEIGHT * 2.0 + ROW_GAP # rates
		+ LINE_HEIGHT # "Flag di gioco:" header
		+ rows * (FLAG_ROW_HEIGHT + ROW_GAP) - ROW_GAP)


## Top-left corner of the fixed panel contents, anchored bottom-right.
func _panel_origin() -> Vector2:
	var viewport := get_viewport_rect().size
	return Vector2(
		viewport.x - PANEL_WIDTH - PANEL_PAD - PANEL_INSET,
		viewport.y - _panel_height() - PANEL_PAD - PANEL_INSET)


## Positions the panel background, the temperature slider (right under the
## temperature text) and the flag/spawn buttons; keeps the slider value in
## sync with Game.temperature. Must match the row layout of _update_labels.
func _sync_slider() -> void:
	var origin := _panel_origin()
	var x := origin.x
	_panel_bg.position = origin - Vector2(PANEL_INSET, PANEL_INSET)
	_panel_bg.size = Vector2(PANEL_WIDTH, _panel_height()) + Vector2(PANEL_INSET, PANEL_INSET) * 2.0

	var y := origin.y + LINE_HEIGHT
	_slider.position = Vector2(x, y)
	_slider.size = Vector2(PANEL_WIDTH, SLIDER_HEIGHT)
	# No signal: only a real drag may switch the temperature to manual mode.
	_slider.set_value_no_signal(Game.temperature)

	# Buttons sit below the rates section and the "Flag di gioco:" header.
	y += SLIDER_HEIGHT + ROW_GAP + LINE_HEIGHT * 2.0 + ROW_GAP + LINE_HEIGHT
	for btn: Button in _flag_buttons.values() + _spawn_buttons.values():
		btn.position = Vector2(x, y)
		btn.size = Vector2(PANEL_WIDTH, FLAG_ROW_HEIGHT)
		y += FLAG_ROW_HEIGHT + ROW_GAP


## Creates a toggle-styled button showing the flag name and current state.
func _make_flag_button(flag_name: String, value: bool) -> Button:
	var btn := Button.new()
	btn.text = _flag_label(flag_name, value)
	btn.add_theme_font_size_override("font_size", FONT_SIZE)
	btn.mouse_filter = Control.MOUSE_FILTER_STOP
	btn.focus_mode = Control.FOCUS_NONE
	return btn


## Creates an action button with the given label.
func _make_action_button(label: String) -> Button:
	var btn := Button.new()
	btn.text = label
	btn.add_theme_font_size_override("font_size", FONT_SIZE)
	btn.mouse_filter = Control.MOUSE_FILTER_STOP
	btn.focus_mode = Control.FOCUS_NONE
	return btn


## Rebuilds the per-entity labels every frame so created/destroyed entities
## are tracked automatically. Also rebuilds the fixed panel labels.
func _update_labels() -> void:
	var wanted := {}
	var origin := _panel_origin()
	var x := origin.x
	var y := origin.y

	# --- Fixed panel: temperature ---
	var temp_text := "Temp: %.2f" % Game.temperature
	if Game.debug_temperature_manual:
		temp_text += " (manuale)"
	_set_label(&"_temp", temp_text, Vector2(x, y), COLOR_TEMP, wanted)
	y += LINE_HEIGHT + SLIDER_HEIGHT + ROW_GAP

	# --- Fixed panel: temperature-dependent rates ---
	var regen := Game.by_temperature(Game.eco.coral_regen_per_sec, Game.eco.coral_regen_hot_per_sec)
	_set_label(&"_regen", "Recupero corallo: %.2f/s" % regen, Vector2(x, y), COLOR_DIM, wanted)
	y += LINE_HEIGHT

	var egg_death := Game.by_temperature(Game.eco.egg_death_chance_cold, Game.eco.egg_death_chance_hot)
	_set_label(&"_eggdeath", "Morte uova: %.0f%%" % (egg_death * 100.0), Vector2(x, y), COLOR_DIM, wanted)
	y += LINE_HEIGHT + ROW_GAP

	# --- Fixed panel: debug flags (editable, see _flag_buttons) ---
	_set_label(&"_flags", "Flag di gioco:", Vector2(x, y), COLOR_TEMP, wanted)

	# Keep flag button labels in sync with current state (only when they change).
	for flag_name in _flag_buttons.keys():
		var btn := _flag_buttons[flag_name] as Button
		var flag_text := _flag_label(flag_name, _flag_value(flag_name))
		if btn.text != flag_text:
			btn.text = flag_text

	# Query each group once per refresh instead of once per entity loop.
	var corals := get_tree().get_nodes_in_group(Groups.CORALS)
	var nests := get_tree().get_nodes_in_group(Groups.NESTS)
	var fishes := get_tree().get_nodes_in_group(Groups.FISH)
	var turtles := get_tree().get_nodes_in_group(Groups.TURTLES)

	# --- Entities: coral oxygen / life ---
	for coral in corals:
		if not _alive(coral):
			continue
		var id := coral.get_instance_id()
		var max_o := Game.eco.coral_max_oxygen
		var text := "O2: %.0f" % coral.oxygen
		if max_o > 0:
			text += "/%.0f" % max_o
		var pos := _viewport_position(coral.global_position)
		var color := COLOR_CORAL if coral.oxygen > max_o * 0.3 else COLOR_CORAL_LOW
		_set_label(id, text, pos + OFFSET, color, wanted)

	# --- Entities: nest hatch time or empty ---
	for nest in nests:
		if not _alive(nest):
			continue
		var id := nest.get_instance_id()
		var text := "VUOTO"
		if nest.has_eggs():
			text = "UOVA: %.1fs" % nest.eggs_time_left()
		var pos := _viewport_position(nest.global_position)
		var color := COLOR_NEST if nest.has_eggs() else COLOR_NEST_EMPTY
		_set_label(id, text, pos + OFFSET, color, wanted)

	# --- Entities: fish state + hunger ---
	for fish in fishes:
		if not _alive(fish) or fish.brain == null:
			continue
		var id := fish.get_instance_id()
		var text := "%s fame %d%%" % [_state_name(fish.brain.state), (fish.brain.hunger_ratio() * 100.0)]
		var pos := _viewport_position(fish.global_position)
		_set_label(id, text, pos + OFFSET, COLOR_FISH, wanted)

	# --- Entities: turtle state + algae eaten ---
	for turtle in turtles:
		if not _alive(turtle) or turtle.brain == null:
			continue
		var id := turtle.get_instance_id()
		var text := "%s alghe %d" % [_turtle_state_name(turtle.brain.state), turtle.brain.algae_eaten]
		var pos := _viewport_position(turtle.global_position)
		_set_label(id, text, pos + OFFSET, COLOR_TURTLE, wanted)

	# Remove labels for elements that no longer exist.
	for id in _labels.keys():
		if not wanted.has(id):
			_labels[id].queue_free()
			_labels.erase(id)


## Returns the Italian display text for a debug flag.
func _flag_label(flag_name: String, value: bool) -> String:
	var pretty: String = FLAG_NAMES.get(flag_name, flag_name.to_upper().replace("_", " "))
	return "%s: %s" % [pretty, "SÌ" if value else "NO"]


## Returns the current value of a debug/feature flag by name.
func _flag_value(flag_name: StringName) -> bool:
	match flag_name:
		"co2_dies_on_coral": return Game.actors.co2_dies_on_coral
		"predator_enabled": return Game.actors.predator_enabled
		"turtle_enabled": return Game.actors.turtle_enabled
		"show_paths": return Game.debug_show_paths
		_: return false


## Creates or recycles the label for `id` and marks it as wanted this frame.
func _set_label(id: Variant, text: String, pos: Vector2, color: Color, wanted: Dictionary) -> void:
	wanted[id] = true
	if _labels.has(id):
		var label := _labels[id] as Label
		if label.text != text:
			label.text = text
		if label.position != pos:
			label.position = pos
		if label.modulate != color:
			label.modulate = color
	else:
		var label := Label.new()
		label.text = text
		label.position = pos
		label.modulate = color
		label.add_theme_font_size_override("font_size", FONT_SIZE)
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(label)
		_labels[id] = label


## Converts a logical-world position to a viewport (screen) position, applying
## the same camera transform used by ViewFollower so labels land over entities.
func _viewport_position(world: Vector2) -> Vector2:
	var viewport_size := get_viewport_rect().size
	var center_world := Game.grid.world_size() * 0.5
	var camera_screen := Game.projection.to_screen(center_world)
	var world_screen := Game.projection.to_screen(world)
	return (world_screen - camera_screen) * Game.VIEW_SETTINGS.zoom + viewport_size * 0.5


func _alive(entity: Object) -> bool:
	return is_instance_valid(entity) and not entity.is_queued_for_deletion()


func _state_name(state: int) -> String:
	match state:
		FishBrain.State.WANDER: return "VAGA"
		FishBrain.State.ORDERED: return "ORDINE"
		FishBrain.State.EATING: return "MANGIA"
		FishBrain.State.FERTILIZING: return "FECONDA"
		FishBrain.State.IDLE: return "FERMO"
		FishBrain.State.SEEKING_FOOD: return "CERCA CIBO"
		_: return "?"


func _turtle_state_name(state: int) -> String:
	match state:
		TurtleBrain.State.HELPING: return "AIUTA"
		TurtleBrain.State.EATING: return "MANGIA"
		TurtleBrain.State.LEAVING: return "SE NE VA"
		_: return "?"


func _clear_labels() -> void:
	for label in _labels.values():
		label.queue_free()
	_labels.clear()
