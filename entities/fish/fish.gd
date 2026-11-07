class_name Fish
extends CharacterBody2D
## Fish (GDD §5.4): wanders, obeys orders, eats algae, fertilizes nests, starves.
## Rules live in FishBrain; this node moves, senses and draws. Orders and food
## seeking follow a route planned by ReefPathfinder around corals and algae.
## CONTRACT (used by Dev A nest, Dev B threats): setup(), is_adult(), destroy(),
## signal destroyed. Added for the commander: order(), selected.

signal destroyed

## Distance (world units) at which a waypoint counts as reached.
const ARRIVE_DISTANCE := 2.0
## Re-plans allowed per route when something unexpected blocks the fish.
const MAX_REPLANS := 1

var adult := true
var brain: FishBrain
var selected := false:
	set(value):
		selected = value
		if _visual != null:
			_visual.selected = value

var _wander: WanderSteering
var _visual: FishVisual
var _pathfinder: ReefPathfinder
## Remaining waypoints (world units) while ORDERED or SEEKING_FOOD.
var _path := PackedVector2Array()
var _replans_left := 0


func setup(world_position: Vector2, p_adult: bool) -> void:
	position = world_position
	adult = p_adult


func _ready() -> void:
	collision_layer = Layers.FISH
	collision_mask = Layers.WALL | Layers.CORAL | Layers.ALGAE
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	add_to_group(Groups.FISH)
	var circle := CircleShape2D.new()
	circle.radius = Game.actors.fish_radius
	var shape := CollisionShape2D.new()
	shape.shape = circle
	add_child(shape)

	brain = FishBrain.new(Game.actors, adult)
	brain.starved.connect(destroy)
	brain.matured.connect(_on_matured)
	brain.eat_finished.connect(_on_eat_finished)
	brain.fertilize_finished.connect(_on_fertilize_finished)

	var rng := RandomNumberGenerator.new()
	rng.randomize()
	_wander = WanderSteering.new(rng, Game.actors.fish_wander_min_seconds, Game.actors.fish_wander_max_seconds)
	_pathfinder = ReefPathfinder.new(Game.grid, _blocks_fish)

	_visual = FishVisual.new()
	_visual.radius_world = Game.actors.fish_radius
	_visual.hunger_threshold = Game.actors.hunger_bar_threshold
	_visual.adult = adult
	ViewFollower.attach(self, _visual)


func _physics_process(delta: float) -> void:
	brain.tick(delta)
	if brain.dead:
		return
	_check_targets_still_exist()
	match brain.state:
		FishBrain.State.WANDER:
			if brain.wants_to_seek_food():
				_seek_food()
			if brain.state == FishBrain.State.WANDER:
				_move(_wander.tick(delta), _speed() * delta)
		FishBrain.State.ORDERED, FishBrain.State.SEEKING_FOOD:
			_follow_path(_speed() * delta)
	_visual.hunger_ratio = brain.hunger_ratio()


func is_adult() -> bool:
	return brain.is_adult() if brain != null else adult


## Player order (from FishCommander): swim to `destination` (world units)
## along a route around obstacles.
func order(destination: Vector2) -> void:
	brain.order(destination)
	_replans_left = MAX_REPLANS
	_path = _pathfinder.find_path(global_position, destination)


func destroy() -> void:
	if is_queued_for_deletion():
		return
	selected = false
	remove_from_group(Groups.FISH)
	destroyed.emit()
	queue_free()


## Speed slows down with temperature (GDD §6, contract #1).
func _speed() -> float:
	return Game.actors.fish_speed * Game.by_temperature(1.0, Game.actors.fish_speed_hot_factor)


## Hungry and wandering: head for the nearest reachable algae, if any.
func _seek_food() -> void:
	var result := _pathfinder.nearest_occupant(global_position, _is_algae)
	if result.is_empty():
		brain.seek_failed()
		return
	brain.seek_food(result["occupant"])
	_replans_left = MAX_REPLANS
	_path = result["path"]


