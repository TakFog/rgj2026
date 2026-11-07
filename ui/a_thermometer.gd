class_name Thermometer
extends Control
## Top-right thermometer (GDD §6, §9), drawn as a sea-themed card matching the
## inventory (InventoryCard palette): a glass tube whose liquid rises and shifts
## from cool aqua through sand to coral red as Game.temperature climbs, a °C
## scale, and a caption. Fully custom-drawn; never blocks clicks on the reef.

const CARD_SIZE := Vector2(96, 268)
const CORNER_RADIUS := InventoryCard.CORNER_RADIUS
const MARGIN := 16

## Glass geometry, in card pixels. The tube is a capsule joined to the bulb.
const TUBE_X := 36.0
const TUBE_HALF_WIDTH := 9.0
const TUBE_TOP := 20.0
const BULB_CENTER_Y := 200.0
const BULB_RADIUS := 19.0
const GLASS_INSET := 4.0
## Scale (and liquid level) runs from just above the bulb to just under the cap.
const SCALE_BOTTOM := BULB_CENTER_Y - BULB_RADIUS - 6.0
const SCALE_TOP := TUBE_TOP + TUBE_HALF_WIDTH + 6.0
const TICK_GAP := 5.0
const MAJOR_TICK := 8.0
const MINOR_TICK := 4.0
const TICK_FONT_SIZE := 12
const CAPTION_FONT_SIZE := 17

## Liquid level eases toward the real value instead of snapping.
const LEVEL_SMOOTHING := 6.0
## From this temperature up the card's rim glows hot and pulses.
const ALARM_FROM := 0.75
const PULSE_SPEED := 4.0
const FLASH_SECONDS := 0.6
const BUBBLE_COUNT := 5

const COLD := Color(0.3, 0.8, 0.95)
const WARM := InventoryCard.SAND_COLOR
const HOT := Color(1.0, 0.3, 0.25)
const GLASS_COLOR := Color(0.25, 0.85, 0.9, 0.08)
const HIGHLIGHT_COLOR := Color(1, 1, 1, 0.28)

var _shown := 0.0
var _time := 0.0
var _flash := 0.0
var _celsius := 0.0
var _style := StyleBoxFlat.new()
var _glass := PackedVector2Array()


## Whole degrees to mark on the scale, between the display bounds.
static func scale_degrees(min_c: float, max_c: float) -> Array[int]:
	var result: Array[int] = []
	for degree in range(ceili(min_c), floori(max_c) + 1):
		result.append(degree)
	return result


static func degree_ratio(celsius: float, min_c: float, max_c: float) -> float:
	return inverse_lerp(min_c, max_c, celsius)


## Cool aqua at 0, sand at 0.5, coral red at 1.
static func liquid_color(t: float) -> Color:
	t = clampf(t, 0.0, 1.0)
	if t < 0.5:
		return COLD.lerp(WARM, t * 2.0)
	return WARM.lerp(HOT, (t - 0.5) * 2.0)


static func caption(celsius: float) -> String:
	return "%.1f °C" % celsius


## Closed outline of a capsule tube joined to a round bulb, centred on `x`.
static func glass_outline(x: float, half_width: float, top: float, bulb_y: float, radius: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	var join_y := bulb_y - sqrt(radius * radius - half_width * half_width)
	var cap_y := top + half_width
	points.append(Vector2(x + half_width, join_y))
	for i in range(13):  # Rounded cap, right side over to left side.
		var angle := -PI * float(i) / 12.0
		points.append(Vector2(x, cap_y) + Vector2(cos(angle), sin(angle)) * half_width)
	# Bulb, from the left joint the long way round the bottom to the right joint.
	var start := atan2(join_y - bulb_y, -half_width)
	var end := atan2(join_y - bulb_y, half_width) - TAU
	for i in range(1, 32):
		var angle := lerpf(start, end, float(i) / 32.0)
		points.append(Vector2(x, bulb_y) + Vector2(cos(angle), sin(angle)) * radius)
	return points


func _ready() -> void:
	# The UI layer runs ALWAYS; the bubbles and alarm pulse freeze with the run
	# (pause, menus, game over) instead of redrawing every frame behind them.
	process_mode = Node.PROCESS_MODE_PAUSABLE
	custom_minimum_size = CARD_SIZE
	size = CARD_SIZE
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	grow_horizontal = Control.GROW_DIRECTION_BEGIN
	set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT, Control.PRESET_MODE_KEEP_SIZE, MARGIN)
	_style.set_corner_radius_all(CORNER_RADIUS)
	_style.anti_aliasing = true
	_style.bg_color = InventoryCard.BG_COLOR
	_style.set_border_width_all(3)
	_glass = glass_outline(TUBE_X, TUBE_HALF_WIDTH, TUBE_TOP, BULB_CENTER_Y, BULB_RADIUS)
	_shown = Game.temperature
	Game.temperature_changed.connect(_on_temperature_changed)
	_on_temperature_changed(Game.temperature)


func _on_temperature_changed(value: float) -> void:
	var celsius := TemperatureModel.to_celsius(value, Game.eco.temp_display_min_c, Game.eco.temp_display_max_c)
	# Flash the caption each time the reading crosses a whole degree upward.
	if floori(celsius) > floori(_celsius) and is_node_ready():
		_flash = 1.0
	_celsius = celsius


func _process(delta: float) -> void:
	_time += delta
	_shown = lerpf(_shown, clampf(Game.temperature, 0.0, 1.0), 1.0 - exp(-LEVEL_SMOOTHING * delta))
	_flash = maxf(_flash - delta / FLASH_SECONDS, 0.0)
	queue_redraw()  # Bubbles and the alarm pulse animate every frame.


