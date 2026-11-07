extends Node
## Plays a scripted run of the real game for the jam trailer and draws the
## title cards and captions on top of it. Gameplay is driven through the same
## entry points the player uses (PlacementController, FishCommander), while a
## fake cursor shows where the "player" clicks. Threats, the predator and the
## turtle are spawned on cue so every feature appears on screen in time.
## Only used by tools/trailer.sh; never part of the shipped game.

const ThreatSpawner := preload("res://systems/b_threat_spawner.gd")
const LOGO: Texture2D = preload("res://assets/ui/logo.png")

## Fixed seed: the scripted threats enter from the same edges on every take.
const SEED := 2026
const CAPTION_FONT_SIZE := 34
const CURSOR_SPEED := 900.0 # screen pixels per second

const TAGLINE := "Il corallo non fa niente.\nSubisce."
const END_LINE := "Quanto riuscirai a resistere?"
const JAM_LINE := "Rome Game Jam 2026  ·  tema SUBIRE"
const TEAM_LINE := "Flavio De Benedictis  ·  Lorenzo Patané  ·  Maria Elena Papale  ·  Mateusz Kulesza"

var _placement: PlacementController
var _commander: FishCommander
var _pause: PauseController
var _rng := RandomNumberGenerator.new()

var _layer: CanvasLayer
var _black: ColorRect
var _card: VBoxContainer
var _card_logo: TextureRect
var _card_text: Label
var _card_small: Label
var _caption_box: PanelContainer
var _caption: Label
var _cursor: Node2D


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rng.seed = SEED
	_build_overlay()
	_run.call_deferred()


# --- Script ----------------------------------------------------------------


func _run() -> void:
	await _wait_for_game()

	# 1. Title card over the live reef.
	await _wait(0.6)
	await _show_card(TAGLINE, "")
	await _wait(2.8)
	await _hide_card()
	_fade(_black, 0.0, 1.6)
	await _wait(1.2)

	# 2. The reef.
	await _say("Una barriera corallina da tenere in equilibrio.")
	await _wait(3.0)

	# 3. Placing from the inventory.
	await _say("Piazza coralli, alghe e nidi.")
	_show_cursor(true)
	await _place(InventoryModel.CORAL, Vector2i(9, 3))
	await _place(InventoryModel.ALGAE, Vector2i(16, 7))
	if not await _place(InventoryModel.NEST, Vector2i(5, 9)):
		await _place(InventoryModel.CORAL, Vector2i(15, 9))
	await _wait(0.8)

	# 4. Commanding the fish.
	await _say("Guida i pesci: mangiano le alghe e fecondano i nidi.")
	await _order_nearest_fish(Game.grid.cell_to_world(Vector2i(16, 12)))
	await _order_nearest_fish(_nest_world())
	await _order_nearest_fish(Game.grid.cell_to_world(Vector2i(7, 5)))
	await _wait(2.0)
	_show_cursor(false)

	# 5. Warming sea + threats.
	_heat_up(0.85, 18.0)
	await _say("Ma il mare si scalda...")
	_spawn_threat(ThreatSchedule.Type.CO2)
	await _wait(2.5)
	_spawn_threat(ThreatSchedule.Type.BAG)
	await _wait(2.0)
	await _say("CO2, plastica e cicloni assediano il reef.")
	_spawn_threat(ThreatSchedule.Type.CYCLONE)
	await _wait(3.0)
	_spawn_threat(ThreatSchedule.Type.BAG)
	await _wait(3.5)

	# 6. Predator and turtle.
	_spawn_actor(true)
	await _say("Predatori affamati...")
	await _wait(4.0)
	_spawn_actor(false)
	await _say("...e tartarughe alleate.")
	await _wait(5.0)

	# 7. The balance rules.
	await _say("Troppe alghe soffocano i coralli.\nTroppi coralli affamano i pesci.")
	await _wait(5.0)

	# 8. Collapse: the coral endures until it can't.
	await _say("Se una specie scompare, la barriera crolla.")
	await _crumble_corals()
	var tree := get_tree()
	while not tree.paused: # the game-over screen pauses the tree
		await _wait(0.25)
	_hide_caption()
	await _wait(3.5)

	# 9. End card.
	await _fade(_black, 1.0, 1.2)
	await _show_card(END_LINE, JAM_LINE + "\n\n" + TEAM_LINE)
	await _wait(5.0)
	await _hide_card()
	await _wait(0.6)
	tree.quit()


func _on_pause_toggled(paused: bool) -> void:
	if paused:
		_pause.set_paused(false)


# --- Gameplay actions ------------------------------------------------------


