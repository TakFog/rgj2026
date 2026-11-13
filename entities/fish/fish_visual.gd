class_name FishVisual
extends Node2D
## Fish drawing in screen space: sprite facing its heading, selection outline,
## hunger bar and a warning bubble when the fish is close to starving.
## While selected, the outline hugs the sprite silhouette (a circle on the
## seabed sat entirely under the body and could not be seen) and its colour
## says what the fish is doing; a badge above the fish then shows whether it is
## eating (green, algae icon) or laying eggs (gold, eggs icon) and how long that
## action still takes.

const TEXTURE := preload("res://assets/sprites/fish.png")
const OUTLINE_SHADER := preload("res://core/sprite_rim.gdshader")
const ACTIVITY_ICON_FOOD := preload("res://assets/sprites/algae.png")
const ACTIVITY_ICON_EGGS := preload("res://assets/sprites/nest_eggs.png")
## Body centre, tail→head angle and body length in the texture (measured on the art).
const FACING_CENTER := Vector2(122, 112)
const FACING_AXIS_DEG := -38.0
const FACING_LENGTH := 210.0
## Half the sprite height, as a fraction of its body length (bars sit above it).
const SPRITE_HALF_HEIGHT := 0.4
const MAX_TILT_DEG := 35.0
## On-screen body length, in fish radii (world units).
const BODY_LENGTH_RADII := 4.0
## Selection outline: on-screen width in pixels, breathing speed and colour
## while the fish is doing nothing in particular.
const OUTLINE_WIDTH_PX := 2.5
const OUTLINE_PULSE_SPEED := 4.0
const OUTLINE_PULSE_MIN := 0.72
const SELECT_COLOR := Color(0.75, 0.95, 1.0, 0.95)
const ACTIVITY_COLOR_FOOD := SelectionColors.FOOD
const ACTIVITY_COLOR_EGGS := SelectionColors.EGGS
## A badge for a fish still swimming to its meal or nest is dimmer: only a timed
## action shows the progress ring.
const ACTIVITY_SEEKING_ALPHA := 0.45
const ACTIVITY_BADGE_RADIUS := 11.0
const ACTIVITY_BADGE_BACK := Color(0.0, 0.0, 0.0, 0.55)
const ACTIVITY_ICON_SIZE := 16.0
const ACTIVITY_RING_WIDTH := 2.5
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
const SEGMENTS := 16

static var _facing := SpriteFacing.new(FACING_CENTER, deg_to_rad(FACING_AXIS_DEG), FACING_LENGTH, deg_to_rad(MAX_TILT_DEG))

## Projected circles are reused every frame (the projection is fixed during a
## run), keyed by radius. `_top` is their highest screen-space point, used to
## place the hunger bar.
var _ellipses: Dictionary = {}
var _tops: Dictionary = {}
var _time := 0.0
## Copy of the sprite drawn behind the body, showing only the selection rim.
var _outline: Sprite2D
var _outline_material: ShaderMaterial

var radius_world := 10.0
## Swimming direction in screen space.
var heading := Vector2.RIGHT:
	set(value):
		if not value.is_equal_approx(heading):
			heading = value
			queue_redraw()
			_sync_outline()
var hunger_threshold := 0.5
var adult := true:
	set(value):
		adult = value
		queue_redraw()
		_sync_outline()
var selected := false:
	set(value):
		selected = value
		queue_redraw()
		_sync_outline()
## What the fish is doing (a FishBrain.State): it picks the outline colour and
## the badge above the fish.
var activity := FishBrain.State.WANDER:
	set(value):
		if value == activity:
			return
		activity = value
		queue_redraw()
		_sync_outline()
## Progress (0..1) of the timed action (eating, laying eggs), from the brain.
var activity_ratio := 0.0:
	set(value):
		if is_equal_approx(value, activity_ratio):
			return
		activity_ratio = value
		queue_redraw()
var hunger_ratio := 0.0:
	set(value):
		if not is_equal_approx(value, hunger_ratio):
			hunger_ratio = value
			queue_redraw()


