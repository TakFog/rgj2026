extends TestCase


class FakeNest:
	extends RefCounted
	var left: float

	func _init(p_left: float) -> void:
		left = p_left

	func eggs_time_left() -> float:
		return left


func test_soonest_hatch_without_nests() -> void:
	assert_almost(PopulationMonitor.soonest_hatch([]), -1.0)


func test_soonest_hatch_ignores_nests_without_eggs() -> void:
	assert_almost(PopulationMonitor.soonest_hatch([FakeNest.new(-1.0), FakeNest.new(-1.0)]), -1.0)


func test_soonest_hatch_picks_smallest_positive() -> void:
	var nests := [FakeNest.new(-1.0), FakeNest.new(12.0), FakeNest.new(5.0)]
	assert_almost(PopulationMonitor.soonest_hatch(nests), 5.0)
