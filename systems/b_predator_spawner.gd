extends Node
## Sends a carnivorous predator onto the island every predator_interval seconds
## (issue #3), entering from the border of the visible seabed like a threat.
## Disabled entirely when Game.actors.predator_enabled is false (feature flag).
## Pausable; the timer advances with delta only.

var _progress := 0.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()


func _process(delta: float) -> void:
	if not Game.actors.predator_enabled:
		return
	_progress += Game.frame_step(delta) / Game.actors.predator_interval
	if _progress < 1.0:
		return
	_progress -= 1.0
	if get_tree().get_nodes_in_group(Groups.PREDATORS).size() >= Game.actors.predator_max_count:
		return
	var island := Rect2(Vector2.ZERO, Game.grid.world_size())
	Game.factory.spawn_predator(EdgeEntry.random(_rng, Game.visible_world_polygon(), island))
