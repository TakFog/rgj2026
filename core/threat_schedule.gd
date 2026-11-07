class_name ThreatSchedule
extends RefCounted
## Independent spawn timers per threat type (GDD §6, §7). Pure: no scene tree.
## Timers are progress-based (progress += delta / interval), so a temperature
## change also speeds up the countdown that is already running.

enum Type { CO2, BAG, CYCLONE }

var _actors: BalanceActors
var _progress := {Type.CO2: 0.0, Type.BAG: 0.0, Type.CYCLONE: 0.0}


func _init(actors: BalanceActors) -> void:
	_actors = actors


## Seconds between two threats of `kind` at `temperature` (clamped to 0..1).
## Same curve as Game.by_temperature (roadmap contract #1). Bags ignore temperature.
func interval(kind: Type, temperature: float) -> float:
	var t := clampf(temperature, 0.0, 1.0)
	match kind:
		Type.CO2:
			return lerpf(_actors.co2_interval_cold, _actors.co2_interval_hot, t)
		Type.CYCLONE:
			return lerpf(_actors.cyclone_interval_cold, _actors.cyclone_interval_hot, t)
	return _actors.bag_interval


## Advances every timer and returns the threat types that are due now.
## Each type appears at most once per tick: a huge `delta` (hitch, debug skip)
## drops the extra spawns instead of releasing a burst. An interval <= 0
## disables that type (it is never due).
func tick(delta: float, temperature: float) -> Array[int]:
	var due: Array[int] = []
	for kind in _progress.keys():
		var seconds := interval(kind, temperature)
		if seconds <= 0.0:
			continue
		var progress: float = _progress[kind] + delta / seconds
		if progress >= 1.0:
			progress = fmod(progress - 1.0, 1.0)
			due.append(kind)
		_progress[kind] = progress
	return due
