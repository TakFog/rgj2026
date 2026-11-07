class_name PredatorVisual
extends Node2D
## Placeholder predator drawing in screen space (until real art lands):
## big dark-red projected body and a satiety bar while it hunts.

const BODY_COLOR := Color(0.55, 0.1, 0.12)
const LEAVING_COLOR := Color(0.4, 0.2, 0.22)
const OUTLINE_COLOR := Color(1.0, 0.35, 0.3, 0.9)
const BAR_BACK := Color(0.0, 0.0, 0.0, 0.6)
const BAR_FILL := Color(1.0, 0.6, 0.2)
const BAR_SIZE := Vector2(36.0, 5.0)
const SEGMENTS := 20

var radius_world := 22.0
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
	var body := _ellipse(radius_world)
	draw_colored_polygon(body, LEAVING_COLOR if leaving else BODY_COLOR)
	var outline := body.duplicate()
	outline.append(body[0])
	draw_polyline(outline, OUTLINE_COLOR, 2.0)
	if leaving:
		return
	var top := 0.0
	for point in body:
		top = minf(top, point.y)
	var back := Rect2(Vector2(-BAR_SIZE.x * 0.5, top - 10.0), BAR_SIZE)
	draw_rect(back, BAR_BACK)
	draw_rect(Rect2(back.position, Vector2(BAR_SIZE.x * satiety_ratio, BAR_SIZE.y)), BAR_FILL)


## A world-space circle of `radius` around the predator, projected to screen space.
func _ellipse(radius: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in SEGMENTS:
		points.append(Vector2.from_angle(TAU * i / SEGMENTS) * radius)
	return Game.projection.project_polygon(points, Vector2.ZERO)
