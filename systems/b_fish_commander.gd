class_name FishCommander
extends Node
## Player control of fish (GDD §5.4): click a fish to select it, click again to
## send it straight there. Right click / Esc deselects. Ignored while placing
## (contract #8).

## Used by the audio system (systems/b_audio.gd).
signal fish_selected
signal fish_ordered
signal selection_cleared

var selected: Fish = null


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
		selected.order(click.clamp(Vector2.ZERO, Game.grid.world_size()))
		fish_ordered.emit()
		_select(null)


func _fish_at(click: Vector2) -> Fish:
	var fishes := get_tree().get_nodes_in_group(Groups.FISH)
	var points := PackedVector2Array()
	for fish in fishes:
		points.append((fish as Node2D).global_position)
	var index := pick_nearest(points, click, Game.actors.fish_click_radius)
	return null if index < 0 else fishes[index] as Fish


func _select(fish: Fish) -> void:
	if is_instance_valid(selected):
		selected.selected = false
	selected = fish
	if fish != null:
		fish.selected = true
