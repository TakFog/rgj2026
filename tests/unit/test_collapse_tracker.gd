extends TestCase

var tracker: CollapseTracker


func before_each() -> void:
	tracker = CollapseTracker.new(10.0)


func test_no_countdown_while_population_alive() -> void:
	tracker.report(&"fish", 3)
	tracker.tick(5.0)
	assert_false(tracker.is_counting(&"fish"))
	assert_almost(tracker.time_left(&"fish"), -1.0)
	assert_false(tracker.is_collapsed())


func test_zero_starts_full_countdown() -> void:
	tracker.report(&"fish", 0)
	assert_true(tracker.is_counting(&"fish"))
	assert_almost(tracker.time_left(&"fish"), 10.0)


func test_tick_counts_down() -> void:
	tracker.report(&"fish", 0)
	tracker.tick(4.0)
	assert_almost(tracker.time_left(&"fish"), 6.0)


func test_recovery_cancels_countdown() -> void:
	tracker.report(&"fish", 0)
	tracker.tick(4.0)
	tracker.report(&"fish", 2)
	tracker.tick(20.0)
	assert_false(tracker.is_counting(&"fish"))
	assert_false(tracker.is_collapsed())


func test_new_zero_restarts_from_full() -> void:
	tracker.report(&"fish", 0)
	tracker.tick(7.0)
	tracker.report(&"fish", 1)
	tracker.report(&"fish", 0)
	assert_almost(tracker.time_left(&"fish"), 10.0)


func test_expiry_collapses_with_population() -> void:
	tracker.report(&"fish", 0)
	tracker.tick(9.9)
	assert_false(tracker.is_collapsed())
	tracker.tick(0.2)
	assert_true(tracker.is_collapsed())
	assert_eq(tracker.collapsed_population, &"fish")


func test_countdowns_are_independent_and_first_expiry_wins() -> void:
	tracker.report(&"fish", 0)
	tracker.tick(3.0)
	tracker.report(&"algae", 0)
	assert_almost(tracker.time_left(&"algae"), 10.0)
	tracker.tick(7.5)
	assert_true(tracker.is_collapsed())
	assert_eq(tracker.collapsed_population, &"fish")


func test_collapse_is_final() -> void:
	tracker.report(&"nests", 0)
	tracker.tick(10.0)
	tracker.report(&"nests", 4)
	tracker.tick(1.0)
	assert_true(tracker.is_collapsed())
	assert_eq(tracker.collapsed_population, &"nests")


func test_most_urgent_is_lowest_time_left() -> void:
	assert_eq(tracker.most_urgent(), &"")
	tracker.report(&"algae", 0)
	tracker.tick(4.0)
	tracker.report(&"corals", 0)
	assert_eq(tracker.most_urgent(), &"algae")


func test_signals() -> void:
	var started := []
	var cancelled := []
	var collapsed := []
	tracker.countdown_started.connect(func(p: StringName) -> void: started.append(p))
	tracker.countdown_cancelled.connect(func(p: StringName) -> void: cancelled.append(p))
	tracker.collapsed.connect(func(p: StringName) -> void: collapsed.append(p))
	tracker.report(&"fish", 0)
	tracker.report(&"fish", 0)
	tracker.report(&"fish", 2)
	tracker.report(&"algae", 0)
	tracker.tick(10.0)
	assert_eq(started, [&"fish", &"algae"])
	assert_eq(cancelled, [&"fish"])
	assert_eq(collapsed, [&"algae"])
