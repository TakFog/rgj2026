extends TestCase

var settings: AudioSettings


func before_each() -> void:
	settings = AudioSettings.new()


func test_defaults_boost_the_quiet_effect_takes() -> void:
	assert_almost(settings.music_gain_db, 0.0)
	assert_almost(settings.effects_gain_db, 8.0)
	assert_almost(settings.effect_gain_db(&"placement"), 8.0)


func test_every_shipped_event_is_configured() -> void:
	var script: GDScript = load("res://systems/b_audio.gd")
	var events: Dictionary = script.get_script_constant_map()["EVENTS"]
	var shipped: AudioSettings = load("res://data/audio_settings.tres")
	assert_false(events.is_empty())
	for name: StringName in events:
		assert_true(settings.events.has(name), "missing default config for %s" % name)
		assert_true(shipped.events.has(name), "missing entry for %s in data/audio_settings.tres" % name)
		var event := settings.event(name)
		assert_almost(event.gain_db, 0.0)
		assert_almost(event.pitch, 1.0)
		assert_almost(event.pitch_jitter, 0.0)
		assert_almost(event.high_pass_hz, 0.0)
		assert_almost(event.low_pass_hz, 0.0)


func test_shipped_music_track_is_set_and_loops() -> void:
	var shipped: AudioSettings = load("res://data/audio_settings.tres")
	assert_true(shipped.music_track != null, "no music track in data/audio_settings.tres")
	var wav := shipped.music_track as AudioStreamWAV
	assert_true(wav != null, "music track is not a WAV")
	assert_true(wav.loop_mode != AudioStreamWAV.LOOP_DISABLED, "music track does not loop")


func test_event_gain_adds_to_the_effects_gain() -> void:
	settings.events[&"placement"].gain_db = -2.0
	assert_almost(settings.effect_gain_db(&"placement"), 6.0)


func test_unknown_event_plays_unmodified() -> void:
	assert_almost(settings.effect_gain_db(&"nope"), settings.effects_gain_db)
	var event := settings.event(&"nope")
	assert_almost(event.gain_db, 0.0)
	assert_almost(event.pitch, 1.0)


func test_random_pitch_is_the_configured_pitch_without_jitter() -> void:
	var event := AudioEvent.new()
	event.pitch = 1.25
	assert_almost(event.random_pitch(_rng()), 1.25)


func test_random_pitch_stays_within_the_jitter_spread() -> void:
	var event := AudioEvent.new()
	event.pitch = 1.2
	event.pitch_jitter = 0.2
	var rng := _rng()
	for i in 200:
		var pitch := event.random_pitch(rng)
		assert_true(pitch >= 1.0 - 0.0001 and pitch <= 1.4 + 0.0001, "pitch %f" % pitch)


func test_ensure_bus_adds_high_then_low_pass_once() -> void:
	var bus := AudioSettings.ensure_bus(&"TestBusFilters", 300.0, 4000.0)
	var index := AudioServer.get_bus_index(bus)
	assert_true(index != -1, "bus not created")
	assert_eq(AudioServer.get_bus_effect_count(index), 2)
	var high := AudioServer.get_bus_effect(index, 0) as AudioEffectHighPassFilter
	assert_true(high != null, "first effect is not a high-pass")
	assert_almost(high.cutoff_hz, 300.0)
	var low := AudioServer.get_bus_effect(index, 1) as AudioEffectLowPassFilter
	assert_true(low != null, "second effect is not a low-pass")
	assert_almost(low.cutoff_hz, 4000.0)
	# Asking again reuses the bus instead of stacking filters on it.
	AudioSettings.ensure_bus(&"TestBusFilters", 300.0, 4000.0)
	assert_eq(AudioServer.get_bus_effect_count(index), 2)
	assert_eq(AudioServer.get_bus_send(index), &"Master")


func test_bus_without_filters_has_no_effects() -> void:
	var bus := AudioSettings.ensure_bus(&"TestBusPlain", 0.0, 0.0)
	var index := AudioServer.get_bus_index(bus)
	assert_true(index != -1, "bus not created")
	assert_eq(AudioServer.get_bus_effect_count(index), 0)


func test_event_bus_carries_the_event_filters() -> void:
	settings.events[&"placement"].high_pass_hz = 120.0
	var index := AudioServer.get_bus_index(settings.event_bus(&"placement"))
	assert_true(index != -1, "event bus not created")
	assert_eq(AudioServer.get_bus_effect_count(index), 1)
	var high := AudioServer.get_bus_effect(index, 0) as AudioEffectHighPassFilter
	assert_true(high != null)
	assert_almost(high.cutoff_hz, 120.0)


func _rng() -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	return rng
