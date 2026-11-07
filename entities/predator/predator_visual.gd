class_name PredatorVisual
extends Node2D
## Predator drawing in screen space: sprite facing its heading (dimmed while
## leaving) and a satiety bar while it hunts.

const TEXTURE := preload("res://assets/sprites/predator.png")
## Body centre, tail→head angle and body length in the texture (measured on the art).
const FACING_CENTER := Vector2(297, 295)
const FACING_AXIS_DEG := 32.0
const FACING_LENGTH := 720.0
## Half the sprite height, as a fraction of its body length (bars sit above it).
const SPRITE_HALF_HEIGHT := 0.3
const MAX_TILT_DEG := 30.0
## On-screen body length, in predator radii (world units).
const BODY_LENGTH_RADII := 4.5
const LEAVING_TINT := Color(0.65, 0.65, 0.75)
const BAR_BACK := Color(0.0, 0.0, 0.0, 0.6)
const BAR_FILL := Color(1.0, 0.6, 0.2)
const BAR_SIZE := Vector2(36.0, 5.0)
const SEGMENTS := 20

static var _facing := SpriteFacing.new(FACING_CENTER, deg_to_rad(FACING_AXIS_DEG), FACING_LENGTH, deg_to_rad(MAX_TILT_DEG))

## Projected circle and its top, reused every frame (fixed projection).
var _ellipses: Dictionary = {}
var _tops: Dictionary = {}

var radius_world := 22.0
## Swimming direction in screen space.
var heading := Vector2.RIGHT:
	set(value):
		if not value.is_equal_approx(heading):
			heading = value
			queue_redraw()
var satiety_ratio := 0.0:
	set(value):
		if not is_equal_approx(value, satiety_ratio):
			satiety_ratio = value
			queue_redraw()
var leaving := false:
	set(value):
		if value != leaving:
			leaving = value
			queue_redraw()


func _draw() -> void:
	var length := radius_world * BODY_LENGTH_RADII * Game.VIEW_SETTINGS.pixels_per_unit
	draw_set_transform_matrix(_facing.transform(heading, length))
	draw_texture(TEXTURE, Vector2.ZERO, LEAVING_TINT if leaving else Color.WHITE)
	draw_set_transform_matrix(Transform2D.IDENTITY)
	if leaving:
		return
	var top := minf(-length * SPRITE_HALF_HEIGHT, _top(radius_world))
	var back := Rect2(Vector2(-BAR_SIZE.x * 0.5, top - 10.0), BAR_SIZE)
	draw_rect(back, BAR_BACK)
	draw_rect(Rect2(back.position, Vector2(BAR_SIZE.x * satiety_ratio, BAR_SIZE.y)), BAR_FILL)


## A world-space circle of `radius` around the predator, projected to screen
## space. Cached: the predator redraws every frame while it swims.
func _ellipse(radius: float) -> PackedVector2Array:
	if not _ellipses.has(radius):
		var points := PackedVector2Array()
		for i in SEGMENTS:
			points.append(Vector2.from_angle(TAU * i / SEGMENTS) * radius)
		_ellipses[radius] = Game.projection.project_polygon(points, Vector2.ZERO)
	return _ellipses[radius]


## Screen-space top of the ellipse, for placing the satiety bar.
func _top(radius: float) -> float:
	if not _tops.has(radius):
		var top := INF
		for point in _ellipse(radius):
			top = minf(top, point.y)
		_tops[radius] = top
	return _tops[radius]
