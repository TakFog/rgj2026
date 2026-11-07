class_name Threat
extends Area2D
## Base for moving threats (GDD §7). Moves freely in the logical world, applies
## ThreatRules on contact (GDD §8) and frees itself after leaving the map.
## Subclasses only set kind / radius / speed / turn_noise / color in _init().

signal destroyed

## Distance beyond the world edge (on top of 2 × radius) before a threat is removed.
const EXIT_MARGIN := 32.0
## Screen pixels the threat body floats above its ground shadow.
const HOVER_PX := 18.0

var kind: int = ThreatSchedule.Type.CO2
var radius := 16.0
var speed := 40.0
var turn_noise := 0.0
var color := Color.WHITE
var heading := 0.0

var _drift: DriftMotion
var _hit := {} # target instance id -> true
var _dead := false


## Places the threat just outside the map at `entry`, heading inward.
## Call before adding the node to the tree.
func setup(entry: EdgeEntry, rng: RandomNumberGenerator) -> void:
	heading = entry.heading
	position = entry.point - Vector2.from_angle(heading) * radius
	_drift = DriftMotion.new(turn_noise, rng)


func _ready() -> void:
	collision_layer = Layers.THREAT
	collision_mask = Layers.CORAL | Layers.ALGAE | Layers.FISH | Layers.NEST | Layers.THREAT
	monitoring = true
	monitorable = true
	add_to_group(Groups.THREATS)
	var circle := CircleShape2D.new()
	circle.radius = radius
	var shape := CollisionShape2D.new()
	shape.shape = circle
	add_child(shape)
	body_entered.connect(_on_contact)
	area_entered.connect(_on_contact)
	ViewFollower.attach(self, _make_visual())


func _physics_process(delta: float) -> void:
	if _dead:
		return
	if _drift:
		heading = _drift.step(heading, delta)
	position += Vector2.from_angle(heading) * speed * delta
	var alive_area := Rect2(Vector2.ZERO, Game.grid.world_size()).grow(radius * 2.0 + EXIT_MARGIN)
	if not alive_area.has_point(position):
		destroy()


## Instant contact resolution. Safe to call several times in one physics step.
func _on_contact(other: Node2D) -> void:
	if _dead or not is_instance_valid(other) or other.is_queued_for_deletion():
		return
	var target := ThreatRules.target_of(other)
	if target == ThreatRules.Target.NONE:
		return
	var nest_has_eggs := target == ThreatRules.Target.NEST and (other as Nest).has_eggs()
	var key := other.get_instance_id()
	var outcome := ThreatRules.resolve(kind, target, Game.actors, nest_has_eggs, _hit.has(key))
	_hit[key] = true
	match outcome.effect:
		ThreatRules.Effect.DAMAGE_CORAL:
			(other as Coral).apply_oxygen_damage(outcome.amount)
		ThreatRules.Effect.DESTROY:
			other.call(&"destroy")
		ThreatRules.Effect.ABSORB_CO2:
			(other as Algae).on_co2_absorbed()
		ThreatRules.Effect.KILL_EGGS:
			(other as Nest).kill_eggs()
	if outcome.threat_dies:
		destroy()


## Ground shadow (the real contact footprint) plus a body floating above it.
func _make_visual() -> Node2D:
	var root := Node2D.new()
	root.add_child(PlaceholderShape.circle(position, radius, Color(0, 0, 0, 0.3)))
	var body := PlaceholderShape.circle(position, radius * 0.8, color)
	body.position = Vector2(0, -HOVER_PX)
	root.add_child(body)
	return root


## Idempotent. Safe inside physics callbacks (monitoring is toggled deferred).
func destroy() -> void:
	if _dead:
		return
	_dead = true
	remove_from_group(Groups.THREATS)
	set_deferred("monitoring", false)
	set_deferred("monitorable", false)
	destroyed.emit()
	queue_free()
