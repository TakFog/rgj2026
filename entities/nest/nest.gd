class_name Nest
extends Area2D
## Nest: single-cell area fish swim over (GDD §5.5).
## CONTRACT (used by Dev B fish/threats): cell, is_empty(), has_eggs(),
## fertilize(), kill_eggs(), eggs_time_left(), destroy().

signal destroyed
## Used by the audio system (systems/b_audio.gd).
signal fertilized
signal eggs_hatched(count: int)
signal eggs_died

## Footprint under the sprites, faint so the art reads first.
const FOOTPRINT_ALPHA := 0.3
const EMPTY_COLOR := Color(0.95, 0.85, 0.4, FOOTPRINT_ALPHA)
const EGGS_COLOR := Color(1.0, 0.55, 0.2, FOOTPRINT_ALPHA)
## Designer's nest sprites: empty and full of eggs.
const EMPTY_TEXTURE := preload("res://assets/sprites/nest_empty.png")
const EGGS_TEXTURE := preload("res://assets/sprites/nest_eggs.png")
## Rim drawn along the nest silhouette for the fish-order highlight.
const RIM_SHADER := preload("res://core/sprite_rim.gdshader")
## Row (texture px, measured on the art) where each nest touches the ground.
## Used to keep the base consistent when the state swaps the texture.
const EMPTY_FOOT_Y := 158.0
const EGGS_FOOT_Y := 158.0
## Height every nest texture is drawn at, in grid cells. Both textures are
## wider than tall, so the sprite is rescaled when the state swaps the texture.
const SPRITE_HEIGHT_CELLS := 0.9
## Juveniles appear around the nest centre, this far apart (world units).
const HATCH_SPREAD := 8.0

var cell: Vector2i
var state: int:
	get:
		return _cycle.state if _cycle else NestCycle.State.EMPTY

var _cycle: NestCycle
var _visual: PlaceholderShape
var _sprite: Sprite2D
## Sprite material carrying the fish-order highlight rim (rim_width 0 when off).
var _rim_material: ShaderMaterial
## Last state drawn: the nest only redraws when eggs appear, hatch or die.
var _shown_eggs := false


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
	_cycle.eggs_died.connect(func() -> void: eggs_died.emit())
	_visual = PlaceholderShape.cell(position, EMPTY_COLOR)
	_sprite = _visual.add_sprite(EMPTY_TEXTURE, SPRITE_HEIGHT_CELLS)
	_rim_material = ShaderMaterial.new()
	_rim_material.shader = RIM_SHADER
	_sprite.material = _rim_material
	_shown_eggs = has_eggs()
	_visual.color = EGGS_COLOR if _shown_eggs else EMPTY_COLOR
	_update_sprite()
	# Ground cover: drawn below the y-sorted actors (fish, corals, threats) so
	# they always swim over the nest, even when the nest sprite overlaps them.
	ViewFollower.attach(self, _visual, true).z_index = -1


func _process(delta: float) -> void:
	var hazard := 0.0
	if has_eggs():
		var death_chance := clampf(Game.by_temperature(
			Game.eco.egg_death_chance_cold, Game.eco.egg_death_chance_hot), 0.0, 1.0)
		hazard = NestCycle.hazard_from_chance(death_chance, _cycle.hatch_seconds)
	_cycle.tick(delta, hazard)
	var eggs := has_eggs()
	if eggs != _shown_eggs:
		_shown_eggs = eggs
		_visual.color = EGGS_COLOR if eggs else EMPTY_COLOR
		_update_sprite()


func _update_sprite() -> void:
	var eggs := has_eggs()
	_sprite.texture = EGGS_TEXTURE if eggs else EMPTY_TEXTURE
	var world_height := Game.grid.cell_size * SPRITE_HEIGHT_CELLS * Game.VIEW_SETTINGS.pixels_per_unit
	_sprite.scale = Vector2.ONE * world_height / _sprite.texture.get_height()
	var foot_y := EGGS_FOOT_Y if eggs else EMPTY_FOOT_Y
	var half_height := _sprite.texture.get_height() * 0.5
	_sprite.offset = Vector2(0.0, half_height - foot_y)
	# Centre the texture on the base cell, so the nest sits on the footprint
	# instead of hanging above it with only the cell centre under its base.
	_sprite.position = Vector2(0.0, (foot_y - half_height) * _sprite.scale.y)


func is_empty() -> bool:
	return _cycle.state == NestCycle.State.EMPTY


func has_eggs() -> bool:
	return _cycle.state == NestCycle.State.EGGS


## Called by a fish that stayed on the nest for fertilize_seconds.
func fertilize() -> void:
	if _cycle.fertilize():
		fertilized.emit()


## Called by CO2: eggs die, nest becomes empty.
func kill_eggs() -> void:
	if has_eggs():
		_cycle.kill_eggs()
		eggs_died.emit()


## Seconds until the eggs hatch, or -1.0 if there are no eggs.
func eggs_time_left() -> float:
	return _cycle.eggs_time_left()


## Screen-space box of the nest art, for the fish-order hover highlight
## (FishCommander): the art stands taller than its cell, so the cell alone
## would miss most of what the player sees.
func screen_rect() -> Rect2:
	if _sprite == null:
		return Rect2()
	return _sprite.get_global_transform() * _sprite.get_rect()


## Rim along the nest silhouette while the selected fish can lay eggs in it
## (see core/order_highlight.gd). `width_px` is on screen.
func set_highlight(color: Color, width_px: float) -> void:
	_rim_material.set_shader_parameter(&"rim_color", color)
	_rim_material.set_shader_parameter(&"rim_width", width_px / _sprite.scale.x)


func clear_highlight() -> void:
	_rim_material.set_shader_parameter(&"rim_width", 0.0)


func destroy() -> void:
	if is_queued_for_deletion():
		return
	remove_from_group(Groups.NESTS)
	Game.grid.release([cell])
	destroyed.emit()
	queue_free()


func _on_hatched(count: int) -> void:
	eggs_hatched.emit(count)
	for i in count:
		var offset := Vector2.from_angle(TAU * i / count) * HATCH_SPREAD
		Game.factory.spawn_fish.call_deferred(position + offset, false)
