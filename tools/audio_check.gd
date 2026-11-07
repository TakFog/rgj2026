extends SceneTree
## Prints the resolved audio configuration: the music track, and for every event
## in core/audio_events.gd its settings from data/audio_settings.tres, the
## takes found on disk and the audio bus (with its filters) it plays on.
## Run with tools/audio.sh.


func _init() -> void:
	var settings: AudioSettings = load("res://data/audio_settings.tres")
	var events: Dictionary = AudioEvents.TAKES

	print("Intro: ", _intro(settings))
	print("Music stems: ", _stems(settings))
	print("Outro: ", _outro(settings))
	print()
	print("%-16s %-10s %8s %11s %10s %10s  %s" % [
		"event", "in .tres", "gain", "pitch±jit", "high-pass", "low-pass", "takes / bus"])
	for name: StringName in events:
		_print_event(settings, name, events[name])
	quit()


func _stems(settings: AudioSettings) -> String:
	if settings.drums.is_empty() and settings.arp_half.is_empty() and settings.arp_full.is_empty():
		if settings.music_track == null:
			return "(no stems and no fallback track, the game is silent)"
		var wav := settings.music_track as AudioStreamWAV
		var loop := "loop: yes" if wav != null and wav.loop_mode != AudioStreamWAV.LOOP_DISABLED else "loop: NO (check the .wav.import)"
		return "fallback %s (%s, %.1f s)  gain %+.1f dB  pitch %.2f  high-pass %s  low-pass %s" % [
			settings.music_track.resource_path, loop, settings.music_track.get_length(),
			settings.music_gain_db, settings.music_pitch,
			_hz(settings.music_high_pass_hz), _hz(settings.music_low_pass_hz)]
	var stems_loop := ""
	if not settings.drums.is_empty():
		var wav := settings.drums[0] as AudioStreamWAV
		if wav != null:
			stems_loop = "loop %.2f s" % (wav.loop_end / float(wav.mix_rate))
	return "drums %d, arp half %d, arp full %d (%s)  music %+.1f dB, drums %+.1f dB, arp %+.1f dB, full at %d hostiles, fade %.1f s / drums %.1f s" % [
		settings.drums.size(), settings.arp_half.size(), settings.arp_full.size(), stems_loop,
		settings.music_gain_db, settings.drums_gain_db, settings.arp_gain_db,
		settings.arp_full_hostiles, settings.music_fade_seconds, settings.drum_fade_seconds]


func _intro(settings: AudioSettings) -> String:
	if settings.intro_track == null:
		return "(none, the loop starts right away)"
	var wav := settings.intro_track as AudioStreamWAV
	var loop := "loop: NO" if wav == null or wav.loop_mode == AudioStreamWAV.LOOP_DISABLED else "loop: YES (should not loop!)"
	return "%s (%s, %.1f s)  gain %+.1f dB" % [
		settings.intro_track.resource_path, loop, settings.intro_track.get_length(),
		settings.intro_gain_db]


func _outro(settings: AudioSettings) -> String:
	if settings.outro_track == null:
		return "(none, a lost run goes quiet)"
	var wav := settings.outro_track as AudioStreamWAV
	var loop := "loop: NO" if wav == null or wav.loop_mode == AudioStreamWAV.LOOP_DISABLED else "loop: YES (should not loop!)"
	return "%s (%s, %.1f s)  gain %+.1f dB" % [
		settings.outro_track.resource_path, loop, settings.outro_track.get_length(),
		settings.outro_gain_db]


func _print_event(settings: AudioSettings, name: StringName, paths: Array) -> void:
	var event := settings.event(name)
	var found := 0
	for path: String in paths:
		if ResourceLoader.exists(path):
			found += 1
	var bus := settings.event_bus(name)
	var bus_index := AudioServer.get_bus_index(bus)
	var effects := []
	for i in AudioServer.get_bus_effect_count(bus_index):
		var effect := AudioServer.get_bus_effect(bus_index, i)
		effects.append("%s %s" % [effect.get_class().replace("AudioEffect", ""), _hz(effect.cutoff_hz)])
	print("%-16s %-10s %+8.1f %11s %10s %10s  %d/%d takes, bus %s%s" % [
		name, "yes" if settings.events.has(name) else "NO", settings.effect_gain_db(name),
		"%.2f±%.2f" % [event.pitch, event.pitch_jitter],
		_hz(event.high_pass_hz), _hz(event.low_pass_hz), found, paths.size(), bus,
		": " + ", ".join(effects) if not effects.is_empty() else ""])


func _hz(value: float) -> String:
	return "off" if value <= 0.0 else "%.0f Hz" % value
