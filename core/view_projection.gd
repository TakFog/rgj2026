class_name ViewProjection
extends RefCounted
## Affine projection from the logical top-down world to screen space.
## screen = world.x * x_axis + world.y * y_axis (scaled by pixels_per_unit).
## Default oblique "/__/" view: x_axis = (1, 0), y_axis = (-0.5, 0.5).

var _to_screen: Transform2D
var _to_world: Transform2D


func _init(x_axis: Vector2, y_axis: Vector2, pixels_per_unit: float, origin: Vector2 = Vector2.ZERO) -> void:
	_to_screen = Transform2D(x_axis * pixels_per_unit, y_axis * pixels_per_unit, origin)
	_to_world = _to_screen.affine_inverse()


static func from_settings(settings: ViewSettings) -> ViewProjection:
	return ViewProjection.new(settings.x_axis, settings.y_axis, settings.pixels_per_unit)


func to_screen(world: Vector2) -> Vector2:
	return _to_screen * world


func to_world(screen: Vector2) -> Vector2:
	return _to_world * screen


## Projects a world-space polygon (e.g. a cell's 4 corners) to screen space,
## relative to the projection of `anchor`. Used to draw shapes around a ViewFollower.
func project_polygon(points: PackedVector2Array, anchor: Vector2) -> PackedVector2Array:
	var result := PackedVector2Array()
	var anchor_screen := to_screen(anchor)
	for point in points:
		result.append(to_screen(point) - anchor_screen)
	return result
