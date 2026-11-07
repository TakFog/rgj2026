class_name DriftMotion
extends RefCounted
## Smooth random heading for drifting threats (GDD §7: "almost straight with
## random curves" for CO2, "more random" for bags, straight for cyclones).
## The turn rate random-walks within ±turn_noise rad/s.

## How fast the turn rate itself changes, relative to turn_noise.
const RATE_CHANGE := 3.0

var turn_noise: float
var _rng: RandomNumberGenerator
var _turn_rate := 0.0


func _init(p_turn_noise: float, rng: RandomNumberGenerator) -> void:
	turn_noise = p_turn_noise
	_rng = rng


## Returns the heading after `delta` seconds. Never turns more than turn_noise * delta.
func step(heading: float, delta: float) -> float:
	if turn_noise <= 0.0:
		return heading
	var change := _rng.randf_range(-1.0, 1.0) * turn_noise * RATE_CHANGE * delta
	_turn_rate = clampf(_turn_rate + change, -turn_noise, turn_noise)
	return heading + _turn_rate * delta
