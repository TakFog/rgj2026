class_name MusicSystem
extends Node
## Loop-based music built from stems (GDD §9). Every stem plays from the start
## and loops in sync; the arrangement switches by fading volumes:
## - the two drum takes alternate at every loop boundary;
## - the arp stays silent with no hostiles, plays the half take with 1..N-1
##   hostiles and the full take from N on, picking one of its takes at random
##   every loop.
## Stems configured in data/audio_settings.tres; see docs/audio.md.

## Below this many hostiles the arp stays silent.
const ARP_HALF_MIN := 1

var _drums: Array[AudioStreamPlayer] = []
var _half: Array[AudioStreamPlayer] = []
var _full: Array[AudioStreamPlayer] = []
var _fallback: AudioStreamPlayer
var _gains := {} # AudioStreamPlayer -> linear gain 0..1
var _clock: AudioStreamPlayer
var _last_pos := -1.0
var _drum_index := 0
var _half_pick := 0
var _full_pick := 0
var _rng := RandomNumberGenerator.new()


## 0 = no arp, 1 = half, 2 = full. `full_at` is the hostile count for full.
static func arp_level(hostiles: int, full_at: int) -> int:
	if hostiles >= full_at:
		return 2
	return 1 if hostiles >= ARP_HALF_MIN else 0


func _ready() -> void:
	_rng.randomize()
	_drums = _make_players(Game.AUDIO_SETTINGS.drums)
	_half = _make_players(Game.AUDIO_SETTINGS.arp_half)
	_full = _make_players(Game.AUDIO_SETTINGS.arp_full)
	if _drums.is_empty() and _half.is_empty() and _full.is_empty():
		_start_fallback()
		return
	for player: AudioStreamPlayer in _all_players():
		player.play()
	_clock = _drums[0] if not _drums.is_empty() else _all_players()[0]


## Stops everything for good: the outro takes over when the run is lost.
func stop_music() -> void:
	for player: AudioStreamPlayer in _all_players():
		player.stop()


## Keeps every stem player silent at the start; the mix raises the ones in use.
func _make_players(streams: Array[AudioStream]) -> Array[AudioStreamPlayer]:
	var players: Array[AudioStreamPlayer] = []
	for stream: AudioStream in streams:
		if stream == null:
			continue
		var player := AudioStreamPlayer.new()
		player.stream = stream
		player.bus = Game.AUDIO_SETTINGS.music_bus()
		player.volume_db = AudioSettings.SILENCE_DB
		# Same pitch (and speed) on every stem keeps the loop aligned.
		player.pitch_scale = Game.AUDIO_SETTINGS.music_pitch
		add_child(player)
		_gains[player] = 0.0
		players.append(player)
	return players


## No stems assigned: fall back to the single looping track.
func _start_fallback() -> void:
	if Game.AUDIO_SETTINGS.music_track == null:
		return
	_fallback = _make_players([Game.AUDIO_SETTINGS.music_track])[0]
	_fallback.volume_db = Game.AUDIO_SETTINGS.music_gain_db
	_fallback.play()


func _process(delta: float) -> void:
	if _clock != null and _clock.playing:
		var pos := _clock.get_playback_position()
		if pos < _last_pos - 0.01:
			_on_loop_boundary()
		_last_pos = pos
	_mix(delta)


## New loop: swap the drum take, roll new arp variants.
func _on_loop_boundary() -> void:
	if _drums.size() > 1:
		_drum_index = (_drum_index + 1) % _drums.size()
	_half_pick = _rng.randi_range(0, maxi(_half.size() - 1, 0))
	_full_pick = _rng.randi_range(0, maxi(_full.size() - 1, 0))


## Fades every stem toward its target volume for the current state.
func _mix(delta: float) -> void:
	var settings := Game.AUDIO_SETTINGS
	var level := arp_level(get_tree().get_nodes_in_group(Groups.THREATS).size(), settings.arp_full_hostiles)
	for i in _drums.size():
		_fade(_drums[i], 1.0 if i == _drum_index else 0.0, delta, settings.drum_fade_seconds)
		_apply(_drums[i], settings.drums_gain_db)
	for i in _half.size():
		_fade(_half[i], 1.0 if level == 1 and i == _half_pick else 0.0, delta, settings.music_fade_seconds)
		_apply(_half[i], settings.arp_gain_db)
	for i in _full.size():
		_fade(_full[i], 1.0 if level == 2 and i == _full_pick else 0.0, delta, settings.music_fade_seconds)
		_apply(_full[i], settings.arp_gain_db)


func _fade(player: AudioStreamPlayer, target: float, delta: float, seconds: float) -> void:
	if seconds <= 0.0:
		_gains[player] = target
	else:
		_gains[player] = move_toward(_gains[player], target, delta / seconds)


## Volume of `player` = global music level + its stem group level + fade gain.
func _apply(player: AudioStreamPlayer, group_db: float) -> void:
	var gain: float = _gains[player]
	if gain <= 0.0:
		player.volume_db = AudioSettings.SILENCE_DB
	else:
		player.volume_db = Game.AUDIO_SETTINGS.music_gain_db + group_db + linear_to_db(gain)


func _all_players() -> Array[AudioStreamPlayer]:
	var players: Array[AudioStreamPlayer] = []
	players.append_array(_drums)
	players.append_array(_half)
	players.append_array(_full)
	if _fallback != null:
		players.append(_fallback)
	return players
