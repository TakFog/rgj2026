extends Node
## Spawns threats on the border of the visible seabed, aimed at the island
## (GDD §7). No warning: the player sees them crossing the seabed.
## Pausable; timers advance with delta only.

var _schedule: ThreatSchedule
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	_schedule = ThreatSchedule.new(Game.actors)


func _process(delta: float) -> void:
	for kind in _schedule.tick(delta, Game.temperature):
		var island := Rect2(Vector2.ZERO, Game.grid.world_size())
		spawn(kind, EdgeEntry.random(_rng, Game.visible_world_polygon(), island), _rng)


## Creates a threat of `kind` entering at `entry` and adds it to the world.
static func spawn(kind: int, entry: EdgeEntry, rng: RandomNumberGenerator) -> Threat:
	var threat: Threat
	match kind:
		ThreatSchedule.Type.CO2:
			threat = Co2Cloud.new()
		ThreatSchedule.Type.BAG:
			threat = PlasticBag.new()
		_:
			threat = Cyclone.new()
	threat.setup(entry, rng)
	Game.world.add_child(threat)
	return threat
