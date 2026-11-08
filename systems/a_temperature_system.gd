class_name TemperatureSystem
extends Node
## The only writer of Game.temperature (roadmap contract #1). Pausable.

## The coral-cell scan visits every occupied grid cell. The count only changes
## when a coral is placed or dies, so 0.25 s sampling is plenty and avoids a
## full grid walk every frame.
const CELL_SAMPLE_SECONDS := 0.25

var model: TemperatureModel

var _cell_elapsed := CELL_SAMPLE_SECONDS
var _coral_cells := 0


func _ready() -> void:
	model = TemperatureModel.new(Game.eco.temp_base_rate, Game.eco.temp_slow_per_cell, Game.eco.temp_max_slowdown)
	Game.temperature = 0.0
	# The level is populated before Dev A's systems enter the tree.
	_coral_cells = Game.grid.count_cells(_is_coral)
	_cell_elapsed = 0.0


func _process(delta: float) -> void:
	# Level 1 runs on a calm reef: the water stays cold. The debug slider still
	# works, so a developer can test hot-water behaviour on any level.
	if not Game.eco.temperature_enabled:
		Game.temperature = Game.debug_temperature_value if Game.debug_temperature_manual else 0.0
		return
	var step := Game.frame_step(delta)
	_cell_elapsed += step
	if _cell_elapsed >= CELL_SAMPLE_SECONDS:
		_cell_elapsed = 0.0
		_coral_cells = Game.grid.count_cells(_is_coral)
	model.tick(step, _coral_cells)
	# Debug override: the F3 temperature slider takes over (roadmap contract
	# #1: only Game writes Game.temperature, conditionally here).
	Game.temperature = Game.debug_temperature_value if Game.debug_temperature_manual else model.value


func _is_coral(entity: Object) -> bool:
	return entity is Coral
