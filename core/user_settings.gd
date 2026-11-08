class_name UserSettings
extends RefCounted
## User audio preferences (music and effects group volume), separate from the
## designer mix in AudioSettings. Saved in user:// so they survive restarts.

const PATH := "user://settings.cfg"
const SECTION := "audio"
const MUSIC_KEY := "music_db"
const EFFECTS_KEY := "effects_db"
const TUTORIAL_SECTION := "tutorial"
const TUTORIAL_KEY := "seen"
const SCORE_SECTION := "score"
const BEST_SECONDS_KEY := "best_seconds"
const LEVELS_SECTION := "levels"
## Number of unlocked campaign levels (level 1 is always available).
const UNLOCKED_KEY := "unlocked"
## Per-level survival record, stored as "best_<index>" (0-based index).
const LEVEL_BEST_PREFIX := "best_"
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


## True once the player has started a run after seeing the tutorial.
static func tutorial_seen(path := PATH) -> bool:
	var config := ConfigFile.new()
	if config.load(path) != OK:
		return false
	return bool(config.get_value(TUTORIAL_SECTION, TUTORIAL_KEY, false))


## Remembers that the tutorial has been seen, keeping every other section.
static func mark_tutorial_seen(path := PATH) -> void:
	var config := ConfigFile.new()
	config.load(path)
	config.set_value(TUTORIAL_SECTION, TUTORIAL_KEY, true)
	config.save(path)


## Best survival time in seconds, or 0.0 when no run has been recorded.
static func best_seconds(path := PATH) -> float:
	var config := ConfigFile.new()
	if config.load(path) != OK:
		return 0.0
	return maxf(0.0, float(config.get_value(SCORE_SECTION, BEST_SECONDS_KEY, 0.0)))


## Stores `seconds` when it beats the current best. Returns true on a new record.
static func submit_best(seconds: float, path := PATH) -> bool:
	if seconds <= best_seconds(path):
		return false
	var config := ConfigFile.new()
	config.load(path)
	config.set_value(SCORE_SECTION, BEST_SECONDS_KEY, seconds)
	config.save(path)
	return true


## How many campaign levels are unlocked. Level 1 is always playable, so the
## value is at least 1 even on a fresh save.
static func unlocked_count(path := PATH) -> int:
	var config := ConfigFile.new()
	if config.load(path) != OK:
		return 1
	return maxi(1, int(config.get_value(LEVELS_SECTION, UNLOCKED_KEY, 1)))


## Marks `index` (0-based) as cleared and unlocks the following level, capped at
## `total`. Keeps every other section of the file.
static func mark_level_cleared(index: int, total: int, path := PATH) -> void:
	var config := ConfigFile.new()
	config.load(path)
	var unlocked := maxi(1, int(config.get_value(LEVELS_SECTION, UNLOCKED_KEY, 1)))
	config.set_value(LEVELS_SECTION, UNLOCKED_KEY, maxi(unlocked, mini(index + 2, total)))
	config.save(path)


## Debug helper (F3): makes every level selectable.
static func unlock_all(total: int, path := PATH) -> void:
	var config := ConfigFile.new()
	config.load(path)
	config.set_value(LEVELS_SECTION, UNLOCKED_KEY, maxi(1, total))
	config.save(path)


## Best survival time on one level, or 0.0 when no run has been recorded.
static func level_best_seconds(index: int, path := PATH) -> float:
	var config := ConfigFile.new()
	if config.load(path) != OK:
		return 0.0
	var key := "%s%d" % [LEVEL_BEST_PREFIX, index]
	return maxf(0.0, float(config.get_value(LEVELS_SECTION, key, 0.0)))


## Stores `seconds` when it beats this level's record. Returns true on a record.
static func submit_level_best(index: int, seconds: float, path := PATH) -> bool:
	if seconds <= level_best_seconds(index, path):
		return false
	var config := ConfigFile.new()
	config.load(path)
	var key := "%s%d" % [LEVEL_BEST_PREFIX, index]
	config.set_value(LEVELS_SECTION, key, seconds)
	config.save(path)
	return true


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
