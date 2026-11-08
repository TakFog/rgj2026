class_name MusicSystem
extends Node
## Loop-based music built from stems (GDD §9). The title screen loops the intro
## track; pressing Play starts every stem, which loop in sync. The
## arrangement switches by fading volumes:
## - the two drum takes alternate at every loop boundary;
## - the arp stays silent with no hostiles, plays the half take with 1..N-1
##   hostiles and the full take from N on, picking one of its takes at random
##   every loop.
## Stems configured in data/audio_settings.tres; see docs/audio.md.

## Below this many hostiles the arp stays silent.
const ARP_HALF_MIN := 1
## Hostiles change slowly; 4 scans per second are plenty for the arp mix and
## avoid a scene-tree group query on every frame.
const HOSTILE_REFRESH_SECONDS := 0.25
## The Music bus feeds this bus, which carries the pause low-pass filter.
const PAUSE_BUS := &"PauseFilter"
## Above human hearing: the pause filter is effectively off at this cutoff.
const FILTER_OPEN_HZ := 20500.0

var _drums: Array[AudioStreamPlayer] = []
var _half: Array[AudioStreamPlayer] = []
var _full: Array[AudioStreamPlayer] = []
var _fallback: AudioStreamPlayer
var _intro: AudioStreamPlayer
var _started := false
var _gains := {} # AudioStreamPlayer -> linear gain 0..1
var _clock: AudioStreamPlayer
var _last_pos := -1.0
var _drum_index := 0
var _half_pick := 0
var _full_pick := 0
var _rng := RandomNumberGenerator.new()
var _hostile_elapsed := HOSTILE_REFRESH_SECONDS
var _hostile_count := 0
var _pause_filter: AudioEffectLowPassFilter
var _pause_cutoff := FILTER_OPEN_HZ
var _paused := false
## Web: browsers keep audio suspended until the first user gesture, so the intro
## is restarted then. Static, so a scene reload does not restart it again.
static var _web_gesture_seen := false


## 0 = no arp, 1 = half, 2 = full. `full_at` is the hostile count for full.
static func arp_level(hostiles: int, full_at: int) -> int:
	if hostiles >= full_at:
		return 2
	return 1 if hostiles >= ARP_HALF_MIN else 0


func _ready() -> void:
	_rng.randomize()
	_setup_pause_filter()
	_drums = _make_players(Game.AUDIO_SETTINGS.drums)
	_half = _make_players(Game.AUDIO_SETTINGS.arp_half)
	_full = _make_players(Game.AUDIO_SETTINGS.arp_full)
	# The title screen plays the intro; Play starts the run's loop. Without an
	# intro the loop starts right away (the old behaviour).
	if Game.AUDIO_SETTINGS.intro_track != null:
		_start_intro()
	else:
		start_game_music()
	set_process_input(OS.has_feature("web") and not _web_gesture_seen)


## Web only: the first click, key or touch unlocks the browser's audio, so the
## intro starts over from there if the title screen is still up.
func _input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton or event is InputEventKey or event is InputEventScreenTouch):
		return
	if not event.is_pressed():
		return
	_web_gesture_seen = true
	set_process_input(false)
	if not _started and _intro != null:
		_intro.play()


## The title screen is over: stop the intro (if any) and start the loop.
func start_game_music() -> void:
	if _started:
		return
	_started = true
	if _intro != null:
		_intro.stop()
	_start_stems()


## Muffles the music while the pause menu is open. Driven by PauseController's
## signal, not get_tree().paused, so the game-over outro stays clear.
func set_paused(value: bool) -> void:
	_paused = value


## Stops everything for good: the outro takes over when the run is lost.
func stop_music() -> void:
	if _intro != null:
		_intro.stop()
	for player: AudioStreamPlayer in _all_players():
		player.stop()


