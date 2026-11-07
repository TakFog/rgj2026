class_name CoralOxygen
extends RefCounted
## Oxygen of one coral (GDD §5.2): instant damage, slow regen, dies at 0.

signal depleted

var max_oxygen: float
var regen_per_sec: float
var value: float
var dead := false


func _init(p_max_oxygen: float, p_regen_per_sec: float) -> void:
	max_oxygen = p_max_oxygen
	regen_per_sec = p_regen_per_sec
	value = p_max_oxygen


## Instant damage. Emits `depleted` once when oxygen reaches 0.
func damage(amount: float) -> void:
	if dead:
		return
	value = maxf(value - amount, 0.0)
	if value <= 0.0:
		dead = true
		depleted.emit()


## Slow regeneration, capped at max_oxygen. A negative regen drains oxygen
## and kills the coral at 0 (hot water). Dead corals do not tick.
func tick(delta: float) -> void:
	if dead:
		return
	value = clampf(value + regen_per_sec * delta, 0.0, max_oxygen)
	if value <= 0.0:
		dead = true
		depleted.emit()


func ratio() -> float:
	return value / max_oxygen
