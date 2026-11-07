extends Node2D
## Draws the seabed parallelogram and, while placing, the grid lines.

const SEABED := Color(0.08, 0.22, 0.35)
const GRID_LINE := Color(1, 1, 1, 0.12)


func _ready() -> void:
	z_index = -100


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var size := Game.grid.world_size()
	var corners := PackedVector2Array([Vector2.ZERO, Vector2(size.x, 0), size, Vector2(0, size.y)])
	draw_colored_polygon(Game.projection.project_polygon(corners, Vector2.ZERO), SEABED)
	if not Game.placing:
		return
	var step := Game.grid.cell_size
	for x in Game.grid.size.x + 1:
		draw_line(Game.projection.to_screen(Vector2(x * step, 0)), Game.projection.to_screen(Vector2(x * step, size.y)), GRID_LINE)
	for y in Game.grid.size.y + 1:
		draw_line(Game.projection.to_screen(Vector2(0, y * step)), Game.projection.to_screen(Vector2(size.x, y * step)), GRID_LINE)