func _ready() -> void:
	_outline_material = ShaderMaterial.new()
	_outline_material.shader = OUTLINE_SHADER
	_outline = Sprite2D.new()
	_outline.texture = TEXTURE
	# Drawn exactly like draw_texture(TEXTURE, Vector2.ZERO) in _draw.
	_outline.centered = false
	_outline.material = _outline_material
	# Behind the body: the shader fills the rim outside the silhouette only.
	_outline.show_behind_parent = true
	add_child(_outline)
	_sync_outline()


func _process(delta: float) -> void:
	# The breathing outline and the warning bubble are the only animations.
	if not selected and not shows_warning(hunger_ratio, hunger_threshold):
		return
	_time += delta
	queue_redraw()
	if selected:
		_update_outline_color()


func _draw() -> void:
	var radius := _radius()
	var length := _body_length()
	draw_set_transform_matrix(_facing.transform(heading, length))
	draw_texture(TEXTURE, Vector2.ZERO)
	draw_set_transform_matrix(Transform2D.IDENTITY)

	var top := minf(-length * SPRITE_HALF_HEIGHT, _top(radius))
	var bar_shown := hunger_ratio > hunger_threshold
	var bar := Rect2(Vector2(-BAR_SIZE.x * 0.5, top - 8.0), BAR_SIZE)
	if bar_shown:
		draw_rect(bar, BAR_BACK)
		draw_rect(Rect2(bar.position, Vector2(BAR_SIZE.x * fullness_ratio(hunger_ratio), BAR_SIZE.y)),
				bar_color(hunger_ratio))

	var warning := shows_warning(hunger_ratio, hunger_threshold)
	var with_activity := selected and shows_activity(activity)
	if not warning and not with_activity:
		return
	# Both share one row above the bar; side by side when they show at once.
	var row_y := bar.position.y if bar_shown else top - 8.0
	var split := (WARNING_BUBBLE_RADIUS + ACTIVITY_BADGE_RADIUS + 4.0) * 0.5 \
			if warning and with_activity else 0.0
	if warning:
		_draw_warning(Vector2(-split, row_y - WARNING_BUBBLE_RADIUS - 5.0))
	if with_activity:
		_draw_activity(Vector2(split, row_y - ACTIVITY_BADGE_RADIUS - 5.0))


## The project UI font, so the warning glyph matches every label and button.
static func warning_font() -> Font:
	var theme := ThemeDB.get_project_theme()
	if theme != null and theme.default_font != null:
		return theme.default_font
	return ThemeDB.fallback_font


## Pulses a small "!" above the bar while the fish is close to starving.
func _draw_warning(center: Vector2) -> void:
	var pulse := 1.0 + 0.08 * sin(_time * WARNING_PULSE_SPEED)
	var radius := WARNING_BUBBLE_RADIUS * pulse
	var at := center + Vector2(0.0, _warning_bob())
	draw_circle(at, radius, Color(BAR_EMPTY, 0.95))
	draw_arc(at, radius, 0.0, TAU, 24, Color(1.0, 1.0, 1.0, 0.85), 1.5, true)
	var font := warning_font()
	var text := "!"
	var text_size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, WARNING_FONT_SIZE)
	var baseline := at + Vector2(-text_size.x * 0.5, WARNING_FONT_SIZE * 0.35)
	draw_string(font, baseline, text, HORIZONTAL_ALIGNMENT_LEFT, -1, WARNING_FONT_SIZE, Color.WHITE)


func _warning_bob() -> float:
	return sin(_time * WARNING_PULSE_SPEED * 0.5) * WARNING_BOB


## Badge above a selected fish: the algae it eats or the eggs it lays, with a
## progress ring while the action runs (dimmed while only swimming there).
func _draw_activity(center: Vector2) -> void:
	var color := activity_color(activity)
	var timed := is_activity_timed(activity)
	if not timed:
		color.a = ACTIVITY_SEEKING_ALPHA
	draw_circle(center, ACTIVITY_BADGE_RADIUS,
			Color(ACTIVITY_BADGE_BACK, ACTIVITY_BADGE_BACK.a * (1.0 if timed else 0.6)))
	var icon := activity_texture(activity)
	var icon_size := icon.get_size()
	var icon_scale := ACTIVITY_ICON_SIZE / maxf(icon_size.x, icon_size.y)
	draw_texture_rect(icon, Rect2(center - icon_size * icon_scale * 0.5, icon_size * icon_scale), false, color)
	if not timed:
		return
	draw_arc(center, ACTIVITY_BADGE_RADIUS, 0.0, TAU, 24, Color(color, 0.3), 1.0, true)
	draw_arc(center, ACTIVITY_BADGE_RADIUS, -PI * 0.5,
			-PI * 0.5 + TAU * clampf(activity_ratio, 0.0, 1.0), 24, color,
			ACTIVITY_RING_WIDTH, true)


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


