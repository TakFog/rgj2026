class_name Turtle
extends CharacterBody2D
## Sea turtle helper (issue #4): enters from the edge of the screen and helps
## the reef. Its priority is defending the fish: it goes after a predator or a
## plastic bag only when it is nearby (a different aggro radius for each), and
## rams the predator (which then leaves the island) or removes the bag (then
## leaves itself). With no threat nearby it eats algae, much faster than fish.
## It leaves when its stay runs out. Rules live in TurtleBrain; routes reuse PredatorPathfinder
## (like the predator it is big: one-cell coral corridors keep it out).
## Physics: a body on the THREAT layer (so nothing is placed on it) but in no
## threat group, so threats and cyclones ignore it. Blocked only by corals: it
## swims over algae (eating them) and nests.

signal destroyed
## Used by the audio system (systems/b_audio.gd).
signal ate_algae
signal rammed

## Distance (world units) at which a waypoint counts as reached.
const ARRIVE_DISTANCE := 3.0
## Distance swum past the island border when leaving, before being removed.
const RUN_OUT := 600.0
## Off-screen distance (on top of 2 × radius) before a leaving turtle is removed.
const EXIT_MARGIN := 32.0
## Fraction of a move that must survive sliding along an obstacle; less = stuck.
const MIN_SLIDE_RATIO := 0.3

var brain: TurtleBrain

var _cfg: BalanceActors
var _pathfinder: PredatorPathfinder
var _path := PackedVector2Array()
var _heading := Vector2.RIGHT
var _replan_timer := 0.0
## Current job: a Predator or PlasticBag to remove, an Algae to eat, or null.
var _target: Node2D = null
var _roam_point := Vector2.ZERO
var _has_roam_point := false
var _visual: TurtleVisual
var _rng := RandomNumberGenerator.new()


## Places the turtle just off screen at `entry`. Call before adding it to the tree.
func setup(entry: EdgeEntry) -> void:
	_heading = Vector2.from_angle(entry.heading)
	position = entry.point - _heading * Game.actors.turtle_radius


func _ready() -> void:
	_cfg = Game.actors
	_rng.randomize()
	collision_layer = Layers.THREAT
	collision_mask = Layers.CORAL
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	add_to_group(Groups.TURTLES)
	var circle := CircleShape2D.new()
	circle.radius = _cfg.turtle_radius
	var shape := CollisionShape2D.new()
	shape.shape = circle
	add_child(shape)

	brain = TurtleBrain.new(_cfg)
	_pathfinder = PredatorPathfinder.new(Game.grid, _blocks_turtle, _cfg.turtle_radius)

	_visual = TurtleVisual.new()
	_visual.radius_world = _cfg.turtle_radius
	ViewFollower.attach(self, _visual)


func _physics_process(delta: float) -> void:
	var was_leaving := brain.state == TurtleBrain.State.LEAVING
	var island := Rect2(Vector2.ZERO, Game.grid.world_size())
	if brain.tick(delta, island.has_point(global_position)):
		_finish_algae()
	_replan_timer -= delta
	match brain.state:
		TurtleBrain.State.HELPING:
			if _try_touch():
				return
			if _replan_timer <= 0.0 or _target != null and not _is_valid_target(_target):
				_plan()
			_follow_path(_speed() * delta)
		TurtleBrain.State.EATING:
			if not _is_valid_target(_target):
				brain.stop_eating()
				_replan_timer = 0.0
			elif _replan_timer <= 0.0:
				# A threat beats the algae: drop it if one shows up.
				_plan(true)
		TurtleBrain.State.LEAVING:
			if not was_leaving or (_path.is_empty() and _replan_timer <= 0.0):
				_plan_exit()
			_follow_path(_speed() * delta)
			if _path.is_empty() and not _in_alive_area():
				destroy()
	_visual.heading = _heading
	_visual.eating = brain.state == TurtleBrain.State.EATING


func destroy() -> void:
	if is_queued_for_deletion():
		return
	remove_from_group(Groups.TURTLES)
	destroyed.emit()
	queue_free()


## Slowed down by heat like the fish and the predator (GDD §6).
func _speed() -> float:
	return _cfg.turtle_speed * Game.by_temperature(1.0, _cfg.fish_speed_hot_factor)


## Acts on the current target if touching it: rams the predator away, removes
## the bag (then leaves), or starts eating the algae.
func _try_touch() -> bool:
	if not _is_valid_target(_target):
		return false
	if global_position.distance_to(_target.global_position) > _reach_of(_target) + _cfg.turtle_reach_margin:
		return false
	if _target is Predator:
		(_target as Predator).scare()
		_target = null
		rammed.emit()
	elif _target is PlasticBag:
		(_target as PlasticBag).destroy()
		_target = null
		brain.bag_removed()
	else:
		brain.start_eating()
	_path.clear()
	_replan_timer = 0.0
	return true


