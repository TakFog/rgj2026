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
	for i in VOICES:
		var player := AudioStreamPlayer.new()
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
	if placement != null:
		placement.placement_finished.connect(_on_placement_finished)
	if inventory != null:
		inventory.model.item_available.connect(func(_index: int) -> void: play(&"item_available"))
	# Entities spawned during the run (the level's starting ones are already in).
	Game.world.child_entered_tree.connect(_on_entity_added)


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
	var music := get_tree().get_first_node_in_group(Groups.MUSIC) as AudioStreamPlayer
	if music != null:
		music.stop()
	if Game.AUDIO_SETTINGS.outro_track == null:
		return
	_outro.stream = Game.AUDIO_SETTINGS.outro_track
	_outro.play()


## Placing an item: its own sound when it has one (e.g. a nest), else the generic.
func _on_placement_finished(kind: StringName) -> void:
	play(AudioEvents.placement_event(kind))


## Threats vanish (bags, CO2) and predators bite (GDD §7.1, §7.2, §7.4).
func _on_entity_added(node: Node) -> void:
	if node is PlasticBag:
		(node as PlasticBag).destroyed.connect(func(_end: int) -> void: play(&"bag_destroyed"))
	elif node is Co2Cloud:
		# Only when it dissipates on screen, not when it drifts off it.
		(node as Co2Cloud).destroyed.connect(func(end: int) -> void:
			if end == Threat.End.IN_PLAY:
				play(&"co2_gone"))
	elif node is Predator:
		(node as Predator).ate.connect(func() -> void: play(&"predator_ate"))
