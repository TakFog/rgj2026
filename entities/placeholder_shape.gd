class_name PlaceholderShape
extends Node2D
## Flat-colour placeholder visual drawn in screen space (until real art lands).
## Build with the static helpers so world shapes are projected correctly.

var polygon := PackedVector2Array()
var color := Color.WHITE:
	set(value):
		color = value
		queue_redraw()


## A full grid cell centred on `center_world`.
static func cell(center_world: Vector2, p_color: Color) -> PlaceholderShape:
	var half := Game.grid.cell_size * 0.5
	var corners := PackedVector2Array([
		center_world + Vector2(-half, -half), center_world + Vector2(half, -half),
		center_world + Vector2(half, half), center_world + Vector2(-half, half)])
	return _make(Game.projection.project_polygon(corners, center_world), p_color)


## A circle of `radius` world units centred on `center_world` (an ellipse on screen).
static func circle(center_world: Vector2, radius: float, p_color: Color) -> PlaceholderShape:
	var points := PackedVector2Array()
	for i in 16:
		points.append(center_world + Vector2.from_angle(TAU * i / 16.0) * radius)
	return _make(Game.projection.project_polygon(points, center_world), p_color)


static func _make(p_polygon: PackedVector2Array, p_color: Color) -> PlaceholderShape:
	var shape := PlaceholderShape.new()
	shape.polygon = p_polygon
	shape.color = p_color
	return shape


func _draw() -> void:
	draw_colored_polygon(polygon, color)
