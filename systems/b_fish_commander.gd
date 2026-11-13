class_name FishCommander
extends Node
## Player control of fish (GDD §5.4): click a fish to select it, click again to
## send it straight there. Right click / Esc deselects. Ignored while placing
## (contract #8).
##
## While a fish is selected, the algae it could eat or the empty nest it could
## lay eggs in is ringed on the seabed under the pointer (core/order_highlight.gd),
## so the player sees what a click will do. Clicking it pulses the ring as the
## fish takes the order. Touch builds have no hover: they only get the pulse.

## Used by the audio system (systems/b_audio.gd).
signal fish_selected
signal fish_ordered
signal selection_cleared

var selected: Fish = null
## Touch builds pick fish with a fingertip-sized radius.
var touch_mode := Platform.is_touch()

## Rings around the hovered target and the clicked one.
var _highlight: OrderHighlight


func _ready() -> void:
	_highlight = OrderHighlight.new()
	_highlight.name = "OrderHighlight"
	add_child(_highlight)


## Index of the point nearest to `click` within `radius`, or -1.
static func pick_nearest(points: PackedVector2Array, click: Vector2, radius: float) -> int:
	var best := -1
	var best_distance := radius
	for i in points.size():
		var distance := points[i].distance_to(click)
		if distance <= best_distance:
			best = i
			best_distance = distance
	return best


## Kind of fish-order target `entity` is for `fish`: an algae it can eat (one
## no other fish has reserved) or an empty nest it can lay eggs in. Empty for
## everything else (corals, nests with eggs, algae another fish is eating).
static func target_kind(entity: Object, fish: Object) -> StringName:
	if entity is Algae:
		return OrderHighlight.ALGAE if not (entity as Algae).is_taken_by_other(fish) else &""
	if entity is Nest and (entity as Nest).is_empty():
		return OrderHighlight.NEST
	return &""


func _physics_process(_delta: float) -> void:
	_sync_hover()


func _unhandled_input(event: InputEvent) -> void:
	if Game.placing:
		return
	if event.is_action_pressed(InputActions.COMMAND):
		_on_command(Game.mouse_world())
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(InputActions.CANCEL) and is_instance_valid(selected):
		_select(null)
		selection_cleared.emit()
		get_viewport().set_input_as_handled()


func _on_command(click: Vector2) -> void:
	var fish := _fish_at(click)
	if fish != null:
		_select(fish)
		fish_selected.emit()
	elif is_instance_valid(selected):
		var target := _interactable_under_pointer()
		selected.order(click.clamp(Vector2.ZERO, Game.grid.world_size()))
		if target != null:
			_highlight.pulse(target)
		fish_ordered.emit()
		_select(null)


## Hover feedback needs a pointer (touch has none), a selected fish and no
## placement in progress.
func _sync_hover() -> void:
	if touch_mode or Game.placing or not is_instance_valid(selected):
		_highlight.set_hover(null)
		return
	_highlight.set_hover(_interactable_under_pointer())


## The algae or empty nest under the pointer that the selected fish can use.
func _interactable_under_pointer() -> Node2D:
	var pointer := Game.view.get_global_mouse_position()
	var best: Node2D = null
	var best_distance := INF
	for group in [Groups.ALGAE, Groups.NESTS]:
		for node in get_tree().get_nodes_in_group(group):
			var item := node as Node2D
			if item == null or target_kind(item, selected) == &"":
				continue
			# The art stands taller than its cell: hover the sprite box.
			var rect := _screen_rect(item)
			if not rect.has_point(pointer):
				continue
			var distance := rect.get_center().distance_to(pointer)
			if distance < best_distance:
				best = item
				best_distance = distance
	return best


## Screen-space box of an item's art, for the hover hit test.
static func _screen_rect(item: Node2D) -> Rect2:
	if item is Algae:
		return (item as Algae).screen_rect()
	if item is Nest:
		return (item as Nest).screen_rect()
	return Rect2()


func _fish_at(click: Vector2) -> Fish:
	var fishes := get_tree().get_nodes_in_group(Groups.FISH)
	var points := PackedVector2Array()
	for fish in fishes:
		points.append((fish as Node2D).global_position)
	var radius := Game.actors.fish_touch_radius if touch_mode else Game.actors.fish_click_radius
	var index := pick_nearest(points, click, radius)
	return null if index < 0 else fishes[index] as Fish


func _select(fish: Fish) -> void:
	if is_instance_valid(selected):
		selected.selected = false
	selected = fish
	if fish != null:
		fish.selected = true
