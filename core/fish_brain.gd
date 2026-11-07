class_name FishBrain
extends RefCounted
## Pure fish rules (GDD §5.4): state machine, hunger, maturity.
## The Fish node feeds it sensor events and executes its decisions.

signal starved
signal matured
signal eat_finished(algae: Object)
signal fertilize_finished(nest: Object)

enum State { WANDER, ORDERED, EATING, FERTILIZING, IDLE, SEEKING_FOOD, SEEKING_NEST }

var state := State.WANDER
## Order destination in world units (meaningful while ORDERED).
var target := Vector2.ZERO
## Seconds since the last meal.
var hunger := 0.0
## Seconds lived as a juvenile (stops counting once adult).
var age := 0.0
var adult: bool
var dead := false
## Algae being eaten while EATING, or swum to while SEEKING_FOOD, otherwise null.
var food: Object = null
## Nest being fertilized while FERTILIZING, otherwise null.
var nest: Object = null
## Seconds between two autonomous fertilizations. A negative constructor
## argument means "use cfg.reproduce_cooldown_seconds".
var reproduce_cooldown_seconds: float

var _cfg: BalanceActors
var _timer := 0.0
## Seconds before a wandering hungry fish looks for food again.
var _seek_cooldown := 0.0
## Seconds before a wandering fish looks for an empty nest again.
var _nest_seek_cooldown := 0.0
## Seconds left before the fish may reproduce again.
var _reproduce_cooldown := 0.0


func _init(cfg: BalanceActors, p_adult: bool, p_reproduce_cooldown_seconds := -1.0) -> void:
	_cfg = cfg
	adult = p_adult
	reproduce_cooldown_seconds = p_reproduce_cooldown_seconds \
		if p_reproduce_cooldown_seconds >= 0.0 else cfg.reproduce_cooldown_seconds
	_reproduce_cooldown = reproduce_cooldown_seconds


## Cooldown between autonomous fertilizations, never shorter than twice the
## nest hatching time.
static func effective_reproduce_cooldown(cfg: BalanceActors, hatch_seconds: float) -> float:
	return maxf(cfg.reproduce_cooldown_seconds, hatch_seconds * 2.0)


func is_adult() -> bool:
	return adult


func hunger_ratio() -> float:
	return clampf(hunger / _cfg.starve_seconds, 0.0, 1.0)


## True when the node should move this frame (wandering, following an order
## or swimming to food).
func wants_to_move() -> bool:
	return not dead and (state == State.WANDER or state == State.ORDERED or state == State.SEEKING_FOOD \
		or state == State.SEEKING_NEST)


## True when a wandering fish is hungry enough to look for food on its own.
func wants_to_seek_food() -> bool:
	return not dead and state == State.WANDER and _seek_cooldown <= 0.0 \
		and hunger_ratio() >= _cfg.seek_food_threshold


## The node found a reachable algae: swim to it. Only from WANDER (or to switch
## target while already seeking), so orders and timed states are never interrupted.
func seek_food(algae: Object) -> void:
	if dead or (state != State.WANDER and state != State.SEEKING_FOOD):
		return
	_enter(State.SEEKING_FOOD)
	food = algae


## The node found no reachable algae: keep wandering, retry later.
func seek_failed() -> void:
	_seek_cooldown = _cfg.seek_retry_seconds


## True when a wandering adult fish is fed, off cooldown, and may look for an
## empty nest on its own.
func wants_to_seek_nest() -> bool:
	return not dead and adult and state == State.WANDER \
		and hunger_ratio() < _cfg.seek_food_threshold \
		and _reproduce_cooldown <= 0.0 and _nest_seek_cooldown <= 0.0


## The node found a reachable empty nest: swim to it. Only from WANDER, so an
## order or another drive is never interrupted.
func seek_nest(target: Object) -> void:
	if dead or not adult or state != State.WANDER:
		return
	_enter(State.SEEKING_NEST)
	nest = target


## The node found no reachable empty nest: keep wandering, retry later.
func nest_seek_failed() -> void:
	_nest_seek_cooldown = _cfg.seek_retry_seconds


## Player order: swim straight to `destination`. Cancels eating/fertilizing.
func order(destination: Vector2) -> void:
	if dead:
		return
	_enter(State.ORDERED)
	target = destination


func tick(delta: float) -> void:
	if dead:
		return
	hunger += delta
	_seek_cooldown -= delta
	_nest_seek_cooldown -= delta
	_reproduce_cooldown -= delta
	if hunger >= _cfg.starve_seconds:
		dead = true
		starved.emit()
		return
	if not adult:
		age += delta
		if age >= _cfg.maturity_seconds:
			adult = true
			matured.emit()
	if state == State.SEEKING_NEST and hunger_ratio() >= _cfg.seek_food_threshold:
		nest_lost()
	if state == State.EATING or state == State.FERTILIZING or state == State.IDLE:
		_timer -= delta
		if _timer <= 0.0:
			_finish_timed_state()


## Sensor: the ordered or food-seeking fish stopped against an algae.
func blocked_by_algae(algae: Object) -> void:
	if state != State.ORDERED and state != State.SEEKING_FOOD:
		return
	_enter(State.EATING)
	food = algae
	_timer = _cfg.eat_seconds


## Sensor: the ordered or food-seeking fish stopped against a coral or a wall.
func blocked_by_other() -> void:
	if state == State.ORDERED:
		_go_idle()
	elif state == State.SEEKING_FOOD:
		_enter(State.WANDER)
		seek_failed()
	elif state == State.SEEKING_NEST:
		_enter(State.WANDER)
		nest_seek_failed()


## Sensor: the ordered fish reached its destination. `empty_nest` is the empty
## nest under it, or null.
func arrived(empty_nest: Object) -> void:
	if state != State.ORDERED:
		return
	if empty_nest != null and adult:
		_enter(State.FERTILIZING)
		nest = empty_nest
		_timer = _cfg.fertilize_seconds
	else:
		_go_idle()


## Sensor: the nest-seeking fish reached the nest. `empty_nest` is the empty
## nest under it, or null.
func nest_reached(empty_nest: Object) -> void:
	if state != State.SEEKING_NEST:
		return
	if empty_nest != null and adult:
		_enter(State.FERTILIZING)
		nest = empty_nest
		_timer = _cfg.fertilize_seconds
	else:
		nest_lost()


## Sensor: the algae being eaten or swum to disappeared (eaten by another
## fish, cyclone...).
func food_lost() -> void:
	if state == State.EATING or state == State.SEEKING_FOOD:
		_enter(State.WANDER)


## Sensor: the nest being fertilized or swum to disappeared or is no longer
## empty.
func nest_lost() -> void:
	if state == State.FERTILIZING:
		_enter(State.WANDER)
	elif state == State.SEEKING_NEST:
		_enter(State.WANDER)
		nest_seek_failed()


func _finish_timed_state() -> void:
	match state:
		State.EATING:
			var eaten_algae := food
			hunger = 0.0
			_enter(State.WANDER)
			eat_finished.emit(eaten_algae)
		State.FERTILIZING:
			var fertilized_nest := nest
			_reproduce_cooldown = reproduce_cooldown_seconds
			_enter(State.WANDER)
			fertilize_finished.emit(fertilized_nest)
		State.IDLE:
			_enter(State.WANDER)


func _go_idle() -> void:
	_enter(State.IDLE)
	_timer = _cfg.idle_after_order_seconds


func _enter(new_state: State) -> void:
	state = new_state
	food = null
	nest = null
	_timer = 0.0
