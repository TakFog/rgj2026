extends TestCase

var cfg: BalanceActors
var brain: PredatorBrain


func before_each() -> void:
	cfg = BalanceActors.new()
	cfg.predator_satiety = 6.0
	cfg.predator_juvenile_satisfaction = 1.0
	cfg.predator_adult_satisfaction = 2.0
	cfg.predator_hunt_seconds = 45.0
	cfg.predator_bite_pause_seconds = 1.0
	brain = PredatorBrain.new(cfg)


func test_eggs_worth_juvenile_times_hatch_count() -> void:
	assert_almost(PredatorBrain.satisfaction(cfg, PredatorBrain.Prey.EGGS, 3), 3.0)
	assert_almost(PredatorBrain.satisfaction(cfg, PredatorBrain.Prey.ADULT, 3), 2.0)
	assert_almost(PredatorBrain.satisfaction(cfg, PredatorBrain.Prey.JUVENILE, 3), 1.0)


func test_default_order_is_eggs_then_adults_then_juveniles() -> void:
	var defaults := BalanceActors.new()
	var eggs := PredatorBrain.satisfaction(defaults, PredatorBrain.Prey.EGGS, 3)
	var adult := PredatorBrain.satisfaction(defaults, PredatorBrain.Prey.ADULT, 3)
	var juvenile := PredatorBrain.satisfaction(defaults, PredatorBrain.Prey.JUVENILE, 3)
	assert_true(eggs > adult and adult > juvenile)


func test_pick_best_weighs_satisfaction_by_distance() -> void:
	var candidates := [
		{"satisfaction": 1.0, "distance": 50.0}, # 0.02
		{"satisfaction": 3.0, "distance": 100.0}, # 0.03
		{"satisfaction": 2.0, "distance": 200.0}, # 0.01
	]
	assert_eq(PredatorBrain.pick_best(candidates), 1)


func test_pick_best_prefers_near_cheap_prey_over_far_rich_prey() -> void:
	var candidates := [
		{"satisfaction": 3.0, "distance": 400.0},
		{"satisfaction": 1.0, "distance": 40.0},
	]
	assert_eq(PredatorBrain.pick_best(candidates), 1)


func test_pick_best_ignores_unreachable() -> void:
	var candidates := [
		{"satisfaction": 3.0, "distance": INF},
		{"satisfaction": 1.0, "distance": 300.0},
	]
	assert_eq(PredatorBrain.pick_best(candidates), 1)
	assert_eq(PredatorBrain.pick_best([{"satisfaction": 3.0, "distance": INF}]), -1)
	assert_eq(PredatorBrain.pick_best([]), -1)


func test_pause_after_bite_then_hunts_again() -> void:
	brain.ate(2.0)
	assert_eq(brain.state, PredatorBrain.State.BITING)
	brain.tick(0.5)
	assert_eq(brain.state, PredatorBrain.State.BITING)
	brain.tick(0.6)
	assert_eq(brain.state, PredatorBrain.State.HUNTING)


func test_leaves_when_sated() -> void:
	brain.ate(3.0)
	brain.tick(2.0)
	brain.ate(3.0)
	assert_eq(brain.state, PredatorBrain.State.LEAVING)
	assert_almost(brain.satiety_ratio(), 1.0)


func test_leaves_when_hunt_time_runs_out() -> void:
	brain.tick(44.9)
	assert_eq(brain.state, PredatorBrain.State.HUNTING)
	brain.tick(0.2)
	assert_eq(brain.state, PredatorBrain.State.LEAVING)


func test_leaving_is_final() -> void:
	brain.tick(50.0)
	brain.ate(1.0)
	brain.tick(1.0)
	assert_eq(brain.state, PredatorBrain.State.LEAVING)


func test_hunt_time_only_runs_on_the_island() -> void:
	brain.tick(100.0, false)
	assert_eq(brain.state, PredatorBrain.State.HUNTING)
	assert_almost(brain.hunt_time, 0.0)
