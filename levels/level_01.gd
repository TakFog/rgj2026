class_name Level01
extends RefCounted
## Fixed starting map (GDD §4). Cells are in a 20x20 grid.

const CORALS := [
	[&"single", Vector2i(4, 4)],
	[&"domino", Vector2i(13, 3)],
	[&"ell", Vector2i(3, 13)],
	[&"square", Vector2i(14, 14)],
	[&"tee", Vector2i(8, 9)],
]
const ALGAE: Array[Vector2i] = [
	Vector2i(6, 4), Vector2i(7, 5), Vector2i(12, 6), Vector2i(5, 15), Vector2i(16, 12),
]
const NESTS: Array[Vector2i] = [Vector2i(10, 15)]
## Fish positions in cells (spawned at the cell centre, as adults).
const FISH: Array[Vector2i] = [Vector2i(9, 6), Vector2i(11, 12), Vector2i(6, 10)]


static func populate(factory: EntityFactory) -> void:
	for entry in CORALS:
		factory.spawn_coral(entry[0], entry[1])
	for cell in ALGAE:
		factory.spawn_algae(cell)
	for cell in NESTS:
		factory.spawn_nest(cell)
	for cell in FISH:
		factory.spawn_fish(Game.grid.cell_to_world(cell), true)
