extends Node
## Dev B's systems and UI are added here (fish commander, population monitor,
## threat spawner, HUD...). Only Dev B edits this file.

const ThreatSpawner := preload("res://systems/b_threat_spawner.gd")
const PredatorSpawner := preload("res://systems/b_predator_spawner.gd")
const TurtleSpawner := preload("res://systems/b_turtle_spawner.gd")
const AudioSystem := preload("res://systems/b_audio.gd")

var _main_menu: MainMenuScreen
var _tutorial: TutorialScreen
var _level_select: LevelSelectScreen
var _level_clear: LevelClearScreen
var _level_director: LevelDirector


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

	# Campaign levels run on a countdown and clear when it ends (GDD §3). The
	# sandbox is the old endless run, so it has no director and no clear card;
	# the HUD then keeps its elapsed-survival-time meaning.
	if not LevelSession.is_sandbox():
		_level_director = LevelDirector.new()
		_level_director.name = "LevelDirector"
		_level_director.monitor = monitor
		add_child(_level_director)

	var hud := Hud.new()
	hud.name = "Hud"
	hud.bind(monitor)
	if _level_director != null:
		hud.bind_level(_level_director)
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
		if LevelSession.is_sandbox():
			# Old run: no level label and the global survival record.
			game_over.show_result(population, seconds, monitor.counts)
		else:
			var level := LevelSession.current()
			game_over.show_result(population, seconds, monitor.counts,
				LevelSession.current_index, level.level_name))
	game_over.menu_pressed.connect(_on_back_to_menu_requested)

	# Shown when the level timer runs out with the reef alive.
	if _level_director != null:
		_level_clear = LevelClearScreen.new()
		_level_clear.name = "LevelClear"
		Game.ui.add_child(_level_clear)
		_level_director.level_cleared.connect(func(index: int, level: LevelDefinition) -> void:
			_level_clear.show_result(index, level, monitor.counts, _level_director.elapsed()))
		_level_clear.next_requested.connect(_on_next_level_requested)
		_level_clear.restart_requested.connect(_on_retry_level_requested)
		_level_clear.menu_requested.connect(_on_back_to_menu_requested)

	# Level chooser opened by Gioca (campaign levels plus the Sandbox).
	_level_select = LevelSelectScreen.new()
	_level_select.name = "LevelSelect"
	_level_select.level_chosen.connect(_on_level_chosen)
	_level_select.closed.connect(_on_level_select_closed)
	Game.ui.add_child(_level_select)

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


## Play pressed on the title screen: the tutorial comes first on the first run,
## then the level chooser. The run stays paused until a level is chosen.
func _on_play_requested() -> void:
	_main_menu.hide_for_tutorial()
	if UserSettings.tutorial_seen():
		_level_select.open()
	else:
		_tutorial.open(TutorialScreen.Mode.START)


## "Come si gioca" on the title screen: review the tutorial without starting.
func _on_tutorial_requested() -> void:
	_main_menu.hide_for_tutorial()
	_tutorial.open(TutorialScreen.Mode.REVIEW)


## The tutorial is done (Inizia or Salta): now the player picks a level.
func _on_tutorial_run_started() -> void:
	UserSettings.mark_tutorial_seen()
	_tutorial.close()
	_main_menu.hide_for_tutorial()
	_level_select.open()


## "Indietro" in the tutorial: back to the still-paused title screen.
func _on_tutorial_closed() -> void:
	_tutorial.close()
	_main_menu.open()


## The run starts directly (restart path: no tutorial, no level chooser).
func _on_run_started() -> void:
	_start_game_music()


## A level (or the Sandbox) card was pressed. The loaded mode can start at
## once; another one needs a scene rebuild so Main populates the new reef and
## the systems pick up its mechanics.
func _on_level_chosen(index: int) -> void:
	var changed := false
	if index == LevelSession.SANDBOX_INDEX:
		changed = LevelSession.select_sandbox()
	else:
		changed = LevelSession.select(index)
	if changed:
		MainMenuScreen.restart_run(get_tree())
	else:
		_level_select.close()
		get_tree().paused = false
		_start_game_music()


## Indietro/Esc in the chooser: back to the still-paused title screen.
func _on_level_select_closed() -> void:
	_level_select.close()
	_main_menu.open()


## Clear screen: load the next level.
func _on_next_level_requested() -> void:
	if LevelSession.select(LevelSession.current_index + 1):
		MainMenuScreen.restart_run(get_tree())


## Clear/game-over card: retry the same level from a fresh scene.
func _on_retry_level_requested() -> void:
	MainMenuScreen.restart_run(get_tree())


## Back to the title screen (and the level chooser) from a result card.
func _on_back_to_menu_requested() -> void:
	MainMenuScreen.restart_to_menu(get_tree())


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
