class_name TumbleSpin
extends RefCounted
## Cosmetic tumble of a sprite floating in the current (plastic bag): the angle
## turns in a random direction, its rate wandering between a near stall and
## max_speed and sometimes reversing. Purely visual — it never drives gameplay.

## How fast the rate eases toward its current target, per second.
const RATE_CHANGE := 2.5
## Shortest / longest time, in seconds, a spin target is kept before re-rolling.
const SPIN_SECONDS_MIN := 0.2
const SPIN_SECONDS_MAX := 0.6
## A stall target lasts longer than a spin one, so the bag really comes to a
## near-stop before it picks up the current again.
const STALL_SECONDS_MIN := 0.6
const STALL_SECONDS_MAX := 1.2
## Chance a new target is a stall (rate eased to 0) instead of a spin.
const STALL_CHANCE := 0.3

var max_speed: float
## Current angle, radians, wrapped to [-PI, PI].
var angle := 0.0
## Current angular velocity, signed radians per second.
var rate := 0.0

var _rng: RandomNumberGenerator
var _target := 0.0
var _time_to_retarget := 0.0


func _init(p_max_speed: float, rng: RandomNumberGenerator) -> void:
	max_speed = p_max_speed
	_rng = rng
	angle = _rng.randf_range(-PI, PI)
	if max_speed > 0.0:
		var direction := 1.0 if _rng.randf() < 0.5 else -1.0
		rate = _rng.randf_range(0.3, 1.0) * max_speed * direction
		_pick_target()


## Returns the new angle after `delta` seconds. A max_speed of 0 freezes it.
func step(delta: float) -> float:
	if max_speed <= 0.0:
		return angle
	_time_to_retarget -= delta
	if _time_to_retarget <= 0.0:
		_pick_target()
	rate = lerpf(rate, _target, clampf(RATE_CHANGE * delta, 0.0, 1.0))
	angle = wrapf(angle + rate * delta, -PI, PI)
	return angle


## Picks where the rate is heading: sometimes a stall, otherwise a random spin
## speed in either direction.
func _pick_target() -> void:
	if _rng.randf() < STALL_CHANCE:
		_target = 0.0
		_time_to_retarget = _rng.randf_range(STALL_SECONDS_MIN, STALL_SECONDS_MAX)
		return
	var direction := 1.0 if _rng.randf() < 0.5 else -1.0
	_target = _rng.randf_range(0.2, 1.0) * max_speed * direction
	_time_to_retarget = _rng.randf_range(SPIN_SECONDS_MIN, SPIN_SECONDS_MAX)
