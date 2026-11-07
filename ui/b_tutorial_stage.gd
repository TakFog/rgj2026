class_name TutorialStage
extends Control
## Hand-animated mini-reef for the tutorial. It uses the game's textures, the
## oblique projection and the algae sway shader, but it owns plain visuals:
## no entities, no grid, no physics and no gameplay state.
## One step is built and animated at a time; TutorialScreen advances them.

const SEABED_SHADER := preload("res://main/seabed.gdshader")
const CELL_PX := 64.0
## Minimum size; the tutorial screen stretches the stage to fill its pane.
const STAGE_SIZE := Vector2(460, 270)
## The vignettes use cells around x 1.2..6.2, y 1.5..2.7. Keep them centred in
## the pane instead of anchored to the top-left of that range.
const CONTENT_CENTER := Vector2(3.7, 2.0)
const NEST_HEIGHT := 130.0
const ALGAE_HEIGHT := 105.0
const CORAL_HEIGHT := 140.0
## Ground actors stay above the stage background (positive z); predators and the
## other creatures draw above the nest without disappearing behind the seabed.
const Z_BY_ID := {
	&"nest": 1,
	&"nest_eggs": 1,
	&"coral": 2,
	&"algae": 2,
	&"fish": 5,
	&"bag": 8,
	&"co2": 10,
	&"predator": 20,
	&"turtle": 22,
	&"cyclone": 24,
}

var _projection: ViewProjection
var _layer: Node2D
var _tween: Tween
var _extra: Array[Tween] = []

var _nest: Sprite2D
var _ring: ClockRing
var _adult: FishVisual
var _co2_cloud: Co2Bubbles
var _algae_a: Sprite2D
var _ghost_algae: Sprite2D
var _coral_sprite: Sprite2D
var _oxygen_bar: OxygenBar
## Generic interaction vignette (agent on the left, target on the right).
var _agent: Node2D
var _target: Node2D
## The row currently being shown; its agent_end/target_end drive the outcome.
var _data: Dictionary = {}


func _init(x_axis := Vector2(1, 0), y_axis := Vector2(-0.5, 0.5)) -> void:
	custom_minimum_size = STAGE_SIZE
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_projection = ViewProjection.new(x_axis, y_axis, CELL_PX)


func _ready() -> void:
	var seabed := ColorRect.new()
	seabed.name = "Seabed"
	seabed.color = Color8(100, 96, 70)
	seabed.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	seabed.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var material := ShaderMaterial.new()
	material.shader = SEABED_SHADER
	material.set_shader_parameter("to_world_x", Vector2(1, 0))
	material.set_shader_parameter("to_world_y", Vector2(1, 2))
	material.set_shader_parameter("tint_amount", 0.35)
	material.set_shader_parameter("vignette_strength", 0.4)
	seabed.material = material
	add_child(seabed)
	# show_interaction() may have run before the node entered the tree.
	move_child(seabed, 0)


## Builds and (when in the scene tree) animates the selected interaction.
## The three core reactions keep their hand-made vignettes; everything else uses
## a generic agent-to-target diagram.
func show_interaction(data: Dictionary) -> void:
	_clear()
	_data = data
	var id: StringName = data.get("id", &"")
	match id:
		&"fish_nest": _build_nest()
		&"co2_algae": _build_co2()
		&"algae_coral": _build_coral()
		_: _build_generic(data)
	if is_inside_tree():
		_animate(id)


func stop() -> void:
	_clear()


func sprite_count() -> int:
	return visual_nodes().size()


func visual_nodes() -> Array[Node]:
	if _layer == null:
		return []
	return _layer.get_children()


func _visual_layer() -> Node2D:
	if _layer == null:
		_layer = Node2D.new()
		_layer.name = "Visuals"
		_layer.y_sort_enabled = true
		add_child(_layer)
	return _layer


## Cell coordinates to stage pixels, using the same oblique tilt as the game.
func _pos(cell: Vector2) -> Vector2:
	var stage_size := size if size.x > 0.0 else STAGE_SIZE
	var origin := Vector2(stage_size.x * 0.5, stage_size.y * 0.72)
	return origin + _projection.to_screen(cell - CONTENT_CENTER) - _projection.to_screen(Vector2.ZERO)


