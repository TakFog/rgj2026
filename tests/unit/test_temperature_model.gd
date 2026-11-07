extends TestCase

var model: TemperatureModel


func before_each() -> void:
	model = TemperatureModel.new(1.0 / 480.0, 0.03, 0.6)


func test_reaches_max_in_8_minutes_without_corals() -> void:
	model.tick(240.0, 0)
	assert_almost(model.value, 0.5)
	model.tick(240.0, 0)
	assert_almost(model.value, 1.0)


func test_slowdown_is_proportional_to_coral_cells() -> void:
	assert_almost(model.slowdown(0), 0.0)
	assert_almost(model.slowdown(10), 0.3)


func test_slowdown_is_capped() -> void:
	assert_almost(model.slowdown(20), 0.6)
	assert_almost(model.slowdown(100), 0.6)


func test_corals_slow_the_rise_but_never_stop_it() -> void:
	model.tick(100.0, 1000)
	assert_almost(model.value, 100.0 / 480.0 * 0.4)
	assert_true(model.value > 0.0)


func test_never_exceeds_one() -> void:
	model.tick(10000.0, 0)
	assert_almost(model.value, 1.0)


func test_never_decreases() -> void:
	model.tick(60.0, 0)
	var before := model.value
	model.tick(60.0, 1000)
	assert_true(model.value > before)


func test_celsius_mapping() -> void:
	assert_almost(TemperatureModel.to_celsius(0.0, 26.0, 32.0), 26.0)
	assert_almost(TemperatureModel.to_celsius(0.5, 26.0, 32.0), 29.0)
	assert_almost(TemperatureModel.to_celsius(2.0, 26.0, 32.0), 32.0)
