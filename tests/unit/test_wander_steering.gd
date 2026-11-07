extends TestCase

var rng: RandomNumberGenerator
var steer: WanderSteering


func before_each() -> void:
	rng = RandomNumberGenerator.new()
	rng.seed = 42
	steer = WanderSteering.new(rng, 1.5, 4.0)


func test_heading_is_unit_length() -> void:
	assert_almost(steer.heading.length(), 1.0)


func test_heading_is_kept_before_min_duration() -> void:
	var first := steer.tick(0.1)
	assert_almost(steer.tick(1.0), first)


func test_heading_changes_after_max_duration() -> void:
	var first := steer.heading
	steer.tick(4.1)
	assert_true(steer.heading.distance_to(first) > 0.001, "a new heading must be picked")


func test_blocked_turns_away_from_obstacle() -> void:
	for i in 20:
		steer.on_blocked(Vector2.LEFT)
		assert_true(steer.heading.dot(Vector2.LEFT) > 0.0, "heading must point away from the wall")


func test_same_seed_gives_same_heading() -> void:
	var other_rng := RandomNumberGenerator.new()
	other_rng.seed = 42
	var other := WanderSteering.new(other_rng, 1.5, 4.0)
	assert_almost(other.heading, steer.heading)
