extends Node
## Dev A's systems and UI are added here (inventory, placement, temperature...).
## Only Dev A edits this file.

var inventory: InventorySystem
var placement: PlacementController


func _ready() -> void:
	inventory = InventorySystem.new()
	inventory.name = "InventorySystem"
	add_child(inventory)

	placement = PlacementController.new()
	placement.name = "PlacementController"
	placement.inventory = inventory
	add_child(placement)

	var bar := InventoryBar.new()
	bar.name = "InventoryBar"
	bar.inventory = inventory
	bar.placement = placement
	Game.ui.add_child(bar)
