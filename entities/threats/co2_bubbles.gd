class_name Co2Bubbles
extends Node2D
## CO2 cloud body in screen space: a soft grey nebula (a few drifting radial
## blobs, no outline) with soda-like fizz bubbles (clear body, bright rim,
## glint) that keep rising through it and popping, like a fizzy drink.
## Purely cosmetic: the contact footprint is the threat's collision circle.

## Screen-pixel size the sizes below are tuned for (a 60-unit cloud).
const REFERENCE_RADIUS_PX := 75.0
## Rough radius of the grey nebula, in cloud screen radii.
const BODY_RADII := 0.8
## Soft blobs that make up the nebula.
const BLOB_COUNT := 6
## Fizz bubbles spawned per second (at the reference size).
const FIZZ_RATE := 22.0
const FIZZ_MAX := 48
const FIZZ_MIN_PX := 1.5
const FIZZ_MAX_PX := 3.5
const FIZZ_SPEED := Vector2(28.0, 60.0) # px/s, min..max
const POP_TIME := 0.18

const BODY := Color(0.04, 0.04, 0.05, 0.25)
const FILL := Color(0.82, 0.9, 1.0, 0.18)
const RIM := Color(1.0, 1.0, 1.0, 0.8)
const GLINT := Color(1.0, 1.0, 1.0, 0.95)

## On-screen cloud radius in pixels; set before adding to the tree.
var radius_px := REFERENCE_RADIUS_PX
## Tint applied to the whole drawing (alpha included).
var tint := Color.WHITE

var _rng := RandomNumberGenerator.new()
var _time := 0.0
var _fizz: Array[Dictionary] = []
var _pops: Array[Dictionary] = []
var _fizz_debt := 0.0
var _blobs: Array[Dictionary] = []
## Shared radial falloff (opaque centre to transparent rim) for the blobs.
static var _blob_texture: GradientTexture2D


func _ready() -> void:
	_rng.randomize()
	if _blob_texture == null:
		var gradient := Gradient.new()
		gradient.set_color(0, Color.WHITE)
		gradient.set_color(1, Color(1, 1, 1, 0))
		gradient.add_point(0.45, Color(1, 1, 1, 0.55))
		_blob_texture = GradientTexture2D.new()
		_blob_texture.gradient = gradient
		_blob_texture.fill = GradientTexture2D.FILL_RADIAL
		_blob_texture.fill_from = Vector2(0.5, 0.5)
		_blob_texture.fill_to = Vector2(1.0, 0.5)
		_blob_texture.width = 128
		_blob_texture.height = 128
	var body_r := BODY_RADII * radius_px
	for i in BLOB_COUNT:
		_blobs.append({
			"offset": Vector2.from_angle(_rng.randf() * TAU) * _rng.randf_range(0.0, 0.45) * body_r,
			"r": _rng.randf_range(0.6, 1.0) * body_r,
			"phase": _rng.randf() * TAU,
			"speed": _rng.randf_range(0.3, 0.7) * (1.0 if _rng.randf() < 0.5 else -1.0),
		})


func _process(delta: float) -> void:
	_time += delta
	_update_fizz(delta)
	queue_redraw()


func _update_fizz(delta: float) -> void:
	var scale_k := radius_px / REFERENCE_RADIUS_PX
	_fizz_debt += FIZZ_RATE * scale_k * delta
	while _fizz_debt >= 1.0:
		_fizz_debt -= 1.0
		if _fizz.size() >= FIZZ_MAX:
			continue
		# Start low in the nebula and rise until it pops near the top.
		var body_r := BODY_RADII * radius_px
		var x := _rng.randf_range(-0.85, 0.85) * body_r
		var half_chord := sqrt(body_r * body_r - x * x)
		_fizz.append({
			"x": x,
			"y": _rng.randf_range(0.0, half_chord),
			"top": -half_chord * _rng.randf_range(0.6, 1.0),
			"r": _rng.randf_range(FIZZ_MIN_PX, FIZZ_MAX_PX) * maxf(scale_k, 0.6),
			"speed": _rng.randf_range(FIZZ_SPEED.x, FIZZ_SPEED.y),
			"phase": _rng.randf() * TAU,
		})
	for i in range(_fizz.size() - 1, -1, -1):
		var f := _fizz[i]
		f.y -= f.speed * delta
		if f.y <= f.top:
			_pops.append({"pos": _fizz_pos(f), "r": f.r, "age": 0.0})
			_fizz.remove_at(i)
	for i in range(_pops.size() - 1, -1, -1):
		_pops[i].age += delta
		if _pops[i].age >= POP_TIME:
			_pops.remove_at(i)


func _fizz_pos(f: Dictionary) -> Vector2:
	return Vector2(f.x + sin(_time * 6.0 + f.phase) * 2.0, f.y)


func _draw() -> void:
	_draw_cloud()
	for f in _fizz:
		_draw_bubble(_fizz_pos(f), f.r)
	for p in _pops:
		var k: float = p.age / POP_TIME
		var ring := RIM * tint
		ring.a *= 1.0 - k
		draw_arc(p.pos, p.r * (1.0 + 1.5 * k), 0.0, TAU, 10, ring, 1.0, true)


## Overlapping soft blobs slowly circling and breathing, so the gas has no
## fixed outline.
func _draw_cloud() -> void:
	for b in _blobs:
		var angle: float = _time * b.speed + b.phase
		var center: Vector2 = b.offset.rotated(angle * 0.5) + Vector2.from_angle(angle) * radius_px * 0.06
		var r: float = b.r * (1.0 + 0.08 * sin(_time * 0.9 + b.phase))
		draw_texture_rect(_blob_texture, Rect2(center - Vector2(r, r), Vector2(r, r) * 2.0), false, BODY * tint)


func _draw_bubble(center: Vector2, r: float) -> void:
	draw_circle(center, r, FILL * tint)
	draw_arc(center, r, 0.0, TAU, maxi(10, int(r * 1.5)), RIM * tint, clampf(r * 0.1, 1.0, 2.0), true)
	draw_circle(center + Vector2(-0.38, -0.38) * r, maxf(0.8, r * 0.2), GLINT * tint)
