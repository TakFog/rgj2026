class_name Juice
extends Node2D
## Screen-space feedback for gameplay events (GDD §9 polish): short-lived
## particles, placement ripples and camera shake. Purely cosmetic: it only
## listens to gameplay signals and never changes a rule.
##
## Hooked to entities by DevBSystems. World positions are projected with
## Game.projection, the same path as ViewFollower.

const Z_INDEX := 95
## Hard caps keep a busy reef from turning effects into a frame-time problem.
const MAX_PARTICLES := 260
const MAX_RIPPLES := 16
const RIPPLE_SEGMENTS := 20
const RIPPLE_WIDTH := 2.0
const RIPPLE_SECONDS := 0.5

const BLOOD_COLORS := [
	Color(0.85, 0.06, 0.10, 0.9),
	Color(0.62, 0.02, 0.05, 0.9),
	Color(1.0, 0.22, 0.20, 0.8),
]
const BUBBLE_COLOR := Color(0.75, 0.92, 1.0, 0.8)
const CORAL_SPARK_COLORS := [
	Color(1.0, 0.45, 0.5, 0.9),
	Color(0.95, 0.65, 0.6, 0.85),
]
const CORAL_DEBRIS_COLORS := [
	Color(0.75, 0.55, 0.5, 0.85),
	Color(0.55, 0.45, 0.42, 0.85),
]
const IMPACT_COLORS := [
	Color(0.9, 1.0, 1.0, 0.9),
	Color(0.6, 0.95, 1.0, 0.85),
]
const ALGAE_COLORS := [
	Color(0.35, 0.95, 0.4, 0.85),
	Color(0.2, 0.7, 0.3, 0.8),
]
const EGG_COLORS := [
	Color(1.0, 0.8, 0.35, 0.9),
	Color(1.0, 0.62, 0.2, 0.85),
]
const EGG_DEAD_COLORS := [
	Color(0.55, 0.5, 0.4, 0.75),
	Color(0.4, 0.35, 0.3, 0.7),
]
const PLACEMENT_COLORS := {
	&"coral": Color(1.0, 0.55, 0.6, 0.9),
	&"algae": Color(0.4, 1.0, 0.5, 0.9),
	&"nest": Color(1.0, 0.8, 0.4, 0.9),
}

## Dev A's placement controller, set by DevBSystems before the node enters the
## tree. Without it the placement ripple stays silent.
var placement: PlacementController

var _particles: Array[Dictionary] = []
var _ripples: Array[Dictionary] = []
var _rng := RandomNumberGenerator.new()
var _camera: Camera2D
var _shake_time := 0.0
var _shake_duration := 0.0
var _shake_strength := 0.0


func _ready() -> void:
	# Run while paused only to finish/reset the camera shake; particles freeze.
	process_mode = Node.PROCESS_MODE_ALWAYS
	z_index = Z_INDEX
	_rng.randomize()
	_camera = get_viewport().get_camera_2d()
	if placement != null:
		placement.placement_finished.connect(_on_placement_finished)
	Game.world.child_entered_tree.connect(_on_entity_added)
	# Existing level entities (systems are created after Level01.populate).
	for group in [Groups.FISH, Groups.CORALS, Groups.NESTS, Groups.THREATS, Groups.ALGAE]:
		for node in get_tree().get_nodes_in_group(group):
			_on_entity_added(node)


func _process(delta: float) -> void:
	_tick_shake(delta)
	if get_tree().paused:
		return
	var dirty := false
	for i in range(_particles.size() - 1, -1, -1):
		var p := _particles[i]
		p.age += delta
		if p.age >= p.life:
			_particles.remove_at(i)
			dirty = true
			continue
		var vel: Vector2 = p.vel
		vel += Vector2(0.0, p.gravity) * delta
		vel *= maxf(0.0, 1.0 - p.drag * delta)
		p.vel = vel
		p.pos += vel * delta
		_particles[i] = p
		dirty = true
	for i in range(_ripples.size() - 1, -1, -1):
		var ripple := _ripples[i]
		ripple.age += delta
		if ripple.age >= ripple.life:
			_ripples.remove_at(i)
		dirty = true
	if dirty:
		queue_redraw()


func _draw() -> void:
	for ripple in _ripples:
		_draw_ripple(ripple)
	for p in _particles:
		var k: float = p.age / p.life
		var color: Color = p.color
		color.a *= 1.0 - k
		draw_circle(p.pos, p.radius * (1.0 - 0.35 * k), color)


func _exit_tree() -> void:
	if _camera != null and is_instance_valid(_camera):
		_camera.offset = Vector2.ZERO


# --- Signal hooks ---------------------------------------------------------

