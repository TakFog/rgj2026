class_name TurtleVisual
extends Node2D
## Placeholder sea turtle drawing in screen space (until real art lands):
## projected green shell with a head pointing where it swims; the head is
## lowered toward the shell while eating.

const SHELL_COLOR := Color(0.33, 0.55, 0.3)
const OUTLINE_COLOR := Color(0.85, 0.95, 0.6, 0.9)
const SKIN_COLOR := Color(0.6, 0.75, 0.45)
const HEAD_SCALE := 0.35
const SEGMENTS := 20

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
	var forward := heading.normalized() if heading != Vector2.ZERO else Vector2.RIGHT
	var head_distance := radius_world * (0.95 if eating else 1.15)
	var head := _ellipse(forward * head_distance, radius_world * HEAD_SCALE)
	draw_colored_polygon(head, SKIN_COLOR)
	var shell := _ellipse(Vector2.ZERO, radius_world)
	draw_colored_polygon(shell, SHELL_COLOR)
	var outline := shell.duplicate()
	outline.append(shell[0])
	draw_polyline(outline, OUTLINE_COLOR, 2.0)
	var inner := _ellipse(Vector2.ZERO, radius_world * 0.55)
	inner.append(inner[0])
	draw_polyline(inner, OUTLINE_COLOR, 1.0)


## A world-space circle of `radius` at `center` (relative to the turtle),
## projected to screen space.
func _ellipse(center: Vector2, radius: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in SEGMENTS:
		points.append(center + Vector2.from_angle(TAU * i / SEGMENTS) * radius)
	return Game.projection.project_polygon(points, Vector2.ZERO)
