extends Node
## Builds the node tree described in GDD §10 and loads the current campaign level.
## Main
## ├ World   (logical physics world, hidden)
## ├ Screen  (Ground + y-sorted View + Camera2D)
## ├ DevASystems / DevBSystems
## └ UI      (CanvasLayer)

const DevASystems := preload("res://main/dev_a_systems.gd")
const DevBSystems := preload("res://main/dev_b_systems.gd")
const Music := preload("res://systems/b_music.gd")
const Ground := preload("res://main/ground.gd")


func _ready() -> void:
	Game.reset()
	LevelSession.clamp_current()
	var level := LevelSession.current()
	_apply_level_rules(level)

	# Stem-based background music, configured in data/audio_settings.tres.
	var music := Music.new()
	music.name = "Music"
	music.add_to_group(Groups.MUSIC)
	# Keep the track going while the game is paused (e.g. menus).
	music.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(music)

	var world := Node2D.new()
	world.name = "World"
	world.visible = false
	add_child(world)

	var screen := Node2D.new()
	screen.name = "Screen"
	add_child(screen)
	var ground := Ground.new()
	ground.name = "Ground"
	screen.add_child(ground)
	var view := Node2D.new()
	view.name = "View"
	view.y_sort_enabled = true
	screen.add_child(view)
	var camera := Camera2D.new()
	camera.name = "Camera"
	camera.position = Game.projection.to_screen(Game.grid.world_size() * 0.5)
	camera.zoom = Vector2.ONE * Game.VIEW_SETTINGS.zoom
	screen.add_child(camera)

	var ui := CanvasLayer.new()
	ui.name = "UI"
	ui.process_mode = Node.PROCESS_MODE_ALWAYS

	Game.world = world
	Game.view = view
	Game.ui = ui
	Game.factory = EntityFactory.new()

	# F3 debug view: planned routes of fish, predators and turtles.
	var path_debug := PathDebug.new()
	path_debug.name = "PathDebug"
	view.add_child(path_debug)

	_build_walls(world)
	level.populate(Game.factory)

	var dev_a := DevASystems.new()
	dev_a.name = "DevASystems"
	add_child(dev_a)
	var dev_b := DevBSystems.new()
	dev_b.name = "DevBSystems"
	add_child(dev_b)

	var debug_overlay := DebugOverlay.new()
	debug_overlay.name = "DebugOverlay"
	Game.ui.add_child(debug_overlay)

	add_child(ui)


## Copies the level's mechanics into the balance feature flags. Systems then
## gate themselves on Game.eco/actors as usual, and F3 shows the real state.
func _apply_level_rules(level: LevelDefinition) -> void:
	Game.eco.temperature_enabled = level.temperature_enabled
	Game.actors.co2_enabled = level.co2_enabled
	Game.actors.bag_enabled = level.bag_enabled
	Game.actors.cyclone_enabled = level.cyclone_enabled
	Game.actors.predator_enabled = level.predator_enabled
	Game.actors.turtle_enabled = level.turtle_enabled


## Four static walls just outside the world rectangle.
func _build_walls(world: Node2D) -> void:
	var size := Game.grid.world_size()
	var thickness := 64.0
	var walls := StaticBody2D.new()
	walls.name = "Walls"
	walls.collision_layer = Layers.WALL
	walls.collision_mask = 0
	var rects := [
		Rect2(-thickness, -thickness, size.x + thickness * 2, thickness), # top
		Rect2(-thickness, size.y, size.x + thickness * 2, thickness), # bottom
		Rect2(-thickness, 0, thickness, size.y), # left
		Rect2(size.x, 0, thickness, size.y), # right
	]
	for rect: Rect2 in rects:
		var shape := RectangleShape2D.new()
		shape.size = rect.size
		var collision := CollisionShape2D.new()
		collision.shape = shape
		collision.position = rect.get_center()
		walls.add_child(collision)
	world.add_child(walls)
