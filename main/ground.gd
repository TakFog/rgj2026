extends Node2D
## Draws the open seabed over the whole screen, the painted map on top of it
## (its sand fitted onto the playable island) and, while placing, the grid
## lines (island only). Seabed and map share the animated seabed shader
## (main/seabed.gdshader: caustics, light shafts, refraction).

const MAP := preload("res://assets/sprites/map.png")
## The map's sand area as a parallelogram (texture px, measured on the art):
## top/bottom rows and the range of `x + SAND_SLANT * y` across it.
const SAND_TOP := 602.0
const SAND_BOTTOM := 1550.0
const SAND_SLANT := 0.55
const SAND_LEFT := 1799.0
const SAND_RIGHT := 3185.0
## Grows the fitted sand past the island border, so its ragged edge stays outside.
const SAND_MARGIN := 0.04
## Average colour of the map's outer border, fills the screen around it.
const OPEN_SEABED := Color8(6, 18, 23)
## Fraction of the map width/height (per side) faded out into OPEN_SEABED,
## hiding its edges. Kept inside the water margin around the sand.
const MAP_EDGE_FADE := Vector2(0.1, 0.08)
const GRID_LINE := Color(1, 1, 1, 0.12)
const SEABED_SHADER := preload("res://main/seabed.gdshader")


## Grid lines over the island, shown while placing.
class GridLines extends Node2D:
	func _process(_delta: float) -> void:
		queue_redraw()

	func _draw() -> void:
		if not Game.placing:
			return
		var size := Game.grid.world_size()
		var step := Game.grid.cell_size
		for x in Game.grid.size.x + 1:
			draw_line(Game.projection.to_screen(Vector2(x * step, 0)), Game.projection.to_screen(Vector2(x * step, size.y)), GRID_LINE)
		for y in Game.grid.size.y + 1:
			draw_line(Game.projection.to_screen(Vector2(0, y * step)), Game.projection.to_screen(Vector2(size.x, y * step)), GRID_LINE)


func _ready() -> void:
	z_index = -100
	var size := Game.grid.world_size()
	var corners := PackedVector2Array([Vector2.ZERO, Vector2(size.x, 0), size, Vector2(0, size.y)])
	var map := Sprite2D.new()
	map.name = "Map"
	map.texture = MAP
	map.centered = false
	map.transform = _map_transform(Game.projection.project_polygon(corners, Vector2.ZERO))
	material = _seabed_material()
	map.material = _seabed_material()
	map.material.set_shader_parameter("edge_fade", MAP_EDGE_FADE)
	add_child(map)
	var grid := GridLines.new()
	grid.name = "GridLines"
	add_child(grid)


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	draw_colored_polygon(_screen_polygon(), OPEN_SEABED)


func _seabed_material() -> ShaderMaterial:
	var seabed := ShaderMaterial.new()
	seabed.shader = SEABED_SHADER
	var origin := Game.projection.to_world(Vector2.ZERO)
	seabed.set_shader_parameter("to_world_x", Game.projection.to_world(Vector2.RIGHT) - origin)
	seabed.set_shader_parameter("to_world_y", Game.projection.to_world(Vector2.DOWN) - origin)
	return seabed


## Map texture → local transform mapping the sand parallelogram onto `island`
## (its 4 projected corners, grown by SAND_MARGIN).
func _map_transform(island: PackedVector2Array) -> Transform2D:
	var height := SAND_BOTTOM - SAND_TOP
	var sand := Transform2D(Vector2(SAND_RIGHT - SAND_LEFT, 0.0), Vector2(-SAND_SLANT * height, height),
		Vector2(SAND_LEFT - SAND_SLANT * SAND_TOP, SAND_TOP))
	var x_edge := island[1] - island[0]
	var y_edge := island[3] - island[0]
	var grown := Transform2D(x_edge * (1.0 + 2.0 * SAND_MARGIN), y_edge * (1.0 + 2.0 * SAND_MARGIN),
		island[0] - (x_edge + y_edge) * SAND_MARGIN)
	return grown * sand.affine_inverse()


## The visible screen area in this node's coordinates (camera included).
func _screen_polygon() -> PackedVector2Array:
	var to_local := get_global_transform_with_canvas().affine_inverse()
	var rect := get_viewport_rect()
	return PackedVector2Array([
		to_local * rect.position, to_local * Vector2(rect.end.x, rect.position.y),
		to_local * rect.end, to_local * Vector2(rect.position.x, rect.end.y)])
