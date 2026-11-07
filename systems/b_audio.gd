extends Node
## Plays sound effects for gameplay events (GDD §9). Missing files are silent,
## and events with several takes pick one at random.
## Files: res://assets/audio/<folder>/<take>.wav (see EVENTS).
## Level, pitch and filters come from Game.AUDIO_SETTINGS (data/audio_settings.tres).
## Every event added here needs an entry there too (see docs/audio.md).

const EVENTS := {
	&"placement": [
		"res://assets/audio/corallo/c0.wav",
		"res://assets/audio/corallo/c1.wav",
		"res://assets/audio/corallo/c2.wav",
		"res://assets/audio/corallo/c3.wav",
	],
	&"item_available": [
		"res://assets/audio/item/i0.wav",
		"res://assets/audio/item/i1.wav",
		"res://assets/audio/item/i2.wav",
	],
	&"bag_destroyed": [
		"res://assets/audio/busta/b0.wav",
	],
}
const VOICES := 6

## Dev A's systems (set by DevBSystems before this node enters the tree).
## When null, the matching event stays silent.
var inventory: InventorySystem
var placement: PlacementController

var _streams := {} # StringName -> Array[AudioStream]
var _players: Array[AudioStreamPlayer] = []
var _next := 0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	for event: StringName in EVENTS:
		var takes: Array[AudioStream] = []
		for path: String in EVENTS[event]:
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
	if placement != null:
		placement.placement_finished.connect(func() -> void: play(&"placement"))
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


## A plastic bag popping plays its own sound (GDD §7.2).
func _on_entity_added(node: Node) -> void:
	if node is PlasticBag:
		(node as PlasticBag).destroyed.connect(func() -> void: play(&"bag_destroyed"))
