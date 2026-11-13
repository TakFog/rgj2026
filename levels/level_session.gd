class_name LevelSession
extends RefCounted
## Which level the loaded scene represents. A static field, so it survives the
## `reload_current_scene()` used to switch levels and to retry after a collapse
## (like MainMenuScreen._skip_next_open).

## Pseudo-index for the endless sandbox, outside the campaign range.
const SANDBOX_INDEX := -1

static var current_index := 0


## Level currently loaded (clamped to the campaign range, or the sandbox).
static func current() -> LevelDefinition:
	if is_sandbox():
		return LevelCatalog.sandbox()
	return LevelCatalog.at(current_index)


static func total() -> int:
	return LevelCatalog.COUNT


## True while the loaded scene is the endless sandbox rather than a campaign level.
static func is_sandbox() -> bool:
	return current_index == SANDBOX_INDEX


## Clamps the stored index into the campaign range and returns it. Main calls
## this before building, so a stale index can never point outside the catalog.
## The sandbox pseudo-index is left untouched.
static func clamp_current() -> int:
	if not is_sandbox():
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


## Selects the endless sandbox for the next scene build. Returns true when it
## actually changed (like `select`).
static func select_sandbox() -> bool:
	if is_sandbox():
		return false
	current_index = SANDBOX_INDEX
	return true


## Back to level 1 (tests and a fresh session).
static func reset() -> void:
	current_index = 0
