class_name Algae
extends StaticBody2D
## Algae: single-cell obstacle that spreads and suffocates corals (GDD §5.3).
## CONTRACT (used by Dev B fish/threats): cell, on_co2_absorbed(), destroy(),
## eater / is_taken_by_other() (one fish reserves an algae at a time).

signal destroyed

## Temporary art, until the designer's algae sprite is ready.
const TEXTURE := preload("res://assets/sprites/temp/algae.svg")

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
	var visual := PlaceholderShape.cell(position, Color(0.3, 0.8, 0.35))
	visual.add_sprite(TEXTURE, 0.8)
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


func _is_coral(entity: Object) -> bool:
	return entity is Coral


## Pure rule behind is_taken_by_other(). Untyped `p_eater`: it may be freed.
static func taken_by_other(p_eater: Variant, algae: Object, fish: Object) -> bool:
	return is_instance_valid(p_eater) and p_eater != fish and p_eater.holds(algae)
