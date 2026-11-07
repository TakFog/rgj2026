class_name EntityFactory
extends RefCounted
## The only place that instantiates gameplay entities. Adds them under Game.world.


func spawn_coral(shape_id: StringName, origin_cell: Vector2i) -> Coral:
	var coral := Coral.new()
	coral.setup(shape_id, origin_cell)
	Game.world.add_child(coral)
	return coral


func spawn_algae(cell: Vector2i) -> Algae:
	var algae := Algae.new()
	algae.setup(cell)
	Game.world.add_child(algae)
	return algae


func spawn_nest(cell: Vector2i) -> Nest:
	var nest := Nest.new()
	nest.setup(cell)
	Game.world.add_child(nest)
	return nest


func spawn_fish(world_position: Vector2, adult: bool) -> Fish:
	var fish := Fish.new()
	fish.setup(world_position, adult)
	Game.world.add_child(fish)
	return fish
