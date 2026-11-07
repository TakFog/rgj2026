extends Node2D
## Blinking arrow + label at the map edge announcing an incoming threat (GDD §7).

const MARGIN := 24.0
const BLINK_PERIOD := 0.4
const LABELS := {
	ThreatSchedule.Type.CO2: "CO2",
	ThreatSchedule.Type.BAG: "BAG",
	ThreatSchedule.Type.CYCLONE: "CYCLONE",
}
const COLORS := {
	ThreatSchedule.Type.CO2: Color(0.75, 0.75, 0.8),
	ThreatSchedule.Type.BAG: Color(1.0, 1.0, 1.0),
	ThreatSchedule.Type.CYCLONE: Color(0.45, 0.85, 0.95),
}

var kind: int
var _entry: EdgeEntry
var _time := 0.0
var _angle := 0.0


func setup(p_kind: int, entry: EdgeEntry) -> void:
	kind = p_kind
	_entry = entry


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	_update_placement()


func _process(delta: float) -> void:
	_time += delta
	visible = fmod(_time, BLINK_PERIOD) < BLINK_PERIOD * 0.6
	_update_placement()


func _update_placement() -> void:
	var canvas := Game.view.get_global_transform_with_canvas()
	var at := canvas * Game.projection.to_screen(_entry.point)
	var ahead := canvas * Game.projection.to_screen(_entry.point + Vector2.from_angle(_entry.heading) * 32.0)
	var screen := get_viewport_rect().grow(-MARGIN)
	position = at.clamp(screen.position, screen.end)
	_angle = (ahead - at).angle()
	queue_redraw()


func _draw() -> void:
	var dir := Vector2.from_angle(_angle)
	var side := dir.orthogonal()
	var arrow := PackedVector2Array([dir * 18.0, -dir * 10.0 + side * 12.0, -dir * 10.0 - side * 12.0])
	draw_colored_polygon(arrow, COLORS[kind])
	draw_string(ThemeDB.fallback_font, Vector2(-20, -20), LABELS[kind], HORIZONTAL_ALIGNMENT_LEFT, -1, 14, COLORS[kind])
