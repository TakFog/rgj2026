class_name FishVisual
extends Node2D
## Fish drawing in screen space: sprite facing its heading, selection ring,
## hunger bar.

const TEXTURE := preload("res://assets/sprites/fish.png")
## Body centre, tail→head angle and body length in the texture (measured on the art).
const FACING_CENTER := Vector2(122, 112)
const FACING_AXIS_DEG := -38.0
const FACING_LENGTH := 210.0
## Half the sprite height, as a fraction of its body length (bars sit above it).
const SPRITE_HALF_HEIGHT := 0.4
const MAX_TILT_DEG := 35.0
## On-screen body length, in fish radii (world units).
const BODY_LENGTH_RADII := 4.0
const RING_COLOR := Color(1.0, 1.0, 1.0, 0.9)
const BAR_BACK := Color(0.0, 0.0, 0.0, 0.6)
const BAR_FILL := Color(0.95, 0.3, 0.2)
const BAR_SIZE := Vector2(24.0, 4.0)
const JUVENILE_SCALE := 0.6
const RING_GAP := 4.0
const SEGMENTS := 16

static var _facing := SpriteFacing.new(FACING_CENTER, deg_to_rad(FACING_AXIS_DEG), FACING_LENGTH, deg_to_rad(MAX_TILT_DEG))

## Projected circles are reused every frame (the projection is fixed during a
## run), keyed by radius. `_ring` adds the closing point; `_top` is the highest
## screen-space point, used to place the hunger bar.
var _ellipses: Dictionary = {}
var _rings: Dictionary = {}
var _tops: Dictionary = {}

var radius_world := 10.0
## Swimming direction in screen space.
var heading := Vector2.RIGHT:
	set(value):
		if not value.is_equal_approx(heading):
			heading = value
			queue_redraw()
var hunger_threshold := 0.5
var adult := true:
	set(value):
		adult = value
		queue_redraw()
var selected := false:
	set(value):
		selected = value
		queue_redraw()
var hunger_ratio := 0.0:
	set(value):
		if not is_equal_approx(value, hunger_ratio):
			hunger_ratio = value
			queue_redraw()


func _draw() -> void:
	var radius := radius_world * (1.0 if adult else JUVENILE_SCALE)
	if selected:
		draw_polyline(_ring(radius + RING_GAP), RING_COLOR, 2.0)
	var length := radius * BODY_LENGTH_RADII * Game.VIEW_SETTINGS.pixels_per_unit
	draw_set_transform_matrix(_facing.transform(heading, length))
	draw_texture(TEXTURE, Vector2.ZERO)
	draw_set_transform_matrix(Transform2D.IDENTITY)
	if hunger_ratio > hunger_threshold:
		var top := minf(-length * SPRITE_HALF_HEIGHT, _top(radius))
		var back := Rect2(Vector2(-BAR_SIZE.x * 0.5, top - 8.0), BAR_SIZE)
		draw_rect(back, BAR_BACK)
		draw_rect(Rect2(back.position, Vector2(BAR_SIZE.x * fullness_ratio(hunger_ratio), BAR_SIZE.y)), BAR_FILL)


## Bar fill, opposite to hunger: full when fed, empty when about to starve
## (the same full-means-sated logic as the predator's satiety bar).
static func fullness_ratio(p_hunger_ratio: float) -> float:
	return 1.0 - clampf(p_hunger_ratio, 0.0, 1.0)


## A world-space circle of `radius` around the fish, projected to screen space.
## Cached: the fish redraws every frame while it swims.
func _ellipse(radius: float) -> PackedVector2Array:
	if not _ellipses.has(radius):
		var points := PackedVector2Array()
		for i in SEGMENTS:
			points.append(Vector2.from_angle(TAU * i / SEGMENTS) * radius)
		_ellipses[radius] = Game.projection.project_polygon(points, Vector2.ZERO)
	return _ellipses[radius]


## The same ellipse, closed for draw_polyline (selection ring).
func _ring(radius: float) -> PackedVector2Array:
	if not _rings.has(radius):
		var ring := _ellipse(radius).duplicate()
		ring.append(ring[0])
		_rings[radius] = ring
	return _rings[radius]


## Screen-space top of the ellipse, for placing the hunger bar.
func _top(radius: float) -> float:
	if not _tops.has(radius):
		var top := INF
		for point in _ellipse(radius):
			top = minf(top, point.y)
		_tops[radius] = top
	return _tops[radius]