func _wait_for_game() -> void:
	var tree := get_tree()
	while tree.current_scene == null or tree.current_scene.get_node_or_null("DevBSystems/FishCommander") == null:
		await tree.process_frame
	var main := tree.current_scene
	_placement = main.get_node("DevASystems/PlacementController") as PlacementController
	_commander = main.get_node("DevBSystems/FishCommander") as FishCommander
	# The game pauses when its window loses focus (alt-tab, another app opening
	# during the take). Movie Maker records anyway, so a focus change would
	# bury the trailer under the pause menu: undo any pause at once. Both calls
	# run before the frame is drawn, so the menu never reaches the recording.
	_pause = main.get_node("DevBSystems/PauseController") as PauseController
	_pause.pause_toggled.connect(_on_pause_toggled)
	# The placement preview follows the real OS mouse, which is not part of
	# the recording: hide it, the fake cursor shows the clicks instead.
	var ghost := Game.view.get_node_or_null("PlacementGhost") as CanvasItem
	if ghost != null:
		ghost.visible = false
	await tree.process_frame


## Picks an inventory slot holding `kind` and places it at `cell` (or the
## nearest free spot). Returns false if no such item is in the inventory.
func _place(kind: StringName, cell: Vector2i) -> bool:
	var slot := _slot_with(kind)
	if slot < 0:
		return false
	var card := _card_for(slot)
	if card != null:
		await _cursor_to(card.get_global_rect().get_center())
		await _click()
	_placement.begin(slot)
	var origin := _free_origin_near(cell)
	await _wait(0.25)
	await _cursor_to(_screen_of(Game.grid.cell_to_world(origin)))
	await _click()
	_placement.try_place_at(origin)
	await _wait(0.6)
	return true


func _slot_with(kind: StringName) -> int:
	var model := _placement.inventory.model
	for i in model.slots.size():
		if model.is_ready(i) and model.item(i).get("kind") == kind:
			return i
	return -1


func _card_for(slot: int) -> Control:
	var bar := Game.ui.get_node_or_null("InventoryBar")
	if bar == null or slot >= bar.get_child_count():
		return null
	return bar.get_child(slot) as Control


## Spiral search around `cell` for an origin where the active item fits.
func _free_origin_near(cell: Vector2i) -> Vector2i:
	for radius in 6:
		for dy in range(-radius, radius + 1):
			for dx in range(-radius, radius + 1):
				if maxi(absi(dx), absi(dy)) != radius:
					continue
				var origin := cell + Vector2i(dx, dy)
				if _placement.can_place(_placement.footprint(origin)):
					return origin
	return cell


## Selects the fish closest to `target` and sends it there, both by "clicks".
func _order_nearest_fish(target: Vector2) -> void:
	var fish := _nearest_fish(target)
	if fish == null:
		return
	await _cursor_to(_screen_of(fish.global_position), fish)
	await _click()
	if not is_instance_valid(fish):
		return
	_commander._on_command(fish.global_position)
	await _wait(0.35)
	await _cursor_to(_screen_of(target))
	await _click()
	_commander._on_command(target)
	await _wait(0.5)


func _nearest_fish(target: Vector2) -> Fish:
	var best: Fish = null
	var best_distance := INF
	for node in get_tree().get_nodes_in_group(Groups.FISH):
		var fish := node as Fish
		if fish == null or not fish.is_adult():
			continue
		var distance := fish.global_position.distance_to(target)
		if distance < best_distance:
			best = fish
			best_distance = distance
	return best


func _nest_world() -> Vector2:
	var nests := get_tree().get_nodes_in_group(Groups.NESTS)
	for node in nests:
		var nest := node as Nest
		if nest != null and nest.is_empty():
			return nest.global_position
	return Game.grid.cell_to_world(Vector2i(10, 15))


## Drives the thermometer through the debug override, so the trailer shows the
## hot-sea phase within a minute instead of eight.
func _heat_up(to: float, seconds: float) -> void:
	Game.debug_temperature_value = Game.temperature
	Game.debug_temperature_manual = true
	var tween := create_tween()
	tween.tween_method(func(v: float) -> void: Game.debug_temperature_value = v,
		Game.temperature, to, seconds)


## A threat entering from a random edge, aimed at the middle of the reef.
func _spawn_threat(kind: int) -> void:
	ThreatSpawner.spawn(kind, _entry(), _rng)


func _spawn_actor(predator: bool) -> void:
	if predator:
		Game.factory.spawn_predator(_entry())
	else:
		Game.factory.spawn_turtle(_entry())


func _entry() -> EdgeEntry:
	var size := Game.grid.world_size()
	var middle := Rect2(size * 0.3, size * 0.4)
	return EdgeEntry.random(_rng, Game.visible_world_polygon(), middle)


## Crumbles the corals one by one: the coral population hits zero and the
## collapse countdown starts.
func _crumble_corals() -> void:
	for node in get_tree().get_nodes_in_group(Groups.CORALS):
		var coral := node as Coral
		if coral != null and is_instance_valid(coral):
			coral.destroy()
			await _wait(0.45)


# --- Overlay ---------------------------------------------------------------


