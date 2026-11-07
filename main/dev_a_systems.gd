extends Node
## Dev A's systems and UI are added here (inventory, placement, temperature...).
## Only Dev A edits this file.

var inventory: InventorySystem
var placement: PlacementController
var temperature: TemperatureSystem


func _ready() -> void:
	inventory = InventorySystem.new()
	inventory.name = "InventorySystem"
	add_child(inventory)

	placement = PlacementController.new()
	placement.name = "PlacementController"
	placement.inventory = inventory
	add_child(placement)

	temperature = TemperatureSystem.new()
	temperature.name = "TemperatureSystem"
	add_child(temperature)

	var bar := InventoryBar.new()
	bar.name = "InventoryBar"
	bar.inventory = inventory
	bar.placement = placement
	bar.add_to_group(Groups.GAMEPLAY_HUD)
	Game.ui.add_child(bar)

	var thermometer := Thermometer.new()
	thermometer.name = "Thermometer"
	thermometer.add_to_group(Groups.GAMEPLAY_HUD)
	Game.ui.add_child(thermometer)
