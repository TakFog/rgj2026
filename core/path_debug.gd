class_name PathDebug
extends Node2D
## F3 debug view: draws the remaining planned route of every fish, predator and
## turtle in screen space, using the same projection as ViewFollower.
## Toggled from the debug overlay ("SHOW PATHS"); also needs debug_mode on.
##
## This is read-only: entities expose their current route through debug_path().

## Routes change slowly; 10 redraws per second are enough and keep this cheap.
const REFRESH_SECONDS := 0.1

const FISH_COLOR := Color(0.35, 0.9, 1.0, 0.8)
const PREDATOR_COLOR := Color(1.0, 0.4, 0.3, 0.85)
const TURTLE_COLOR := Color(0.35, 1.0, 0.55, 0.85)
const LINE_WIDTH := 2.0
const WAYPOINT_RADIUS := 2.0
const TARGET_RADIUS := 6.0
const TARGET_WIDTH := 2.0
## Below the placement ghost (100) and the F3 labels, above the normal actors.
const Z_INDEX := 90

var _elapsed := REFRESH_SECONDS


func _ready() -> void:
	z_index = Z_INDEX
	visible = false
	Game.debug_mode_changed.connect(_on_debug_state_changed)
	Game.debug_show_paths_changed.connect(_on_debug_state_changed)
	_sync_visibility()


func _process(delta: float) -> void:
	if not visible:
		return
	_elapsed += delta
	if _elapsed < REFRESH_SECONDS:
		return
	_elapsed = 0.0
	queue_redraw()


func _on_debug_state_changed(_enabled: bool) -> void:
	_sync_visibility()


func _sync_visibility() -> void:
	visible = Game.debug_mode and Game.debug_show_paths
	if visible:
		_elapsed = REFRESH_SECONDS
		queue_redraw()


func _draw() -> void:
	if not Game.debug_mode or not Game.debug_show_paths:
		return
	for node in get_tree().get_nodes_in_group(Groups.FISH):
		var fish := node as Fish
		if fish != null:
			_draw_path(fish, fish.debug_path(), FISH_COLOR)
	for node in get_tree().get_nodes_in_group(Groups.PREDATORS):
		var predator := node as Predator
		if predator != null:
			_draw_path(predator, predator.debug_path(), PREDATOR_COLOR)
	for node in get_tree().get_nodes_in_group(Groups.TURTLES):
		var turtle := node as Turtle
		if turtle != null:
			_draw_path(turtle, turtle.debug_path(), TURTLE_COLOR)


## Draws one route: a line from the actor to every waypoint, dots on the
## waypoints and a ring on the final destination.
func _draw_path(actor: Node2D, path: PackedVector2Array, color: Color) -> void:
	if path.is_empty():
		return
	var points := PackedVector2Array([Game.projection.to_screen(actor.global_position)])
	for waypoint in path:
		points.append(Game.projection.to_screen(waypoint))
	draw_polyline(points, color, LINE_WIDTH, true)
	for i in range(1, points.size()):
		draw_circle(points[i], WAYPOINT_RADIUS, color)
	draw_arc(points[points.size() - 1], TARGET_RADIUS, 0.0, TAU, 20, color, TARGET_WIDTH, true)
