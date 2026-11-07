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
	var job := TurtleBrain.pick([500.0], [10.0])
	assert_eq(job["task"], TurtleBrain.Task.THREAT)
	assert_eq(job["index"], 0)


func test_nearest_reachable_threat_wins() -> void:
	var job := TurtleBrain.pick([INF, 300.0, 100.0], [])
	assert_eq(job["task"], TurtleBrain.Task.THREAT)
	assert_eq(job["index"], 2)


func test_unreachable_threats_fall_back_to_nearest_algae() -> void:
	var job := TurtleBrain.pick([INF], [80.0, 40.0, INF])
	assert_eq(job["task"], TurtleBrain.Task.ALGAE)
	assert_eq(job["index"], 1)


func test_nothing_to_do() -> void:
	var job := TurtleBrain.pick([INF], [INF])
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


func test_cannot_start_eating_while_leaving() -> void:
	brain.bag_removed()
	brain.start_eating()
	assert_eq(brain.state, TurtleBrain.State.LEAVING)
