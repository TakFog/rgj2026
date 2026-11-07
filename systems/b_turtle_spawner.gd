extends Node
## Sends a sea turtle helper onto the island every turtle_interval seconds
## (issue #4), entering from the border of the visible seabed like a threat.
## Disabled entirely when Game.actors.turtle_enabled is false (feature flag).
## Pausable; the timer advances with delta only.

var _progress := 0.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()


func _process(delta: float) -> void:
	if not Game.actors.turtle_enabled:
		return
	_progress += delta / Game.actors.turtle_interval
	if _progress < 1.0:
		return
	_progress -= 1.0
	if get_tree().get_nodes_in_group(Groups.TURTLES).size() >= Game.actors.turtle_max_count:
		return
	var island := Rect2(Vector2.ZERO, Game.grid.world_size())
	Game.factory.spawn_turtle(EdgeEntry.random(_rng, Game.visible_world_polygon(), island))