func _draw() -> void:
	var t := _shown
	var color := liquid_color(t)
	_draw_frame(t)
	_draw_ticks()
	draw_colored_polygon(_glass, GLASS_COLOR)
	_draw_liquid(t, color)
	_draw_glass_shine()
	draw_polyline(_glass + PackedVector2Array([_glass[0]]), Color(InventoryCard.RIM_COLOR, 0.75), 2.0, true)
	_draw_caption(color)


func _draw_frame(t: float) -> void:
	var alarm := clampf(inverse_lerp(ALARM_FROM, 1.0, t), 0.0, 1.0)
	var pulse := 0.5 + 0.5 * sin(_time * PULSE_SPEED)
	_style.border_color = Color(InventoryCard.RIM_COLOR, 0.6).lerp(HOT, alarm * (0.6 + 0.4 * pulse))
	if alarm > 0.0:
		_style.shadow_color = Color(HOT, 0.25 + 0.3 * alarm * pulse)
		_style.shadow_size = int(6 + 8 * alarm * pulse)
		_style.shadow_offset = Vector2.ZERO
	else:
		_style.shadow_color = InventoryCard.SHADOW_COLOR
		_style.shadow_size = 6
		_style.shadow_offset = Vector2(0, 4)
	draw_style_box(_style, Rect2(Vector2.ZERO, size))


func _level_y(ratio: float) -> float:
	return lerpf(SCALE_BOTTOM, SCALE_TOP, clampf(ratio, 0.0, 1.0))


func _draw_ticks() -> void:
	var font := get_theme_default_font()
	var min_c := Game.eco.temp_display_min_c
	var max_c := Game.eco.temp_display_max_c
	var x0 := TUBE_X + TUBE_HALF_WIDTH + TICK_GAP
	var tick_color := Color(InventoryCard.CAPTION_COLOR, 0.55)
	var degrees := scale_degrees(min_c, max_c)
	for degree in degrees:
		var y := _level_y(degree_ratio(degree, min_c, max_c))
		draw_line(Vector2(x0, y), Vector2(x0 + MAJOR_TICK, y), tick_color, 2.0, true)
		draw_string(font, Vector2(x0 + MAJOR_TICK + 3.0, y + TICK_FONT_SIZE * 0.35), "%d°" % degree,
				HORIZONTAL_ALIGNMENT_LEFT, -1, TICK_FONT_SIZE, tick_color)
		if degree != degrees[-1]:
			var half := _level_y(degree_ratio(degree + 0.5, min_c, max_c))
			draw_line(Vector2(x0, half), Vector2(x0 + MINOR_TICK, half), Color(tick_color, 0.3), 1.0, true)


func _draw_liquid(t: float, color: Color) -> void:
	var half := TUBE_HALF_WIDTH - GLASS_INSET
	var level := _level_y(t)
	var bulb := Vector2(TUBE_X, BULB_CENTER_Y)
	var bottom_color := color.darkened(0.12)
	var top_color := color.lightened(0.15)
	# Column with a vertical gradient: deeper at the bulb, brighter at the top.
	var column := PackedVector2Array([
		Vector2(TUBE_X - half, level), Vector2(TUBE_X + half, level),
		Vector2(TUBE_X + half, BULB_CENTER_Y), Vector2(TUBE_X - half, BULB_CENTER_Y),
	])
	draw_polygon(column, PackedColorArray([top_color, top_color, bottom_color, bottom_color]))
	draw_circle(bulb, BULB_RADIUS - GLASS_INSET, bottom_color, true, -1.0, true)
	# Rounded meniscus.
	draw_circle(Vector2(TUBE_X, level), half, top_color, true, -1.0, true)
	draw_line(Vector2(TUBE_X - half + 1.0, level - half * 0.3), Vector2(TUBE_X + half - 1.0, level - half * 0.3),
			Color(1, 1, 1, 0.35), 1.5, true)
	# Bubbles rise from the bulb, faster and more of them as it heats up.
	var travel := BULB_CENTER_Y - level
	if travel <= 0.0:
		return
	var speed := 14.0 + 40.0 * t
	var bubble_count := maxi(1, roundi(BUBBLE_COUNT * (0.4 + 0.6 * t)))
	for i in range(bubble_count):
		var phase := fposmod(_time * speed / travel + float(i) / bubble_count, 1.0)
		var y := BULB_CENTER_Y - phase * travel
		var x := TUBE_X + sin(_time * 3.0 + i * 1.7) * half * 0.45
		var radius := 1.2 + 0.8 * fposmod(i * 0.37, 1.0)
		draw_circle(Vector2(x, y), radius, Color(1, 1, 1, 0.6 * (1.0 - phase)), true, -1.0, true)


func _draw_glass_shine() -> void:
	var x := TUBE_X - TUBE_HALF_WIDTH + 3.0
	draw_line(Vector2(x, TUBE_TOP + TUBE_HALF_WIDTH), Vector2(x, SCALE_BOTTOM), HIGHLIGHT_COLOR, 2.0, true)
	draw_arc(Vector2(TUBE_X, BULB_CENTER_Y), BULB_RADIUS - 6.0, PI * 1.05, PI * 1.4, 10, HIGHLIGHT_COLOR, 2.5, true)


func _draw_caption(color: Color) -> void:
	var font := get_theme_default_font()
	var text_color := color.lightened(0.35).lerp(Color.WHITE, _flash)
	var baseline := CARD_SIZE.y - 16.0
	var font_size := CAPTION_FONT_SIZE + roundi(3.0 * _flash)
	draw_string(font, Vector2(0, baseline), caption(_celsius), HORIZONTAL_ALIGNMENT_CENTER, size.x, font_size, text_color)