func _finish_algae() -> void:
	if _is_valid_target(_target) and _target is Algae:
		(_target as Algae).destroy()
		ate_algae.emit()
	_target = null
	_path.clear()
	_replan_timer = 0.0


## Picks the next job (nearest reachable threat nearby, else nearest reachable
## algae) and plans the route to it. With `threats_only` (while eating) it only
## switches job if a threat is in range. With nothing to do, roams.
func _plan(threats_only := false) -> void:
	_replan_timer = _cfg.turtle_replan_seconds
	if not _pathfinder.plan_from(global_position):
		if not threats_only:
			_path.clear()
		return
	var threats: Array[Node2D] = []
	var threat_costs := []
	var threat_distances := []
	var threat_radii := []
	# Predators are threats too: this covers predators and bags.
	for node in get_tree().get_nodes_in_group(Groups.THREATS):
		if not _is_valid_target(node):
			continue
		threats.append(node)
		threat_costs.append(_pathfinder.reach_cost(node.global_position, _reach_of(node)))
		threat_distances.append(global_position.distance_to(node.global_position))
		threat_radii.append(_aggro_radius(node))
	var algae: Array[Node2D] = []
	var algae_costs := []
	if not threats_only:
		for node in get_tree().get_nodes_in_group(Groups.ALGAE):
			if not _is_valid_target(node):
				continue
			algae.append(node)
			algae_costs.append(_pathfinder.reach_cost(node.global_position, _reach_of(node)))
	# A threat it is already chasing stays its job until resolved.
	var job := TurtleBrain.pick(threat_costs, threat_distances, threat_radii, algae_costs,
			threats.find(_target))
	match job["task"]:
		TurtleBrain.Task.THREAT:
			brain.stop_eating()
			_target = threats[job["index"]]
		TurtleBrain.Task.ALGAE:
			_target = algae[job["index"]]
		_:
			if not threats_only:
				_target = null
				_roam()
			return
	_has_roam_point = false
	_path = _pathfinder.path_to(_target.global_position, _reach_of(_target))


## Nothing to do: cruise toward a random point of the island.
func _roam() -> void:
	var reach := Game.grid.cell_size * 1.5
	if not _has_roam_point or global_position.distance_to(_roam_point) <= reach \
			or is_inf(_pathfinder.reach_cost(_roam_point, reach)):
		_roam_point = Vector2(_rng.randf(), _rng.randf()) * Game.grid.world_size()
		_has_roam_point = true
	_path = _pathfinder.path_to(_roam_point, reach)


func _plan_exit() -> void:
	_replan_timer = _cfg.turtle_replan_seconds
	_target = null
	var island := Rect2(Vector2.ZERO, Game.grid.world_size())
	if not island.grow(_cfg.turtle_radius).has_point(global_position):
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
		_heading = PathSteering.turn(_heading, to_next, step, _cfg.turtle_turn_radius)
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


## Inside the visible seabed, grown so the turtle leaves fully off screen.
func _in_alive_area() -> bool:
	var grown := Geometry2D.offset_polygon(Game.visible_world_polygon(), _cfg.turtle_radius * 2.0 + EXIT_MARGIN)
	return not grown.is_empty() and Geometry2D.is_point_in_polygon(global_position, grown[0])


## Straight-line range within which a threat makes the turtle drop its algae.
func _aggro_radius(target: Node2D) -> float:
	if target is Predator:
		return _cfg.turtle_predator_aggro_radius
	return _cfg.turtle_bag_aggro_radius


## Centre distance at which the turtle touches `target`.
func _reach_of(target: Node2D) -> float:
	var other := Game.grid.cell_size * 0.5
	if target is Predator:
		other = _cfg.predator_radius
	elif target is PlasticBag:
		other = (target as PlasticBag).radius
	return _cfg.turtle_radius + other


## A predator still hunting, a live plastic bag, or a live algae. Untyped:
## `target` may be a freed object.
static func _is_valid_target(target: Variant) -> bool:
	if not is_instance_valid(target) or (target as Node).is_queued_for_deletion():
		return false
	if target is Predator:
		return (target as Node).is_in_group(Groups.PREDATORS) and (target as Predator).is_hunting()
	if target is PlasticBag:
		return (target as Node).is_in_group(Groups.THREATS)
	if target is Algae:
		return (target as Node).is_in_group(Groups.ALGAE)
	return false


## Grid occupants that block the turtle: only corals (it swims over algae and nests).
static func _blocks_turtle(occupant: Object) -> bool:
	return occupant is Coral
