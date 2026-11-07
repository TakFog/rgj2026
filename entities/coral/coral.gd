class_name Coral
extends StaticBody2D
## Coral: multi-cell static obstacle with oxygen. It only "suffers" (GDD §5.2).
## CONTRACT (used by Dev B threats): cells, oxygen, apply_oxygen_damage(), destroy().

signal destroyed
## Used by the audio system (systems/b_audio.gd).
signal damaged

## Footprint under the sprites: a faint tint of the coral state (health).
const FOOTPRINT_ALPHA := 0.3
const HEALTHY_COLOR := Color(1.0, 0.45, 0.55, FOOTPRINT_ALPHA)
const SUFFOCATED_COLOR := Color(0.45, 0.42, 0.42, FOOTPRINT_ALPHA)
## Tint of the (grayscale) coral art: red at full oxygen, fading to its own gray at 0.
## Red is overbright (> 1) so the mid-gray art reads as a vivid, bright red.
const CORAL_HEALTHY_TINT := Color(1.6, 0.25, 0.25)
const CORAL_SUFFOCATED_TINT := Color.WHITE
const CRUMBLE_SECONDS := 0.6
## Oxygen ratio change needed before the cell tint is refreshed. Regen is slow,
## so updating the tint (which queues a redraw of every cell) each frame is
## wasted work; 1 % is invisible to the player and damage jumps past it at once.
const TINT_STEP := 0.01
## Brief white-red flash and wobble when the coral takes a hit.
const DAMAGE_FLASH_SECONDS := 0.18
const WOBBLE_DEGREES := 4.0
## Rock the corals grow on (never tinted) and the grayscale corals drawn over it.
const BASE_TEXTURE := preload("res://assets/sprites/coral_base.png")
const CORAL_TEXTURE := preload("res://assets/sprites/coral.png")

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
var _shown_ratio := -1.0
var _damage_flash := 0.0
var _was_flashing := false


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
		visual.add_sprite(BASE_TEXTURE)
		_sprites.append(visual.add_sprite(CORAL_TEXTURE))
		_followers.append(ViewFollower.attach(marker, visual))


func _process(delta: float) -> void:
	if _dead:
		return
	_oxygen.regen_per_sec = Game.by_temperature(Game.eco.coral_regen_per_sec, Game.eco.coral_regen_hot_per_sec)
	_oxygen.tick(delta)
	if _dead:
		return
	_damage_flash = maxf(_damage_flash - delta / DAMAGE_FLASH_SECONDS, 0.0)
	var ratio := _oxygen.ratio()
	var ratio_changed := absf(ratio - _shown_ratio) >= TINT_STEP
	var flashing := _damage_flash > 0.0
	# Update when the oxygen tint moves, while flashing, and once more when the
	# flash ends so the coral returns to its normal tint.
	if not ratio_changed and not flashing and not _was_flashing:
		return
	_shown_ratio = ratio
	_was_flashing = flashing
	var tint := SUFFOCATED_COLOR.lerp(HEALTHY_COLOR, ratio)
	var sprite_tint := CORAL_SUFFOCATED_TINT.lerp(CORAL_HEALTHY_TINT, ratio)
	if flashing:
		tint = tint.lerp(Color(1.0, 0.9, 0.85, FOOTPRINT_ALPHA), _damage_flash * 0.7)
		sprite_tint = sprite_tint.lerp(Color(2.2, 1.4, 1.2), _damage_flash * 0.85)
	for visual in _visuals:
		visual.color = tint
	for sprite in _sprites:
		sprite.modulate = sprite_tint


## Instant damage on contact. Kills the coral at 0 oxygen.
func apply_oxygen_damage(amount: float) -> void:
	if _dead:
		return
	damaged.emit()
	_oxygen.damage(amount)
	if _dead:
		return
	# Juice: a short bright flash and a wobble of every occupied cell.
	_damage_flash = 1.0
	_wobble()


## Brief cosmetic wobble of each cell's screen-space follower on damage.
func _wobble() -> void:
	for follower in _followers:
		if not is_instance_valid(follower):
			continue
		var tween := follower.create_tween()
		tween.tween_property(follower, "rotation", deg_to_rad(WOBBLE_DEGREES), 0.05)
		tween.tween_property(follower, "rotation", deg_to_rad(-WOBBLE_DEGREES * 0.75), 0.08)
		tween.tween_property(follower, "rotation", 0.0, 0.05)


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
