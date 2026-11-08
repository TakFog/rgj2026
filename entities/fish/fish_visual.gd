class_name FishVisual
extends Node2D
## Fish drawing in screen space: sprite facing its heading, selection ring,
## hunger bar and a warning bubble when the fish is close to starving.

const TEXTURE := preload("res://assets/sprites/fish.png")
## Body centre, tail→head angle and body length in the texture (measured on the art).
const FACING_CENTER := Vector2(122, 112)
const FACING_AXIS_DEG := -38.0
const FACING_LENGTH := 210.0
## Half the sprite height, as a fraction of its body length (bars sit above it).
const SPRITE_HALF_HEIGHT := 0.4
const MAX_TILT_DEG := 35.0
## On-screen body length, in fish radii (world units).
const BODY_LENGTH_RADII := 4.0
const RING_COLOR := Color(1.0, 1.0, 1.0, 0.9)
const BAR_BACK := Color(0.0, 0.0, 0.0, 0.6)
const BAR_FULL := Color(0.35, 0.95, 0.45)
const BAR_EMPTY := Color(0.95, 0.25, 0.2)
const BAR_SIZE := Vector2(24.0, 4.0)
## The "!" bubble appears this much hunger above the bar threshold, so the bar
## shows the need and the bubble marks the urgent case.
const WARNING_RATIO_STEP := 0.25
const WARNING_BUBBLE_RADIUS := 8.5
const WARNING_FONT_SIZE := 13
const WARNING_PULSE_SPEED := 6.0
const WARNING_BOB := 2.0
const JUVENILE_SCALE := 0.6
const RING_GAP := 4.0
const SEGMENTS := 16

static var _facing := SpriteFacing.new(FACING_CENTER, deg_to_rad(FACING_AXIS_DEG), FACING_LENGTH, deg_to_rad(MAX_TILT_DEG))

## Projected circles are reused every frame (the projection is fixed during a
## run), keyed by radius. `_ring` adds the closing point; `_top` is the highest
## screen-space point, used to place the hunger bar.
var _ellipses: Dictionary = {}
var _rings: Dictionary = {}
var _tops: Dictionary = {}
var _time := 0.0

var radius_world := 10.0
## Swimming direction in screen space.
var heading := Vector2.RIGHT:
	set(value):
		if not value.is_equal_approx(heading):
			heading = value
			queue_redraw()
var hunger_threshold := 0.5
var adult := true:
	set(value):
		adult = value
		queue_redraw()
var selected := false:
	set(value):
		selected = value
		queue_redraw()
var hunger_ratio := 0.0:
	set(value):
		if not is_equal_approx(value, hunger_ratio):
			hunger_ratio = value
			queue_redraw()


func _process(delta: float) -> void:
	if not shows_warning(hunger_ratio, hunger_threshold):
		return
	_time += delta
	queue_redraw()


func _draw() -> void:
	var radius := radius_world * (1.0 if adult else JUVENILE_SCALE)
	if selected:
		draw_polyline(_ring(radius + RING_GAP), RING_COLOR, 2.0)
	var length := radius * BODY_LENGTH_RADII * Game.VIEW_SETTINGS.pixels_per_unit
	draw_set_transform_matrix(_facing.transform(heading, length))
	draw_texture(TEXTURE, Vector2.ZERO)
	draw_set_transform_matrix(Transform2D.IDENTITY)
	if hunger_ratio > hunger_threshold:
		var top := minf(-length * SPRITE_HALF_HEIGHT, _top(radius))
		var back := Rect2(Vector2(-BAR_SIZE.x * 0.5, top - 8.0), BAR_SIZE)
		draw_rect(back, BAR_BACK)
		draw_rect(Rect2(back.position, Vector2(BAR_SIZE.x * fullness_ratio(hunger_ratio), BAR_SIZE.y)),
				bar_color(hunger_ratio))
		_draw_warning(back)


## The project UI font, so the warning glyph matches every label and button.
static func warning_font() -> Font:
	var theme := ThemeDB.get_project_theme()
	if theme != null and theme.default_font != null:
		return theme.default_font
	return ThemeDB.fallback_font


## Pulses a small "!" above the bar while the fish is close to starving.
func _draw_warning(bar: Rect2) -> void:
	if not shows_warning(hunger_ratio, hunger_threshold):
		return
	var pulse := 1.0 + 0.08 * sin(_time * WARNING_PULSE_SPEED)
	var bob := sin(_time * WARNING_PULSE_SPEED * 0.5) * WARNING_BOB
	var radius := WARNING_BUBBLE_RADIUS * pulse
	var center := Vector2(bar.get_center().x, bar.position.y - radius - 5.0 + bob)
	draw_circle(center, radius, Color(BAR_EMPTY, 0.95))
	draw_arc(center, radius, 0.0, TAU, 24, Color(1.0, 1.0, 1.0, 0.85), 1.5, true)
	var font := warning_font()
	var text := "!"
	var text_size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, WARNING_FONT_SIZE)
	var baseline := center + Vector2(-text_size.x * 0.5, WARNING_FONT_SIZE * 0.35)
	draw_string(font, baseline, text, HORIZONTAL_ALIGNMENT_LEFT, -1, WARNING_FONT_SIZE, Color.WHITE)


## Bar fill, opposite to hunger: full when fed, empty when about to starve
## (the same full-means-sated logic as the predator's satiety bar).
static func fullness_ratio(p_hunger_ratio: float) -> float:
	return 1.0 - clampf(p_hunger_ratio, 0.0, 1.0)


## Bar colour follows fullness: green when fed, red when starving.
static func bar_color(p_hunger_ratio: float) -> Color:
	return BAR_FULL.lerp(BAR_EMPTY, clampf(p_hunger_ratio, 0.0, 1.0))


## Hunger ratio at which the warning bubble appears.
static func warning_threshold(p_hunger_threshold: float) -> float:
	return clampf(p_hunger_threshold + WARNING_RATIO_STEP, 0.0, 1.0)


## True when the fish is hungry enough for the urgent "!" bubble.
static func shows_warning(p_hunger_ratio: float, p_hunger_threshold: float) -> bool:
	return p_hunger_ratio >= warning_threshold(p_hunger_threshold)


## A world-space circle of `radius` around the fish, projected to screen space.
## Cached: the fish redraws every frame while it swims.
func _ellipse(radius: float) -> PackedVector2Array:
	if not _ellipses.has(radius):
		var points := PackedVector2Array()
		for i in SEGMENTS:
			points.append(Vector2.from_angle(TAU * i / SEGMENTS) * radius)
		_ellipses[radius] = Game.projection.project_polygon(points, Vector2.ZERO)
	return _ellipses[radius]


## The same ellipse, closed for draw_polyline (selection ring).
func _ring(radius: float) -> PackedVector2Array:
	if not _rings.has(radius):
		var ring := _ellipse(radius).duplicate()
		ring.append(ring[0])
		_rings[radius] = ring
	return _rings[radius]


## Screen-space top of the ellipse, for placing the hunger bar.
func _top(radius: float) -> float:
	if not _tops.has(radius):
		var top := INF
		for point in _ellipse(radius):
			top = minf(top, point.y)
		_tops[radius] = top
	return _tops[radius]
