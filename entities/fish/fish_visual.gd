class_name FishVisual
extends Node2D
## Placeholder fish drawing in screen space (until real art lands):
## projected body ellipse, selection ring, hunger bar.

const BODY_COLOR := Color(0.3, 0.7, 1.0)
const RING_COLOR := Color(1.0, 1.0, 1.0, 0.9)
const BAR_BACK := Color(0.0, 0.0, 0.0, 0.6)
const BAR_FILL := Color(0.95, 0.3, 0.2)
const BAR_SIZE := Vector2(24.0, 4.0)
const JUVENILE_SCALE := 0.6
const RING_GAP := 4.0
const SEGMENTS := 16

var radius_world := 10.0
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
	var body := _ellipse(radius)
	if selected:
		var ring := _ellipse(radius + RING_GAP)
		ring.append(ring[0])
		draw_polyline(ring, RING_COLOR, 2.0)
	draw_colored_polygon(body, BODY_COLOR)
	if hunger_ratio > hunger_threshold:
		var top := 0.0
		for point in body:
			top = minf(top, point.y)
		var back := Rect2(Vector2(-BAR_SIZE.x * 0.5, top - 8.0), BAR_SIZE)
		draw_rect(back, BAR_BACK)
		draw_rect(Rect2(back.position, Vector2(BAR_SIZE.x * hunger_ratio, BAR_SIZE.y)), BAR_FILL)


## A world-space circle of `radius` around the fish, projected to screen space.
func _ellipse(radius: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in SEGMENTS:
		points.append(Vector2.from_angle(TAU * i / SEGMENTS) * radius)
	return Game.projection.project_polygon(points, Vector2.ZERO)
