extends Node
## Global service locator (autoload "Game"). Shared contract: change only
## after telling the other developer.

signal temperature_changed(value: float)

const ECOSYSTEM: BalanceEcosystem = preload("res://data/balance_ecosystem.tres")
const ACTORS: BalanceActors = preload("res://data/balance_actors.tres")
const VIEW_SETTINGS: ViewSettings = preload("res://data/view_settings.tres")
const AUDIO_SETTINGS: AudioSettings = preload("res://data/audio_settings.tres")

var eco: BalanceEcosystem = ECOSYSTEM
var actors: BalanceActors = ACTORS
var grid: GridModel
var projection: ViewProjection
## Logical physics world (top-down). Set by Main. Entities live here.
var world: Node2D
## Y-sorted screen-space node holding all visuals. Set by Main.
var view: Node2D
## UI CanvasLayer. Set by Main.
var ui: CanvasLayer
var factory: EntityFactory
## True while the player is placing an inventory item (fish orders are ignored).
var placing := false
## Normalised temperature 0..1. Written only by Dev A's TemperatureSystem.
var temperature := 0.0:
	set(value):
		temperature = value
		temperature_changed.emit(value)
## Debug overlay flag (F3). When true, shows per-entity numbers (coral life,
## nest time, fish state...) over everything (GDD §9).
var debug_mode := false:
	set(value):
		debug_mode = value
		debug_mode_changed.emit(value)

signal debug_mode_changed(enabled: bool)

## When true, the debug overlay's temperature slider overrides the automatic
## TemperatureSystem (roadmap contract #1: only Game writes Game.temperature,
## conditionally here).
var debug_temperature_manual := false:
	set(value):
		debug_temperature_manual = value

## Manual temperature value (0..1), applied by TemperatureSystem when
## debug_temperature_manual is true (debug overlay slider).
var debug_temperature_value := 0.0:
	set(value):
		debug_temperature_value = clampf(value, 0.0, 1.0)

var _actions_registered := false

## Cached visible world area and its grown variants. The viewport and camera do
## not move during a run, so re-projecting four corners and running
## Geometry2D.offset_polygon on every threat every physics frame is wasted work.
var _visible_polygon := PackedVector2Array()
var _visible_polygon_valid := false
var _grown_polygons: Dictionary = {} # float margin -> PackedVector2Array


func _ready() -> void:
	if not _actions_registered:
		InputActions.register()
		_actions_registered = true
	reset()
	get_viewport().size_changed.connect(invalidate_view_cache)


## Fresh state for a new run. Called by Main._ready (also after a restart).
func reset() -> void:
	grid = GridModel.new(eco.grid_size, eco.cell_size)
	projection = ViewProjection.from_settings(VIEW_SETTINGS)
	placing = false
	temperature = 0.0
	get_tree().paused = false
	invalidate_view_cache()


## Mouse position in logical world coordinates.
func mouse_world() -> Vector2:
	return projection.to_world(view.get_global_mouse_position())


## Toggles the debug overlay with F3 (GDD §9).
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(InputActions.DEBUG_OVERLAY):
		debug_mode = not debug_mode
		get_viewport().set_input_as_handled()


## Drops the cached visible-area polygons (restart or viewport resize).
func invalidate_view_cache() -> void:
	_visible_polygon_valid = false
	_grown_polygons.clear()


## The world area currently on screen (viewport corners projected back to the
## logical world, camera included). A parallelogram under the oblique view.
## Cached: callers read it many times per frame (threats, spawners, debug).
func visible_world_polygon() -> PackedVector2Array:
	if not _visible_polygon_valid:
		_visible_polygon = _compute_visible_world_polygon()
		_visible_polygon_valid = true
	return _visible_polygon


## `visible_world_polygon()` grown outward by `margin`, cached per margin.
## Threats use it every physics frame to decide when they have left the screen;
## offsetting the polygon every frame for every threat is the expensive part.
func visible_world_polygon_grown(margin: float) -> PackedVector2Array:
	if not _visible_polygon_valid:
		visible_world_polygon()
	if not _grown_polygons.has(margin):
		var grown := Geometry2D.offset_polygon(_visible_polygon, margin)
		_grown_polygons[margin] = grown[0] if not grown.is_empty() else PackedVector2Array()
	return _grown_polygons[margin]


func _compute_visible_world_polygon() -> PackedVector2Array:
	var to_canvas := view.get_global_transform_with_canvas().affine_inverse()
	var rect := view.get_viewport_rect()
	var corners := [rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)]
	var polygon := PackedVector2Array()
	for corner: Vector2 in corners:
		polygon.append(projection.to_world(to_canvas * corner))
	return polygon


## Linear interpolation by current temperature (cold value at 0, hot value at 1).
func by_temperature(cold: float, hot: float) -> float:
	return lerpf(cold, hot, clampf(temperature, 0.0, 1.0))