## Loops the intro track while the title screen is up.
func _start_intro() -> void:
	_intro = AudioStreamPlayer.new()
	_intro.name = "Intro"
	_intro.stream = Game.AUDIO_SETTINGS.intro_track
	_intro.bus = Game.AUDIO_SETTINGS.music_bus()
	_intro.volume_db = Game.AUDIO_SETTINGS.intro_gain_db
	_intro.pitch_scale = Game.AUDIO_SETTINGS.music_pitch
	add_child(_intro)
	_intro.play()


## Starts every stem at once (or the fallback track when there are none).
func _start_stems() -> void:
	if _drums.is_empty() and _half.is_empty() and _full.is_empty():
		_start_fallback()
		return
	for player: AudioStreamPlayer in _all_players():
		player.play()
	_clock = _drums[0] if not _drums.is_empty() else _all_players()[0]


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
	if _fallback != null or Game.AUDIO_SETTINGS.music_track == null:
		return
	_fallback = _make_players([Game.AUDIO_SETTINGS.music_track])[0]
	_fallback.volume_db = Game.AUDIO_SETTINGS.music_gain_db
	_fallback.play()


func _process(delta: float) -> void:
	_update_pause_filter(delta)
	if not _started:
		return
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
	_hostile_elapsed += delta
	if _hostile_elapsed >= HOSTILE_REFRESH_SECONDS:
		_hostile_elapsed = 0.0
		_hostile_count = get_tree().get_nodes_in_group(Groups.THREATS).size()
	var level := arp_level(_hostile_count, settings.arp_full_hostiles)
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
	var volume_db := AudioSettings.SILENCE_DB
	if gain > 0.0:
		volume_db = Game.AUDIO_SETTINGS.music_gain_db + group_db + linear_to_db(gain)
	# Fades are settled most of the time: skip the redundant audio server write.
	if not is_equal_approx(player.volume_db, volume_db):
		player.volume_db = volume_db


## Cutoff the music eases toward: the pause cutoff while paused (unless the
## effect is disabled), otherwise fully open.
static func pause_cutoff(p_paused: bool, pause_hz: float) -> float:
	if p_paused and pause_hz > 0.0:
		return minf(pause_hz, FILTER_OPEN_HZ)
	return FILTER_OPEN_HZ


## Routes the Music bus through a dedicated filtered bus. The bus and its filter
## are created once and reused across scene reloads, so restarts do not stack
## effects on the audio server.
func _setup_pause_filter() -> void:
	var bus_name := AudioSettings.ensure_bus(PAUSE_BUS, 0.0, 0.0)
	var music_index := AudioServer.get_bus_index(Game.AUDIO_SETTINGS.music_bus())
	if music_index != -1:
		AudioServer.set_bus_send(music_index, bus_name)
	var index := AudioServer.get_bus_index(bus_name)
	if index == -1:
		return
	if AudioServer.get_bus_effect_count(index) > 0:
		_pause_filter = AudioServer.get_bus_effect(index, 0) as AudioEffectLowPassFilter
	if _pause_filter == null:
		_pause_filter = AudioEffectLowPassFilter.new()
		AudioServer.add_bus_effect(index, _pause_filter)
	_pause_cutoff = FILTER_OPEN_HZ
	_pause_filter.cutoff_hz = _pause_cutoff


## Eases the pause filter cutoff toward its target while the tree is paused.
func _update_pause_filter(delta: float) -> void:
	if _pause_filter == null:
		return
	var settings := Game.AUDIO_SETTINGS
	var target := pause_cutoff(_paused, settings.pause_music_low_pass_hz)
	if settings.pause_filter_fade_seconds <= 0.0:
		_pause_cutoff = target
	else:
		var span := maxf(FILTER_OPEN_HZ - minf(settings.pause_music_low_pass_hz, FILTER_OPEN_HZ), 1.0)
		_pause_cutoff = move_toward(_pause_cutoff, target, span / settings.pause_filter_fade_seconds * delta)
	_pause_filter.cutoff_hz = _pause_cutoff


func _all_players() -> Array[AudioStreamPlayer]:
	var players: Array[AudioStreamPlayer] = []
	players.append_array(_drums)
	players.append_array(_half)
	players.append_array(_full)
	if _fallback != null:
		players.append(_fallback)
	return players
