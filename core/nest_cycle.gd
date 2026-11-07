class_name NestCycle
extends RefCounted
## Nest life cycle (GDD §5.5): EMPTY -> (fertilize) -> EGGS -> hatch -> EMPTY.

signal hatched(count: int)
signal eggs_died

enum State { EMPTY, EGGS }

var hatch_seconds: float
var hatch_count: int
var state := State.EMPTY
var _time_left := 0.0
var _rng := RandomNumberGenerator.new()


func _init(p_hatch_seconds: float, p_hatch_count: int) -> void:
	hatch_seconds = p_hatch_seconds
	hatch_count = p_hatch_count
	_rng.randomize()


## Starts the eggs. Returns false (and does nothing) if the nest already has eggs.
func fertilize() -> bool:
	if state != State.EMPTY:
		return false
	state = State.EGGS
	_time_left = hatch_seconds
	return true


## CO2: the eggs die and the nest becomes empty.
func kill_eggs() -> void:
	state = State.EMPTY
	_time_left = 0.0


## Advances the eggs. `death_hazard_per_sec` is the heat-driven mortality
## hazard: the chance to die over the full hatch time is
## `hazard_from_chance(chance, hatch_seconds)`.
func tick(delta: float, death_hazard_per_sec: float = 0.0) -> void:
	if state != State.EGGS:
		return
	if death_hazard_per_sec > 0.0 and _rng.randf() < death_chance_per_tick(death_hazard_per_sec, delta):
		state = State.EMPTY
		_time_left = 0.0
		eggs_died.emit()
		return
	_time_left -= delta
	if _time_left <= 0.0:
		state = State.EMPTY
		_time_left = 0.0
		hatched.emit(hatch_count)


## Converts a desired chance over the whole incubation into a per-second hazard.
static func hazard_from_chance(chance_per_hatch: float, hatch_seconds: float) -> float:
	if chance_per_hatch <= 0.0 or hatch_seconds <= 0.0:
		return 0.0
	var chance := minf(chance_per_hatch, 0.999)
	return -log(1.0 - chance) / hatch_seconds


## Probability of dying during `delta` seconds at the given hazard.
static func death_chance_per_tick(hazard_per_sec: float, delta: float) -> float:
	return 1.0 - exp(-maxf(hazard_per_sec, 0.0) * delta)


## Seconds until hatching, or -1.0 if there are no eggs.
func eggs_time_left() -> float:
	return _time_left if state == State.EGGS else -1.0
