class_name Algae
extends StaticBody2D
## Algae: single-cell obstacle that spreads and suffocates corals (GDD §5.3).
## CONTRACT (used by Dev B fish/threats): cell, on_co2_absorbed(), destroy(),
## eater / is_taken_by_other() (one fish reserves an algae at a time).

signal destroyed
## Used by the audio system (systems/b_audio.gd).
signal spread

const TEXTURE := preload("res://assets/sprites/algae.png")
## Swaying movement of the plant underwater (fragment-space UV warp).
const SWAY_SHADER := preload("res://entities/algae/algae_sway.gdshader")
## Alpha of the coloured cell drawn under the sprite.
const FOOTPRINT_ALPHA := 0.3
## The art is a dark, detailed clump; lift it so it reads green on bright sand.
const SPRITE_TINT := Color(1.8, 1.8, 1.8)
## The art stands on its own sand tile, a "/__/" parallelogram like a grid cell
## (texture px, measured on the art): its centre and the length of its
## horizontal edges. The sprite is fitted so this tile lies on the cell.
const ART_TILE_CENTER := Vector2(125.5, 167.0)
const ART_TILE_WIDTH := 139.0

static var _shared_sway: ShaderMaterial

var cell: Vector2i
## Last fish that reserved this algae (to swim to it or eat it), or null. It
## only counts while that fish still reports holds(self), so no release
## bookkeeping is needed.
var eater: Object = null

var _rng := RandomNumberGenerator.new()
var _time_to_grow := 0.0
var _visual: PlaceholderShape
var _sprite: Sprite2D


func setup(p_cell: Vector2i) -> void:
	cell = p_cell


func _ready() -> void:
	position = Game.grid.cell_to_world(cell)
	collision_layer = Layers.ALGAE
	collision_mask = 0
	add_to_group(Groups.ALGAE)
	Game.grid.occupy([cell], self)
	CellShapes.add_collision(self, [cell], cell)
	# Faint footprint: the sprite does the reading, the cell only grounds it.
	_visual = PlaceholderShape.cell(position, Color(0.3, 0.8, 0.35, FOOTPRINT_ALPHA))
	_sprite = _visual.add_sprite(TEXTURE)
	_fit_on_cell(_sprite, _visual.polygon)
	_sprite.modulate = SPRITE_TINT
	_sprite.material = _sway_material()
	_attach_sorted_by_back_edge(_visual)
	_rng.randomize()
	_reset_timer()


## The plant is tall, so it y-sorts with corals and actors (a coral in front of
## it covers it, and it covers a coral behind it). It sorts by the back edge of
## its cell, not the centre: an actor anywhere on the cell, like the predator
## and the turtle swimming over it (GDD §5), is drawn on top of the plant.
func _attach_sorted_by_back_edge(visual: Node2D) -> void:
	var anchor := Marker2D.new()
	anchor.position = Vector2(0.0, -Game.grid.cell_size * 0.5)
	add_child(anchor)
	# Shift the visual back so it still sits on the cell.
	visual.position = Game.projection.to_screen(position) - Game.projection.to_screen(position + anchor.position)
	ViewFollower.attach(anchor, visual, true)


## Screen-space box of the plant art, for the fish-order hover highlight
## (FishCommander): the art stands taller than its cell, so the cell alone
## would miss most of what the player sees.
func screen_rect() -> Rect2:
	if _sprite == null:
		return Rect2()
	return _sprite.get_global_transform() * _sprite.get_rect()


func _physics_process(delta: float) -> void:
	_time_to_grow -= delta
	if _time_to_grow <= 0.0:
		_reset_timer()
		try_expand()


## One expansion attempt (GDD §5.3). At the algae cap no new algae is born,
## but the attempt still runs (it can damage a coral).
func try_expand() -> void:
	if is_queued_for_deletion():
		return
	var at_cap := get_tree().get_node_count_in_group(Groups.ALGAE) >= Game.eco.algae_max_count
	var result := AlgaeSpread.attempt(cell, Game.grid, _rng, _is_coral, CellProbe.is_covered_by_actor)
	result = AlgaeSpread.apply_cap(result, at_cap)
	match result["outcome"]:
		AlgaeSpread.Outcome.SPAWN:
			Game.factory.spawn_algae(result["cell"])
			spread.emit()
		AlgaeSpread.Outcome.DAMAGE_CORAL:
			(result["target"] as Coral).apply_oxygen_damage(Game.eco.algae_coral_damage)


## Called by a CO2 cloud that touches this algae: the cloud is absorbed and the
## algae expands immediately. Deferred: B3 calls this from a physics callback.
func on_co2_absorbed() -> void:
	try_expand.call_deferred()


## True if a fish other than `fish` has reserved this algae right now.
func is_taken_by_other(fish: Object) -> bool:
	return taken_by_other(eater, self, fish)


func destroy() -> void:
	if is_queued_for_deletion():
		return
	remove_from_group(Groups.ALGAE)
	Game.grid.release([cell])
	destroyed.emit()
	queue_free()


func _reset_timer() -> void:
	var base := Game.by_temperature(Game.eco.algae_growth_interval_cold, Game.eco.algae_growth_interval_hot)
	_time_to_grow = AlgaeSpread.next_interval(base, Game.eco.algae_growth_jitter, _rng)


## Scales the sprite so the art's sand tile is as wide as the cell and centres
## that tile on the cell, so the plant grows out of its own footprint.
## `cell_polygon`: the cell's screen corners around its centre, top edge first.
static func _fit_on_cell(sprite: Sprite2D, cell_polygon: PackedVector2Array) -> void:
	var cell_width := cell_polygon[1].x - cell_polygon[0].x
	sprite.scale = Vector2.ONE * cell_width / ART_TILE_WIDTH
	sprite.offset = Vector2.ZERO
	var texture_center := Vector2(sprite.texture.get_size()) * 0.5
	sprite.position = -(ART_TILE_CENTER - texture_center) * sprite.scale


## One material shared by every algae so their sprites batch; the shader
## derives each plant's phase from its position, so they still sway apart.
static func _sway_material() -> ShaderMaterial:
	if _shared_sway == null:
		_shared_sway = ShaderMaterial.new()
		_shared_sway.shader = SWAY_SHADER
	return _shared_sway


func _is_coral(entity: Object) -> bool:
	return entity is Coral


## Pure rule behind is_taken_by_other(). Untyped `p_eater`: it may be freed.
static func taken_by_other(p_eater: Variant, algae: Object, fish: Object) -> bool:
	return is_instance_valid(p_eater) and p_eater != fish and p_eater.holds(algae)
