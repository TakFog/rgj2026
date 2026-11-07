class_name PredatorBrain
extends RefCounted
## Pure rules of the carnivorous predator fish (issue #3): it hunts fish and
## eggs until sated, then leaves; it also leaves if it cannot get sated within
## predator_hunt_seconds. Prey is chosen by satisfaction / route length.

enum State { HUNTING, BITING, LEAVING }
enum Prey { JUVENILE, ADULT, EGGS }

## Route lengths below this (world units) count as this, so prey right next to
## the predator does not get an infinite score.
const MIN_DISTANCE := 1.0

var state := State.HUNTING
var satiety := 0.0
## Seconds spent hunting on the island so far (the swim in from the edge of
## the screen does not count).
var hunt_time := 0.0

var _cfg: BalanceActors
var _timer := 0.0


func _init(cfg: BalanceActors) -> void:
	_cfg = cfg


## Satisfaction given by one prey. Eggs are worth one juvenile per egg that
## would hatch, so they hurt the player most.
static func satisfaction(cfg: BalanceActors, prey: Prey, hatch_count: int) -> float:
	match prey:
		Prey.JUVENILE:
			return cfg.predator_juvenile_satisfaction
		Prey.ADULT:
			return cfg.predator_adult_satisfaction
	return cfg.predator_juvenile_satisfaction * hatch_count


## Attractiveness of a prey: satisfaction per unit of route to swim.
static func score(prey_satisfaction: float, distance: float) -> float:
	return prey_satisfaction / maxf(distance, MIN_DISTANCE)


## Index of the best candidate (`{satisfaction, distance}` dictionaries;
## unreachable ones have distance INF and are ignored), or -1.
static func pick_best(candidates: Array) -> int:
	var best := -1
	var best_score := 0.0
	for i in candidates.size():
		var candidate: Dictionary = candidates[i]
		if is_inf(candidate["distance"]):
			continue
		var value := score(candidate["satisfaction"], candidate["distance"])
		if best == -1 or value > best_score:
			best = i
			best_score = value
	return best


func satiety_ratio() -> float:
	return clampf(satiety / _cfg.predator_satiety, 0.0, 1.0)


## `on_island`: whether the predator is over the island (only then the hunting
## time runs out).
func tick(delta: float, on_island := true) -> void:
	if state == State.LEAVING:
		return
	if on_island:
		hunt_time += delta
	if state == State.BITING:
		_timer -= delta
		if _timer <= 0.0:
			state = State.HUNTING
	if hunt_time >= _cfg.predator_hunt_seconds:
		state = State.LEAVING


## The predator swallowed a prey worth `amount`: pause briefly, or leave if sated.
func ate(amount: float) -> void:
	if state == State.LEAVING:
		return
	satiety += amount
	if satiety >= _cfg.predator_satiety:
		state = State.LEAVING
	else:
		state = State.BITING
		_timer = _cfg.predator_bite_pause_seconds
