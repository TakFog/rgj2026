class_name AudioSettings
extends Resource
## Level, pitch and filters of the music and the sound effects, tuned by the
## designer (GDD §9). Levels are in dB: 0.0 is unmodified and positive values
## boost. Tweak in data/audio_settings.tres; see docs/audio.md for the how-to.

const MUSIC_BUS := &"Music"
const SFX_BUS_PREFIX := "Sfx_"
## At or below this level a sound is skipped instead of played inaudibly.
const SILENCE_DB := -80.0

@export_group("Music")
## Looping track played during the run: pick a .wav from assets/audio in the
## inspector. It must loop, which comes from the WAV import (edit/loop_mode = 2).
## Empty means silence.
@export var music_track: AudioStream
@export_range(-80.0, 24.0, 0.1) var music_gain_db := 0.0
## Playback speed multiplier: 1.0 unmodified, 0.5 an octave down, 2.0 up.
@export_range(0.25, 4.0, 0.05) var music_pitch := 1.0
@export_range(0.0, 21000.0, 10.0) var music_high_pass_hz := 0.0
@export_range(0.0, 21000.0, 10.0) var music_low_pass_hz := 0.0

@export_group("Effects")
## Applied to every effect, on top of the per-event gain. The takes peak around
## -10 dBFS, well under the music, hence the default boost (~+8 dB).
@export_range(-80.0, 24.0, 0.1) var effects_gain_db := 8.0
## One entry per event in AudioEvents.TAKES: level, pitch and filters.
## An event missing here plays at the neutral defaults.
@export var events: Dictionary[StringName, AudioEvent] = {
	&"placement": AudioEvent.new(),
	&"item_available": AudioEvent.new(),
	&"bag_destroyed": AudioEvent.new(),
}

static var _neutral := AudioEvent.new()


## Settings for `event` (neutral defaults when the event isn't configured).
func event(name: StringName) -> AudioEvent:
	return events.get(name, _neutral) as AudioEvent


## Final level in dB for `event`: the global effects level plus the event's own.
func effect_gain_db(name: StringName) -> float:
	return effects_gain_db + event(name).gain_db


## Audio bus for `event`, carrying its filters. Created on first use.
func event_bus(name: StringName) -> StringName:
	var settings := event(name)
	return ensure_bus(StringName(SFX_BUS_PREFIX + name), settings.high_pass_hz, settings.low_pass_hz)


## Audio bus for the music, carrying the music filters. Created on first use.
func music_bus() -> StringName:
	return ensure_bus(MUSIC_BUS, music_high_pass_hz, music_low_pass_hz)


## Creates `bus_name` (routed to Master) with a high-pass and/or a low-pass
## filter, unless it already exists. A cutoff of 0.0 leaves that filter off.
static func ensure_bus(bus_name: StringName, high_pass_hz: float, low_pass_hz: float) -> StringName:
	if AudioServer.get_bus_index(bus_name) != -1:
		return bus_name
	AudioServer.add_bus()
	var index := AudioServer.bus_count - 1
	AudioServer.set_bus_name(index, bus_name)
	AudioServer.set_bus_send(index, &"Master")
	if high_pass_hz > 0.0:
		var high_pass := AudioEffectHighPassFilter.new()
		high_pass.cutoff_hz = high_pass_hz
		AudioServer.add_bus_effect(index, high_pass)
	if low_pass_hz > 0.0:
		var low_pass := AudioEffectLowPassFilter.new()
		low_pass.cutoff_hz = low_pass_hz
		AudioServer.add_bus_effect(index, low_pass)
	return bus_name
