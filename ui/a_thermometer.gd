class_name Thermometer
extends Control
## Top-right thermometer (GDD §6, §9): fills and reddens as Game.temperature rises.

const TUBE_SIZE := Vector2(22, 160)
const BULB_RADIUS := 18.0
const COLD := Color(0.35, 0.7, 1.0)
const HOT := Color(1.0, 0.25, 0.15)

var _label: Label


func _ready() -> void:
	custom_minimum_size = Vector2(90, TUBE_SIZE.y + BULB_RADIUS * 2.0 + 30.0)
	size = custom_minimum_size
	grow_horizontal = Control.GROW_DIRECTION_BEGIN
	set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT, Control.PRESET_MODE_KEEP_SIZE, 16)
	_label = Label.new()
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.position = Vector2(0, TUBE_SIZE.y + BULB_RADIUS * 2.0 + 4.0)
	_label.size = Vector2(custom_minimum_size.x, 24)
	add_child(_label)
	Game.temperature_changed.connect(_on_temperature_changed)
	_on_temperature_changed(Game.temperature)


func _on_temperature_changed(value: float) -> void:
	_label.text = "%.1f °C" % TemperatureModel.to_celsius(value, Game.eco.temp_display_min_c, Game.eco.temp_display_max_c)
	queue_redraw()


func _draw() -> void:
	var t := clampf(Game.temperature, 0.0, 1.0)
	var color := COLD.lerp(HOT, t)
	var x := (custom_minimum_size.x - TUBE_SIZE.x) * 0.5
	var tube := Rect2(Vector2(x, 0), TUBE_SIZE)
	var bulb_center := Vector2(custom_minimum_size.x * 0.5, TUBE_SIZE.y + BULB_RADIUS)
	draw_rect(tube, Color(1, 1, 1, 0.2))
	draw_circle(bulb_center, BULB_RADIUS, Color(1, 1, 1, 0.2))
	var fill_height := TUBE_SIZE.y * t
	draw_rect(Rect2(Vector2(x + 4, TUBE_SIZE.y - fill_height), Vector2(TUBE_SIZE.x - 8, fill_height)), color)
	draw_circle(bulb_center, BULB_RADIUS - 4.0, color)
