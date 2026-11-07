extends Node
## Dev B's systems and UI are added here (fish commander, population monitor,
## threat spawner, HUD...). Only Dev B edits this file.

const ThreatSpawner := preload("res://systems/b_threat_spawner.gd")
const PredatorSpawner := preload("res://systems/b_predator_spawner.gd")
const TurtleSpawner := preload("res://systems/b_turtle_spawner.gd")
const AudioSystem := preload("res://systems/b_audio.gd")
const Juice := preload("res://core/juice.gd")
const MainMenuScreen := preload("res://ui/b_main_menu.gd")


func _ready() -> void:
	var commander := FishCommander.new()
	commander.name = "FishCommander"
	add_child(commander)
	_setup_population_and_hud(commander)

	# B3: threats announced at the map edge (GDD §7).
	var threat_spawner := ThreatSpawner.new()
	threat_spawner.name = "ThreatSpawner"
	add_child(threat_spawner)

	# Carnivorous predator (issue #3), behind the predator_enabled feature flag.
	var predator_spawner := PredatorSpawner.new()
	predator_spawner.name = "PredatorSpawner"
	add_child(predator_spawner)

	# Sea turtle helper (issue #4), behind the turtle_enabled feature flag.
	var turtle_spawner := TurtleSpawner.new()
	turtle_spawner.name = "TurtleSpawner"
	add_child(turtle_spawner)

	# P4: sound effects for gameplay events.
	_setup_audio()
	# Juice: particles, placement ripples and camera shake.
	_setup_juice()


## B2: population monitor, HUD, pause and game over (GDD §3, §9).
## Game.ui is not in the tree yet when this runs (Main adds it last); adding
## children to it is fine, they enter the tree together with it.
func _setup_population_and_hud(commander: FishCommander) -> void:
	var monitor := PopulationMonitor.new()
	monitor.name = "PopulationMonitor"
	add_child(monitor)

	var hud := Hud.new()
	hud.name = "Hud"
	hud.bind(monitor)
	Game.ui.add_child(hud)

	var game_over := GameOverScreen.new()
	game_over.name = "GameOver"
	Game.ui.add_child(game_over)
	monitor.game_over.connect(game_over.show_result)

	# Title screen: shown at game start, pauses the run until Play is pressed.
	# MainMenuScreen opens itself from its own _ready once it is in the tree.
	var main_menu := MainMenuScreen.new()
	main_menu.name = "MainMenu"
	main_menu.play_pressed.connect(_on_play_pressed)
	main_menu.exit_pressed.connect(_on_exit_pressed)
	Game.ui.add_child(main_menu)

	var pause := PauseController.new()
	pause.name = "PauseController"
	pause.monitor = monitor
	pause.commander = commander
	add_child(pause)


## Play pressed on the title screen: swap the intro for the run's music.
func _on_play_pressed() -> void:
	var music := get_tree().get_first_node_in_group(Groups.MUSIC)
	if music != null and music.has_method(&"start_game_music"):
		music.start_game_music()


## Exit pressed on the title screen: close the game (hidden in web builds).
func _on_exit_pressed() -> void:
	get_tree().quit()


## P4: sound effects (GDD §9). Hooks Dev A's placement and inventory, read from
## the sibling DevASystems node Main adds before this one (see Main._ready).
func _setup_audio() -> void:
	var audio := AudioSystem.new()
	audio.name = "Audio"
	var dev_a := get_parent().get_node_or_null("DevASystems")
	if dev_a != null:
		audio.inventory = dev_a.get("inventory") as InventorySystem
		audio.placement = dev_a.get("placement") as PlacementController
	audio.monitor = get_node("PopulationMonitor") as PopulationMonitor
	add_child(audio)


## Particles, placement ripples and camera shake (core/juice.gd). Lives in the
## screen-space View so it uses the same projection as the entity visuals.
func _setup_juice() -> void:
	var juice := Juice.new()
	juice.name = "Juice"
	var dev_a := get_parent().get_node_or_null("DevASystems")
	if dev_a != null:
		juice.placement = dev_a.get("placement") as PlacementController
	Game.view.add_child(juice)
