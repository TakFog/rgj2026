class_name Predator
extends CharacterBody2D
## Carnivorous predator fish (issue #3): enters from the edge of the screen,
## hunts fish and eggs until sated (or until its hunting time runs out), then
## swims off the island. It is big: it cannot fit through one-cell corridors
## between corals, so the player can shelter fish and nests behind them.
## Rules live in PredatorBrain, routes in PredatorPathfinder.
## Physics: a body on the THREAT layer (so placements and algae avoid it, and
## a cyclone sweeps it away like any other threat), blocked only by corals: it
## swims over algae and nests, so only corals can shelter fish and eggs.

signal destroyed
## Emitted when it bites a fish or a nest's eggs (the eat sound, GDD §7.4).
signal ate
## Used by the audio system (systems/b_audio.gd).
signal left

## Distance (world units) at which a waypoint counts as reached.
const ARRIVE_DISTANCE := 3.0
## Distance swum past the island border when leaving, before being removed.
const RUN_OUT := 600.0
## Off-screen distance (on top of 2 × radius) before a leaving predator is removed.
const EXIT_MARGIN := 32.0
## Fraction of a move that must survive sliding along an obstacle; less = stuck.
const MIN_SLIDE_RATIO := 0.3

var brain: PredatorBrain

var _cfg: BalanceActors
var _pathfinder: PredatorPathfinder
var _path := PackedVector2Array()
var _heading := Vector2.RIGHT
var _replan_timer := 0.0
## Prey being hunted (Fish or Nest), or null while roaming.
var _target: Node2D = null
var _roam_point := Vector2.ZERO
var _has_roam_point := false
var _visual: PredatorVisual
var _rng := RandomNumberGenerator.new()


## Places the predator just off screen at `entry`. Call before adding it to the tree.
func setup(entry: EdgeEntry) -> void:
	_heading = Vector2.from_angle(entry.heading)
	position = entry.point - _heading * Game.actors.predator_radius


func _ready() -> void:
	_cfg = Game.actors
	_rng.randomize()
	collision_layer = Layers.THREAT
	collision_mask = Layers.CORAL
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	add_to_group(Groups.THREATS)
	add_to_group(Groups.PREDATORS)
	var circle := CircleShape2D.new()
	circle.radius = _cfg.predator_radius
	var shape := CollisionShape2D.new()
	shape.shape = circle
	add_child(shape)

	brain = PredatorBrain.new(_cfg)
	_pathfinder = PredatorPathfinder.new(Game.grid, _blocks_predator, _cfg.predator_radius)

	_visual = PredatorVisual.new()
	_visual.radius_world = _cfg.predator_radius
	ViewFollower.attach(self, _visual)


func _physics_process(delta: float) -> void:
	var was_leaving := brain.state == PredatorBrain.State.LEAVING
	brain.tick(delta, Rect2(Vector2.ZERO, Game.grid.world_size()).has_point(global_position))
	if not was_leaving and brain.state == PredatorBrain.State.LEAVING:
		left.emit()
	_replan_timer -= delta
	match brain.state:
		PredatorBrain.State.HUNTING:
			if _try_bite():
				return
			if _replan_timer <= 0.0 or not _is_valid_prey(_target) and _target != null:
				_plan_hunt()
			_follow_path(_speed() * delta)
		PredatorBrain.State.LEAVING:
			if not was_leaving or (_path.is_empty() and _replan_timer <= 0.0):
				_plan_exit()
			_follow_path(_speed() * delta)
			if _path.is_empty() and not _in_alive_area():
				destroy()
	_visual.satiety_ratio = brain.satiety_ratio()
	_visual.heading = Game.projection.to_screen(_heading) - Game.projection.to_screen(Vector2.ZERO)
	_visual.leaving = brain.state == PredatorBrain.State.LEAVING


## Rammed by the sea turtle (issue #4): it swims off the island.
func scare() -> void:
	brain.scare()


## Still hunting on the island (not leaving yet): the turtle chases it.
func is_hunting() -> bool:
	return brain != null and brain.state != PredatorBrain.State.LEAVING


func destroy() -> void:
	if is_queued_for_deletion():
		return
	remove_from_group(Groups.THREATS)
	remove_from_group(Groups.PREDATORS)
	destroyed.emit()
	queue_free()


## Slowed down by heat like the other fish (GDD §6).
func _speed() -> float:
	return _cfg.predator_speed * Game.by_temperature(1.0, _cfg.fish_speed_hot_factor)


## Bites the hunted prey if it is touching it.
func _try_bite() -> bool:
	if not _is_valid_prey(_target):
		return false
	var reach := _reach_of(_target) + _cfg.predator_bite_margin
	if global_position.distance_to(_target.global_position) > reach:
		return false
	var amount := _satisfaction_of(_target)
	if _target is Fish:
		(_target as Fish).destroy()
	else:
		(_target as Nest).kill_eggs()
	_target = null
	_path.clear()
	_replan_timer = 0.0
	brain.ate(amount)
	ate.emit()
	return true


