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


func test_zero_scale_keeps_heading_straight() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var drift := DriftMotion.new(2.0, rng)
	var heading := 0.7
	for i in 200:
		heading = drift.step(heading, 0.05, 0.0)
	assert_almost(heading, 0.7)


func test_scaled_step_is_bounded_by_scaled_noise() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var drift := DriftMotion.new(2.0, rng)
	var heading := 0.0
	for i in 500:
		var next := drift.step(heading, 0.05, 0.1)
		assert_true(absf(next - heading) <= 2.0 * 0.1 * 0.05 + 0.000001, "step %d turned %f" % [i, next - heading])
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


func test_steer_inward_turns_toward_island_center_when_outside() -> void:
	var previous_grid := Game.grid
	Game.grid = GridModel.new(Vector2i(10, 10), 10.0)  # 100 × 100 island, center (50, 50)
	var threat := Threat.new()
	autofree(threat)
	threat.position = Vector2(200, 200)  # well outside the island
	var heading := 0.0
	var target := (Vector2(50, 50) - Vector2(200, 200)).angle()
	var new_heading := threat._steer_inward(heading, 0.1)
	assert_true(absf(new_heading - target) < absf(heading - target), "heading %f did not move toward target %f" % [new_heading, target])
	Game.grid = previous_grid


func test_steer_inward_is_a_noop_inside_the_island() -> void:
	var previous_grid := Game.grid
	Game.grid = GridModel.new(Vector2i(10, 10), 10.0)
	var threat := Threat.new()
	autofree(threat)
	threat.position = Vector2(50, 50)  # inside the island
	assert_eq(threat._steer_inward(1.25, 0.1), 1.25)
	Game.grid = previous_grid


func test_cyclone_keeps_heading_when_outside_the_island() -> void:
	var previous_grid := Game.grid
	Game.grid = GridModel.new(Vector2i(10, 10), 10.0)  # 100 × 100 island, center (50, 50)
	var cyclone := Cyclone.new()
	autofree(cyclone)
	cyclone.position = Vector2(200, 200)  # well outside the island
	var heading := 0.7
	assert_eq(cyclone._steer_inward(heading, 0.1), heading, "cyclone must keep going straight")
	Game.grid = previous_grid
