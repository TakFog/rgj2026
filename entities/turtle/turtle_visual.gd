class_name TurtleVisual
extends Node2D
## Sea turtle drawing in screen space: a temporary sprite (until the designer's
## art lands) over a projected ground shadow, flipped to face where it swims;
## it dips toward the seabed while eating.

## Temporary art, until the designer's turtle sprite is ready. Faces right.
const TEXTURE := preload("res://assets/sprites/temp/turtle.png")
const SHADOW_COLOR := Color(0.0, 0.0, 0.0, 0.3)
## On-screen sprite width, in turtle radii (world units).
const WIDTH_RADII := 2.6
## Screen pixels the body floats above its shadow (lower while eating).
const HOVER_PX := 10.0
const EATING_HOVER_PX := 3.0
const SEGMENTS := 20

## Projected circles reused every frame (the projection is fixed during a run).
var _ellipses: Dictionary = {}

var radius_world := 20.0
var heading := Vector2.RIGHT:
	set(value):
		if not value.is_equal_approx(heading):
			heading = value
			queue_redraw()
var eating := false:
	set(value):
		if value != eating:
			eating = value
			queue_redraw()


func _draw() -> void:
	draw_colored_polygon(_ellipse(radius_world), SHADOW_COLOR)
	var width := radius_world * WIDTH_RADII * Game.VIEW_SETTINGS.pixels_per_unit
	var size := Vector2(width, width * TEXTURE.get_height() / TEXTURE.get_width())
	if heading.x < 0.0:
		size.x = -size.x # flip to face left
	var hover := EATING_HOVER_PX if eating else HOVER_PX
	draw_texture_rect(TEXTURE, Rect2(Vector2(-size.x * 0.5, -size.y * 0.5 - hover), size), false)


## A world-space circle of `radius` around the turtle, projected to screen
## space. Cached: the turtle redraws every frame while it swims.
func _ellipse(radius: float) -> PackedVector2Array:
	if not _ellipses.has(radius):
		var points := PackedVector2Array()
		for i in SEGMENTS:
			points.append(Vector2.from_angle(TAU * i / SEGMENTS) * radius)
		_ellipses[radius] = Game.projection.project_polygon(points, Vector2.ZERO)
	return _ellipses[radius]
