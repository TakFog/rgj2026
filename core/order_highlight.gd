class_name OrderHighlight
extends Node2D
## Seabed feedback for the fish order (GDD §5.4). While a fish is selected, the
## algae it could eat or the empty nest it could lay eggs in gets a ring under
## the pointer; clicking it widens the ring by one pixel for a moment, as the
## fish receives the order (which also clears the selection).
##
## The ring is drawn above the reef like the placement ghost: it is an
## affordance, so a fish swimming over the item must not hide it.

## Cell value meaning "nothing highlighted".
const NO_CELL := Vector2i(-(1 << 30), -(1 << 30))
## The two kinds of item a fish can be ordered to use.
const ALGAE := &"algae"
const NEST := &"nest"

## The ring wraps the whole cell, whose corners sit ~0.71 cells from the
## centre, so it never hides under the item's own footprint.
const RADIUS_CELLS := 0.72
const WIDTH := 2.0
## A click adds one pixel of width, fading back over CLICK_SECONDS.
const CLICK_BONUS := 1.0
const CLICK_SECONDS := 0.3
## The hover ring breathes a little so it reads as interactive.
const BREATH_SPEED := 3.0
const MIN_ALPHA := 0.6
const SEGMENTS := 24
## Above the y-sorted actors and items, like the placement ghost: a fish
## swimming over the item must not hide the feedback that it is clickable.
const Z_INDEX := 90

var _hover_cell := NO_CELL
var _hover_kind: StringName = &""
var _click_cell := NO_CELL
var _click_kind: StringName = &""
var _click_left := 0.0
var _time := 0.0


func _ready() -> void:
	z_index = Z_INDEX


## Rings `cell` while the pointer is over the algae or nest it holds. Pass
## NO_CELL to clear it.
func set_hover(cell: Vector2i, kind: StringName) -> void:
	if cell == _hover_cell and kind == _hover_kind:
		return
	_hover_cell = cell
	_hover_kind = kind
	queue_redraw()


## The clicked item took the order: widen its ring for a moment.
func pulse(cell: Vector2i, kind: StringName) -> void:
	_click_cell = cell
	_click_kind = kind
	_click_left = CLICK_SECONDS
	queue_redraw()


func _process(delta: float) -> void:
	if _click_left <= 0.0 and _hover_cell == NO_CELL:
		return
	_time += delta
	if _click_left > 0.0:
		_click_left = maxf(_click_left - delta, 0.0)
		if _click_left <= 0.0:
			_click_cell = NO_CELL
	queue_redraw()


func _draw() -> void:
	if _click_cell != NO_CELL:
		_draw_ring(_click_cell, _click_kind, width_at(_click_left), click_alpha(_click_left))
	if _hover_cell != NO_CELL:
		_draw_ring(_hover_cell, _hover_kind, WIDTH, hover_alpha(_time))


## Ring width `p_click_left` seconds into the click pulse: one pixel wider at
## the click, back to normal when it ends.
static func width_at(p_click_left: float) -> float:
	return WIDTH + CLICK_BONUS * clampf(p_click_left / CLICK_SECONDS, 0.0, 1.0)


## Click ring brightness: a bright flash that fades out with the pulse.
static func click_alpha(p_click_left: float) -> float:
	return clampf(p_click_left / CLICK_SECONDS, 0.0, 1.0)


## Hover ring brightness, breathing so the target reads as interactive.
static func hover_alpha(p_time: float) -> float:
	return MIN_ALPHA + (1.0 - MIN_ALPHA) * (0.5 + 0.5 * sin(p_time * BREATH_SPEED))


## Colour of the ring for `kind`: the same green and gold as the fish's badge.
static func color_for(kind: StringName) -> Color:
	match kind:
		ALGAE:
			return SelectionColors.FOOD
		NEST:
			return SelectionColors.EGGS
	return Color.WHITE


## World-space radius of the ring around a cell.
static func ring_radius(cell_size: float) -> float:
	return cell_size * RADIUS_CELLS


func _draw_ring(cell: Vector2i, kind: StringName, width: float, alpha: float) -> void:
	var color := color_for(kind)
	color.a = alpha
	draw_polyline(_projected_circle(Game.grid.cell_to_world(cell), ring_radius(Game.grid.cell_size)),
			color, width, true)


## A world-space circle projected to screen space, closed for draw_polyline.
func _projected_circle(center_world: Vector2, radius: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in SEGMENTS:
		var angle := TAU * float(i) / float(SEGMENTS)
		points.append(Game.projection.to_screen(center_world + Vector2.from_angle(angle) * radius))
	points.append(points[0])
	return points
