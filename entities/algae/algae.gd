class_name Algae
extends StaticBody2D
## Algae: single-cell obstacle that spreads and suffocates corals (GDD §5.3).
## CONTRACT (used by Dev B fish/threats): cell, on_co2_absorbed(), destroy(),
## eater / is_taken_by_other() (one fish reserves an algae at a time).

signal destroyed
## Used by the audio system (systems/b_audio.gd).
signal spread

const TEXTURE := preload("res://assets/sprites/algae.png")
## Swaying movement of the plant underwater (fragment-space UV warp).
const SWAY_SHADER := preload("res://entities/algae/algae_sway.gdshader")
## Alpha of the coloured cell drawn under the sprite.
const FOOTPRINT_ALPHA := 0.3
## The art is a dark, detailed clump; lift it so it reads green on bright sand.
const SPRITE_TINT := Color(1.8, 1.8, 1.8)

var cell: Vector2i
## Last fish that reserved this algae (to swim to it or eat it), or null. It
## only counts while that fish still reports holds(self), so no release
## bookkeeping is needed.
var eater: Object = null

var _rng := RandomNumberGenerator.new()
var _time_to_grow := 0.0


func setup(p_cell: Vector2i) -> void:
	cell = p_cell


func _ready() -> void:
	position = Game.grid.cell_to_world(cell)
	collision_layer = Layers.ALGAE
	collision_mask = 0
	add_to_group(Groups.ALGAE)
	Game.grid.occupy([cell], self)
	CellShapes.add_collision(self, [cell], cell)
	# Flat ground cover: drawn below the y-sorted actors, so the predator and
	# the turtle swimming over an algae stay on top of it.
	# Faint footprint: the sprite does the reading, the cell only grounds it.
	var visual := PlaceholderShape.cell(position, Color(0.3, 0.8, 0.35, FOOTPRINT_ALPHA))
	var sprite := visual.add_sprite(TEXTURE, 1.6)
	sprite.modulate = SPRITE_TINT
	sprite.material = _sway_material(cell)
	ViewFollower.attach(self, visual).z_index = -1
	_rng.randomize()
	_reset_timer()


func _physics_process(delta: float) -> void:
	_time_to_grow -= delta
	if _time_to_grow <= 0.0:
		_reset_timer()
		try_expand()


## One expansion attempt (GDD §5.3). Skipped when the algae cap is reached.
func try_expand() -> void:
	if is_queued_for_deletion():
		return
	if get_tree().get_nodes_in_group(Groups.ALGAE).size() >= Game.eco.algae_max_count:
		return
	var result := AlgaeSpread.attempt(cell, Game.grid, _rng, _is_coral, CellProbe.is_covered_by_actor)
	match result["outcome"]:
		AlgaeSpread.Outcome.SPAWN:
			Game.factory.spawn_algae(result["cell"])
			spread.emit()
		AlgaeSpread.Outcome.DAMAGE_CORAL:
			(result["target"] as Coral).apply_oxygen_damage(Game.eco.algae_coral_damage)


## Called by a CO2 cloud that touches this algae: the cloud is absorbed and the
## algae expands immediately. Deferred: B3 calls this from a physics callback.
func on_co2_absorbed() -> void:
	try_expand.call_deferred()


## True if a fish other than `fish` has reserved this algae right now.
func is_taken_by_other(fish: Object) -> bool:
	return taken_by_other(eater, self, fish)


func destroy() -> void:
	if is_queued_for_deletion():
		return
	remove_from_group(Groups.ALGAE)
	Game.grid.release([cell])
	destroyed.emit()
	queue_free()


func _reset_timer() -> void:
	var base := Game.by_temperature(Game.eco.algae_growth_interval_cold, Game.eco.algae_growth_interval_hot)
	_time_to_grow = AlgaeSpread.next_interval(base, Game.eco.algae_growth_jitter, _rng)


## Per-cell phase: neighbouring algae sway independently instead of in lockstep.
func _sway_material(at_cell: Vector2i) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = SWAY_SHADER
	material.set_shader_parameter("phase", float(at_cell.x) * 0.73 + float(at_cell.y) * 1.21)
	return material


func _is_coral(entity: Object) -> bool:
	return entity is Coral


## Pure rule behind is_taken_by_other(). Untyped `p_eater`: it may be freed.
static func taken_by_other(p_eater: Variant, algae: Object, fish: Object) -> bool:
	return is_instance_valid(p_eater) and p_eater != fish and p_eater.holds(algae)
