class_name AlgaeSpread
extends RefCounted
## Pure rules of one algae expansion attempt (GDD §5.3).

enum Outcome { SPAWN, DAMAGE_CORAL, BLOCKED }


## Tries the 4 neighbours of `origin` in random order:
## - empty and not covered by an actor -> SPAWN there
## - occupied by a coral -> DAMAGE_CORAL (that coral)
## - anything else (out of map, algae, nest, covered by fish/threat) -> next
## Returns { "outcome": Outcome, "cell": Vector2i, "target": Object }.
## `is_coral(occupant) -> bool`, `is_covered(cell) -> bool` are injected for testability.
static func attempt(origin: Vector2i, grid: GridModel, rng: RandomNumberGenerator,
		is_coral: Callable, is_covered: Callable) -> Dictionary:
	var candidates := grid.neighbors4(origin)
	_shuffle(candidates, rng)
	for cell in candidates:
		if not grid.in_bounds(cell):
			continue
		var occupant := grid.occupant(cell)
		if occupant == null:
			if is_covered.call(cell):
				continue
			return {"outcome": Outcome.SPAWN, "cell": cell, "target": null}
		if is_coral.call(occupant):
			return {"outcome": Outcome.DAMAGE_CORAL, "cell": cell, "target": occupant}
	return {"outcome": Outcome.BLOCKED, "cell": origin, "target": null}


## Base interval randomised by ±jitter (e.g. 0.2 = ±20%).
static func next_interval(base: float, jitter: float, rng: RandomNumberGenerator) -> float:
	return base * rng.randf_range(1.0 - jitter, 1.0 + jitter)


## Fisher-Yates shuffle driven by `rng` (deterministic with a seed).
static func _shuffle(cells: Array[Vector2i], rng: RandomNumberGenerator) -> void:
	for i in range(cells.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp := cells[i]
		cells[i] = cells[j]
		cells[j] = tmp