func _sprite(texture: Texture2D, height_px: float, cell: Vector2, tint := Color.WHITE) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.modulate = tint
	_fit(sprite, texture, height_px)
	sprite.position = _pos(cell)
	_visual_layer().add_child(sprite)
	return sprite


## Resizes `sprite` so the texture's foot sits on its anchor at `height_px`.
func _fit(sprite: Sprite2D, texture: Texture2D, height_px: float) -> void:
	sprite.texture = texture
	sprite.scale = Vector2.ONE * (height_px / texture.get_height())
	sprite.offset = Vector2(0, -texture.get_height() * 0.45)


func _fish(cell: Vector2, adult: bool, heading: Vector2) -> FishVisual:
	var fish := FishVisual.new()
	fish.radius_world = 15.0
	fish.adult = adult
	fish.heading = heading
	fish.position = _pos(cell)
	fish.z_index = 10
	_visual_layer().add_child(fish)
	return fish


func _algae(cell: Vector2) -> Sprite2D:
	var sprite := _sprite(Algae.TEXTURE, ALGAE_HEIGHT, cell, Algae.SPRITE_TINT)
	var material := ShaderMaterial.new()
	material.shader = Algae.SWAY_SHADER
	material.set_shader_parameter("phase", cell.x * 0.73 + cell.y * 1.21)
	sprite.material = material
	return sprite


func _co2(cell: Vector2) -> Co2Bubbles:
	var cloud := Co2Bubbles.new()
	cloud.radius_px = 55.0
	cloud.tint = Color.WHITE
	cloud.position = _pos(cell)
	cloud.z_index = 20
	_visual_layer().add_child(cloud)
	return cloud


func _coral(cell: Vector2) -> Array[Sprite2D]:
	var sprites: Array[Sprite2D] = []
	sprites.append(_sprite(Coral.BASE_TEXTURE, CORAL_HEIGHT, cell))
	sprites.append(_sprite(Coral.CORAL_TEXTURE, CORAL_HEIGHT, cell, Coral.CORAL_HEALTHY_TINT))
	return sprites


func _make_oxygen_bar(cell: Vector2) -> OxygenBar:
	var bar := OxygenBar.new()
	bar.position = _pos(cell) + Vector2(-OxygenBar.WIDTH * 0.5, -CORAL_HEIGHT - 18.0)
	bar.z_index = 5
	_visual_layer().add_child(bar)
	return bar


func _start_tween() -> Tween:
	if not is_inside_tree():
		return null
	_tween = create_tween()
	_tween.set_parallel(true)
	return _tween


func _extra_tween() -> Tween:
	var tween := create_tween()
	_extra.append(tween)
	return tween


## Small scale pop used by the nest and the algae.
func _pulse(item: Node2D, amount: float, seconds: float) -> void:
	if not is_inside_tree():
		return
	var base: Vector2 = item.scale
	var tween := _extra_tween()
	tween.tween_property(item, "scale", base * amount, seconds * 0.4)
	tween.tween_property(item, "scale", base, seconds * 0.6)


## Fades every stage visual; used at the end of each vignette.
func _fade_all(progress: float) -> void:
	for child in visual_nodes():
		if child is CanvasItem:
			(child as CanvasItem).modulate.a = 1.0 - progress


func _clear() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = null
	for tween in _extra:
		if tween.is_valid():
			tween.kill()
	_extra.clear()
	_nest = null
	_ring = null
	_adult = null
	_co2_cloud = null
	_algae_a = null
	_ghost_algae = null
	_coral_sprite = null
	_oxygen_bar = null
	_agent = null
	_target = null
	_data = {}
	if _layer == null:
		return
	for child in _layer.get_children():
		child.free()


func _build_nest() -> void:
	_nest = _sprite(Nest.EMPTY_TEXTURE, NEST_HEIGHT, Vector2(5.0, 2.0))
	_nest.z_index = Z_BY_ID[&"nest"]
	_adult = _fish(Vector2(1.2, 2.7), true, Vector2.RIGHT)
	_ring = ClockRing.new()
	_ring.position = _pos(Vector2(5.0, 2.0))
	_ring.visible = false
	_ring.z_index = 1
	_visual_layer().add_child(_ring)


