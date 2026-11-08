class_name LevelClock
extends RefCounted
## Countdown of one level's time limit. Pure: no scene tree, no pause handling.
## The caller ticks it with the already-capped frame step and reacts to the
## single `true` returned when the countdown reaches zero.

var duration := 0.0
var remaining := 0.0
var finished := false


func _init(p_duration: float) -> void:
	duration = maxf(0.0, p_duration)
	remaining = duration


## Advances the countdown. Returns true exactly once, on the tick that ends it.
func tick(delta: float) -> bool:
	if finished or delta <= 0.0:
		return false
	remaining = maxf(0.0, remaining - delta)
	if remaining > 0.0:
		return false
	finished = true
	return true


## Seconds survived in this level (duration - remaining).
func elapsed() -> float:
	return duration - remaining
