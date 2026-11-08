class_name LevelSession
extends RefCounted
## Which level the loaded scene represents. A static field, so it survives the
## `reload_current_scene()` used to switch levels and to retry after a collapse
## (like MainMenuScreen._skip_next_open).

static var current_index := 0


## Level currently loaded (clamped to the campaign range).
static func current() -> LevelDefinition:
	return LevelCatalog.at(current_index)


static func total() -> int:
	return LevelCatalog.COUNT


## Clamps the stored index into the campaign range and returns it. Main calls
## this before building, so a stale index can never point outside the catalog.
static func clamp_current() -> int:
	current_index = clampi(current_index, 0, total() - 1)
	return current_index


## Selects a level for the next scene build. Returns true when it actually
## changed, so the caller knows a reload is needed.
static func select(index: int) -> bool:
	var clamped := clampi(index, 0, total() - 1)
	if clamped == current_index:
		return false
	current_index = clamped
	return true


## Back to level 1 (tests and a fresh session).
static func reset() -> void:
	current_index = 0
