class_name Fish
extends CharacterBody2D
## Fish (GDD §5.4): wanders, obeys orders, eats algae, fertilizes nests, starves.
## Rules live in FishBrain; this node moves, senses and draws.
## CONTRACT (used by Dev A nest, Dev B threats): setup(), is_adult(), destroy(),
## signal destroyed. Added for the commander: order(), selected.

signal destroyed

## Distance (world units) at which an order destination counts as reached.
const ARRIVE_DISTANCE := 2.0

var adult := true
var brain: FishBrain
var selected := false:
	set(value):
		selected = value
		if _visual != null:
			_visual.selected = value

var _wander: WanderSteering
var _visual: FishVisual


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
			_move(_wander.tick(delta), _speed() * delta)
		FishBrain.State.ORDERED:
			var to_target := brain.target - global_position
			if to_target.length() <= ARRIVE_DISTANCE:
				brain.arrived(_empty_nest_under())
			else:
				_move(to_target.normalized(), minf(_speed() * delta, to_target.length()))
	_visual.hunger_ratio = brain.hunger_ratio()


func is_adult() -> bool:
	return brain.is_adult() if brain != null else adult


## Player order (from FishCommander): swim straight to `destination` (world units).
func order(destination: Vector2) -> void:
	brain.order(destination)


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


func _move(direction: Vector2, distance: float) -> void:
	var collision := move_and_collide(direction * distance)
	if collision == null:
		return
	var collider := collision.get_collider()
	if brain.state == FishBrain.State.ORDERED:
		if collider is Node and (collider as Node).is_in_group(Groups.ALGAE):
			brain.blocked_by_algae(collider)
		else:
			brain.blocked_by_other()
	else:
		_wander.on_blocked(collision.get_normal())


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
	if brain.state == FishBrain.State.EATING and not _alive_in(brain.food, Groups.ALGAE):
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


## True if `entity` still exists and still belongs to `group` (destroy() leaves
## the group immediately, even when the node is freed later). Untyped on purpose:
## a freed object passed to an `Object` parameter fails the call-site type check.
static func _alive_in(entity: Variant, group: StringName) -> bool:
	return is_instance_valid(entity) and (entity as Node).is_in_group(group)
