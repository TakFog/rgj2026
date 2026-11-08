extends TestCase

var settings: AudioSettings


func before_each() -> void:
	settings = AudioSettings.new()


func test_defaults_boost_the_quiet_effect_takes() -> void:
	assert_almost(settings.music_gain_db, 0.0)
	assert_almost(settings.effects_gain_db, 8.0)
	assert_almost(settings.effect_gain_db(&"placement"), 8.0)


func test_every_shipped_event_is_configured() -> void:
	var events: Dictionary = AudioEvents.TAKES
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


func test_shipped_music_stems_loop_in_sync() -> void:
	var shipped: AudioSettings = load("res://data/audio_settings.tres")
	assert_eq(shipped.drums.size(), 2, "two drum takes")
	assert_eq(shipped.arp_half.size(), 2, "two half arp takes")
	assert_eq(shipped.arp_full.size(), 2, "two full arp takes")
	var loop_end := -1
	for stream: AudioStream in shipped.drums + shipped.arp_half + shipped.arp_full:
		var wav := stream as AudioStreamWAV
		assert_true(wav != null, "%s is not a WAV" % stream.resource_path)
		assert_eq(wav.loop_mode, AudioStreamWAV.LOOP_FORWARD, "%s does not loop" % stream.resource_path)
		if loop_end < 0:
			loop_end = wav.loop_end
		assert_eq(wav.loop_end, loop_end, "%s does not share the loop point" % stream.resource_path)


func test_arp_level_from_hostile_count() -> void:
	assert_eq(MusicSystem.arp_level(0, 6), 0, "no arp without hostiles")
	assert_eq(MusicSystem.arp_level(1, 6), 1)
	assert_eq(MusicSystem.arp_level(5, 6), 1, "half up to 5")
	assert_eq(MusicSystem.arp_level(6, 6), 2, "full from 6")
	assert_eq(MusicSystem.arp_level(9, 6), 2)


func test_shipped_intro_is_set_and_loops() -> void:
	var shipped: AudioSettings = load("res://data/audio_settings.tres")
	assert_true(shipped.intro_track != null, "no intro track in data/audio_settings.tres")
	if shipped.intro_track is AudioStreamWAV:
		assert_eq((shipped.intro_track as AudioStreamWAV).loop_mode, AudioStreamWAV.LOOP_FORWARD,
				"the title screen intro must loop")


func test_shipped_outro_is_set_and_does_not_loop() -> void:
	var shipped: AudioSettings = load("res://data/audio_settings.tres")
	assert_true(shipped.outro_track != null, "no outro track in data/audio_settings.tres")
	if shipped.outro_track is AudioStreamWAV:
		assert_eq((shipped.outro_track as AudioStreamWAV).loop_mode, AudioStreamWAV.LOOP_DISABLED,
				"the outro must not loop")


func test_placement_uses_the_item_kind_sound_when_it_has_one() -> void:
	assert_eq(AudioEvents.placement_event(&"nest"), &"placement_nest")
	assert_eq(AudioEvents.placement_event(&"algae"), &"placement_algae")
	assert_eq(AudioEvents.placement_event(&"coral"), &"placement")


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


func test_event_buses_are_routed_through_the_effects_bus() -> void:
	# A name of its own: another test reuses the placement bus with filters.
	var bus := settings.event_bus(&"route_probe")
	var index := AudioServer.get_bus_index(bus)
	assert_true(index != -1, "event bus not created")
	assert_eq(AudioServer.get_bus_send(index), AudioSettings.EFFECTS_BUS)
	var effects := AudioServer.get_bus_index(AudioSettings.EFFECTS_BUS)
	assert_true(effects != -1, "effects bus not created")
	assert_eq(AudioServer.get_bus_send(effects), &"Master")


func test_volume_percent_maps_to_db() -> void:
	assert_almost(UserSettings.db_from_percent(100.0), 0.0)
	assert_almost(UserSettings.db_from_percent(50.0), -6.0206, 0.01)
	assert_almost(UserSettings.db_from_percent(0.0), UserSettings.MIN_DB)
	assert_almost(UserSettings.percent_from_db(0.0), 100.0)
	assert_almost(UserSettings.percent_from_db(-6.0206), 50.0, 0.1)


func test_event_bus_carries_the_event_filters() -> void:
	settings.events[&"placement"].high_pass_hz = 120.0
	var index := AudioServer.get_bus_index(settings.event_bus(&"placement"))
	assert_true(index != -1, "event bus not created")
	assert_eq(AudioServer.get_bus_effect_count(index), 1)
	var high := AudioServer.get_bus_effect(index, 0) as AudioEffectHighPassFilter
	assert_true(high != null)
	assert_almost(high.cutoff_hz, 120.0)


func test_pause_filter_is_configured() -> void:
	var shipped: AudioSettings = load("res://data/audio_settings.tres")
	assert_true(shipped.pause_music_low_pass_hz > 0.0, "pause filter disabled")
	assert_true(shipped.pause_filter_fade_seconds >= 0.0)


func test_pause_cutoff_opens_when_running_or_disabled() -> void:
	assert_almost(MusicSystem.pause_cutoff(false, 900.0), MusicSystem.FILTER_OPEN_HZ)
	assert_almost(MusicSystem.pause_cutoff(true, 900.0), 900.0)
	assert_almost(MusicSystem.pause_cutoff(true, 0.0), MusicSystem.FILTER_OPEN_HZ)


func _rng() -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	return rng
