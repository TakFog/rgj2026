extends TestCase

var cfg: BalanceActors
var brain: TurtleBrain


func before_each() -> void:
	cfg = BalanceActors.new()
	cfg.turtle_stay_seconds = 30.0
	cfg.turtle_eat_seconds = 0.5
	cfg.turtle_max_algae = 0
	brain = TurtleBrain.new(cfg)


func test_threat_beats_closer_algae() -> void:
	var job := TurtleBrain.pick([500.0], [10.0], [160.0], [10.0])
	assert_eq(job["task"], TurtleBrain.Task.THREAT)
	assert_eq(job["index"], 0)


func test_nearest_reachable_threat_wins() -> void:
	var job := TurtleBrain.pick([INF, 300.0, 100.0], [10.0, 10.0, 10.0], [160.0, 160.0, 160.0], [])
	assert_eq(job["task"], TurtleBrain.Task.THREAT)
	assert_eq(job["index"], 2)


func test_unreachable_threats_fall_back_to_nearest_algae() -> void:
	var job := TurtleBrain.pick([INF], [10.0], [160.0], [80.0, 40.0, INF])
	assert_eq(job["task"], TurtleBrain.Task.ALGAE)
	assert_eq(job["index"], 1)


func test_threat_outside_its_aggro_radius_is_ignored() -> void:
	var job := TurtleBrain.pick([10.0], [500.0], [160.0], [80.0])
	assert_eq(job["task"], TurtleBrain.Task.ALGAE)
	assert_eq(job["index"], 0)


func test_each_threat_uses_its_own_aggro_radius() -> void:
	# A predator out of reach (index 0), a bag in reach even though farther (index 1).
	var job := TurtleBrain.pick([10.0, 20.0], [200.0, 300.0], [160.0, 320.0], [])
	assert_eq(job["task"], TurtleBrain.Task.THREAT)
	assert_eq(job["index"], 1)


func test_nearest_threat_inside_range_wins() -> void:
	var job := TurtleBrain.pick([100.0, 20.0], [50.0, 300.0], [160.0, 320.0], [])
	assert_eq(job["task"], TurtleBrain.Task.THREAT)
	assert_eq(job["index"], 1)


func test_locked_threat_is_kept_outside_its_radius() -> void:
	# Already chasing a predator that drifted out of range: keep it (no flip-flop).
	var job := TurtleBrain.pick([10.0], [500.0], [160.0], [80.0], 0)
	assert_eq(job["task"], TurtleBrain.Task.THREAT)
	assert_eq(job["index"], 0)


func test_locked_unreachable_threat_is_dropped() -> void:
	var job := TurtleBrain.pick([INF], [10.0], [160.0], [80.0], 0)
	assert_eq(job["task"], TurtleBrain.Task.ALGAE)
	assert_eq(job["index"], 0)


func test_nothing_to_do() -> void:
	var job := TurtleBrain.pick([INF], [10.0], [160.0], [INF])
	assert_eq(job["task"], TurtleBrain.Task.NONE)
	assert_eq(job["index"], -1)


func test_eats_faster_than_fish_by_default() -> void:
	var defaults := BalanceActors.new()
	assert_true(defaults.turtle_eat_seconds < defaults.eat_seconds)


func test_eating_finishes_after_eat_seconds() -> void:
	brain.start_eating()
	assert_eq(brain.state, TurtleBrain.State.EATING)
	assert_false(brain.tick(0.3))
	assert_true(brain.tick(0.3))
	assert_eq(brain.state, TurtleBrain.State.HELPING)
	assert_eq(brain.algae_eaten, 1)


func test_stop_eating_does_not_count() -> void:
	brain.start_eating()
	brain.stop_eating()
	assert_eq(brain.state, TurtleBrain.State.HELPING)
	assert_false(brain.tick(1.0))
	assert_eq(brain.algae_eaten, 0)


func test_leaves_after_removing_a_bag() -> void:
	brain.bag_removed()
	assert_eq(brain.state, TurtleBrain.State.LEAVING)


func test_leaves_when_stay_runs_out_only_on_island() -> void:
	brain.tick(40.0, false)
	assert_eq(brain.state, TurtleBrain.State.HELPING)
	brain.tick(29.0)
	assert_eq(brain.state, TurtleBrain.State.HELPING)
	brain.tick(1.0)
	assert_eq(brain.state, TurtleBrain.State.LEAVING)


func test_leaves_after_max_algae() -> void:
	cfg.turtle_max_algae = 2
	for i in 2:
		brain.start_eating()
		brain.tick(0.5)
	assert_eq(brain.state, TurtleBrain.State.LEAVING)


func test_unlimited_algae_when_max_is_zero() -> void:
	for i in 10:
		brain.start_eating()
		brain.tick(0.5)
	assert_eq(brain.state, TurtleBrain.State.HELPING)
	assert_eq(brain.algae_eaten, 10)


func test_custom_max_algae_overrides_the_balance_value() -> void:
	# The early-rush turtles leave after a few algae even though the shared
	# turtle_max_algae is 0 (unlimited).
	var capped := TurtleBrain.new(cfg, 2)
	for i in 2:
		capped.start_eating()
		capped.tick(0.5)
	assert_eq(capped.algae_eaten, 2)
	assert_eq(capped.state, TurtleBrain.State.LEAVING)


func test_negative_override_uses_the_balance_value() -> void:
	cfg.turtle_max_algae = 1
	var default_cap := TurtleBrain.new(cfg, -1)
	default_cap.start_eating()
	default_cap.tick(0.5)
	assert_eq(default_cap.state, TurtleBrain.State.LEAVING)


func test_cannot_start_eating_while_leaving() -> void:
	brain.bag_removed()
	brain.start_eating()
	assert_eq(brain.state, TurtleBrain.State.LEAVING)