func _build_overlay() -> void:
	_layer = CanvasLayer.new()
	_layer.layer = 100
	add_child(_layer)

	_caption_box = PanelContainer.new()
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.02, 0.06, 0.12, 0.72)
	box.set_corner_radius_all(14)
	box.content_margin_left = 28
	box.content_margin_right = 28
	box.content_margin_top = 12
	box.content_margin_bottom = 12
	_caption_box.add_theme_stylebox_override("panel", box)
	_caption_box.modulate.a = 0.0
	_caption_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(_caption_box)
	_caption = Label.new()
	_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_caption.add_theme_font_size_override("font_size", CAPTION_FONT_SIZE)
	_caption.add_theme_color_override("font_color", SeaStyle.SAND_COLOR)
	_caption_box.add_child(_caption)

	_black = ColorRect.new()
	_black.color = Color(0.01, 0.03, 0.07)
	_black.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_black.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(_black)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(center)
	_card = VBoxContainer.new()
	_card.add_theme_constant_override("separation", 18)
	_card.modulate.a = 0.0
	center.add_child(_card)
	_card_logo = TextureRect.new()
	_card_logo.texture = LOGO
	_card_logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_card_logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_card_logo.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_card_logo.custom_minimum_size = Vector2(720, 330)
	_card.add_child(_card_logo)
	_card_text = Label.new()
	SeaStyle.style_title(_card_text, SeaStyle.HERO_TITLE_FONT_SIZE)
	_card.add_child(_card_text)
	_card_small = Label.new()
	SeaStyle.style_body(_card_small, 20)
	_card.add_child(_card_small)

	_cursor = Node2D.new()
	_cursor.draw.connect(_draw_cursor)
	_cursor.visible = false
	_layer.add_child(_cursor)


func _show_card(text: String, small: String) -> void:
	_card_text.text = text
	_card_small.text = small
	_card_small.visible = not small.is_empty()
	await _fade(_card, 1.0, 1.0)


func _hide_card() -> void:
	await _fade(_card, 0.0, 0.7)


## Replaces the caption (fade out, swap text, fade in) near the top of the screen.
func _say(text: String) -> void:
	if _caption_box.modulate.a > 0.0:
		await _fade(_caption_box, 0.0, 0.25)
	_caption.text = text
	_caption_box.reset_size()
	var screen := get_viewport().get_visible_rect().size
	_caption_box.position = Vector2((screen.x - _caption_box.size.x) * 0.5, screen.y * 0.13)
	await _fade(_caption_box, 1.0, 0.35)


func _hide_caption() -> void:
	_fade(_caption_box, 0.0, 0.4)


func _fade(item: CanvasItem, alpha: float, seconds: float) -> void:
	var tween := create_tween()
	tween.tween_property(item, "modulate:a", alpha, seconds)
	await tween.finished


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds, true).timeout


# --- Fake cursor -----------------------------------------------------------


func _show_cursor(value: bool) -> void:
	if value and not _cursor.visible:
		var screen := get_viewport().get_visible_rect().size
		_cursor.position = Vector2(screen.x * 0.5, screen.y * 0.7)
	_cursor.visible = value


## Glides the cursor to `to`. If `follow` is set, keeps homing on that node
## (a moving fish) until it is reached.
func _cursor_to(to: Vector2, follow: Node2D = null) -> void:
	var tree := get_tree()
	while true:
		var target := to
		if follow != null and is_instance_valid(follow):
			target = _screen_of(follow.global_position)
		var step := CURSOR_SPEED * get_process_delta_time()
		var offset := target - _cursor.position
		if offset.length() <= step:
			_cursor.position = target
			return
		# Ease in on the last stretch so the motion looks hand-made.
		var speed_scale := clampf(offset.length() / 120.0, 0.35, 1.0)
		_cursor.position += offset.normalized() * step * speed_scale
		await tree.process_frame


func _click() -> void:
	var tween := create_tween()
	tween.tween_property(_cursor, "scale", Vector2.ONE * 0.8, 0.07)
	tween.tween_property(_cursor, "scale", Vector2.ONE, 0.1)
	await tween.finished


func _draw_cursor() -> void:
	var arrow := PackedVector2Array([
		Vector2(0, 0), Vector2(0, 26), Vector2(7, 20), Vector2(12, 31),
		Vector2(17, 29), Vector2(12, 18), Vector2(21, 18)])
	var outline := arrow.duplicate()
	outline.append(arrow[0])
	_cursor.draw_colored_polygon(arrow, Color.WHITE)
	_cursor.draw_polyline(outline, Color(0.05, 0.1, 0.15), 2.0, true)


## World units -> overlay (canvas) pixels, through the oblique projection
## and the camera.
func _screen_of(world: Vector2) -> Vector2:
	return Game.view.get_global_transform_with_canvas() * Game.projection.to_screen(world)
