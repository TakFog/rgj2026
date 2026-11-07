class_name NestCycle
extends RefCounted
## Nest life cycle (GDD §5.5): EMPTY -> (fertilize) -> EGGS -> hatch -> EMPTY.

signal hatched(count: int)

enum State { EMPTY, EGGS }

var hatch_seconds: float
var hatch_count: int
var state := State.EMPTY
var _time_left := 0.0


func _init(p_hatch_seconds: float, p_hatch_count: int) -> void:
	hatch_seconds = p_hatch_seconds
	hatch_count = p_hatch_count


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


func tick(delta: float) -> void:
	if state != State.EGGS:
		return
	_time_left -= delta
	if _time_left <= 0.0:
		state = State.EMPTY
		_time_left = 0.0
		hatched.emit(hatch_count)


## Seconds until hatching, or -1.0 if there are no eggs.
func eggs_time_left() -> float:
	return _time_left if state == State.EGGS else -1.0
