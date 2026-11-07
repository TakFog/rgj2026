class_name TemperatureSystem
extends Node
## The only writer of Game.temperature (roadmap contract #1). Pausable.

var model: TemperatureModel


func _ready() -> void:
	model = TemperatureModel.new(Game.eco.temp_base_rate, Game.eco.temp_slow_per_cell, Game.eco.temp_max_slowdown)
	Game.temperature = 0.0


func _process(delta: float) -> void:
	model.tick(delta, Game.grid.count_cells(_is_coral))
	Game.temperature = model.value


func _is_coral(entity: Object) -> bool:
	return entity is Coral
