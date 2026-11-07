class_name InventorySystem
extends Node
## Owns the InventoryModel and advances its refill timers (pausable).

var model: InventoryModel


func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	model = InventoryModel.new(Game.eco, rng, _nests_on_map)
	model.fill_all()


func _process(delta: float) -> void:
	model.tick(delta)


func _nests_on_map() -> int:
	return get_tree().get_nodes_in_group(Groups.NESTS).size()
