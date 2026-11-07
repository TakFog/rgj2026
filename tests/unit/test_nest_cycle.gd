extends TestCase

var cycle: NestCycle
var hatched_counts: Array[int] = []


func before_each() -> void:
	cycle = NestCycle.new(20.0, 3)
	hatched_counts = []
	cycle.hatched.connect(_on_hatched)


func _on_hatched(count: int) -> void:
	hatched_counts.append(count)


func test_starts_empty_without_eggs() -> void:
	assert_eq(cycle.state, NestCycle.State.EMPTY)
	assert_almost(cycle.eggs_time_left(), -1.0)


func test_fertilize_starts_the_timer() -> void:
	assert_true(cycle.fertilize())
	assert_eq(cycle.state, NestCycle.State.EGGS)
	assert_almost(cycle.eggs_time_left(), 20.0)


func test_cannot_fertilize_twice() -> void:
	cycle.fertilize()
	cycle.tick(5.0)
	assert_false(cycle.fertilize())
	assert_almost(cycle.eggs_time_left(), 15.0)


func test_hatches_once_after_hatch_seconds() -> void:
	cycle.fertilize()
	cycle.tick(19.0)
	assert_eq(hatched_counts.size(), 0)
	cycle.tick(1.5)
	cycle.tick(30.0)
	assert_eq(hatched_counts, [3] as Array[int])
	assert_eq(cycle.state, NestCycle.State.EMPTY)


func test_kill_eggs_cancels_hatching() -> void:
	cycle.fertilize()
	cycle.tick(10.0)
	cycle.kill_eggs()
	cycle.tick(30.0)
	assert_eq(hatched_counts.size(), 0)
	assert_almost(cycle.eggs_time_left(), -1.0)


func test_can_be_fertilized_again_after_hatching() -> void:
	cycle.fertilize()
	cycle.tick(20.0)
	assert_true(cycle.fertilize())
