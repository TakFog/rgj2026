class_name Nest
extends Area2D
## Nest: single-cell area fish swim over (GDD §5.5).
## CONTRACT (used by Dev B fish/threats): cell, is_empty(), has_eggs(),
## fertilize(), kill_eggs(), eggs_time_left(), destroy().

signal destroyed

const EMPTY_COLOR := Color(0.95, 0.85, 0.4)
const EGGS_COLOR := Color(1.0, 0.55, 0.2)
## Temporary art, until the designer's nest sprites are ready.
const EMPTY_TEXTURE := preload("res://assets/sprites/temp/nest_empty.png")
const EGGS_TEXTURE := preload("res://assets/sprites/temp/nest_eggs.png")
## Juveniles appear around the nest centre, this far apart (world units).
const HATCH_SPREAD := 8.0

var cell: Vector2i
var state: int:
	get:
		return _cycle.state if _cycle else NestCycle.State.EMPTY

var _cycle: NestCycle
var _visual: PlaceholderShape
var _sprite: Sprite2D


func setup(p_cell: Vector2i) -> void:
	cell = p_cell


func _ready() -> void:
	position = Game.grid.cell_to_world(cell)
	collision_layer = Layers.NEST
	collision_mask = 0
	monitoring = false
	monitorable = true
	add_to_group(Groups.NESTS)
	Game.grid.occupy([cell], self)
	CellShapes.add_collision(self, [cell], cell)
	_cycle = NestCycle.new(Game.eco.nest_hatch_seconds, Game.eco.nest_hatch_count)
	_cycle.hatched.connect(_on_hatched)
	_visual = PlaceholderShape.cell(position, EMPTY_COLOR)
	_sprite = _visual.add_sprite(EMPTY_TEXTURE, 0.9)
	ViewFollower.attach(self, _visual)


func _process(delta: float) -> void:
	var hazard := 0.0
	if has_eggs():
		var death_chance := clampf(Game.by_temperature(
			Game.eco.egg_death_chance_cold, Game.eco.egg_death_chance_hot), 0.0, 1.0)
		hazard = NestCycle.hazard_from_chance(death_chance, _cycle.hatch_seconds)
	_cycle.tick(delta, hazard)
	_visual.color = EGGS_COLOR if has_eggs() else EMPTY_COLOR
	_sprite.texture = EGGS_TEXTURE if has_eggs() else EMPTY_TEXTURE


func is_empty() -> bool:
	return _cycle.state == NestCycle.State.EMPTY


func has_eggs() -> bool:
	return _cycle.state == NestCycle.State.EGGS


## Called by a fish that stayed on the nest for fertilize_seconds.
func fertilize() -> void:
	_cycle.fertilize()


## Called by CO2: eggs die, nest becomes empty.
func kill_eggs() -> void:
	_cycle.kill_eggs()


## Seconds until the eggs hatch, or -1.0 if there are no eggs.
func eggs_time_left() -> float:
	return _cycle.eggs_time_left()


func destroy() -> void:
	if is_queued_for_deletion():
		return
	remove_from_group(Groups.NESTS)
	Game.grid.release([cell])
	destroyed.emit()
	queue_free()


func _on_hatched(count: int) -> void:
	for i in count:
		var offset := Vector2.from_angle(TAU * i / count) * HATCH_SPREAD
		Game.factory.spawn_fish.call_deferred(position + offset, false)
