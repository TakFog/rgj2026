extends TestCase
## The campaign line-up: three levels, each adding one pressure.

var levels: Array[LevelDefinition]


func before_each() -> void:
	levels = LevelCatalog.all()


func test_campaign_has_three_levels() -> void:
	assert_eq(levels.size(), 3)
	assert_eq(LevelCatalog.COUNT, 3)


func test_every_level_has_a_name_and_a_time_limit() -> void:
	for level in levels:
		assert_false(level.level_name.is_empty())
		assert_false(level.mechanic_summary.is_empty())
		assert_true(level.duration_seconds > 0.0)


func test_first_level_is_the_calm_reef() -> void:
	var level := levels[0]
	assert_false(level.temperature_enabled)
	assert_false(level.co2_enabled)
	assert_false(level.bag_enabled)
	assert_false(level.cyclone_enabled)
	assert_false(level.predator_enabled)
	assert_false(level.turtle_enabled)


func test_second_level_adds_temperature_only() -> void:
	var level := levels[1]
	assert_true(level.temperature_enabled)
	assert_false(level.co2_enabled)
	assert_false(level.bag_enabled)
	assert_false(level.cyclone_enabled)
	assert_false(level.predator_enabled)
	assert_false(level.turtle_enabled)


func test_third_level_is_the_full_sea() -> void:
	var level := levels[2]
	assert_true(level.temperature_enabled)
	assert_true(level.co2_enabled)
	assert_true(level.bag_enabled)
	assert_true(level.cyclone_enabled)
	assert_true(level.predator_enabled)
	assert_true(level.turtle_enabled)


func test_durations_grow_with_the_mechanic_count() -> void:
	assert_almost(levels[0].duration_seconds, 60.0)
	assert_almost(levels[1].duration_seconds, 90.0)
	assert_almost(levels[2].duration_seconds, 120.0)


func test_every_level_starts_with_the_base_reef() -> void:
	for level in levels:
		assert_eq(level.corals.size(), Level01.CORALS.size())
		assert_eq(level.nests.size(), Level01.NESTS.size())
		assert_eq(level.fish.size(), Level01.FISH.size())
		assert_true(level.algae.size() >= Level01.ALGAE.size())


func test_at_clamps_out_of_range_indices() -> void:
	assert_eq(LevelCatalog.at(-5).level_name, levels[0].level_name)
	assert_eq(LevelCatalog.at(99).level_name, levels[2].level_name)


func test_sandbox_is_the_old_endless_full_sea() -> void:
	var sandbox := LevelCatalog.sandbox()
	assert_eq(sandbox.level_name, "Sandbox")
	assert_true(sandbox.endless)
	assert_almost(sandbox.duration_seconds, 0.0)
	assert_true(sandbox.temperature_enabled)
	assert_true(sandbox.co2_enabled)
	assert_true(sandbox.bag_enabled)
	assert_true(sandbox.cyclone_enabled)
	assert_true(sandbox.predator_enabled)
	assert_true(sandbox.turtle_enabled)


func test_sandbox_uses_the_original_reef_and_stays_out_of_the_campaign() -> void:
	var sandbox := LevelCatalog.sandbox()
	assert_eq(sandbox.corals.size(), Level01.CORALS.size())
	assert_eq(sandbox.algae.size(), Level01.ALGAE.size())
	assert_eq(sandbox.nests.size(), Level01.NESTS.size())
	assert_eq(sandbox.fish.size(), Level01.FISH.size())
	assert_eq(LevelCatalog.COUNT, levels.size())
