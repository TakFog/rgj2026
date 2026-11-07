extends TestCase
## The early turtle rush is a one-shot, chance-based schedule: it never runs
## twice, never spawns more than its count, and spaces the group out.

var cfg: BalanceActors
var rng: RandomNumberGenerator


func before_each() -> void:
	cfg = BalanceActors.new()
	cfg.turtle_rush_chance = 1.0
	cfg.turtle_rush_seconds = 10.0
	cfg.turtle_rush_count = 3
	cfg.turtle_rush_spacing_seconds = 2.0
	rng = RandomNumberGenerator.new()
	rng.seed = 1


func test_zero_chance_never_starts() -> void:
	cfg.turtle_rush_chance = 0.0
	var rush := TurtleRush.new(cfg, rng)
	assert_false(rush.is_active())
	assert_eq(rush.tick(1000.0), 0)


func test_zero_count_never_starts() -> void:
	cfg.turtle_rush_count = 0
	var rush := TurtleRush.new(cfg, rng)
	assert_false(rush.is_active())
	assert_eq(rush.tick(1000.0), 0)


func test_group_starts_after_delay_and_is_spaced_out() -> void:
	var rush := TurtleRush.new(cfg, rng)
	assert_true(rush.is_active())
	assert_eq(rush.tick(9.9), 0)
	assert_eq(rush.tick(0.2), 1, "first turtle at turtle_rush_seconds")
	assert_eq(rush.tick(1.8), 0)
	assert_eq(rush.tick(0.2), 1, "second turtle one spacing later")
	assert_eq(rush.tick(1.8), 0)
	assert_eq(rush.tick(0.2), 1, "third turtle one spacing later")
	assert_false(rush.is_active())


func test_rush_is_one_shot() -> void:
	var rush := TurtleRush.new(cfg, rng)
	var total := 0
	for i in 200:
		total += rush.tick(0.1)
	assert_eq(total, cfg.turtle_rush_count)
	assert_eq(rush.tick(1000.0), 0, "no second wave")


func test_zero_spacing_releases_the_whole_group_at_once() -> void:
	cfg.turtle_rush_spacing_seconds = 0.0
	var rush := TurtleRush.new(cfg, rng)
	assert_eq(rush.tick(9.9), 0)
	assert_eq(rush.tick(0.2), cfg.turtle_rush_count)
	assert_false(rush.is_active())


func test_long_frame_still_respects_the_count() -> void:
	var rush := TurtleRush.new(cfg, rng)
	assert_eq(rush.tick(500.0), cfg.turtle_rush_count)
	assert_false(rush.is_active())
