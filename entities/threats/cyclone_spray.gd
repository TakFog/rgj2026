class_name CycloneSpray
extends Node2D
## Orbiting water droplets around the cyclone funnel. Purely cosmetic: they
## rise and spiral outward along the funnel, then fade near the mouth.

class Droplet:
	var angle := 0.0
	## 0 at the funnel tip, 1 at the top of the art.
	var height := 0.0
	var spin := 1.5
	var rise := 0.35
	var size := 2.0
	var life := 1.5
	var age := 0.0
	var radius_scale := 1.0

const MAX_DROPLETS := 22
const SPAWN_RATE := 10.0
const MIN_SIZE_PX := 1.0
const MAX_SIZE_PX := 2.4
const SPIN_SPEED := Vector2(1.8, 3.6)
const RISE_SPEED := Vector2(0.25, 0.55)
const LIFE := Vector2(1.2, 2.2)
const RADIUS_SCALE := Vector2(0.7, 1.0)
## The funnel reaches its widest point around here (measured on the stock art).
const MOUTH_HEIGHT := 0.65
## Orbit radius at the tip and at the mouth, as a fraction of the art half-width.
const TIP_ORBIT := 0.15
const MOUTH_ORBIT := 0.85
const FILL := Color(0.85, 0.97, 1.0, 0.55)
const GLINT := Color(1.0, 1.0, 1.0, 0.95)

## Visible funnel height in screen pixels.
var funnel_height := 93.0
## Visible funnel half-width in world units.
var funnel_half_width := 35.0
## Screen-space bottom of the funnel (the tip on the ground shadow).
var funnel_bottom := Vector2.ZERO
var tint := Color.WHITE
var spin_sign := 1.0

var _rng := RandomNumberGenerator.new()
var _droplets: Array[Droplet] = []
var _debt := 0.0
var _to_screen := Transform2D.IDENTITY


## Call before adding the spray to the tree.
func setup(p_funnel_height: float, p_funnel_half_width: float, p_funnel_bottom: Vector2, p_tint: Color) -> void:
	funnel_height = p_funnel_height
	funnel_half_width = p_funnel_half_width
	funnel_bottom = p_funnel_bottom
	tint = p_tint
	_rng.randomize()
	spin_sign = 1.0 if _rng.randf() < 0.5 else -1.0
	var ppu := Game.VIEW_SETTINGS.pixels_per_unit
	_to_screen = Transform2D(
		Game.VIEW_SETTINGS.x_axis * ppu,
		Game.VIEW_SETTINGS.y_axis * ppu,
		Vector2.ZERO)


func _process(delta: float) -> void:
	_debt += SPAWN_RATE * delta
	while _debt >= 1.0:
		_debt -= 1.0
		if _droplets.size() < MAX_DROPLETS:
			_spawn()
	for i in range(_droplets.size() - 1, -1, -1):
		var d := _droplets[i]
		d.age += delta
		d.angle += d.spin * delta
		d.height += d.rise * delta
		if d.age >= d.life or d.height >= 1.0:
			_droplets.remove_at(i)
	queue_redraw()


func _spawn() -> void:
	var d := Droplet.new()
	d.angle = _rng.randf() * TAU
	d.height = _rng.randf_range(0.0, 0.25)
	d.spin = spin_sign * _rng.randf_range(SPIN_SPEED.x, SPIN_SPEED.y)
	d.rise = _rng.randf_range(RISE_SPEED.x, RISE_SPEED.y)
	d.size = _rng.randf_range(MIN_SIZE_PX, MAX_SIZE_PX)
	d.life = _rng.randf_range(LIFE.x, LIFE.y)
	d.radius_scale = _rng.randf_range(RADIUS_SCALE.x, RADIUS_SCALE.y)
	_droplets.append(d)


func _draw() -> void:
	for d in _droplets:
		var h := clampf(d.height, 0.0, 1.0)
		var fade := smoothstep(0.0, 0.15, d.age)
		fade *= 1.0 - smoothstep(0.7, 0.95, h)
		fade *= 1.0 - smoothstep(d.life * 0.75, d.life, d.age)
		if fade <= 0.0:
			continue
		var pos := _droplet_pos(d, h)
		var fill := FILL * tint
		fill.a *= fade
		var glint := GLINT * tint
		glint.a *= fade
		draw_circle(pos, d.size, fill)
		draw_circle(pos + Vector2(-0.35, -0.35) * d.size, maxf(0.5, d.size * 0.3), glint)


## Screen position of a droplet on the funnel: it orbits in the oblique ground
## plane and rises from the tip (h = 0) to the top of the art (h = 1).
func _droplet_pos(d: Droplet, h: float) -> Vector2:
	var reach := smoothstep(0.0, MOUTH_HEIGHT, h)
	var orbit_world := lerpf(TIP_ORBIT, MOUTH_ORBIT, reach) * funnel_half_width * d.radius_scale
	var orbit := _to_screen * (Vector2.from_angle(d.angle) * orbit_world)
	return funnel_bottom + orbit + Vector2(0.0, -h * funnel_height)
