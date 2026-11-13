class_name OrderHighlight
extends Node
## Highlights the algae or the empty nest the selected fish can use (GDD
## §5.4): a rim along the item's own sprite silhouette, in the same green/gold
## as the fish's activity badge. Clicking the item widens the rim by one pixel
## for a moment, as the fish takes the order.
##
## Pure controller: the rim is drawn by the item itself (the algae sway shader,
## the nest's sprite material), because only the item knows where and how its
## art is drawn. The same rim shader also outlines the selected fish.

## The two kinds of item a fish can be ordered to use.
const ALGAE := &"algae"
const NEST := &"nest"

## On-screen rim width in pixels, and the extra width a click adds while it
## fades back over CLICK_SECONDS.
const WIDTH := 2.5
const CLICK_BONUS := 1.0
const CLICK_SECONDS := 0.3
## The hover rim breathes a little so it reads as interactive.
const BREATH_SPEED := 3.0
const MIN_ALPHA := 0.6

## Untyped on purpose: either may be freed while highlighted (eaten by a fish).
var _hover: Object = null
var _click: Object = null
var _click_left := 0.0
var _time := 0.0


## Highlights `target` (an algae or nest) while the pointer is over it. `null`
## clears the highlight.
func set_hover(target: Object) -> void:
	if target == _hover:
		return
	_clear(_hover)
	_hover = target if is_instance_valid(target) else null
	if _hover != null:
		_apply(_hover, hover_alpha(_time), WIDTH)


## The clicked item took the order: widen its rim for a moment.
func pulse(target: Object) -> void:
	if not is_instance_valid(target):
		return
	_click = target
	_click_left = CLICK_SECONDS
	_apply(_click, click_alpha(_click_left), width_at(_click_left))


func _process(delta: float) -> void:
	if _click_left <= 0.0 and _hover == null:
		return
	_time += delta
	if _hover != null and not is_instance_valid(_hover):
		_hover = null
	if _click_left > 0.0:
		_click_left = maxf(_click_left - delta, 0.0)
		if _click_left <= 0.0:
			_clear(_click)
			_click = null
		else:
			_apply(_click, click_alpha(_click_left), width_at(_click_left))
	# The hover rim goes last so it wins on the frame a pulse ends.
	if _hover != null:
		_apply(_hover, hover_alpha(_time), WIDTH)


## Kind of a highlightable item, or empty for anything else.
static func kind_of(target: Object) -> StringName:
	if target is Algae:
		return ALGAE
	if target is Nest:
		return NEST
	return &""


## Rim colour for `kind`: the same green and gold as the fish's activity badge.
static func color_for(kind: StringName) -> Color:
	match kind:
		ALGAE:
			return SelectionColors.FOOD
		NEST:
			return SelectionColors.EGGS
	return Color.WHITE


## Rim width `p_click_left` seconds into the click pulse: one pixel wider at
## the click, back to normal when it ends.
static func width_at(p_click_left: float) -> float:
	return WIDTH + CLICK_BONUS * clampf(p_click_left / CLICK_SECONDS, 0.0, 1.0)


## Click rim brightness: a bright flash that fades out with the pulse.
static func click_alpha(p_click_left: float) -> float:
	return clampf(p_click_left / CLICK_SECONDS, 0.0, 1.0)


## Hover rim brightness, breathing so the target reads as interactive.
static func hover_alpha(p_time: float) -> float:
	return MIN_ALPHA + (1.0 - MIN_ALPHA) * (0.5 + 0.5 * sin(p_time * BREATH_SPEED))


## Applies the rim to `target` at `alpha` brightness and `width` screen pixels.
func _apply(target: Object, alpha: float, width: float) -> void:
	var kind := kind_of(target)
	if kind == &"":
		return
	var color := color_for(kind)
	color.a *= alpha
	if target is Algae:
		(target as Algae).set_highlight(color, width)
	elif target is Nest:
		(target as Nest).set_highlight(color, width)


## Removes the rim from `target`, if it still exists.
func _clear(target: Object) -> void:
	if not is_instance_valid(target):
		return
	if target is Algae:
		(target as Algae).clear_highlight()
	elif target is Nest:
		(target as Nest).clear_highlight()
