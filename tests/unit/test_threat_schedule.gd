extends TestCase

var schedule: ThreatSchedule


func before_each() -> void:
	schedule = ThreatSchedule.new(BalanceActors.new())


func test_nothing_due_before_first_interval() -> void:
	assert_true(schedule.tick(29.9, 0.0).is_empty())


func test_co2_due_at_cold_interval() -> void:
	schedule.tick(29.9, 0.0)
	var due := schedule.tick(0.2, 0.0)
	assert_eq(due.count(ThreatSchedule.Type.CO2), 1)
	assert_eq(due.size(), 1)


func test_co2_is_faster_when_hot() -> void:
	var due := schedule.tick(8.01, 1.0)
	assert_eq(due.count(ThreatSchedule.Type.CO2), 1)
	assert_eq(due.size(), 1)


func test_bag_interval_ignores_temperature() -> void:
	var first := schedule.tick(39.9, 1.0)
	assert_eq(first.count(ThreatSchedule.Type.BAG), 0)
	var second := schedule.tick(0.2, 1.0)
	assert_eq(second.count(ThreatSchedule.Type.BAG), 1)


func test_types_run_independently() -> void:
	var due := schedule.tick(90.01, 0.0)
	assert_eq(due.count(ThreatSchedule.Type.CO2), 1)
	assert_eq(due.count(ThreatSchedule.Type.BAG), 1)
	assert_eq(due.count(ThreatSchedule.Type.CYCLONE), 1)


func test_huge_delta_spawns_at_most_one_per_type() -> void:
	var due := schedule.tick(1000.0, 1.0)
	assert_eq(due.count(ThreatSchedule.Type.CO2), 1)
	assert_eq(due.size(), 3)
	assert_true(schedule.tick(0.01, 1.0).is_empty())


func test_non_positive_interval_disables_type() -> void:
	var actors := BalanceActors.new()
	actors.bag_interval = 0.0
	actors.co2_interval_cold = -5.0
	schedule = ThreatSchedule.new(actors)
	var due := schedule.tick(1000.0, 0.0)
	assert_eq(due.count(ThreatSchedule.Type.BAG), 0)
	assert_eq(due.count(ThreatSchedule.Type.CO2), 0)
	assert_eq(due.count(ThreatSchedule.Type.CYCLONE), 1)


func test_interval_follows_temperature_curve() -> void:
	assert_almost(schedule.interval(ThreatSchedule.Type.CO2, 0.5), 19.0)
	assert_almost(schedule.interval(ThreatSchedule.Type.CO2, 2.0), 8.0)
	assert_almost(schedule.interval(ThreatSchedule.Type.CYCLONE, 0.0), 90.0)
	assert_almost(schedule.interval(ThreatSchedule.Type.BAG, 1.0), 40.0)
