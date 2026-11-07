extends TestCase

var eco: BalanceEcosystem
var rng: RandomNumberGenerator
var nests_on_map := 0
var inventory: InventoryModel


func before_each() -> void:
	eco = BalanceEcosystem.new()
	rng = RandomNumberGenerator.new()
	rng.seed = 7
	nests_on_map = 0
	inventory = InventoryModel.new(eco, rng, _count_nests_on_map)


func _count_nests_on_map() -> int:
	return nests_on_map


func _only(kind: StringName) -> void:
	eco.weight_coral = 1.0 if kind == InventoryModel.CORAL else 0.0
	eco.weight_algae = 1.0 if kind == InventoryModel.ALGAE else 0.0
	eco.nest_base_weight = 1.0 if kind == InventoryModel.NEST else 0.0


func test_has_configured_slot_count_and_starts_empty() -> void:
	assert_eq(inventory.slots.size(), 4)
	assert_false(inventory.is_ready(0))


func test_fill_all_fills_every_slot() -> void:
	inventory.fill_all()
	for i in 4:
		assert_true(inventory.is_ready(i))


func test_take_empties_slot_and_refills_after_timer() -> void:
	_only(InventoryModel.ALGAE)
	inventory.fill_all()
	var taken := inventory.take(1)
	assert_eq(taken["kind"], InventoryModel.ALGAE)
	assert_false(inventory.is_ready(1))
	inventory.tick(4.0)
	assert_almost(inventory.refill_ratio(1), 0.5)
	assert_false(inventory.is_ready(1))
	inventory.tick(4.1)
	assert_true(inventory.is_ready(1))
	assert_almost(inventory.refill_ratio(1), 1.0)


func test_other_slots_are_not_affected_by_a_refill() -> void:
	inventory.fill_all()
	var before := inventory.item(0)
	inventory.take(2)
	inventory.tick(10.0)
	assert_eq(inventory.item(0), before)


func test_coral_items_carry_a_known_shape() -> void:
	_only(InventoryModel.CORAL)
	var item := inventory.draw()
	assert_eq(item["kind"], InventoryModel.CORAL)
	assert_true(CoralShapes.ids().has(item["shape_id"]))


func test_nest_weight_drops_with_nests_on_map_and_in_inventory() -> void:
	assert_almost(inventory.nest_weight(), 20.0)
	nests_on_map = 1
	assert_almost(inventory.nest_weight(), 10.0)
	_only(InventoryModel.NEST)
	inventory.fill_all()
	eco.nest_base_weight = 20.0
	assert_almost(inventory.nest_weight(), 20.0 / 6.0)


func test_draw_follows_weights_roughly() -> void:
	var counts := {InventoryModel.CORAL: 0, InventoryModel.ALGAE: 0, InventoryModel.NEST: 0}
	nests_on_map = 1 # nest weight 10 -> 50 / 40 / 10 of 100
	for i in 2000:
		counts[inventory.draw()["kind"]] += 1
	assert_almost(counts[InventoryModel.CORAL] / 2000.0, 0.5, 0.05)
	assert_almost(counts[InventoryModel.ALGAE] / 2000.0, 0.4, 0.05)
	assert_almost(counts[InventoryModel.NEST] / 2000.0, 0.1, 0.05)


func test_changed_is_emitted_on_take() -> void:
	inventory.fill_all()
	var emitted := [0]
	inventory.changed.connect(func(): emitted[0] += 1)
	inventory.take(0)
	assert_eq(emitted[0], 1)
