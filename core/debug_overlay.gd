class_name DebugOverlay
extends Control
## Debug overlay toggled with F3 (GDD §9).
## Draws per-entity debug numbers over everything in screen space:
## coral oxygen/life, nest hatch time, fish state + hunger, algae cell,
## threat kind + radius, plus the global temperature.

signal enabled_changed(enabled: bool)

var enabled := false:
	set(value):
		enabled = value
		visible = value
		enabled_changed.emit(value)

## One recycled label per tracked entity, keyed by instance id.
var _labels: Dictionary = {} # int -> Label

const FONT_SIZE := 11
## Pixels above the entity anchor so the text does not sit on the sprite.
const OFFSET := Vector2(0, -14)

const COLOR_CORAL := Color(0.7, 1.0, 0.7)
const COLOR_CORAL_LOW := Color(1.0, 0.5, 0.5)
const COLOR_NEST := Color(1.0, 0.75, 0.35)
const COLOR_NEST_EMPTY := Color(0.55, 0.55, 0.55)
const COLOR_FISH := Color(0.7, 0.85, 1.0)
const COLOR_ALGAE := Color(0.7, 1.0, 0.7)
const COLOR_THREAT := Color(1.0, 0.55, 0.55)
const COLOR_TEMP := Color(1.0, 1.0, 1.0)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	Game.debug_mode_changed.connect(_on_debug_mode_changed)
	visible = Game.debug_mode


func _on_debug_mode_changed(value: bool) -> void:
	enabled = value
	visible = value
	if not value:
		_clear_labels()


func _process(_delta: float) -> void:
	if not enabled:
		return
	_update_labels()


## Rebuilds the per-entity labels every frame so created/destroyed entities
## are tracked automatically.
func _update_labels() -> void:
	var wanted := {} # int -> true, ids present this frame

	# Global temperature at the top-left of the world.
	var temp_pos := _viewport_position(Vector2.ZERO)
	_set_label(&"_temp", "T: %.2f" % Game.temperature, temp_pos + OFFSET, COLOR_TEMP, wanted)

	# --- Corals: oxygen / life ---
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

	# --- Nests: hatch time or empty ---
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

	# --- Algae: cell coordinates ---
	for algae in get_tree().get_nodes_in_group(Groups.ALGAE):
		if not _alive(algae):
			continue
		var id := algae.get_instance_id()
		var text := "ALGAE (%d,%d)" % [algae.cell.x, algae.cell.y]
		var pos := _viewport_position(algae.global_position)
		_set_label(id, text, pos + OFFSET, COLOR_ALGAE, wanted)

	# --- Fish: state + hunger ---
	for fish in get_tree().get_nodes_in_group(Groups.FISH):
		if not _alive(fish) or fish.brain == null:
			continue
		var id := fish.get_instance_id()
		var text := "%s h:%d%%" % [_state_name(fish.brain.state), (fish.brain.hunger_ratio() * 100.0)]
		var pos := _viewport_position(fish.global_position)
		_set_label(id, text, pos + OFFSET, COLOR_FISH, wanted)

	# --- Threats: kind + radius ---
	for threat in get_tree().get_nodes_in_group(Groups.THREATS):
		if not _alive(threat):
			continue
		var id := threat.get_instance_id()
		var text := "%s r:%.0f" % [_threat_name(threat.kind), threat.radius]
		var pos := _viewport_position(threat.global_position)
		_set_label(id, text, pos + OFFSET, COLOR_THREAT, wanted)

	# Remove labels for entities that no longer exist.
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


func _threat_name(kind: int) -> String:
	match kind:
		ThreatSchedule.Type.CO2: return "CO2"
		ThreatSchedule.Type.BAG: return "BAG"
		ThreatSchedule.Type.CYCLONE: return "CYCLONE"
		_: return "?"


func _clear_labels() -> void:
	for label in _labels.values():
		label.queue_free()
	_labels.clear()
