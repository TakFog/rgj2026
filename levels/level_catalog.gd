class_name LevelCatalog
extends RefCounted
## The three campaign levels, easiest first. Each one adds a pressure on top of
## the previous: the calm base reef, then temperature, then the full sea.
## Starting contents reuse Level01 (the hand-built map) unless a level adds to it.
## The endless sandbox lives outside the campaign (see `sandbox`), so COUNT and
## the unlock progression only ever describe the three timed levels.

const COUNT := 3


static func all() -> Array[LevelDefinition]:
	var levels: Array[LevelDefinition] = []
	levels.append(_level_1())
	levels.append(_level_2())
	levels.append(_level_3())
	return levels


## Level at `index`, clamped to the campaign range (never returns null).
static func at(index: int) -> LevelDefinition:
	var levels := all()
	return levels[clampi(index, 0, levels.size() - 1)]


## The old endless run, offered as a bonus in the level chooser: every mechanic
## on, no time limit, and the global survival record (not a per-level one).
## Not part of COUNT, so it never affects unlocking or level numbering.
static func sandbox() -> LevelDefinition:
	var level := LevelDefinition.new()
	level.level_name = "Sandbox"
	level.mechanic_summary = "Tutte le meccaniche, senza limite di tempo"
	level.duration_seconds = 0.0
	level.endless = true
	level.temperature_enabled = true
	level.co2_enabled = true
	level.bag_enabled = true
	level.cyclone_enabled = true
	level.predator_enabled = true
	level.turtle_enabled = true
	_base_contents(level)
	return level


## The base reef every level starts from.
static func _base_contents(level: LevelDefinition) -> void:
	for entry in Level01.CORALS:
		level.corals.append([entry[0], entry[1]])
	for cell: Vector2i in Level01.ALGAE:
		level.algae.append(cell)
	for cell: Vector2i in Level01.NESTS:
		level.nests.append(cell)
	for cell: Vector2i in Level01.FISH:
		level.fish.append(cell)


static func _add_algae(level: LevelDefinition, cells: Array[Vector2i]) -> void:
	for cell: Vector2i in cells:
		level.algae.append(cell)


## Level 1: the base loop on a calm reef. No temperature rise, no threats.
static func _level_1() -> LevelDefinition:
	var level := LevelDefinition.new()
	level.level_name = "La barriera"
	level.mechanic_summary = "Pesci, coralli, alghe e nidi"
	level.duration_seconds = 60.0
	_base_contents(level)
	return level


## Level 2: the water starts warming up; corals slow it down.
static func _level_2() -> LevelDefinition:
	var level := LevelDefinition.new()
	level.level_name = "L'acqua si scalda"
	level.mechanic_summary = "La temperatura sale: i coralli la rallentano"
	level.duration_seconds = 90.0
	level.temperature_enabled = true
	_base_contents(level)
	_add_algae(level, [Vector2i(6, 5), Vector2i(11, 6), Vector2i(12, 13)])
	return level


## Level 3: the full sea. Threats arrive from the open water, and the predator
## and the turtle join the reef.
static func _level_3() -> LevelDefinition:
	var level := LevelDefinition.new()
	level.level_name = "Il mare aperto"
	level.mechanic_summary = "CO2, buste, cicloni, predatore e tartaruga"
	level.duration_seconds = 120.0
	level.temperature_enabled = true
	level.co2_enabled = true
	level.bag_enabled = true
	level.cyclone_enabled = true
	level.predator_enabled = true
	level.turtle_enabled = true
	_base_contents(level)
	_add_algae(level, [
		Vector2i(6, 5), Vector2i(11, 6), Vector2i(12, 13),
		Vector2i(13, 12), Vector2i(2, 8),
	])
	return level
