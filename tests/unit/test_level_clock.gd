extends TestCase
## The level countdown reports its single clear exactly once.

func test_starts_at_full_duration() -> void:
	var clock := LevelClock.new(60.0)
	assert_almost(clock.remaining, 60.0)
	assert_false(clock.finished)


func test_tick_subtracts_and_reports_elapsed() -> void:
	var clock := LevelClock.new(60.0)
	assert_false(clock.tick(15.0))
	assert_almost(clock.remaining, 45.0)
	assert_almost(clock.elapsed(), 15.0)


func test_clear_is_reported_once_at_zero() -> void:
	var clock := LevelClock.new(10.0)
	assert_false(clock.tick(9.9))
	assert_true(clock.tick(0.2))
	assert_almost(clock.remaining, 0.0)
	assert_true(clock.finished)
	assert_false(clock.tick(1.0), "a finished clock must stay silent")


func test_negative_duration_cannot_go_below_zero() -> void:
	var clock := LevelClock.new(-5.0)
	assert_almost(clock.duration, 0.0)
	assert_true(clock.tick(0.1))


func test_zero_or_negative_steps_do_nothing() -> void:
	var clock := LevelClock.new(10.0)
	assert_false(clock.tick(0.0))
	assert_false(clock.tick(-3.0))
	assert_almost(clock.remaining, 10.0)