func _build_co2() -> void:
	_algae_a = _algae(Vector2(3.0, 2.2))
	_co2_cloud = _co2(Vector2(0.0, 1.6))


func _build_coral() -> void:
	var corals := _coral(Vector2(5.0, 2.2))
	_coral_sprite = corals[1]
	_algae_a = _algae(Vector2(3.2, 2.2))
	_ghost_algae = _algae(Vector2(4.0, 2.2))
	_ghost_algae.scale = Vector2.ZERO
	_oxygen_bar = _make_oxygen_bar(Vector2(5.0, 2.2))


func _build_generic(data: Dictionary) -> void:
	_agent = _generic_visual(StringName(data.get("agent_id", &"")), Vector2(1.2, 2.2))
	_target = _generic_visual(StringName(data.get("target_id", &"")), Vector2(5.0, 2.2))


func _generic_visual(id: StringName, cell: Vector2) -> Node2D:
	var visual: Node2D
	match id:
		&"co2":
			visual = _co2(cell)
		&"fish":
			visual = _fish(cell, true, Vector2.RIGHT)
		&"algae":
			visual = _algae(cell)
		_:
			var texture := TutorialIcons.texture(id)
			if texture == null:
				return null
			var tint := Coral.CORAL_HEALTHY_TINT if id == &"coral" else Color.WHITE
			visual = _sprite(texture, TutorialIcons.height(id), cell, tint)
	visual.z_index = Z_BY_ID.get(id, 0)
	return visual


func _animate(id: StringName) -> void:
	var tween := _start_tween()
	if tween == null:
		return
	match id:
		&"fish_nest": _animate_nest(tween)
		&"co2_algae": _animate_co2(tween)
		&"algae_coral": _animate_coral(tween)
		_: _animate_generic(tween)


func _animate_nest(tween: Tween) -> void:
	var adult := _adult
	var nest := _nest
	var ring := _ring
	tween.tween_property(adult, "position", _pos(Vector2(5.0, 2.0)), 1.6).set_delay(0.2)
	tween.tween_callback(func() -> void:
		_fit(nest, Nest.EGGS_TEXTURE, NEST_HEIGHT)
		_pulse(nest, 1.08, 0.3)
		ring.visible = true
	).set_delay(1.8)
	tween.tween_property(ring, "ratio", 1.0, 1.6).set_delay(1.8)
	for i in 2:
		var juvenile := _fish(Vector2(5.0, 2.0), false, Vector2.LEFT if i == 0 else Vector2.RIGHT)
		juvenile.modulate.a = 0.0
		var target := Vector2(3.8, 1.5) if i == 0 else Vector2(6.2, 1.5)
		tween.tween_property(juvenile, "modulate:a", 1.0, 0.2).set_delay(3.4)
		tween.tween_property(juvenile, "position", _pos(target), 1.4).set_delay(3.4)
	tween.tween_method(_fade_all, 0.0, 1.0, 0.5).set_delay(5.2)


func _animate_co2(tween: Tween) -> void:
	var cloud := _co2_cloud
	var alga := _algae_a
	tween.tween_property(cloud, "position", _pos(Vector2(3.0, 2.2)), 1.8).set_delay(0.2)
	tween.tween_callback(func() -> void:
		cloud.vanish()
		_pulse(alga, 1.1, 0.5)
		var second := _algae(Vector2(4.0, 2.2))
		var target := second.scale
		second.scale = Vector2.ZERO
		var grow := _extra_tween()
		grow.tween_property(second, "scale", target, 0.5) \
				.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	).set_delay(2.0)
	tween.tween_method(_fade_all, 0.0, 1.0, 0.5).set_delay(5.2)


func _animate_coral(tween: Tween) -> void:
	var ghost := _ghost_algae
	var target := Vector2.ONE * (ALGAE_HEIGHT / Algae.TEXTURE.get_height())
	tween.tween_property(ghost, "scale", target, 0.6).set_delay(0.4)
	tween.tween_property(ghost, "scale", Vector2.ZERO, 0.3).set_delay(1.0)
	tween.tween_property(_coral_sprite, "modulate", Color(2.0, 0.6, 0.6), 0.3).set_delay(1.0)
	tween.tween_property(_coral_sprite, "modulate", Coral.CORAL_HEALTHY_TINT, 0.3).set_delay(1.3)
	tween.tween_property(_oxygen_bar, "ratio", 0.8, 0.4).set_delay(1.2)
	tween.tween_method(_fade_all, 0.0, 1.0, 0.5).set_delay(5.2)