## Picks the prey with the best satisfaction / route length; unreachable prey
## (e.g. hidden in a one-cell corridor) is ignored. With no prey, roams.
func _plan_hunt() -> void:
	_replan_timer = _cfg.predator_replan_seconds
	if not _pathfinder.plan_from(global_position):
		_path.clear()
		return
	var preys: Array[Node2D] = []
	var candidates := []
	for node in get_tree().get_nodes_in_group(Groups.FISH) + get_tree().get_nodes_in_group(Groups.NESTS):
		if not _is_valid_prey(node):
			continue
		preys.append(node)
		candidates.append({
			"satisfaction": _satisfaction_of(node),
			"distance": _pathfinder.reach_cost(node.global_position, _reach_of(node)),
		})
	var best := PredatorBrain.pick_best(candidates)
	if best >= 0:
		_target = preys[best]
		_has_roam_point = false
		_path = _pathfinder.path_to(_target.global_position, _reach_of(_target))
		return
	_target = null
	_roam()


## No prey in reach: cruise toward a random point of the island.
func _roam() -> void:
	var reach := Game.grid.cell_size * 1.5
	if not _has_roam_point or global_position.distance_to(_roam_point) <= reach \
			or is_inf(_pathfinder.reach_cost(_roam_point, reach)):
		_roam_point = Vector2(_rng.randf(), _rng.randf()) * Game.grid.world_size()
		_has_roam_point = true
	_path = _pathfinder.path_to(_roam_point, reach)


func _plan_exit() -> void:
	_replan_timer = _cfg.predator_replan_seconds
	_target = null
	var island := Rect2(Vector2.ZERO, Game.grid.world_size())
	if not island.grow(_cfg.predator_radius).has_point(global_position):
		# Already off the island: open water, swim straight away from it.
		var outward := (global_position - island.get_center()).normalized()
		_path = PackedVector2Array([global_position + outward * RUN_OUT])
	elif _pathfinder.plan_from(global_position):
		_path = _pathfinder.exit_path(RUN_OUT)


## Swims up to `budget` world units along the waypoints, curving between them.
func _follow_path(budget: float) -> void:
	while budget > 0.0 and not _path.is_empty():
		var to_next := _path[0] - global_position
		var distance := to_next.length()
		if distance <= ARRIVE_DISTANCE:
			_path.remove_at(0)
			continue
		var step := minf(budget, distance)
		_heading = PathSteering.turn(_heading, to_next, step, _cfg.predator_turn_radius)
		if not _move(_heading * step, to_next / distance * step):
			# Stuck against an obstacle (e.g. a coral just placed): re-plan soon.
			_replan_timer = minf(_replan_timer, 0.1)
			return
		budget -= step


## Moves by `motion`, sliding along grazed obstacles. If most of the move is
## lost, tries `straight` (directly toward the waypoint) instead.
func _move(motion: Vector2, straight: Vector2) -> bool:
	var collision := move_and_collide(motion)
	if collision == null:
		return true
	var travelled := collision.get_travel().length()
	var slide := collision.get_remainder().slide(collision.get_normal())
	var second := move_and_collide(slide)
	travelled += slide.length() if second == null else second.get_travel().length()
	if travelled >= motion.length() * MIN_SLIDE_RATIO:
		return true
	if move_and_collide(straight) == null:
		_heading = straight.normalized()
		return true
	return false


## Inside the visible seabed, grown so the predator leaves fully off screen.
func _in_alive_area() -> bool:
	var grown := Geometry2D.offset_polygon(Game.visible_world_polygon(), _cfg.predator_radius * 2.0 + EXIT_MARGIN)
	return not grown.is_empty() and Geometry2D.is_point_in_polygon(global_position, grown[0])


func _satisfaction_of(prey: Node2D) -> float:
	if prey is Nest:
		return PredatorBrain.satisfaction(_cfg, PredatorBrain.Prey.EGGS, Game.eco.nest_hatch_count)
	var kind := PredatorBrain.Prey.ADULT if (prey as Fish).is_adult() else PredatorBrain.Prey.JUVENILE
	return PredatorBrain.satisfaction(_cfg, kind, Game.eco.nest_hatch_count)


## Centre distance at which the predator touches `prey`.
func _reach_of(prey: Node2D) -> float:
	var prey_radius := Game.grid.cell_size * 0.5 if prey is Nest else _cfg.fish_radius
	return _cfg.predator_radius + prey_radius


## A live fish, or a live nest with eggs. Untyped: `prey` may be a freed object.
static func _is_valid_prey(prey: Variant) -> bool:
	if not is_instance_valid(prey) or (prey as Node).is_queued_for_deletion():
		return false
	if prey is Fish:
		return (prey as Node).is_in_group(Groups.FISH)
	if prey is Nest:
		return (prey as Node).is_in_group(Groups.NESTS) and (prey as Nest).has_eggs()
	return false


## Grid occupants that block the predator: only corals (it swims over algae and nests).
static func _blocks_predator(occupant: Object) -> bool:
	return occupant is Coral
