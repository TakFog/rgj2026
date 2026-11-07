extends Node
## Plays sound effects for gameplay events (GDD §9). Missing files are silent,
## and events with several takes pick one at random.
## Events and their takes: AudioEvents.TAKES (core/audio_events.gd).
## Level, pitch and filters come from Game.AUDIO_SETTINGS (data/audio_settings.tres).
## Every event needs an entry there too (see docs/audio.md).

const VOICES := 6

## Dev A's systems (set by DevBSystems before this node enters the tree).
## When null, the matching event stays silent.
var inventory: InventorySystem
var placement: PlacementController
## Tells us when the run is lost (set by DevBSystems).
var monitor: PopulationMonitor

var _streams := {} # StringName -> Array[AudioStream]
var _players: Array[AudioStreamPlayer] = []
var _outro: AudioStreamPlayer
var _wind: AudioStreamPlayer
## Linear fade of the cyclone wind: 0 = silent, 1 = at its normal level.
var _wind_gain := 0.0
var _wind_target := 0.0
## Cyclones currently on screen, by instance id.
var _cyclones_in_view := {}
var _next := 0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	for event: StringName in AudioEvents.TAKES:
		var takes: Array[AudioStream] = []
		for path: String in AudioEvents.TAKES[event]:
			if ResourceLoader.exists(path):
				takes.append(load(path))
		if not takes.is_empty():
			_streams[event] = takes
	for name: StringName in _streams:
		Game.AUDIO_SETTINGS.event_bus(name) # Create the filter buses up front.
	# Apply the player's saved Music/Effects levels now that the buses exist.
	UserSettings.load_and_apply()
	for i in VOICES:
		var player := AudioStreamPlayer.new()
		# UI feedback must be audible on the title screen and pause menu, when
		# the tree is paused; gameplay takes simply finish if a pause starts.
		player.process_mode = Node.PROCESS_MODE_ALWAYS
		add_child(player)
		_players.append(player)

	_outro = AudioStreamPlayer.new()
	_outro.name = "Outro"
	_outro.bus = Game.AUDIO_SETTINGS.music_bus()
	_outro.volume_db = Game.AUDIO_SETTINGS.outro_gain_db
	_outro.pitch_scale = Game.AUDIO_SETTINGS.music_pitch
	# The game over screen pauses the tree right after this signal.
	_outro.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_outro)
	if monitor != null:
		monitor.game_over.connect(_on_game_over)
		monitor.countdown_started.connect(func(_population: StringName) -> void: play(&"collapse_warning"))
		monitor.countdown_cancelled.connect(func(_population: StringName) -> void: play(&"collapse_cancelled"))

	_wind = AudioStreamPlayer.new()
	_wind.name = "CycloneWind"
	_wind.stream = _first_take(&"cyclone_wind")
	_wind.bus = Game.AUDIO_SETTINGS.event_bus(&"cyclone_wind")
	_wind.volume_db = AudioSettings.SILENCE_DB
	_wind.pitch_scale = Game.AUDIO_SETTINGS.event(&"cyclone_wind").pitch
	add_child(_wind)
	if placement != null:
		placement.placement_started.connect(func() -> void: play(&"item_hover"))
		placement.placement_finished.connect(_on_placement_finished)
		placement.placement_cancelled.connect(func() -> void: play(&"ui_cancel"))
		placement.placement_failed.connect(func() -> void: play(&"ui_denied"))
	if inventory != null:
		inventory.model.item_available.connect(func(_index: int) -> void: play(&"item_available"))
	_connect_ui()
	_connect_commander()
	# Entities spawned during the run plus the level's starting ones.
	for group: StringName in [Groups.FISH, Groups.NESTS, Groups.CORALS, Groups.ALGAE]:
		for node in get_tree().get_nodes_in_group(group):
			_on_entity_added(node)
	Game.world.child_entered_tree.connect(_on_entity_added)


func _process(delta: float) -> void:
	_fade_wind(delta)


## The wind fades in while a cyclone is on screen and out once it leaves.
func _fade_wind(delta: float) -> void:
	if _wind == null or _wind.stream == null:
		return
	var seconds := Game.AUDIO_SETTINGS.cyclone_wind_fade_seconds
	_wind_gain = _wind_target if seconds <= 0.0 else move_toward(_wind_gain, _wind_target, delta / seconds)
	if _wind_gain <= 0.0:
		if _wind.playing:
			_wind.stop()
		_wind.volume_db = AudioSettings.SILENCE_DB
	else:
		_wind.volume_db = Game.AUDIO_SETTINGS.effect_gain_db(&"cyclone_wind") + linear_to_db(_wind_gain)


## Plays a random take of `event` on the next voice in the ring.
func play(name: StringName) -> void:
	if not _streams.has(name):
		return
	var gain_db := Game.AUDIO_SETTINGS.effect_gain_db(name)
	if gain_db <= AudioSettings.SILENCE_DB:
		return
	var takes: Array[AudioStream] = _streams[name]
	var player := _players[_next]
	_next = (_next + 1) % _players.size()
	player.stream = takes[_rng.randi_range(0, takes.size() - 1)]
	player.bus = Game.AUDIO_SETTINGS.event_bus(name)
	player.volume_db = gain_db
	player.pitch_scale = Game.AUDIO_SETTINGS.event(name).random_pitch(_rng)
	player.play()


## Losing the run: the loop stops and the outro track plays once (GDD §3).
func _on_game_over(_population: StringName, _score_seconds: float) -> void:
	var music := get_tree().get_first_node_in_group(Groups.MUSIC)
	if music != null and music.has_method(&"stop_music"):
		music.stop_music()
	if Game.AUDIO_SETTINGS.outro_track == null:
		return
	_outro.stream = Game.AUDIO_SETTINGS.outro_track
	_outro.play()


