class_name TurtleBrain
extends RefCounted
## Pure rules of the sea turtle helper (issue #4). It comes from outside the
## island to help: first it defends the fish from threats (rams the predator
## away, removes a plastic bag), then it cleans algae, much faster than fish.
## It leaves after removing a bag, after eating turtle_max_algae algae (if > 0),
## or after turtle_stay_seconds on the island.

enum State { HELPING, EATING, LEAVING }
## What the turtle swims to: a threat (predator or bag) beats any algae.
enum Task { NONE, THREAT, ALGAE }

var state := State.HELPING
## Seconds spent on the island so far (the swim in from the edge does not count).
var stay_time := 0.0
var algae_eaten := 0

var _cfg: BalanceActors
var _eat_timer := 0.0


func _init(cfg: BalanceActors) -> void:
	_cfg = cfg


## Picks the next job from route lengths (INF = unreachable): the nearest
## reachable threat if any, else the nearest reachable algae.
## Returns `{task: Task, index: int}` (index -1 with Task.NONE).
static func pick(threat_costs: Array, algae_costs: Array) -> Dictionary:
	var threat := _nearest(threat_costs)
	if threat >= 0:
		return {"task": Task.THREAT, "index": threat}
	var algae := _nearest(algae_costs)
	if algae >= 0:
		return {"task": Task.ALGAE, "index": algae}
	return {"task": Task.NONE, "index": -1}


## `on_island`: whether the turtle is over the island (only then its stay runs
## out). Returns true on the tick an algae finishes being eaten.
func tick(delta: float, on_island := true) -> bool:
	if state == State.LEAVING:
		return false
	if on_island:
		stay_time += delta
	var finished := false
	if state == State.EATING:
		_eat_timer -= delta
		if _eat_timer <= 0.0:
			finished = true
			algae_eaten += 1
			state = State.HELPING
			if _cfg.turtle_max_algae > 0 and algae_eaten >= _cfg.turtle_max_algae:
				state = State.LEAVING
	if stay_time >= _cfg.turtle_stay_seconds:
		state = State.LEAVING
	return finished


## Reached an algae: start munching it.
func start_eating() -> void:
	if state != State.HELPING:
		return
	state = State.EATING
	_eat_timer = _cfg.turtle_eat_seconds


## The algae vanished, or a threat showed up: drop it and get back to helping.
func stop_eating() -> void:
	if state == State.EATING:
		state = State.HELPING


## The turtle removed a plastic bag: its job is done, it leaves.
func bag_removed() -> void:
	state = State.LEAVING


static func _nearest(costs: Array) -> int:
	var best := -1
	for i in costs.size():
		if is_inf(costs[i]):
			continue
		if best == -1 or costs[i] < costs[best]:
			best = i
	return best
