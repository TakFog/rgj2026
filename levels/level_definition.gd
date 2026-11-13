class_name LevelDefinition
extends RefCounted
## One campaign level: time limit, enabled mechanics and starting reef (GDD §4).
## Pure data, built by LevelCatalog; `populate` is the only place that touches
## the scene tree.

## Player-facing name and the mechanic this level introduces (menu/clear cards).
var level_name := ""
var mechanic_summary := ""
## Time limit in seconds. Reaching 0 with the reef alive clears the level.
var duration_seconds := 60.0
## Sandbox mode: no countdown and no clear, the run lasts until a collapse.
var endless := false

## Mechanics enabled for this level. Main copies them into the balance flags
## before the systems enter the tree, so the F3 overlay shows the real state.
var temperature_enabled := false
var co2_enabled := false
var bag_enabled := false
var cyclone_enabled := false
var predator_enabled := false
var turtle_enabled := false

## Starting map: `[shape_id: StringName, origin_cell: Vector2i]` pairs, algae,
## nest and adult-fish cells. Same 20x20 grid for every level.
var corals: Array[Array] = []
var algae: Array[Vector2i] = []
var nests: Array[Vector2i] = []
var fish: Array[Vector2i] = []


func populate(factory: EntityFactory) -> void:
	for entry: Array in corals:
		var shape: StringName = entry[0]
		var origin: Vector2i = entry[1]
		factory.spawn_coral(shape, origin)
	for cell: Vector2i in algae:
		factory.spawn_algae(cell)
	for cell: Vector2i in nests:
		factory.spawn_nest(cell)
	for cell: Vector2i in fish:
		factory.spawn_fish(Game.grid.cell_to_world(cell), true)
