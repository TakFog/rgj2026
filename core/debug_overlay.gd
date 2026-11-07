class_name DebugOverlay
extends Control
## Debug overlay toggled with F3 (GDD §9).
## Draws per-entity debug numbers over everything in screen space:
## coral oxygen/life, nest hatch time, fish state + hunger.
## A fixed panel also shows temperature-dependent rates, a manual
## temperature slider and editable feature flags.

signal enabled_changed(enabled: bool)

## One recycled label per tracked element, keyed by instance id (entities)
## or by a fixed name (panel entries).
var _labels: Dictionary = {} # Variant -> Label
var _slider: HSlider
## Editable feature-flag toggle buttons, keyed by flag name.
var _flag_buttons: Dictionary = {} # StringName -> Button
## Threat spawn buttons, keyed by threat type.
var _spawn_buttons: Dictionary = {} # String -> Button

const FONT_SIZE := 11
## Pixels above the entity anchor so the text does not sit on the sprite.
const OFFSET := Vector2(0, -14)
## Fixed panel padding from the top-right screen corner.
const PANEL_PAD := 16.0
const PANEL_WIDTH := 190.0
const LINE_HEIGHT := FONT_SIZE + 4.0
## Gap between the temperature text and its slider.
const TEMP_SLIDER_GAP := 6.0
## Height of a flag toggle button row.
const FLAG_ROW_HEIGHT := 22.0

const COLOR_CORAL := Color(0.7, 1.0, 0.7)
const COLOR_CORAL_LOW := Color(1.0, 0.5, 0.5)
const COLOR_NEST := Color(1.0, 0.75, 0.35)
const COLOR_NEST_EMPTY := Color(0.55, 0.55, 0.55)
const COLOR_FISH := Color(0.7, 0.85, 1.0)
const COLOR_TEMP := Color(1.0, 1.0, 1.0)
const COLOR_DIM := Color(0.7, 0.7, 0.7)

const ThreatSpawner := preload("res://systems/b_threat_spawner.gd")

var _enabled := false
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
	visible = Game.debug_mode

	_slider = HSlider.new()
	_slider.min_value = 0.0
	_slider.max_value = 1.0
	_slider.step = 0.01
	_slider.mouse_filter = Control.MOUSE_FILTER_STOP
	_slider.value_changed.connect(_on_temperature_slider_changed)
	add_child(_slider)

	# Editable feature-flag toggle buttons.
	var co2 := _make_flag_button("co2_dies_on_coral", Game.actors.co2_dies_on_coral)
	co2.pressed.connect(_toggle_co2_dies_on_coral)
	add_child(co2)
	_flag_buttons["co2_dies_on_coral"] = co2

	var predator := _make_flag_button("predator_enabled", Game.actors.predator_enabled)
	predator.pressed.connect(_toggle_predator_enabled)
	add_child(predator)
	_flag_buttons["predator_enabled"] = predator

	# Threat spawn buttons (debug only).
	var spawn_co2 := _make_action_button("Spawn CO2")
	spawn_co2.pressed.connect(_spawn_co2)
	add_child(spawn_co2)
	_spawn_buttons["co2"] = spawn_co2

	var spawn_bag := _make_action_button("Spawn Bag")
	spawn_bag.pressed.connect(_spawn_bag)
	add_child(spawn_bag)
	_spawn_buttons["bag"] = spawn_bag

	var spawn_cyclone := _make_action_button("Spawn Cyclone")
	spawn_cyclone.pressed.connect(_spawn_cyclone)
	add_child(spawn_cyclone)
	_spawn_buttons["cyclone"] = spawn_cyclone

	var spawn_predator := _make_action_button("Spawn Predator")
	spawn_predator.pressed.connect(_spawn_predator)
	add_child(spawn_predator)
	_spawn_buttons["predator"] = spawn_predator


func _on_debug_mode_changed(value: bool) -> void:
	enabled = value
	visible = value
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


func _process(_delta: float) -> void:
	if not enabled:
		return
	_update_labels()
	_sync_slider()


