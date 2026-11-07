extends TestCase


func test_zero_noise_keeps_heading() -> void:
	var drift := DriftMotion.new(0.0, RandomNumberGenerator.new())
	for i in 10:
		assert_almost(drift.step(1.25, 0.1), 1.25)


func test_turn_per_step_is_bounded_by_noise() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var drift := DriftMotion.new(2.0, rng)
	var heading := 0.0
	for i in 500:
		var next := drift.step(heading, 0.05)
		assert_true(absf(next - heading) <= 2.0 * 0.05 + 0.000001, "step %d turned %f" % [i, next - heading])
		heading = next


func test_heading_changes_over_time() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var drift := DriftMotion.new(0.6, rng)
	var heading := 0.0
	for i in 200:
		heading = drift.step(heading, 0.1)
	assert_true(absf(heading) > 0.01, "heading %f" % heading)


func test_same_seed_gives_same_path() -> void:
	var a := RandomNumberGenerator.new()
	var b := RandomNumberGenerator.new()
	a.seed = 11
	b.seed = 11
	var drift_a := DriftMotion.new(2.0, a)
	var drift_b := DriftMotion.new(2.0, b)
	var heading_a := 0.0
	var heading_b := 0.0
	for i in 50:
		heading_a = drift_a.step(heading_a, 0.1)
		heading_b = drift_b.step(heading_b, 0.1)
	assert_almost(heading_a, heading_b)
