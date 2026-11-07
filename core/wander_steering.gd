class_name WanderSteering
extends RefCounted
## Random wandering for fish (GDD §5.4): keep a random heading for a random
## time, then pick another; when blocked, turn away from the obstacle.

## Max deviation from the obstacle normal when bouncing (just under 90°).
const BOUNCE_SPREAD := PI * 0.45

var heading := Vector2.RIGHT

var _rng: RandomNumberGenerator
var _min_seconds: float
var _max_seconds: float
var _time_left := 0.0


func _init(rng: RandomNumberGenerator, min_seconds: float, max_seconds: float) -> void:
	_rng = rng
	_min_seconds = min_seconds
	_max_seconds = max_seconds
	_pick(Vector2.from_angle(_rng.randf_range(0.0, TAU)))


## Advances the timer and returns the heading to swim along this frame.
func tick(delta: float) -> Vector2:
	_time_left -= delta
	if _time_left <= 0.0:
		_pick(Vector2.from_angle(_rng.randf_range(0.0, TAU)))
	return heading


## Called when the fish bumps into something; `normal` points away from it.
func on_blocked(normal: Vector2) -> void:
	if normal == Vector2.ZERO:
		_pick(Vector2.from_angle(_rng.randf_range(0.0, TAU)))
		return
	_pick(normal.normalized().rotated(_rng.randf_range(-BOUNCE_SPREAD, BOUNCE_SPREAD)))


func _pick(new_heading: Vector2) -> void:
	heading = new_heading
	_time_left = _rng.randf_range(_min_seconds, _max_seconds)
