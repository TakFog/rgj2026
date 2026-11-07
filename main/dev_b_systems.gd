extends Node
## Dev B's systems and UI are added here (fish commander, population monitor,
## threat spawner, HUD...). Only Dev B edits this file.

const ThreatSpawner := preload("res://systems/b_threat_spawner.gd")
const PredatorSpawner := preload("res://systems/b_predator_spawner.gd")
const TurtleSpawner := preload("res://systems/b_turtle_spawner.gd")
const AudioSystem := preload("res://systems/b_audio.gd")

var _main_menu: MainMenuScreen
var _tutorial: TutorialScreen


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

	# Touch builds only: on-screen Pausa/Annulla buttons. Added before the
	# overlays (game over, menu, tutorial, pause) so those cover it.
	var touch_controls: TouchControls = null
	if Platform.is_touch():
		touch_controls = TouchControls.new()
		touch_controls.name = "TouchControls"
		touch_controls.commander = commander
		touch_controls.add_to_group(Groups.GAMEPLAY_HUD)
		Game.ui.add_child(touch_controls)

	var game_over := GameOverScreen.new()
	game_over.name = "GameOver"
	Game.ui.add_child(game_over)
	monitor.game_over.connect(func(population: StringName, seconds: float) -> void:
		game_over.show_result(population, seconds, monitor.counts))

	# Title screen: shown at game start, pauses the run until Play is pressed.
	# MainMenuScreen opens itself from its own _ready once it is in the tree.
	_main_menu = MainMenuScreen.new()
	_main_menu.name = "MainMenu"
	_main_menu.play_requested.connect(_on_play_requested)
	_main_menu.tutorial_requested.connect(_on_tutorial_requested)
	_main_menu.play_pressed.connect(_on_run_started)
	_main_menu.exit_pressed.connect(_on_exit_pressed)
	Game.ui.add_child(_main_menu)

	# Tutorial between Play and the run; shown only on the first run, but
	# always reachable from the menu ("Come si gioca").
	_tutorial = TutorialScreen.new()
	_tutorial.name = "Tutorial"
	_tutorial.run_started.connect(_on_tutorial_run_started)
	_tutorial.closed.connect(_on_tutorial_closed)
	Game.ui.add_child(_tutorial)

	var pause := PauseController.new()
	pause.name = "PauseController"
	pause.monitor = monitor
	pause.commander = commander
	# Game over pauses the tree directly (not through this controller), so its
	# outro stays clear while a player pause muffles the music.
	var music := get_tree().get_first_node_in_group(Groups.MUSIC) as MusicSystem
	if music != null:
		pause.pause_toggled.connect(music.set_paused)
	add_child(pause)
	if touch_controls != null:
		touch_controls.pause = pause


## Play pressed on the title screen: the tutorial comes first on the first run.
func _on_play_requested() -> void:
	if UserSettings.tutorial_seen():
		_main_menu.close()
		_start_game_music()
	else:
		_main_menu.hide_for_tutorial()
		_tutorial.open(TutorialScreen.Mode.START)


## "Come si gioca" on the title screen: review the tutorial without starting.
func _on_tutorial_requested() -> void:
	_main_menu.hide_for_tutorial()
	_tutorial.open(TutorialScreen.Mode.REVIEW)


## The tutorial starts the run (Inizia or Salta).
func _on_tutorial_run_started() -> void:
	UserSettings.mark_tutorial_seen()
	_tutorial.close()
	_main_menu.close()
	_start_game_music()


## "Indietro" in the tutorial: back to the still-paused title screen.
func _on_tutorial_closed() -> void:
	_tutorial.close()
	_main_menu.open()


## The run starts directly (restart path: no tutorial).
func _on_run_started() -> void:
	_start_game_music()


## Swaps the intro for the run's music.
func _start_game_music() -> void:
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