## True when `state` deserves a badge above the selected fish: eating, laying
## eggs, or swimming to the algae or the nest it picked.
static func shows_activity(state: int) -> bool:
	return state == FishBrain.State.EATING or state == FishBrain.State.SEEKING_FOOD \
			or state == FishBrain.State.FERTILIZING or state == FishBrain.State.SEEKING_NEST


## True while the action runs on a timer (eating, laying eggs), so the badge can
## fill a progress ring; seeking states only show where the fish is going.
static func is_activity_timed(state: int) -> bool:
	return state == FishBrain.State.EATING or state == FishBrain.State.FERTILIZING


## Icon of what the fish is doing: the algae it eats or the eggs it lays.
static func activity_texture(state: int) -> Texture2D:
	return ACTIVITY_ICON_EGGS if state == FishBrain.State.FERTILIZING \
			or state == FishBrain.State.SEEKING_NEST else ACTIVITY_ICON_FOOD


## Badge and outline colour: green for food, gold for eggs.
static func activity_color(state: int) -> Color:
	return ACTIVITY_COLOR_EGGS if state == FishBrain.State.FERTILIZING \
			or state == FishBrain.State.SEEKING_NEST else ACTIVITY_COLOR_FOOD


## Outline colour: neutral while merely selected, then the activity colour, so
## the border alone already says whether the fish is eating or laying eggs.
static func outline_color(state: int) -> Color:
	return activity_color(state) if shows_activity(state) else SELECT_COLOR


## Body radius on screen, shrunk for juveniles.
func _radius() -> float:
	return radius_world * (1.0 if adult else JUVENILE_SCALE)


## On-screen body length in pixels.
func _body_length() -> float:
	return _radius() * BODY_LENGTH_RADII * Game.VIEW_SETTINGS.pixels_per_unit


## Keeps the outline on the body and its rim a fixed width on screen.
func _sync_outline() -> void:
	if _outline == null:
		return
	_outline.visible = selected
	if not selected:
		return
	var length := _body_length()
	_outline.transform = _facing.transform(heading, length)
	_outline_material.set_shader_parameter(&"rim_width",
			OUTLINE_WIDTH_PX * FACING_LENGTH / length)
	_update_outline_color()


## The breathing selection rim. The shader carries no pulse of its own because
## the algae and nest reuse it for their own static highlight colours.
func _update_outline_color() -> void:
	var color := outline_color(activity)
	color.a *= OUTLINE_PULSE_MIN + (1.0 - OUTLINE_PULSE_MIN) * _pulse()
	_outline_material.set_shader_parameter(&"rim_color", color)


## 0..1 breathing used by the rim shader.
func _pulse() -> float:
	return 0.5 + 0.5 * sin(_time * OUTLINE_PULSE_SPEED)


## A world-space circle of `radius` around the fish, projected to screen space.
## Cached: the fish redraws every frame while it swims.
func _ellipse(radius: float) -> PackedVector2Array:
	if not _ellipses.has(radius):
		var points := PackedVector2Array()
		for i in SEGMENTS:
			points.append(Vector2.from_angle(TAU * i / SEGMENTS) * radius)
		_ellipses[radius] = Game.projection.project_polygon(points, Vector2.ZERO)
	return _ellipses[radius]


## Screen-space top of the ellipse, for placing the hunger bar.
func _top(radius: float) -> float:
	if not _tops.has(radius):
		var top := INF
		for point in _ellipse(radius):
			top = minf(top, point.y)
		_tops[radius] = top
	return _tops[radius]
