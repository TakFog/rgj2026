extends Node
## Announces threats at the map edge and spawns them after
## threat_warning_seconds (GDD §7). Pausable; timers advance with delta only.

const ThreatWarning := preload("res://ui/b_threat_warning.gd")
## ±30° around the inward direction.
const ENTRY_SPREAD := 0.5236


class Pending:
	var kind: int
	var entry: EdgeEntry
	var time_left: float
	var warning: Node


var _schedule: ThreatSchedule
var _rng := RandomNumberGenerator.new()
var _pending: Array[Pending] = []


func _ready() -> void:
	_rng.randomize()
	_schedule = ThreatSchedule.new(Game.actors)


func _process(delta: float) -> void:
	for kind in _schedule.tick(delta, Game.temperature):
		_announce(kind)
	for i in range(_pending.size() - 1, -1, -1):
		var pending := _pending[i]
		pending.time_left -= delta
		if pending.time_left <= 0.0:
			_pending.remove_at(i)
			if is_instance_valid(pending.warning):
				pending.warning.queue_free()
			spawn(pending.kind, pending.entry, _rng)


func _announce(kind: int) -> void:
	var pending := Pending.new()
	pending.kind = kind
	pending.entry = EdgeEntry.random(_rng, Game.grid.world_size(), ENTRY_SPREAD)
	pending.time_left = Game.actors.threat_warning_seconds
	var warning := ThreatWarning.new()
	warning.setup(kind, pending.entry)
	Game.ui.add_child(warning)
	pending.warning = warning
	_pending.append(pending)


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
