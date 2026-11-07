class_name BloodBurst
extends Node2D
## Short-lived screen-space blood splash: red droplets plus a softer dark haze.
## Self-contained and self-freeing, so any screen-space scene (the game's Juice
## system or the tutorial vignettes) can spawn one at a local point.

const COLORS := [
	Color(0.85, 0.06, 0.10, 0.9),
	Color(0.62, 0.02, 0.05, 0.9),
	Color(1.0, 0.22, 0.20, 0.8),
]
const CLOUD_COLOR := Color(0.55, 0.02, 0.04, 0.35)
const DROPLET_COUNT := 20
const CLOUD_COUNT := 4
const DROPLET_SPEED := Vector2(25.0, 85.0)
const DROPLET_RADIUS := Vector2(2.0, 5.0)
const DROPLET_LIFE := Vector2(0.45, 0.9)
const CLOUD_RADIUS := Vector2(7.0, 12.0)
const CLOUD_LIFE := Vector2(0.45, 0.75)
const GRAVITY := 55.0
const DRAG := 1.2
const UPWARD := -15.0
const CLOUD_GRAVITY := -5.0
const CLOUD_DRAG := 0.8


class Particle:
	var pos := Vector2.ZERO
	var vel := Vector2.ZERO
	var color := Color.WHITE
	var radius := 1.0
	var age := 0.0
	var life := 1.0
	var gravity := 0.0
	var drag := 0.0


var _particles: Array[Particle] = []
var _rng := RandomNumberGenerator.new()


func _init() -> void:
	_rng.randomize()
	# Droplets first, then the haze: same order and tuning as the in-game burst.
	for i in DROPLET_COUNT:
		var direction := Vector2.from_angle(_rng.randf() * TAU)
		var color: Color = COLORS[_rng.randi_range(0, COLORS.size() - 1)]
		var droplet := Particle.new()
		droplet.pos = direction * _rng.randf_range(0.0, 4.0)
		droplet.vel = direction * _rng.randf_range(DROPLET_SPEED.x, DROPLET_SPEED.y) \
			+ Vector2(0.0, UPWARD)
		droplet.color = color
		droplet.radius = _rng.randf_range(DROPLET_RADIUS.x, DROPLET_RADIUS.y)
		droplet.life = _rng.randf_range(DROPLET_LIFE.x, DROPLET_LIFE.y)
		droplet.gravity = GRAVITY
		droplet.drag = DRAG
		_particles.append(droplet)
	for i in CLOUD_COUNT:
		var cloud := Particle.new()
		cloud.pos = Vector2(_rng.randf_range(-8.0, 8.0), _rng.randf_range(-8.0, 8.0))
		cloud.vel = Vector2(_rng.randf_range(-8.0, 8.0), _rng.randf_range(-15.0, 0.0))
		cloud.color = CLOUD_COLOR
		cloud.radius = _rng.randf_range(CLOUD_RADIUS.x, CLOUD_RADIUS.y)
		cloud.life = _rng.randf_range(CLOUD_LIFE.x, CLOUD_LIFE.y)
		cloud.gravity = CLOUD_GRAVITY
		cloud.drag = CLOUD_DRAG
		_particles.append(cloud)


func _process(delta: float) -> void:
	var alive := false
	for i in range(_particles.size() - 1, -1, -1):
		var p := _particles[i]
		p.age += delta
		if p.age >= p.life:
			_particles.remove_at(i)
			continue
		p.vel += Vector2(0.0, p.gravity) * delta
		p.vel *= maxf(0.0, 1.0 - p.drag * delta)
		p.pos += p.vel * delta
		alive = true
	queue_redraw()
	if not alive:
		queue_free()


func _draw() -> void:
	for p in _particles:
		var k := p.age / p.life
		var color := p.color
		color.a *= 1.0 - k
		draw_circle(p.pos, p.radius * (1.0 - 0.35 * k), color)
