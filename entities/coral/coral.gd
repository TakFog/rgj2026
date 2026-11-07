class_name Coral
extends StaticBody2D
## Coral: multi-cell static obstacle with oxygen. It only "suffers" (GDD §5.2).
## CONTRACT (used by Dev B threats): cells, oxygen, apply_oxygen_damage(), destroy().

signal destroyed

const HEALTHY_COLOR := Color(1.0, 0.45, 0.55)
const SUFFOCATED_COLOR := Color(0.45, 0.42, 0.42)
const CRUMBLE_SECONDS := 0.6
## Temporary art, until the designer's coral sprite is ready.
const TEXTURE := preload("res://assets/sprites/temp/coral.png")

var shape_id: StringName
var origin_cell: Vector2i
var cells: Array[Vector2i] = []
var oxygen: float:
	get:
		return _oxygen.value if _oxygen else 0.0

var _oxygen: CoralOxygen
var _visuals: Array[PlaceholderShape] = []
var _sprites: Array[Sprite2D] = []
var _followers: Array[ViewFollower] = []
var _dead := false


func setup(p_shape_id: StringName, p_origin_cell: Vector2i) -> void:
	shape_id = p_shape_id
	origin_cell = p_origin_cell
	cells = CoralShapes.cells_at(shape_id, origin_cell)


func _ready() -> void:
	position = Game.grid.cell_to_world(origin_cell)
	collision_layer = Layers.CORAL
	collision_mask = 0
	add_to_group(Groups.CORALS)
	Game.grid.occupy(cells, self)
	CellShapes.add_collision(self, cells, origin_cell)
	_oxygen = CoralOxygen.new(Game.eco.coral_max_oxygen, Game.eco.coral_regen_per_sec)
	_oxygen.depleted.connect(destroy)
	_build_visuals()


## One follower per cell so each cell y-sorts on its own (GDD §4.1).
func _build_visuals() -> void:
	for cell in cells:
		var marker := Marker2D.new()
		marker.position = Vector2(cell - origin_cell) * Game.grid.cell_size
		add_child(marker)
		var visual := PlaceholderShape.cell(Game.grid.cell_to_world(cell), HEALTHY_COLOR)
		_visuals.append(visual)
		_sprites.append(visual.add_sprite(TEXTURE))
		_followers.append(ViewFollower.attach(marker, visual))


func _process(delta: float) -> void:
	if _dead:
		return
	_oxygen.regen_per_sec = Game.by_temperature(Game.eco.coral_regen_per_sec, Game.eco.coral_regen_hot_per_sec)
	_oxygen.tick(delta)
	if _dead:
		return
	var tint := SUFFOCATED_COLOR.lerp(HEALTHY_COLOR, _oxygen.ratio())
	for visual in _visuals:
		visual.color = tint
	var sprite_tint := Color.WHITE.lerp(SUFFOCATED_COLOR, 1.0 - _oxygen.ratio())
	for sprite in _sprites:
		sprite.modulate = sprite_tint


## Instant damage on contact. Kills the coral at 0 oxygen.
func apply_oxygen_damage(amount: float) -> void:
	if _dead:
		return
	_oxygen.damage(amount)


## Dies immediately for gameplay (group, grid, collisions), then crumbles visually.
func destroy() -> void:
	if _dead:
		return
	_dead = true
	remove_from_group(Groups.CORALS)
	Game.grid.release(cells)
	set_deferred("collision_layer", 0)
	destroyed.emit()
	_crumble()


func _crumble() -> void:
	var tween := create_tween().set_parallel(true)
	for follower in _followers:
		tween.tween_property(follower, "modulate:a", 0.0, CRUMBLE_SECONDS)
		tween.tween_property(follower, "scale", Vector2(1.0, 0.3), CRUMBLE_SECONDS)
	tween.chain().tween_callback(queue_free)
