extends TestCase
## Guards the performance cap of the cosmetic particle system.

func test_particle_cap_is_enforced() -> void:
	var juice := Juice.new()
	for i in Juice.MAX_PARTICLES + 20:
		juice._add_particle(Vector2.ZERO, Vector2.ZERO, Color.WHITE, 1.0, 1.0, 0.0, 0.0)
	assert_eq(juice.get("_particles").size(), Juice.MAX_PARTICLES)
	juice.free()
