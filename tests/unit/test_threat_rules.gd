extends TestCase

var actors: BalanceActors


func before_each() -> void:
	actors = BalanceActors.new()


func _resolve(kind: int, target: int, nest_has_eggs := false, already_hit := false) -> ThreatRules.Outcome:
	return ThreatRules.resolve(kind, target, actors, nest_has_eggs, already_hit)


func test_co2_damages_coral_and_goes_through() -> void:
	var outcome := _resolve(ThreatSchedule.Type.CO2, ThreatRules.Target.CORAL)
	assert_eq(outcome.effect, ThreatRules.Effect.DAMAGE_CORAL)
	assert_almost(outcome.amount, 50.0)
	assert_false(outcome.threat_dies, "corals must not destroy the cloud")


func test_co2_dies_on_coral_when_the_debug_flag_is_on() -> void:
	actors.co2_dies_on_coral = true
	var outcome := _resolve(ThreatSchedule.Type.CO2, ThreatRules.Target.CORAL)
	assert_eq(outcome.effect, ThreatRules.Effect.DAMAGE_CORAL)
	assert_true(outcome.threat_dies)


func test_co2_damages_the_same_coral_only_once_while_passing_through() -> void:
	var outcome := _resolve(ThreatSchedule.Type.CO2, ThreatRules.Target.CORAL, false, true)
	assert_eq(outcome.effect, ThreatRules.Effect.NOTHING)
	assert_false(outcome.threat_dies)


func test_co2_is_absorbed_by_algae() -> void:
	var outcome := _resolve(ThreatSchedule.Type.CO2, ThreatRules.Target.ALGAE)
	assert_eq(outcome.effect, ThreatRules.Effect.ABSORB_CO2)
	assert_true(outcome.threat_dies)


func test_co2_kills_eggs_only_when_present() -> void:
	var with_eggs := _resolve(ThreatSchedule.Type.CO2, ThreatRules.Target.NEST, true)
	assert_eq(with_eggs.effect, ThreatRules.Effect.KILL_EGGS)
	assert_false(with_eggs.threat_dies)
	var empty := _resolve(ThreatSchedule.Type.CO2, ThreatRules.Target.NEST, false)
	assert_eq(empty.effect, ThreatRules.Effect.NOTHING)


func test_co2_ignores_fish_and_threats() -> void:
	assert_eq(_resolve(ThreatSchedule.Type.CO2, ThreatRules.Target.FISH).effect, ThreatRules.Effect.NOTHING)
	assert_eq(_resolve(ThreatSchedule.Type.CO2, ThreatRules.Target.THREAT).effect, ThreatRules.Effect.NOTHING)


func test_bag_kills_fish_and_stays() -> void:
	var outcome := _resolve(ThreatSchedule.Type.BAG, ThreatRules.Target.FISH)
	assert_eq(outcome.effect, ThreatRules.Effect.DESTROY)
	assert_false(outcome.threat_dies)


func test_bag_damages_coral_and_disappears() -> void:
	var outcome := _resolve(ThreatSchedule.Type.BAG, ThreatRules.Target.CORAL)
	assert_eq(outcome.effect, ThreatRules.Effect.DAMAGE_CORAL)
	assert_almost(outcome.amount, 35.0)
	assert_true(outcome.threat_dies)


func test_bag_ignores_algae_nests_and_threats() -> void:
	for target in [ThreatRules.Target.ALGAE, ThreatRules.Target.NEST, ThreatRules.Target.THREAT]:
		var outcome := _resolve(ThreatSchedule.Type.BAG, target, true)
		assert_eq(outcome.effect, ThreatRules.Effect.NOTHING, "target %d" % target)
		assert_false(outcome.threat_dies)


func test_cyclone_destroys_fish_algae_nests_threats_and_keeps_going() -> void:
	for target in [ThreatRules.Target.FISH, ThreatRules.Target.ALGAE, ThreatRules.Target.NEST, ThreatRules.Target.THREAT]:
		var outcome := _resolve(ThreatSchedule.Type.CYCLONE, target)
		assert_eq(outcome.effect, ThreatRules.Effect.DESTROY, "target %d" % target)
		assert_false(outcome.threat_dies)


func test_nothing_reacts_to_a_cyclone() -> void:
	for kind in [ThreatSchedule.Type.CO2, ThreatSchedule.Type.BAG, ThreatSchedule.Type.CYCLONE]:
		var outcome := _resolve(kind, ThreatRules.Target.CYCLONE)
		assert_eq(outcome.effect, ThreatRules.Effect.NOTHING, "kind %d" % kind)
		assert_false(outcome.threat_dies)


func test_target_of_tells_cyclones_from_other_threats() -> void:
	var cyclone := Cyclone.new()
	cyclone.add_to_group(Groups.THREATS)
	var bag := PlasticBag.new()
	bag.add_to_group(Groups.THREATS)
	assert_eq(ThreatRules.target_of(cyclone), ThreatRules.Target.CYCLONE)
	assert_eq(ThreatRules.target_of(bag), ThreatRules.Target.THREAT)
	cyclone.free()
	bag.free()


func test_cyclone_kills_coral_and_stops() -> void:
	var outcome := _resolve(ThreatSchedule.Type.CYCLONE, ThreatRules.Target.CORAL)
	assert_eq(outcome.effect, ThreatRules.Effect.DESTROY)
	assert_true(outcome.threat_dies)


func test_target_of_uses_groups() -> void:
	var coral := Node.new()
	coral.add_to_group(Groups.CORALS)
	var threat := Node.new()
	threat.add_to_group(Groups.THREATS)
	var plain := Node.new()
	assert_eq(ThreatRules.target_of(coral), ThreatRules.Target.CORAL)
	assert_eq(ThreatRules.target_of(threat), ThreatRules.Target.THREAT)
	assert_eq(ThreatRules.target_of(plain), ThreatRules.Target.NONE)
	coral.free()
	threat.free()
	plain.free()