## Placing an item: its own sound when it has one (e.g. a nest), else the generic.
func _on_placement_finished(kind: StringName) -> void:
	play(AudioEvents.placement_event(kind))


## Menu buttons, the pause key and the game-over restart button.
func _connect_ui() -> void:
	var menu := Game.ui.get_node_or_null("MainMenu") as MainMenuScreen
	if menu != null:
		menu.button_pressed.connect(func() -> void: play(&"ui_click"))
	var tutorial := Game.ui.get_node_or_null("Tutorial") as TutorialScreen
	if tutorial != null:
		tutorial.button_pressed.connect(func() -> void: play(&"ui_click"))
	var game_over := Game.ui.get_node_or_null("GameOver") as GameOverScreen
	if game_over != null:
		game_over.restart_pressed.connect(func() -> void: play(&"ui_click"))
	var pause := get_parent().get_node_or_null("PauseController") as PauseController
	if pause != null:
		pause.pause_toggled.connect(func(_paused: bool) -> void: play(&"ui_click"))
		pause.button_pressed.connect(func() -> void: play(&"ui_click"))


## Selecting a fish, sending it somewhere and clearing the selection.
func _connect_commander() -> void:
	var commander := get_parent().get_node_or_null("FishCommander") as FishCommander
	if commander == null:
		return
	commander.fish_selected.connect(func() -> void: play(&"fish_select"))
	commander.fish_ordered.connect(func() -> void: play(&"fish_order"))
	commander.selection_cleared.connect(func() -> void: play(&"ui_cancel"))


## Hooks the audio of one entity. Called for starting entities in _ready and for
## every node spawned into Game.world afterwards.
func _on_entity_added(node: Node) -> void:
	if node is PlasticBag:
		var bag := node as PlasticBag
		_play_when_in_play(bag.destroyed, &"bag_destroyed")
		_play_when_in_view(bag, &"bag_arrive")
		bag.impacted.connect(func(_victim: Node2D) -> void: play(&"threat_impact"))
	elif node is Co2Cloud:
		var co2 := node as Co2Cloud
		_play_when_in_play(co2.destroyed, &"co2_gone")
		_play_when_in_view(co2, &"co2_arrive")
		co2.impacted.connect(func(_victim: Node2D) -> void: play(&"threat_impact"))
	elif node is Predator:
		var predator := node as Predator
		predator.ate.connect(func() -> void: play(&"predator_ate"))
		predator.left.connect(func() -> void: play(&"predator_leave"))
		play(&"predator_arrive")
	elif node is Turtle:
		var turtle := node as Turtle
		turtle.ate_algae.connect(func() -> void: play(&"turtle_eat"))
		turtle.rammed.connect(func() -> void: play(&"turtle_ram"))
		play(&"turtle_arrive")
	elif node is Cyclone:
		_on_cyclone_added(node as Cyclone)
	elif node is Fish:
		var fish := node as Fish
		fish.ate_algae.connect(func() -> void: play(&"fish_eat"))
		fish.matured.connect(func() -> void: play(&"fish_matured"))
		fish.starved.connect(func() -> void: play(&"fish_died"))
	elif node is Nest:
		var nest := node as Nest
		nest.fertilized.connect(func() -> void: play(&"eggs_laid"))
		nest.eggs_hatched.connect(func(_count: int) -> void: play(&"eggs_hatched"))
		nest.eggs_died.connect(func() -> void: play(&"eggs_died"))
	elif node is Coral:
		var coral := node as Coral
		coral.damaged.connect(func() -> void: play(&"coral_hit"))
		coral.destroyed.connect(func() -> void: play(&"coral_destroyed"))
	elif node is Algae:
		(node as Algae).spread.connect(func() -> void: play(&"algae_spread"))


## A threat entering the visible seabed for the first time.
func _play_when_in_view(threat: Threat, event: StringName) -> void:
	var played := false
	threat.view_changed.connect(func(in_view: bool) -> void:
		if in_view and not played:
			played = true
			play(event))


## A cyclone has its own wind loop while it is on screen and a very quiet hit
## each time it destroys something (GDD §7.3).
func _on_cyclone_added(cyclone: Cyclone) -> void:
	var id := cyclone.get_instance_id()
	cyclone.view_changed.connect(func(in_view: bool) -> void: _set_cyclone_in_view(id, in_view))
	cyclone.destroyed.connect(func(_end: int) -> void: _set_cyclone_in_view(id, false))
	cyclone.hit.connect(func(_victim: Node2D) -> void: play(&"cyclone_hit"))


## The wind plays while at least one cyclone is on screen.
func _set_cyclone_in_view(id: int, in_view: bool) -> void:
	if in_view:
		_cyclones_in_view[id] = true
	else:
		_cyclones_in_view.erase(id)
	_wind_target = 0.0 if _cyclones_in_view.is_empty() else 1.0
	if _wind_target > 0.0 and not _wind.playing and _wind.stream != null:
		_wind.play()


## First loaded take of `name`, or null.
func _first_take(name: StringName) -> AudioStream:
	if not _streams.has(name):
		return null
	var takes: Array[AudioStream] = _streams[name]
	return takes[0] if not takes.is_empty() else null


## A threat drifting out of the visible seabed makes no sound; only the ones
## that end in play (on screen) do.
func _play_when_in_play(destroyed: Signal, event: StringName) -> void:
	destroyed.connect(func(end: int) -> void:
		if end == Threat.End.IN_PLAY:
			play(event))
