extends Node2D
## Draws the open seabed over the whole screen, the playable island on top
## of it and, while placing, the grid lines (island only).

const OPEN_SEABED := Color(0.03, 0.1, 0.19)
const ISLAND := Color(0.08, 0.22, 0.35)
const ISLAND_EDGE := Color(0.35, 0.6, 0.75, 0.6)
const ISLAND_EDGE_WIDTH := 3.0
const GRID_LINE := Color(1, 1, 1, 0.12)


func _ready() -> void:
	z_index = -100


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var size := Game.grid.world_size()
	var corners := PackedVector2Array([Vector2.ZERO, Vector2(size.x, 0), size, Vector2(0, size.y)])
	var island := Game.projection.project_polygon(corners, Vector2.ZERO)
	draw_colored_polygon(_screen_polygon(), OPEN_SEABED)
	draw_colored_polygon(island, ISLAND)
	var outline := island.duplicate()
	outline.append(island[0])
	draw_polyline(outline, ISLAND_EDGE, ISLAND_EDGE_WIDTH, true)
	if not Game.placing:
		return
	var step := Game.grid.cell_size
	for x in Game.grid.size.x + 1:
		draw_line(Game.projection.to_screen(Vector2(x * step, 0)), Game.projection.to_screen(Vector2(x * step, size.y)), GRID_LINE)
	for y in Game.grid.size.y + 1:
		draw_line(Game.projection.to_screen(Vector2(0, y * step)), Game.projection.to_screen(Vector2(size.x, y * step)), GRID_LINE)


## The visible screen area in this node's coordinates (camera included).
func _screen_polygon() -> PackedVector2Array:
	var to_local := get_global_transform_with_canvas().affine_inverse()
	var rect := get_viewport_rect()
	return PackedVector2Array([
		to_local * rect.position, to_local * Vector2(rect.end.x, rect.position.y),
		to_local * rect.end, to_local * Vector2(rect.position.x, rect.end.y)])