## Swims up to `budget` world units along the waypoints.
func _follow_path(budget: float) -> void:
	while budget > 0.0:
		if _path.is_empty():
			_on_path_end()
			return
		var to_next := _path[0] - global_position
		if to_next.length() <= ARRIVE_DISTANCE:
			_path.remove_at(0)
			continue
		var step := minf(budget, to_next.length())
		var state_before := brain.state
		if not _move(to_next.normalized(), step) or brain.state != state_before:
			return
		budget -= step


func _on_path_end() -> void:
	if brain.state == FishBrain.State.ORDERED:
		brain.arrived(_empty_nest_under())
	else:
		# Reached the end without touching the algae: it is gone or moved.
		brain.food_lost()


## Moves and reacts to collisions. Returns false if the fish was blocked.
func _move(direction: Vector2, distance: float) -> bool:
	var collision := move_and_collide(direction * distance)
	if collision == null:
		return true
	var collider := collision.get_collider()
	if brain.state == FishBrain.State.WANDER:
		_wander.on_blocked(collision.get_normal())
	elif collider is Node and (collider as Node).is_in_group(Groups.ALGAE):
		brain.blocked_by_algae(collider)
	elif _replans_left > 0:
		_replans_left -= 1
		_replan()
	else:
		brain.blocked_by_other()
	return false


## Something unexpected (a newly placed coral) blocks the route: plan again.
func _replan() -> void:
	if brain.state == FishBrain.State.ORDERED:
		_path = _pathfinder.find_path(global_position, brain.target)
		return
	var result := _pathfinder.nearest_occupant(global_position, _is_algae)
	if result.is_empty():
		# No algae reachable now: give up, the brain retries after a cooldown.
		brain.blocked_by_other()
		return
	brain.seek_food(result["occupant"])
	_path = result["path"]


## Contract #4: the empty nest under the fish, or null.
func _empty_nest_under() -> Nest:
	var query := PhysicsPointQueryParameters2D.new()
	query.position = global_position
	query.collision_mask = Layers.NEST
	query.collide_with_areas = true
	query.collide_with_bodies = false
	for hit in get_world_2d().direct_space_state.intersect_point(query, 4):
		var nest := hit["collider"] as Nest
		if nest != null and nest.is_empty():
			return nest
	return null


func _check_targets_still_exist() -> void:
	var has_food := brain.state == FishBrain.State.EATING or brain.state == FishBrain.State.SEEKING_FOOD
	if has_food and not _alive_in(brain.food, Groups.ALGAE):
		brain.food_lost()
	elif brain.state == FishBrain.State.FERTILIZING:
		if not _alive_in(brain.nest, Groups.NESTS) or not (brain.nest as Nest).is_empty():
			brain.nest_lost()


func _on_matured() -> void:
	adult = true
	_visual.adult = true


## Contract #7: the eaten algae disappears.
func _on_eat_finished(algae: Variant) -> void:
	if _alive_in(algae, Groups.ALGAE):
		(algae as Algae).destroy()


## Contract #4: the nest receives the eggs if it is still there and empty.
func _on_fertilize_finished(nest: Variant) -> void:
	if _alive_in(nest, Groups.NESTS) and (nest as Nest).is_empty():
		(nest as Nest).fertilize()


## Grid occupants fish cannot swim through: everything but nests (Area2D).
static func _blocks_fish(occupant: Object) -> bool:
	return not occupant is Nest


static func _is_algae(occupant: Object) -> bool:
	return occupant is Algae


## True if `entity` still exists and still belongs to `group` (destroy() leaves
## the group immediately, even when the node is freed later). Untyped on purpose:
## a freed object passed to an `Object` parameter fails the call-site type check.
static func _alive_in(entity: Variant, group: StringName) -> bool:
	return is_instance_valid(entity) and (entity as Node).is_in_group(group)
