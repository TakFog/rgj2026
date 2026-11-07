extends TestCase

var oxygen: CoralOxygen
var depleted_count := 0


func before_each() -> void:
	oxygen = CoralOxygen.new(100.0, 0.5)
	depleted_count = 0
	oxygen.depleted.connect(_on_depleted)


func _on_depleted() -> void:
	depleted_count += 1


func test_starts_full() -> void:
	assert_almost(oxygen.value, 100.0)
	assert_almost(oxygen.ratio(), 1.0)


func test_damage_is_instant() -> void:
	oxygen.damage(35.0)
	assert_almost(oxygen.value, 65.0)
	assert_false(oxygen.dead)


func test_regen_is_capped() -> void:
	oxygen.damage(10.0)
	oxygen.tick(4.0)
	assert_almost(oxygen.value, 92.0)
	oxygen.tick(100.0)
	assert_almost(oxygen.value, 100.0)


func test_depletes_once_at_zero() -> void:
	oxygen.damage(60.0)
	oxygen.damage(60.0)
	oxygen.damage(10.0)
	assert_true(oxygen.dead)
	assert_almost(oxygen.value, 0.0)
	assert_eq(depleted_count, 1)


func test_dead_coral_does_not_regenerate() -> void:
	oxygen.damage(100.0)
	oxygen.tick(10.0)
	assert_almost(oxygen.value, 0.0)


func test_negative_regen_drains_oxygen() -> void:
	oxygen = CoralOxygen.new(100.0, -0.5)
	oxygen.tick(10.0)
	assert_almost(oxygen.value, 95.0)
	assert_false(oxygen.dead)


func test_negative_regen_depletes_once_at_zero() -> void:
	oxygen = CoralOxygen.new(100.0, -10.0)
	oxygen.depleted.connect(_on_depleted)
	oxygen.tick(20.0)
	assert_true(oxygen.dead)
	assert_almost(oxygen.value, 0.0)
	assert_eq(depleted_count, 1)
	oxygen.tick(10.0)
	assert_almost(oxygen.value, 0.0)
	assert_eq(depleted_count, 1)