func _on_entity_added(node: Node) -> void:
	if node is Fish:
		(node as Fish).starved.connect(_on_fish_starved.bind(node))
	elif node is Coral:
		(node as Coral).damaged.connect(_on_coral_damaged.bind(node))
		(node as Coral).destroyed.connect(_on_coral_destroyed.bind(node))
	elif node is Nest:
		(node as Nest).eggs_hatched.connect(_on_eggs_hatched.bind(node))
		(node as Nest).eggs_died.connect(_on_eggs_died.bind(node))
	elif node is Algae:
		(node as Algae).destroyed.connect(_on_algae_destroyed.bind(node))
	elif node is Predator:
		(node as Predator).prey_eaten.connect(_on_prey_eaten)
	elif node is Threat:
		(node as Threat).impacted.connect(_on_threat_impacted)
		if node is Cyclone:
			(node as Cyclone).hit.connect(_on_cyclone_hit)
			(node as Cyclone).view_changed.connect(_on_cyclone_view_changed)


func _on_fish_starved(fish: Fish) -> void:
	if not _alive(fish):
		return
	_bubbles(fish.global_position)


func _on_prey_eaten(world_position: Vector2, was_fish: bool) -> void:
	if was_fish:
		_blood(world_position)
	else:
		_egg_burst(world_position)


func _on_coral_damaged(coral: Coral) -> void:
	if _alive(coral):
		_coral_sparks(_coral_center(coral))


func _on_coral_destroyed(coral: Coral) -> void:
	if _alive(coral):
		_coral_debris(_coral_center(coral))


func _on_algae_destroyed(algae: Algae) -> void:
	if _alive(algae):
		_algae_puff(algae.global_position)


func _on_eggs_hatched(_count: int, nest: Nest) -> void:
	if _alive(nest):
		_egg_burst(nest.global_position)


func _on_eggs_died(nest: Nest) -> void:
	if _alive(nest):
		_burst(_screen_of(nest.global_position), EGG_DEAD_COLORS, 8,
				Vector2(15.0, 45.0), Vector2(1.5, 3.0), Vector2(0.35, 0.6), 25.0, 0.8, -10.0)


func _on_threat_impacted(victim: Node2D) -> void:
	# The victim may already be queued for deletion (destroy() runs before the
	# threat emits impacted), but its position is still valid this frame.
	if not is_instance_valid(victim) or victim is Coral or victim is Algae:
		# Coral and algae emit their own damaged/destroyed effects.
		return
	if victim is Fish:
		_bubbles(victim.global_position)
	elif victim is Nest:
		# CO2 already emitted eggs_died; only a cyclone destruction (eggs still
		# in the nest when it is removed) needs this burst.
		if (victim as Nest).has_eggs():
			_egg_burst(victim.global_position)
	else:
		_impact_sparks(victim.global_position)


func _on_cyclone_hit(_victim: Node2D) -> void:
	_shake(9.0, 0.35)


func _on_cyclone_view_changed(in_view: bool) -> void:
	if in_view:
		_shake(3.0, 0.15)


func _on_placement_finished(kind: StringName) -> void:
	var world := Game.mouse_world()
	var color: Color = PLACEMENT_COLORS.get(kind, IMPACT_COLORS[0])
	_ripple(world, color, Game.grid.cell_size * 1.4)
	_burst(_screen_of(world), [color], 6, Vector2(20.0, 55.0),
			Vector2(1.5, 3.0), Vector2(0.3, 0.5), 30.0, 0.8, -5.0)


# --- Effects ---------------------------------------------------------------

func _blood(world_position: Vector2) -> void:
	var center := _screen_of(world_position)
	_burst(center, BLOOD_COLORS, 20, Vector2(25.0, 85.0),
			Vector2(2.0, 5.0), Vector2(0.45, 0.9), 55.0, 1.2, -15.0)
	# A softer, larger cloud behind the droplets.
	for i in 4:
		var offset := Vector2(_rng.randf_range(-8.0, 8.0), _rng.randf_range(-8.0, 8.0))
		_add_particle(center + offset, Vector2(_rng.randf_range(-8.0, 8.0), _rng.randf_range(-15.0, 0.0)),
				Color(0.55, 0.02, 0.04, 0.35), _rng.randf_range(7.0, 12.0),
				_rng.randf_range(0.45, 0.75), -5.0, 0.8)


func _bubbles(world_position: Vector2) -> void:
	_burst(_screen_of(world_position), [BUBBLE_COLOR], 10, Vector2(15.0, 50.0),
			Vector2(1.5, 3.5), Vector2(0.6, 1.1), -30.0, 0.4, -20.0)


func _coral_sparks(world_position: Vector2) -> void:
	_burst(_screen_of(world_position), CORAL_SPARK_COLORS, 8, Vector2(25.0, 70.0),
			Vector2(1.5, 3.0), Vector2(0.25, 0.5), 50.0, 1.0, -20.0)