## Generic vignette: the agent slides into the target, then the row's
## agent_end/target_end decide who flashes, vanishes, leaves or passes through.
func _animate_generic(tween: Tween) -> void:
	var agent := _agent
	var target := _target
	if agent == null or target == null:
		return
	var agent_end: String = _data.get("agent_end", "stay")
	var target_end: String = _data.get("target_end", "damage")
	tween.tween_property(agent, "position", _pos(Vector2(4.0, 2.2)), 1.2).set_delay(0.2)
	tween.tween_callback(func() -> void:
		if not is_instance_valid(agent) or not is_instance_valid(target):
			return
		_pulse(target, 1.1, 0.35)
		_apply_end(agent, agent_end, Vector2.RIGHT)
		_apply_end(target, target_end, Vector2.RIGHT)
	).set_delay(1.2)
	tween.tween_method(_fade_all, 0.0, 1.0, 0.5).set_delay(5.0)


## Applies one outcome to an actor: stay, vanish, leave, pass, damage, empty.
func _apply_end(item: Node2D, end: String, direction: Vector2) -> void:
	match end:
		"vanish":
			if item is Co2Bubbles:
				(item as Co2Bubbles).vanish()
			else:
				_fade_out(item, 0.3)
		"leave", "pass":
			_move_out(item, direction, 260.0, 0.9)
		"damage":
			_flash(item)
		"empty":
			_empty_nest(item)
		"grow":
			_pulse(item, 1.12, 0.5)
		_:
			pass


func _fade_out(item: Node2D, seconds: float) -> void:
	var tween := _extra_tween()
	tween.tween_property(item, "modulate:a", 0.0, seconds)


func _move_out(item: Node2D, direction: Vector2, distance: float, seconds: float) -> void:
	var tween := _extra_tween()
	tween.set_parallel(true)
	tween.tween_property(item, "position", item.position + direction * distance, seconds)
	tween.tween_property(item, "modulate:a", 0.0, seconds)


func _flash(item: Node2D) -> void:
	var original: Color = item.modulate
	var tween := _extra_tween()
	tween.tween_property(item, "modulate", Color(2.0, 0.6, 0.6, 1.0), 0.15)
	tween.tween_property(item, "modulate", original, 0.25)


## Eggs eaten/destroyed: swap the nest sprite to the empty-nest art.
func _empty_nest(item: Node2D) -> void:
	var sprite := item as Sprite2D
	if sprite == null:
		_fade_out(item, 0.3)
		return
	_fit(sprite, Nest.EMPTY_TEXTURE, NEST_HEIGHT)
	_pulse(sprite, 1.05, 0.2)


## Sweeping arc that compresses the nest's 20-second wait into the vignette.
class ClockRing extends Node2D:
	var ratio := 0.0:
		set(value):
			ratio = value
			queue_redraw()

	func _draw() -> void:
		if ratio <= 0.0:
			return
		draw_arc(Vector2.ZERO, 34.0, -PI * 0.5, -PI * 0.5 + TAU * ratio, 32,
				Color(1.0, 0.76, 0.16, 0.9), 3.0)


## Faint oxygen bar above the coral; it drops when the algae presses on it.
class OxygenBar extends Control:
	const WIDTH := 44.0
	const HEIGHT := 6.0

	var ratio := 1.0:
		set(value):
			ratio = clampf(value, 0.0, 1.0)
			if _fill != null:
				_fill.size = Vector2(WIDTH * ratio, HEIGHT)

	var _fill: ColorRect

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		size = Vector2(WIDTH, HEIGHT)
		var back := ColorRect.new()
		back.color = Color(0.0, 0.0, 0.0, 0.6)
		back.size = Vector2(WIDTH, HEIGHT)
		back.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(back)
		_fill = ColorRect.new()
		_fill.color = Color(0.25, 0.85, 0.9)
		_fill.size = Vector2(WIDTH, HEIGHT)
		_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_fill)
