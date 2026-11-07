class_name TemperatureModel
extends RefCounted
## Ever-rising normalised temperature (GDD §6), slowed by living coral cells.
## dT/dt = base_rate * (1 - min(coral_cells * slow_per_cell, max_slowdown)).

var base_rate: float
var slow_per_cell: float
var max_slowdown: float
var value := 0.0


func _init(p_base_rate: float, p_slow_per_cell: float, p_max_slowdown: float) -> void:
	base_rate = p_base_rate
	slow_per_cell = p_slow_per_cell
	max_slowdown = p_max_slowdown


func slowdown(coral_cells: int) -> float:
	return minf(coral_cells * slow_per_cell, max_slowdown)


## Never decreases (max_slowdown < 1) and never exceeds 1.0.
func tick(delta: float, coral_cells: int) -> void:
	value = minf(value + base_rate * (1.0 - slowdown(coral_cells)) * delta, 1.0)


static func to_celsius(normalised: float, min_c: float, max_c: float) -> float:
	return lerpf(min_c, max_c, clampf(normalised, 0.0, 1.0))
