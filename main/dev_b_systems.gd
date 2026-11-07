extends Node
## Dev B's systems and UI are added here (fish commander, population monitor,
## threat spawner, HUD...). Only Dev B edits this file.


func _ready() -> void:
	var commander := FishCommander.new()
	commander.name = "FishCommander"
	add_child(commander)
