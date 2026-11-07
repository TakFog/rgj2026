extends TestCase


func _spin(seed_value: int, max_speed := 1.0) -> TumbleSpin:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return TumbleSpin.new(max_speed, rng)


func test_zero_speed_freezes_the_angle() -> void:
	var spin := _spin(1, 0.0)
	var angle := spin.step(0.1)
	for i in 50:
		assert_almost(spin.step(0.25), angle)
	assert_almost(spin.rate, 0.0)


func test_step_never_exceeds_max_speed() -> void:
	var spin := _spin(5, 1.0)
	var angle := spin.angle
	for i in 400:
		var next := spin.step(0.05)
		assert_true(absf(wrapf(next - angle, -PI, PI)) <= 1.0 * 0.05 + 0.000001,
				"step %d moved %f" % [i, wrapf(next - angle, -PI, PI)])
		angle = next


func test_rate_stays_within_max_speed() -> void:
	var spin := _spin(7, 2.0)
	for i in 400:
		spin.step(0.05)
		assert_true(absf(spin.rate) <= 2.0 + 0.000001, "rate %f" % spin.rate)


func test_angle_stays_wrapped() -> void:
	var spin := _spin(9, 4.0)
	for i in 400:
		assert_true(absf(spin.step(0.05)) <= PI + 0.000001)


func test_both_directions_occur_across_seeds() -> void:
	var seen_positive := false
	var seen_negative := false
	for seed_value in range(1, 21):
		var spin := _spin(seed_value, 1.0)
		for i in 200:
			spin.step(0.05)
			seen_positive = seen_positive or spin.rate > 0.0
			seen_negative = seen_negative or spin.rate < 0.0
	assert_true(seen_positive, "no clockwise spin")
	assert_true(seen_negative, "no counter-clockwise spin")


func test_speed_varies_between_stall_and_spin() -> void:
	var spin := _spin(3, 1.0)
	var slowest := 1.0
	var fastest := 0.0
	for i in 400:
		spin.step(0.05)
		slowest = minf(slowest, absf(spin.rate))
		fastest = maxf(fastest, absf(spin.rate))
	assert_true(slowest < 0.3, "never nearly stopped, slowest %f" % slowest)
	assert_true(fastest > 0.5, "never really spun, fastest %f" % fastest)


func test_direction_reverses() -> void:
	var spin := _spin(3, 1.0)
	var reversed := false
	for i in 400:
		var before := signf(spin.rate)
		spin.step(0.05)
		if before != 0.0 and signf(spin.rate) == -before:
			reversed = true
	assert_true(reversed, "never changed direction")


func test_same_seed_gives_the_same_angles() -> void:
	var a := _spin(11, 1.5)
	var b := _spin(11, 1.5)
	for i in 200:
		assert_almost(a.step(0.05), b.step(0.05))
