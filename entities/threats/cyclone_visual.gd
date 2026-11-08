class_name CycloneVisual
extends Node2D
## Cyclone body in screen space: an animated funnel from the 9-frame
## spritesheet, a soft spiral ground shadow and orbiting spray. Purely
## cosmetic; the contact footprint is the threat's collision circle.

## Frames in the funnel spritesheet, laid out horizontally.
const FRAMES := 9
## Loop speed of the funnel frames.
const FRAME_FPS := 9.0

## On-screen funnel height, in threat radii (same default as Threat).
const BODY_HEIGHT_RADII := 2.5

const SHADOW_ALPHA := 0.24
const SPIRAL_TURNS := 2.5
const SPIRAL_SEGMENTS := 120
const SPIRAL_RADIUS := 0.88
const SPIRAL_SPEED := 1.3
const SPIRAL_COLOR := Color(0.0, 0.0, 0.0, 0.16)
const SPIRAL_WIDTH := 2.0

const BOB_PX := 2.0
const BOB_SPEED := 1.7
const BREATHE := 0.025
const BREATHE_SPEED := 1.1

## The funnel sprite (the threat's `_body`).
var body: Sprite2D
## Orbiting spray drawn in front of the funnel.
var spray: CycloneSpray

var _radius_world := 40.0
var _tint := Color.WHITE
var _phase := 0.0
var _time := 0.0
var _base_scale := 1.0
var _frames := FRAMES
var _frame_offset := 0
var _rng := RandomNumberGenerator.new()
## Visible art size in screen pixels, measured once from the texture.
var _funnel_height := 93.0
## Visible art half-width in world units, measured once from the texture.
var _funnel_half_width := 35.0
static var _shadow_texture: GradientTexture2D
## Texture instance id -> its visible (non-transparent) rect, in texture pixels.
static var _bounds_cache: Dictionary = {}


## Builds the funnel and its spray. Call before adding the visual to the tree.
func setup(p_radius_world: float, p_tint: Color, p_texture: Texture2D) -> void:
	_radius_world = p_radius_world
	_tint = p_tint
	_rng.randomize()
	_phase = _rng.randf() * TAU
	var texture_size := Vector2(p_texture.get_width(), p_texture.get_height())
	_frames = maxi(1, roundi(texture_size.x / texture_size.y))
	var frame_size := Vector2(texture_size.x / float(_frames), texture_size.y)
	var content := _content_rect(p_texture, texture_size)
	var sprite_scale := p_radius_world * BODY_HEIGHT_RADII * Game.VIEW_SETTINGS.pixels_per_unit \
		/ frame_size.y
	_base_scale = sprite_scale
	_funnel_height = content.size.y * sprite_scale
	_funnel_half_width = frame_size.x * 0.5 * sprite_scale / Game.VIEW_SETTINGS.pixels_per_unit
	_frame_offset = _rng.randi_range(0, _frames - 1)
	_make_body(p_texture, frame_size, content, sprite_scale)
	_make_spray()
	queue_redraw()


func _process(delta: float) -> void:
	_time += delta
	if body:
		body.frame = (_frame_offset + int(_time * FRAME_FPS)) % _frames
		body.position.y = sin(_time * BOB_SPEED + _phase) * BOB_PX
		var breathe := 1.0 + sin(_time * BREATHE_SPEED + _phase) * BREATHE
		body.scale = Vector2.ONE * _base_scale * breathe
		if spray:
			spray.funnel_bottom = Vector2(0.0, body.position.y)
	queue_redraw()


## The sprite is anchored on the union of every frame's visible content, not
## on per-frame bounds: the frames have different padding, and following each
## one would make the funnel jump vertically as the animation plays.
func _make_body(p_texture: Texture2D, frame_size: Vector2, content: Rect2, sprite_scale: float) -> void:
	body = Sprite2D.new()
	body.texture = p_texture
	body.hframes = _frames
	body.frame = _frame_offset
	body.modulate = _tint
	body.scale = Vector2.ONE * sprite_scale
	body.offset = Vector2(0.0, -(content.end.y - frame_size.y * 0.5))
	add_child(body)


func _make_spray() -> void:
	spray = CycloneSpray.new()
	spray.setup(_funnel_height, _funnel_half_width, Vector2.ZERO, _tint)
	spray.z_index = 1
	add_child(spray)


func _draw() -> void:
	_draw_shadow()
	_draw_spiral()


## Soft elliptical shadow on the seabed, projected like the collision circle.
func _draw_shadow() -> void:
	var ppu := Game.VIEW_SETTINGS.pixels_per_unit
	var xform := Transform2D(
		Game.VIEW_SETTINGS.x_axis * ppu * _radius_world,
		Game.VIEW_SETTINGS.y_axis * ppu * _radius_world,
		Vector2.ZERO)
	draw_set_transform_matrix(xform)
	draw_texture_rect(_shadow(), Rect2(Vector2(-1.0, -1.0), Vector2(2.0, 2.0)), false,
		Color(0.0, 0.0, 0.0, SHADOW_ALPHA))
	draw_set_transform_matrix(Transform2D.IDENTITY)


## A dark spiral turning on the seabed, so the shadow reads as churning water.
func _draw_spiral() -> void:
	if Game.projection == null:
		return
	var points := PackedVector2Array()
	for i in SPIRAL_SEGMENTS + 1:
		var t := float(i) / float(SPIRAL_SEGMENTS)
		var angle := t * TAU * SPIRAL_TURNS + _time * SPIRAL_SPEED + _phase
		var radius := _radius_world * SPIRAL_RADIUS * (0.12 + 0.88 * t)
		points.append(Vector2.from_angle(angle) * radius)
	var screen := Game.projection.project_polygon(points, Vector2.ZERO)
	draw_polyline(screen, SPIRAL_COLOR, SPIRAL_WIDTH, true)


## Visible rect of the texture in pixels; cached because it never changes.
static func _content_rect(texture: Texture2D, texture_size: Vector2) -> Rect2:
	var key := texture.get_instance_id()
	if _bounds_cache.has(key):
		return _bounds_cache[key]
	var rect := Rect2(Vector2.ZERO, texture_size)
	var image := texture.get_image()
	if image != null:
		var used := image.get_used_rect()
		if used.size.x > 0 and used.size.y > 0:
			rect = Rect2(Vector2(used.position), Vector2(used.size))
	_bounds_cache[key] = rect
	return rect


## Shared radial falloff (opaque centre to transparent rim) for the shadow.
static func _shadow() -> GradientTexture2D:
	if _shadow_texture == null:
		var gradient := Gradient.new()
		gradient.set_color(0, Color.WHITE)
		gradient.set_color(1, Color(1.0, 1.0, 1.0, 0.0))
		gradient.add_point(0.55, Color(1.0, 1.0, 1.0, 0.65))
		_shadow_texture = GradientTexture2D.new()
		_shadow_texture.gradient = gradient
		_shadow_texture.fill = GradientTexture2D.FILL_RADIAL
		_shadow_texture.fill_from = Vector2(0.5, 0.5)
		_shadow_texture.fill_to = Vector2(1.0, 0.5)
		_shadow_texture.width = 128
		_shadow_texture.height = 128
	return _shadow_texture