func _coral_debris(world_position: Vector2) -> void:
	_burst(_screen_of(world_position), CORAL_DEBRIS_COLORS, 18, Vector2(30.0, 110.0),
			Vector2(2.0, 4.0), Vector2(0.5, 0.9), 120.0, 0.4, -30.0)


func _impact_sparks(world_position: Vector2) -> void:
	_burst(_screen_of(world_position), IMPACT_COLORS, 8, Vector2(30.0, 90.0),
			Vector2(1.0, 2.5), Vector2(0.2, 0.4), 0.0, 1.5, 0.0)


func _algae_puff(world_position: Vector2) -> void:
	_burst(_screen_of(world_position), ALGAE_COLORS, 7, Vector2(20.0, 55.0),
			Vector2(1.5, 3.0), Vector2(0.3, 0.55), 35.0, 1.0, -10.0)


func _egg_burst(world_position: Vector2) -> void:
	_burst(_screen_of(world_position), EGG_COLORS, 9, Vector2(20.0, 65.0),
			Vector2(1.5, 3.2), Vector2(0.3, 0.6), 45.0, 0.8, -15.0)


## Adds `count` particles in random directions around `center` (screen space).
func _burst(center: Vector2, colors: Array, count: int, speed: Vector2,
		radius: Vector2, life: Vector2, gravity: float, drag: float, upward: float) -> void:
	for i in count:
		var direction := Vector2.from_angle(_rng.randf() * TAU)
		var velocity := direction * _rng.randf_range(speed.x, speed.y) + Vector2(0.0, upward)
		var color: Color = colors[_rng.randi_range(0, colors.size() - 1)]
		_add_particle(center + direction * _rng.randf_range(0.0, 4.0), velocity, color,
				_rng.randf_range(radius.x, radius.y), _rng.randf_range(life.x, life.y),
				gravity, drag)


func _add_particle(pos: Vector2, velocity: Vector2, color: Color, radius: float,
		life: float, gravity: float, drag: float) -> void:
	if _particles.size() >= MAX_PARTICLES:
		return
	_particles.append({
		"pos": pos,
		"vel": velocity,
		"color": color,
		"radius": radius,
		"age": 0.0,
		"life": life,
		"gravity": gravity,
		"drag": drag,
	})


func _ripple(center_world: Vector2, color: Color, max_radius: float) -> void:
	if _ripples.size() >= MAX_RIPPLES:
		_ripples.remove_at(0)
	_ripples.append({
		"center": center_world,
		"color": color,
		"age": 0.0,
		"life": RIPPLE_SECONDS,
		"start_radius": Game.grid.cell_size * 0.25,
		"max_radius": max_radius,
	})


func _draw_ripple(ripple: Dictionary) -> void:
	var k: float = ripple.age / ripple.life
	var radius := lerpf(ripple.start_radius, ripple.max_radius, ease(k, 0.4))
	var color: Color = ripple.color
	color.a *= 1.0 - k
	draw_polyline(_projected_circle(ripple.center, radius), color, RIPPLE_WIDTH, true)


func _projected_circle(center_world: Vector2, radius: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in RIPPLE_SEGMENTS:
		var angle := TAU * float(i) / float(RIPPLE_SEGMENTS)
		points.append(Game.projection.to_screen(center_world + Vector2.from_angle(angle) * radius))
	points.append(points[0])
	return points


# --- Screen shake ---------------------------------------------------------

func _shake(strength: float, duration: float) -> void:
	if duration <= 0.0:
		return
	if _shake_time <= 0.0 or strength >= _shake_strength:
		_shake_strength = strength
		_shake_duration = duration
		_shake_time = duration


func _tick_shake(delta: float) -> void:
	if _shake_time <= 0.0:
		return
	var camera := _camera_node()
	if camera == null:
		_shake_time = 0.0
		return
	_shake_time = maxf(_shake_time - delta, 0.0)
	if _shake_time <= 0.0:
		camera.offset = Vector2.ZERO
		_shake_strength = 0.0
		return
	var falloff := _shake_time / maxf(_shake_duration, 0.001)
	camera.offset = Vector2(
		_rng.randf_range(-1.0, 1.0),
		_rng.randf_range(-1.0, 1.0)) * _shake_strength * falloff


func _camera_node() -> Camera2D:
	if _camera == null or not is_instance_valid(_camera):
		_camera = get_viewport().get_camera_2d()
	return _camera


# --- Helpers --------------------------------------------------------------

func _screen_of(world_position: Vector2) -> Vector2:
	return Game.projection.to_screen(world_position)


func _coral_center(coral: Coral) -> Vector2:
	if coral.cells.is_empty():
		return coral.global_position
	var center := Vector2.ZERO
	for cell in coral.cells:
		center += Game.grid.cell_to_world(cell)
	return center / float(coral.cells.size())


func _alive(entity: Object) -> bool:
	return is_instance_valid(entity) and not (entity as Node).is_queued_for_deletion()