## Positions the temperature slider right under the temperature text and
## keeps its value in sync with Game.temperature. Positions the flag buttons.
func _sync_slider() -> void:
	var size := get_viewport_rect().size
	var x := size.x - PANEL_WIDTH - PANEL_PAD
	# Temperature text is at PANEL_PAD; slider sits one line below it.
	var y := PANEL_PAD + LINE_HEIGHT + TEMP_SLIDER_GAP
	_slider.position = Vector2(x, y)
	_slider.size = Vector2(PANEL_WIDTH, 20.0)
	_slider.value = Game.temperature

	# Flag buttons sit below the rates section (temp + 2 rate lines + header gap).
	var flag_y := PANEL_PAD + LINE_HEIGHT * 3.0 + 8.0
	for name in _flag_buttons.keys():
		var btn := _flag_buttons[name] as Button
		btn.position = Vector2(x, flag_y)
		btn.size = Vector2(PANEL_WIDTH, FLAG_ROW_HEIGHT)
		flag_y += FLAG_ROW_HEIGHT + 4.0

	# Spawn buttons sit below the flag buttons.
	var spawn_y := flag_y
	for name in _spawn_buttons.keys():
		var btn := _spawn_buttons[name] as Button
		btn.position = Vector2(x, spawn_y)
		btn.size = Vector2(PANEL_WIDTH, FLAG_ROW_HEIGHT)
		spawn_y += FLAG_ROW_HEIGHT + 4.0


## Creates a toggle-styled button showing the flag name and current state.
func _make_flag_button(name: String, value: bool) -> Button:
	var btn := Button.new()
	btn.text = _flag_label(name, value)
	btn.mouse_filter = Control.MOUSE_FILTER_STOP
	btn.focus_mode = Control.FOCUS_NONE
	return btn


## Creates an action button with the given label.
func _make_action_button(label: String) -> Button:
	var btn := Button.new()
	btn.text = label
	btn.mouse_filter = Control.MOUSE_FILTER_STOP
	btn.focus_mode = Control.FOCUS_NONE
	return btn


## Rebuilds the per-entity labels every frame so created/destroyed entities
## are tracked automatically. Also rebuilds the fixed panel labels.
func _update_labels() -> void:
	var wanted := {}
	var size := get_viewport_rect().size
	var x := size.x - PANEL_WIDTH - PANEL_PAD
	var y := PANEL_PAD

	# --- Fixed panel: temperature ---
	var temp_text := "T: %.2f" % Game.temperature
	if Game.debug_temperature_manual:
		temp_text += " (manual)"
	_set_label(&"_temp", temp_text, Vector2(x, y), COLOR_TEMP, wanted)
	y += LINE_HEIGHT

	# --- Fixed panel: temperature-dependent rates ---
	var regen := Game.by_temperature(Game.eco.coral_regen_per_sec, Game.eco.coral_regen_hot_per_sec)
	_set_label(&"_regen", "Coral regen: %.2f/s" % regen, Vector2(x, y), COLOR_DIM, wanted)
	y += LINE_HEIGHT

	var egg_death := Game.by_temperature(Game.eco.egg_death_chance_cold, Game.eco.egg_death_chance_hot)
	_set_label(&"_eggdeath", "Egg death: %.0f%%" % (egg_death * 100.0), Vector2(x, y), COLOR_DIM, wanted)
	y += LINE_HEIGHT + 4.0

	# --- Fixed panel: feature flags (editable, see _flag_buttons) ---
	_set_label(&"_flags", "Feature flags:", Vector2(x, y), COLOR_TEMP, wanted)

	# Keep flag button labels in sync with current state.
	for name in _flag_buttons.keys():
		var btn := _flag_buttons[name] as Button
		btn.text = _flag_label(name, _flag_value(name))

	# Remove labels for elements that no longer exist.
	for id in _labels.keys():
		if not wanted.has(id):
			_labels[id].queue_free()
			_labels.erase(id)


## Returns the display text for a feature flag.
func _flag_label(name: String, value: bool) -> String:
	var pretty := name.to_upper().replace("_", " ")
	return "%s: %s" % [pretty, "ON" if value else "OFF"]


## Returns the current value of a feature flag by name.
func _flag_value(name: StringName) -> bool:
	match name:
		"co2_dies_on_coral": return Game.actors.co2_dies_on_coral
		"predator_enabled": return Game.actors.predator_enabled
		_: return false


## Creates or recycles the label for `id` and marks it as wanted this frame.
func _set_label(id: Variant, text: String, pos: Vector2, color: Color, wanted: Dictionary) -> void:
	wanted[id] = true
	if _labels.has(id):
		var label := _labels[id] as Label
		label.text = text
		label.position = pos
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
		FishBrain.State.WANDER: return "WANDER"
		FishBrain.State.ORDERED: return "ORDERED"
		FishBrain.State.EATING: return "EATING"
		FishBrain.State.FERTILIZING: return "FERTILIZING"
		FishBrain.State.IDLE: return "IDLE"
		FishBrain.State.SEEKING_FOOD: return "SEEKING"
		_: return "?"


func _clear_labels() -> void:
	for label in _labels.values():
		label.queue_free()
	_labels.clear()
