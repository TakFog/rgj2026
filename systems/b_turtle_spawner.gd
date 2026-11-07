extends Node
## Sends a sea turtle helper onto the island every turtle_interval seconds
## (issue #4), entering from the border of the visible seabed like a threat.
## Some runs also start with an early turtle rush (see core/turtle_rush.gd):
## a small group arrives together, before the algae have spread, and can eat
## them down to zero if the player does not react.
## Disabled entirely when Game.actors.turtle_enabled is false (feature flag).
## Pausable; both timers advance with delta only.

var _progress := 0.0
var _rush: TurtleRush
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	_rush = TurtleRush.new(Game.actors, _rng)


func _process(delta: float) -> void:
	if not Game.actors.turtle_enabled:
		return
	var step := Game.frame_step(delta)
	for _i in _rush.tick(step):
		# The rush deliberately ignores turtle_max_count: that cap paces the
		# normal helper, while this is a one-shot group event.
		_spawn(Game.actors.turtle_rush_max_algae)
	_progress += step / Game.actors.turtle_interval
	if _progress < 1.0:
		return
	_progress -= 1.0
	if get_tree().get_nodes_in_group(Groups.TURTLES).size() >= Game.actors.turtle_max_count:
		return
	_spawn()


## Spawns one turtle from a random edge of the visible seabed.
func _spawn(max_algae := -1) -> void:
	var island := Rect2(Vector2.ZERO, Game.grid.world_size())
	Game.factory.spawn_turtle(EdgeEntry.random(_rng, Game.visible_world_polygon(), island), max_algae)
