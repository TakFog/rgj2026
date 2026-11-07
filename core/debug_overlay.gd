class_name DebugOverlay
extends Control
## Debug overlay toggled with F3 (GDD §9).
## Draws per-entity debug numbers over everything in screen space:
## coral oxygen/life, nest hatch time, fish state + hunger.
## A fixed panel also shows temperature-dependent rates, a manual
## temperature slider and the feature flags.

signal enabled_changed(enabled: bool)

var enabled := false:
	set(value):
		enabled = value
		visible = value
		enabled_changed.emit(value)

## One recycled label per tracked element, keyed by instance id (entities)
## or by a fixed name (panel entries).
var _labels: Dictionary = {} # Variant -> Label
var _slider: HSlider

const FONT_SIZE := 11
## Pixels above the entity anchor so the text does not sit on the sprite.
const OFFSET := Vector2(0, -14)
## Fixed panel padding from the top-right screen corner.
const PANEL_PAD := 16.0
const PANEL_WIDTH := 190.0
const LINE_HEIGHT := FONT_SIZE + 4.0

const COLOR_CORAL := Color(0.7, 1.0, 0.7)
const COLOR_CORAL_LOW := Color(1.0, 0.5, 0.5)
const COLOR_NEST := Color(1.0, 0.75, 0.35)
const COLOR_NEST_EMPTY := Color(0.55, 0.55, 0.55)
const COLOR_FISH := Color(0.7, 0.85, 1.0)
const COLOR_TEMP := Color(1.0, 1.0, 1.0)
const COLOR_DIM := Color(0.7, 0.7, 0.7)
const COLOR_ON := Color(0.7, 1.0, 0.7)
const COLOR_OFF := Color(1.0, 0.5, 0.5)


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


func _process(_delta: float) -> void:
	if not enabled:
		return
	_update_labels()
	_sync_slider()


## Positions the temperature slider inside the fixed panel and keeps its
## value in sync with Game.temperature.
func _sync_slider() -> void:
	var size := get_viewport_rect().size
	var x := size.x - PANEL_WIDTH - PANEL_PAD
	var y := PANEL_PAD + LINE_HEIGHT * 3.0 + 8.0
	_slider.position = Vector2(x, y)
	_slider.size = Vector2(PANEL_WIDTH, 20.0)
	_slider.value = Game.temperature


## Rebuilds the per-entity labels every frame so created/destroyed entities
## are tracked automatically. Also rebuilds the fixed panel.
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

	# --- Fixed panel: feature flags ---
	_set_label(&"_flags", "Feature flags:", Vector2(x, y), COLOR_TEMP, wanted)
	y += LINE_HEIGHT

	var co2_on := Game.actors.co2_dies_on_coral
	_set_label(&"_co2flag", "CO2 dies on coral: %s" % ("ON" if co2_on else "OFF"),
		Vector2(x, y), COLOR_ON if co2_on else COLOR_OFF, wanted)
	y += LINE_HEIGHT

	var pred_on := Game.actors.predator_enabled
	_set_label(&"_predatorflag", "Predator enabled: %s" % ("ON" if pred_on else "OFF"),
		Vector2(x, y), COLOR_ON if pred_on else COLOR_OFF, wanted)

	# --- Entities: coral oxygen / life ---
	for coral in get_tree().get_nodes_in_group(Groups.CORALS):
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
	for nest in get_tree().get_nodes_in_group(Groups.NESTS):
		if not _alive(nest):
			continue
		var id := nest.get_instance_id()
		var text := "EMPTY"
		if nest.has_eggs():
			text = "EGGS: %.1fs" % nest.eggs_time_left()
		var pos := _viewport_position(nest.global_position)
		var color := COLOR_NEST if nest.has_eggs() else COLOR_NEST_EMPTY
		_set_label(id, text, pos + OFFSET, color, wanted)

	# --- Entities: fish state + hunger ---
	for fish in get_tree().get_nodes_in_group(Groups.FISH):
		if not _alive(fish) or fish.brain == null:
			continue
		var id := fish.get_instance_id()
		var text := "%s h:%d%%" % [_state_name(fish.brain.state), (fish.brain.hunger_ratio() * 100.0)]
		var pos := _viewport_position(fish.global_position)
		_set_label(id, text, pos + OFFSET, COLOR_FISH, wanted)

	# Remove labels for elements that no longer exist.
	for id in _labels.keys():
		if not wanted.has(id):
			_labels[id].queue_free()
			_labels.erase(id)


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
