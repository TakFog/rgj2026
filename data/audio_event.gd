class_name AudioEvent
extends Resource
## Level, pitch and filters of one sound event, tuned by the designer in
## data/audio_settings.tres (see docs/audio.md).

## Level in dB added to the global effects level: 0.0 unmodified, -6.0 half as
## loud, above 0.0 boosts. -80.0 or below is silent.
@export_range(-80.0, 24.0, 0.1) var gain_db := 0.0
## Playback speed multiplier: 1.0 unmodified, 0.5 an octave down, 2.0 an
## octave up (pitch and speed move together).
@export_range(0.25, 4.0, 0.05) var pitch := 1.0
## Random spread added to pitch on every play (0.0 never varies).
@export_range(0.0, 0.5, 0.01) var pitch_jitter := 0.0
## High-pass cutoff in Hz: removes what sits below it (0.0 = filter off).
@export_range(0.0, 21000.0, 10.0) var high_pass_hz := 0.0
## Low-pass cutoff in Hz: removes what sits above it (0.0 = filter off).
@export_range(0.0, 21000.0, 10.0) var low_pass_hz := 0.0


## Pitch for one play: `pitch` ± `pitch_jitter`, kept in the playable range.
func random_pitch(rng: RandomNumberGenerator) -> float:
	if pitch_jitter <= 0.0:
		return pitch
	return clampf(pitch + rng.randf_range(-pitch_jitter, pitch_jitter), 0.25, 4.0)
