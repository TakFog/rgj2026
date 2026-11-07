extends TestCase

var cycle: NestCycle
var hatched_counts: Array[int] = []
var eggs_died_count := 0


func before_each() -> void:
	cycle = NestCycle.new(20.0, 3)
	hatched_counts = []
	eggs_died_count = 0
	cycle.hatched.connect(_on_hatched)
	cycle.eggs_died.connect(_on_eggs_died)


func _on_hatched(count: int) -> void:
	hatched_counts.append(count)


func _on_eggs_died() -> void:
	eggs_died_count += 1


func test_starts_empty_without_eggs() -> void:
	assert_eq(cycle.state, NestCycle.State.EMPTY)
	assert_almost(cycle.eggs_time_left(), -1.0)


func test_fertilize_starts_the_timer() -> void:
	assert_true(cycle.fertilize())
	assert_eq(cycle.state, NestCycle.State.EGGS)
	assert_almost(cycle.eggs_time_left(), 20.0)


func test_cannot_fertilize_twice() -> void:
	cycle.fertilize()
	cycle.tick(5.0)
	assert_false(cycle.fertilize())
	assert_almost(cycle.eggs_time_left(), 15.0)


func test_hatches_once_after_hatch_seconds() -> void:
	cycle.fertilize()
	cycle.tick(19.0)
	assert_eq(hatched_counts.size(), 0)
	cycle.tick(1.5)
	cycle.tick(30.0)
	assert_eq(hatched_counts, [3] as Array[int])
	assert_eq(cycle.state, NestCycle.State.EMPTY)


func test_kill_eggs_cancels_hatching() -> void:
	cycle.fertilize()
	cycle.tick(10.0)
	cycle.kill_eggs()
	cycle.tick(30.0)
	assert_eq(hatched_counts.size(), 0)
	assert_almost(cycle.eggs_time_left(), -1.0)


func test_can_be_fertilized_again_after_hatching() -> void:
	cycle.fertilize()
	cycle.tick(20.0)
	assert_true(cycle.fertilize())


func test_no_heat_hazard_leaves_eggs_alive() -> void:
	cycle.fertilize()
	cycle.tick(10.0, 0.0)
	assert_eq(cycle.state, NestCycle.State.EGGS)
	assert_eq(eggs_died_count, 0)
	cycle.tick(10.0, -5.0)
	assert_eq(cycle.state, NestCycle.State.EMPTY)
	assert_eq(hatched_counts, [3] as Array[int])
	assert_eq(eggs_died_count, 0)


func test_eggs_die_from_a_high_hazard() -> void:
	cycle.fertilize()
	cycle.tick(1.0, 1000000.0)
	assert_eq(cycle.state, NestCycle.State.EMPTY)
	assert_almost(cycle.eggs_time_left(), -1.0)
	assert_eq(eggs_died_count, 1)
	cycle.tick(30.0)
	assert_eq(hatched_counts.size(), 0)
	assert_eq(eggs_died_count, 1)


func test_hazard_from_chance_matches_full_incubation_chance() -> void:
	assert_almost(NestCycle.hazard_from_chance(0.0, 20.0), 0.0)
	assert_almost(NestCycle.hazard_from_chance(-0.5, 20.0), 0.0)
	var chance := 0.6
	var hazard := NestCycle.hazard_from_chance(chance, 20.0)
	assert_almost(1.0 - exp(-hazard * 20.0), chance)


func test_death_chance_per_tick_is_clamped_at_zero() -> void:
	assert_almost(NestCycle.death_chance_per_tick(0.0, 1.0), 0.0)
	assert_almost(NestCycle.death_chance_per_tick(-5.0, 1.0), 0.0)
	assert_almost(NestCycle.death_chance_per_tick(1.0, 1.0), 1.0 - exp(-1.0))
