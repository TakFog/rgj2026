class_name UserSettings
extends RefCounted
## User audio preferences (music and effects group volume), separate from the
## designer mix in AudioSettings. Saved in user:// so they survive restarts.

const PATH := "user://settings.cfg"
const SECTION := "audio"
const MUSIC_KEY := "music_db"
const EFFECTS_KEY := "effects_db"
## Slider range: -80 dB is silent, 0 dB leaves the designed mix untouched.
const MIN_DB := -80.0
const MAX_DB := 0.0


static func music_db() -> float:
	return _load_db(MUSIC_KEY)


static func effects_db() -> float:
	return _load_db(EFFECTS_KEY)


## Saves both group levels, keeping any other sections in the file.
static func save(music_db_value: float, effects_db_value: float) -> void:
	var config := ConfigFile.new()
	config.load(PATH)
	config.set_value(SECTION, MUSIC_KEY, clampf(music_db_value, MIN_DB, MAX_DB))
	config.set_value(SECTION, EFFECTS_KEY, clampf(effects_db_value, MIN_DB, MAX_DB))
	config.save(PATH)


## Applies the two user levels to their buses (missing buses are skipped).
static func apply(music_db_value: float, effects_db_value: float) -> void:
	_set_bus(AudioSettings.MUSIC_BUS, music_db_value)
	_set_bus(AudioSettings.EFFECTS_BUS, effects_db_value)


static func load_and_apply() -> void:
	apply(music_db(), effects_db())


## Slider position (0..100) -> bus level. Linear in amplitude, so 50% is -6 dB.
static func db_from_percent(percent: float) -> float:
	if percent <= 0.0:
		return MIN_DB
	return clampf(linear_to_db(percent / 100.0), MIN_DB, MAX_DB)


## Bus level -> slider position (0..100).
static func percent_from_db(db: float) -> float:
	if db <= MIN_DB:
		return 0.0
	return clampf(db_to_linear(db) * 100.0, 0.0, 100.0)


static func _load_db(key: String) -> float:
	var config := ConfigFile.new()
	if config.load(PATH) != OK:
		return 0.0
	return clampf(float(config.get_value(SECTION, key, 0.0)), MIN_DB, MAX_DB)


static func _set_bus(bus: StringName, db: float) -> void:
	var index := AudioServer.get_bus_index(bus)
	if index != -1:
		AudioServer.set_bus_volume_db(index, db)
