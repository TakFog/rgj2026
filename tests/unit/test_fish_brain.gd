extends TestCase

var cfg: BalanceActors
var brain: FishBrain
var food: RefCounted
var nest: RefCounted
## Signal logs. The lambdas capture these arrays (not `self`), so the brain
## does not keep the test alive through a reference cycle.
var starved_log: Array = []
var matured_log: Array = []
var eaten: Array = []
var fertilized: Array = []


func before_each() -> void:
	cfg = BalanceActors.new() # GDD defaults: starve 60, maturity 45, eat 3, fertilize 3, idle 2
	brain = _make_brain(true)
	food = RefCounted.new()
	nest = RefCounted.new()


func _make_brain(adult: bool) -> FishBrain:
	var b := FishBrain.new(cfg, adult)
	var s_log := starved_log
	var m_log := matured_log
	var e_log := eaten
	var f_log := fertilized
	b.starved.connect(func() -> void: s_log.append(true))
	b.matured.connect(func() -> void: m_log.append(true))
	b.eat_finished.connect(func(algae: Object) -> void: e_log.append(algae))
	b.fertilize_finished.connect(func(n: Object) -> void: f_log.append(n))
	return b


func test_starts_wandering() -> void:
	assert_eq(brain.state, FishBrain.State.WANDER)
	assert_true(brain.wants_to_move())


func test_order_sets_target() -> void:
	brain.order(Vector2(100, 50))
	assert_eq(brain.state, FishBrain.State.ORDERED)
	assert_almost(brain.target, Vector2(100, 50))
	assert_true(brain.wants_to_move())


func test_wandering_fish_ignores_algae() -> void:
	brain.blocked_by_algae(food)
	assert_eq(brain.state, FishBrain.State.WANDER)
	assert_true(brain.food == null)


func test_eating_completes_and_resets_hunger() -> void:
	brain.order(Vector2(10, 0))
	brain.tick(30.0)
	brain.blocked_by_algae(food)
	assert_eq(brain.state, FishBrain.State.EATING)
	assert_false(brain.wants_to_move())
	brain.tick(2.0)
	assert_eq(brain.state, FishBrain.State.EATING)
	brain.tick(1.5)
	assert_eq(brain.state, FishBrain.State.WANDER)
	assert_almost(brain.hunger, 0.0)
	assert_eq(eaten.size(), 1)
	assert_true(eaten[0] == food)


func test_food_lost_returns_to_wander_without_feeding() -> void:
	brain.order(Vector2(10, 0))
	brain.tick(10.0)
	brain.blocked_by_algae(food)
	brain.food_lost()
	assert_eq(brain.state, FishBrain.State.WANDER)
	assert_almost(brain.hunger, 10.0)
	brain.tick(5.0)
	assert_eq(eaten.size(), 0)


func test_adult_arriving_on_empty_nest_fertilizes() -> void:
	brain.order(Vector2(10, 0))
	brain.arrived(nest)
	assert_eq(brain.state, FishBrain.State.FERTILIZING)
	assert_false(brain.wants_to_move())
	brain.tick(3.1)
	assert_eq(brain.state, FishBrain.State.WANDER)
	assert_eq(fertilized.size(), 1)
	assert_true(fertilized[0] == nest)


func test_juvenile_on_nest_only_idles() -> void:
	var young := _make_brain(false)
	young.order(Vector2(10, 0))
	young.arrived(nest)
	assert_eq(young.state, FishBrain.State.IDLE)
	young.tick(5.0)
	assert_eq(fertilized.size(), 0)


func test_new_order_cancels_fertilizing() -> void:
	brain.order(Vector2(10, 0))
	brain.arrived(nest)
	brain.tick(1.0)
	brain.order(Vector2(200, 0))
	assert_eq(brain.state, FishBrain.State.ORDERED)
	assert_true(brain.nest == null)
	brain.tick(5.0)
	assert_eq(fertilized.size(), 0)


func test_arrived_without_nest_idles_then_wanders() -> void:
	brain.order(Vector2(10, 0))
	brain.arrived(null)
	assert_eq(brain.state, FishBrain.State.IDLE)
	brain.tick(1.0)
	assert_eq(brain.state, FishBrain.State.IDLE)
	brain.tick(1.5)
	assert_eq(brain.state, FishBrain.State.WANDER)


func test_blocked_by_other_idles() -> void:
	brain.order(Vector2(10, 0))
	brain.blocked_by_other()
	assert_eq(brain.state, FishBrain.State.IDLE)


func test_starves_once() -> void:
	brain.tick(59.0)
	assert_false(brain.dead)
	brain.tick(2.0)
	assert_true(brain.dead)
	assert_false(brain.wants_to_move())
	brain.tick(5.0)
	assert_eq(starved_log.size(), 1)


func test_juvenile_matures_once() -> void:
	var young := _make_brain(false)
	assert_false(young.is_adult())
	young.tick(44.0)
	assert_false(young.is_adult())
	young.tick(2.0)
	assert_true(young.is_adult())
	young.tick(2.0)
	assert_eq(matured_log.size(), 1)


func test_hunger_ratio() -> void:
	brain.tick(30.0)
	assert_almost(brain.hunger_ratio(), 0.5)
