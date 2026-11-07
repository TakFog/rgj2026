class_name TurtleVisual
extends Node2D
## Sea turtle drawing in screen space: sprite mirrored and tilted toward its
## heading like the fish; it dips toward the seabed while eating.

## Final art. Faces left in the texture, so it is mirrored when swimming right.
const TEXTURE := preload("res://assets/sprites/turtle.png")
## Body centre in the texture (measured on the art); rotation pivots on it.
const FACING_CENTER := Vector2(126, 138)
const MAX_TILT_DEG := 30.0
## On-screen sprite width, in turtle radii (world units).
const WIDTH_RADII := 2.6
## Screen pixels the body floats off the seabed (lower while eating).
const HOVER_PX := 10.0
const EATING_HOVER_PX := 3.0

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
	var width := radius_world * WIDTH_RADII * Game.VIEW_SETTINGS.pixels_per_unit
	var sprite_scale := width / TEXTURE.get_width()
	var size := TEXTURE.get_size() * sprite_scale
	var hover := EATING_HOVER_PX if eating else HOVER_PX
	var matrix := facing(heading)
	matrix.origin = Vector2(0.0, -hover)
	draw_set_transform_matrix(matrix)
	draw_texture_rect(TEXTURE, Rect2(-FACING_CENTER * sprite_scale, size), false)
	draw_set_transform_matrix(Transform2D.IDENTITY)


## Sprite transform: mirrored when swimming right and tilted toward `heading`,
## up to `MAX_TILT_DEG`, around the body centre.
static func facing(p_heading: Vector2) -> Transform2D:
	var flip := p_heading.x >= 0.0
	var tilt := 0.0
	if p_heading != Vector2.ZERO:
		var level := 0.0 if flip else PI
		var limit := deg_to_rad(MAX_TILT_DEG)
		tilt = clampf(wrapf(p_heading.angle() - level, -PI, PI), -limit, limit)
	return Transform2D(tilt, Vector2(-1.0 if flip else 1.0, 1.0), 0.0, Vector2.ZERO)
