class_name CollapseTracker
extends RefCounted
## Per-population collapse countdowns (GDD §3).
## A population at zero starts its own countdown of `grace_seconds`; going back
## above zero cancels it; going to zero again restarts it from full. The first
## countdown to expire collapses the ecosystem (final). Advance with tick(delta).

signal countdown_started(population: StringName)
signal countdown_cancelled(population: StringName)
signal collapsed(population: StringName)

var grace_seconds: float
var collapsed_population: StringName = &""
var _remaining: Dictionary = {} # StringName -> float, only populations at zero
var _collapsed := false


func _init(p_grace_seconds: float) -> void:
	grace_seconds = p_grace_seconds


## Report the latest count of `population`. Call every frame for every population.
func report(population: StringName, count: int) -> void:
	if _collapsed:
		return
	if count <= 0:
		if not _remaining.has(population):
			_remaining[population] = grace_seconds
			countdown_started.emit(population)
	elif _remaining.has(population):
		_remaining.erase(population)
		countdown_cancelled.emit(population)


func tick(delta: float) -> void:
	if _collapsed:
		return
	var expired: StringName = &""
	var lowest := INF
	for population: StringName in _remaining.keys():
		var left: float = _remaining[population] - delta
		_remaining[population] = left
		if left <= 0.0 and left < lowest:
			lowest = left
			expired = population
	if expired != &"":
		_collapsed = true
		collapsed_population = expired
		collapsed.emit(expired)


func is_counting(population: StringName) -> bool:
	return _remaining.has(population)


## Seconds left before `population` collapses the ecosystem, or -1.0 if not counting.
func time_left(population: StringName) -> float:
	return _remaining.get(population, -1.0)


func is_collapsed() -> bool:
	return _collapsed


## The counting population closest to expiry, or &"" if none is counting.
func most_urgent() -> StringName:
	var result: StringName = &""
	var lowest := INF
	for population: StringName in _remaining.keys():
		if _remaining[population] < lowest:
			lowest = _remaining[population]
			result = population
	return result
