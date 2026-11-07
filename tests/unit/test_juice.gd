extends TestCase
## Guards the performance cap of the cosmetic particle system.

func test_particle_cap_is_enforced() -> void:
	var juice := Juice.new()
	for i in Juice.MAX_PARTICLES + 20:
		juice._add_particle(Vector2.ZERO, Vector2.ZERO, Color.WHITE, 1.0, 1.0, 0.0, 0.0)
	assert_eq(juice.get("_particles").size(), Juice.MAX_PARTICLES)
	juice.free()


func test_low_oxygen_threshold() -> void:
	assert_true(Juice.is_low_oxygen(30.0, 100.0))
	assert_true(Juice.is_low_oxygen(20.0, 100.0))
	assert_false(Juice.is_low_oxygen(30.1, 100.0))
	assert_false(Juice.is_low_oxygen(10.0, 0.0))


func test_hatch_progress_clamps() -> void:
	assert_almost(Juice.hatch_progress(20.0, 20.0), 0.0)
	assert_almost(Juice.hatch_progress(10.0, 20.0), 0.5)
	assert_almost(Juice.hatch_progress(0.0, 20.0), 1.0)
	assert_almost(Juice.hatch_progress(-5.0, 20.0), 1.0)
	assert_almost(Juice.hatch_progress(5.0, 0.0), 0.0)
