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


func _make_brain(adult: bool, reproduce_cooldown := -1.0) -> FishBrain:
	var b := FishBrain.new(cfg, adult, reproduce_cooldown)
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


func test_not_hungry_does_not_seek_food() -> void:
	brain.tick(29.0) # ratio 0.48 < 0.5
	assert_false(brain.wants_to_seek_food())


func test_hungry_wandering_fish_seeks_food() -> void:
	brain.tick(31.0)
	assert_true(brain.wants_to_seek_food())
	brain.seek_food(food)
	assert_eq(brain.state, FishBrain.State.SEEKING_FOOD)
	assert_true(brain.food == food)
	assert_true(brain.wants_to_move())
	assert_false(brain.wants_to_seek_food())


func test_seeking_fish_eats_on_algae_contact() -> void:
	brain.tick(31.0)
	brain.seek_food(food)
	brain.blocked_by_algae(food)
	assert_eq(brain.state, FishBrain.State.EATING)
	brain.tick(3.0)
	assert_eq(eaten, [food])
	assert_almost(brain.hunger, 0.0)
	assert_false(brain.wants_to_seek_food(), "fed fish is not hungry anymore")


func test_busy_fish_does_not_seek_food() -> void:
	brain.tick(31.0)
	brain.order(Vector2(10, 0))
	assert_false(brain.wants_to_seek_food())
	brain.seek_food(food)
	assert_eq(brain.state, FishBrain.State.ORDERED, "seeking never overrides an order")


func test_order_overrides_seeking() -> void:
	brain.tick(31.0)
	brain.seek_food(food)
	brain.order(Vector2(10, 0))
	assert_eq(brain.state, FishBrain.State.ORDERED)
	assert_true(brain.food == null)


func test_seek_failed_waits_before_retrying() -> void:
	brain.tick(31.0)
	brain.seek_failed()
	assert_false(brain.wants_to_seek_food())
	brain.tick(cfg.seek_retry_seconds * 0.5)
	assert_false(brain.wants_to_seek_food())
	brain.tick(cfg.seek_retry_seconds * 0.6)
	assert_true(brain.wants_to_seek_food())


func test_seeking_blocked_by_other_wanders_and_waits() -> void:
	brain.tick(31.0)
	brain.seek_food(food)
	brain.blocked_by_other()
	assert_eq(brain.state, FishBrain.State.WANDER)
	assert_false(brain.wants_to_seek_food())


func test_seeking_food_lost_wanders() -> void:
	brain.tick(31.0)
	brain.seek_food(food)
	brain.food_lost()
	assert_eq(brain.state, FishBrain.State.WANDER)
	assert_true(brain.food == null)
	assert_true(brain.wants_to_seek_food(), "can pick another algae right away")


func test_arrived_is_ignored_while_seeking() -> void:
	brain.tick(31.0)
	brain.seek_food(food)
	brain.arrived(nest)
	assert_eq(brain.state, FishBrain.State.SEEKING_FOOD)


func test_seeking_fish_can_switch_target() -> void:
	var other := RefCounted.new()
	brain.tick(31.0)
	brain.seek_food(food)
	brain.seek_food(other)
	assert_eq(brain.state, FishBrain.State.SEEKING_FOOD)
	assert_true(brain.food == other)


func test_waits_for_reproduce_cooldown() -> void:
	var ready := _make_brain(true, 5.0)
	assert_false(ready.wants_to_seek_nest(), "not ready right after creation")
	ready.tick(5.1)
	assert_true(ready.wants_to_seek_nest())


func test_juvenile_never_seeks_nest() -> void:
	assert_false(_make_brain(false, 0.0).wants_to_seek_nest())


func test_hungry_adult_does_not_seek_nest() -> void:
	var ready := _make_brain(true, 0.0)
	ready.tick(30.0) # 30 / 45 = 67 % > seek_food_threshold
	assert_false(ready.wants_to_seek_nest())


func test_seek_nest_holds_target() -> void:
	var ready := _make_brain(true, 0.0)
	ready.seek_nest(nest)
	assert_eq(ready.state, FishBrain.State.SEEKING_NEST)
	assert_true(ready.nest == nest)
	assert_true(ready.wants_to_move())
	assert_false(ready.wants_to_seek_nest())


func test_nest_reached_starts_fertilizing_and_restarts_cooldown() -> void:
	var ready := _make_brain(true, 5.0)
	ready.tick(5.1)
	ready.seek_nest(nest)
	ready.nest_reached(nest)
	assert_eq(ready.state, FishBrain.State.FERTILIZING)
	ready.tick(3.1)
	assert_eq(ready.state, FishBrain.State.WANDER)
	assert_eq(fertilized, [nest])
	assert_false(ready.wants_to_seek_nest(), "cooldown restarted after success")


func test_nest_reached_without_empty_nest_abandons() -> void:
	var ready := _make_brain(true, 0.0)
	ready.seek_nest(nest)
	ready.nest_reached(null)
	assert_eq(ready.state, FishBrain.State.WANDER)
	assert_false(ready.wants_to_seek_nest(), "waits before retrying")


func test_nest_lost_waits_before_retrying() -> void:
	var ready := _make_brain(true, 0.0)
	ready.seek_nest(nest)
	ready.nest_lost()
	assert_eq(ready.state, FishBrain.State.WANDER)
	assert_false(ready.wants_to_seek_nest())
	ready.tick(cfg.seek_retry_seconds + 0.1)
	assert_true(ready.wants_to_seek_nest())


func test_hungry_fish_abandons_nest() -> void:
	var ready := _make_brain(true, 0.0)
	ready.seek_nest(nest)
	ready.tick(cfg.starve_seconds * cfg.seek_food_threshold + 0.1)
	assert_eq(ready.state, FishBrain.State.WANDER)
	assert_true(ready.nest == null, "hunger has priority over reproduction")


func test_order_cancels_nest_seek() -> void:
	var ready := _make_brain(true, 0.0)
	ready.seek_nest(nest)
	ready.order(Vector2(10, 0))
	assert_eq(ready.state, FishBrain.State.ORDERED)
	assert_true(ready.nest == null)


func test_nest_seek_blocked_returns_to_wander_with_retry() -> void:
	var ready := _make_brain(true, 0.0)
	ready.seek_nest(nest)
	ready.blocked_by_other()
	assert_eq(ready.state, FishBrain.State.WANDER)
	assert_false(ready.wants_to_seek_nest())


func test_effective_cooldown_is_twice_hatch_at_least() -> void:
	var cfg2 := BalanceActors.new()
	cfg2.reproduce_cooldown_seconds = 40.0
	assert_almost(FishBrain.effective_reproduce_cooldown(cfg2, 25.0), 50.0)
	assert_almost(FishBrain.effective_reproduce_cooldown(cfg2, 10.0), 40.0)
