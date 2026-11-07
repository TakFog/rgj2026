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
## Continuous indicators (low oxygen, egg hatch) redraw at 20 Hz.
const INDICATOR_REFRESH_SECONDS := 0.05
const LOW_OXYGEN_RATIO := 0.3
const LOW_OXYGEN_PULSE_SPEED := 6.0
const LOW_OXYGEN_COLOR := Color(1.0, 0.28, 0.2, 0.9)
const EGG_RING_COLOR := Color(1.0, 0.82, 0.35)
const EGG_RING_WIDTH := 1.2
const EGG_RING_RADIUS_CELLS := 0.55
## The timer stays almost invisible at laying and only becomes readable as the
## eggs get close to hatching.
const EGG_RING_MIN_ALPHA := 0.10
const EGG_RING_MAX_ALPHA := 0.38

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
var _time := 0.0
var _indicator_elapsed := INDICATOR_REFRESH_SECONDS
var _had_indicators := false


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
	_time += delta
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

	# Pulse low-oxygen rings and advance egg rings. Redraw while any indicator
	# is visible, and once more after the last one disappears to clear it.
	_indicator_elapsed += delta
	if _indicator_elapsed >= INDICATOR_REFRESH_SECONDS:
		_indicator_elapsed = 0.0
		var has_indicators := _has_indicators()
		if has_indicators or _had_indicators:
			dirty = true
		_had_indicators = has_indicators

	if dirty:
		queue_redraw()


func _draw() -> void:
	_draw_indicators()
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


# --- Continuous indicators -------------------------------------------------

## True when `oxygen` is at or below the danger threshold.
static func is_low_oxygen(oxygen: float, max_oxygen: float) -> bool:
	return max_oxygen > 0.0 and oxygen <= max_oxygen * LOW_OXYGEN_RATIO


## 0 at laying, 1 at hatching. Clamped; a zero total reports 0.
static func hatch_progress(seconds_left: float, total_seconds: float) -> float:
	if total_seconds <= 0.0:
		return 0.0
	return clampf(1.0 - seconds_left / total_seconds, 0.0, 1.0)


func _has_indicators() -> bool:
	var max_oxygen := Game.eco.coral_max_oxygen
	for node in get_tree().get_nodes_in_group(Groups.CORALS):
		var coral := node as Coral
		if coral != null and not coral.is_queued_for_deletion() \
				and is_low_oxygen(coral.oxygen, max_oxygen):
			return true
	for node in get_tree().get_nodes_in_group(Groups.NESTS):
		var nest := node as Nest
		if nest != null and not nest.is_queued_for_deletion() and nest.has_eggs() \
				and nest.eggs_time_left() > 0.0:
			return true
	return false


func _draw_indicators() -> void:
	_draw_low_oxygen_rings()
	_draw_egg_rings()


## Pulses a red danger ring around corals that are close to crumbling.
func _draw_low_oxygen_rings() -> void:
	var max_oxygen := Game.eco.coral_max_oxygen
	for node in get_tree().get_nodes_in_group(Groups.CORALS):
		var coral := node as Coral
		if coral == null or coral.is_queued_for_deletion() \
				or not is_low_oxygen(coral.oxygen, max_oxygen):
			continue
		var ring := _coral_ring(coral)
		var center: Vector2 = ring["center"]
		var radius: float = ring["radius"]
		var phase := float(coral.get_instance_id() % 17)
		var pulse := 0.5 + 0.5 * sin(_time * LOW_OXYGEN_PULSE_SPEED + phase)
		var color := LOW_OXYGEN_COLOR
		color.a *= 0.35 + 0.65 * pulse
		draw_polyline(_projected_circle(center, radius + pulse * 2.0), color,
				1.5 + pulse * 1.5, true)


## A barely-there gold arc around a nest while its eggs incubate. No track and
## no end dot; it only brightens as hatching gets close.
func _draw_egg_rings() -> void:
	var total := Game.eco.nest_hatch_seconds
	if total <= 0.0:
		return
	for node in get_tree().get_nodes_in_group(Groups.NESTS):
		var nest := node as Nest
		if nest == null or nest.is_queued_for_deletion() or not nest.has_eggs():
			continue
		var left: float = nest.eggs_time_left()
		if left <= 0.0:
			continue
		var progress := hatch_progress(left, total)
		if progress <= 0.0:
			continue
		var center := nest.global_position
		var radius := Game.grid.cell_size * EGG_RING_RADIUS_CELLS
		var color := EGG_RING_COLOR
		color.a = lerpf(EGG_RING_MIN_ALPHA, EGG_RING_MAX_ALPHA, progress)
		var arc := _projected_arc(center, radius, -PI * 0.5, -PI * 0.5 + TAU * progress, 24)
		draw_polyline(arc, color, EGG_RING_WIDTH, true)


## World-space centre and half-size of a coral's footprint, plus a small margin.
func _coral_ring(coral: Coral) -> Dictionary:
	if coral.cells.is_empty():
		return {"center": coral.global_position, "radius": Game.grid.cell_size * 0.5}
	var half := Game.grid.cell_size * 0.5
	var min_cell: Vector2i = coral.cells[0]
	var max_cell: Vector2i = coral.cells[0]
	for cell in coral.cells:
		min_cell = Vector2i(mini(min_cell.x, cell.x), mini(min_cell.y, cell.y))
		max_cell = Vector2i(maxi(max_cell.x, cell.x), maxi(max_cell.y, cell.y))
	var min_world := Game.grid.cell_to_world(min_cell) - Vector2(half, half)
	var max_world := Game.grid.cell_to_world(max_cell) + Vector2(half, half)
	return {
		"center": (min_world + max_world) * 0.5,
		"radius": maxf(max_world.x - min_world.x, max_world.y - min_world.y) * 0.5 + 4.0,
	}


# --- Effects ---------------------------------------------------------------

## Shared with the tutorial vignettes: core/blood_burst.gd.
func _blood(world_position: Vector2) -> void:
	var burst := BloodBurst.new()
	burst.position = _screen_of(world_position)
	# The old pooled blood froze with the game; keep that behaviour.
	burst.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(burst)


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


func _projected_arc(center_world: Vector2, radius: float, from_angle: float,
		to_angle: float, segments: int) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in range(segments + 1):
		var angle := lerpf(from_angle, to_angle, float(i) / float(segments))
		points.append(Game.projection.to_screen(center_world + Vector2.from_angle(angle) * radius))
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
