extends TestCase


func test_scale_marks_every_whole_degree_in_range() -> void:
	assert_eq(Thermometer.scale_degrees(26.0, 32.0), [26, 27, 28, 29, 30, 31, 32] as Array[int])
	assert_eq(Thermometer.scale_degrees(26.5, 28.2), [27, 28] as Array[int])


func test_degree_ratio_maps_display_range_to_unit() -> void:
	assert_almost(Thermometer.degree_ratio(26.0, 26.0, 32.0), 0.0)
	assert_almost(Thermometer.degree_ratio(29.0, 26.0, 32.0), 0.5)
	assert_almost(Thermometer.degree_ratio(32.0, 26.0, 32.0), 1.0)


func test_liquid_goes_from_cold_through_warm_to_hot() -> void:
	assert_eq(Thermometer.liquid_color(0.0), Thermometer.COLD)
	assert_eq(Thermometer.liquid_color(0.5), Thermometer.WARM)
	assert_eq(Thermometer.liquid_color(1.0), Thermometer.HOT)
	assert_eq(Thermometer.liquid_color(-1.0), Thermometer.COLD)
	assert_eq(Thermometer.liquid_color(2.0), Thermometer.HOT)


func test_caption_shows_one_decimal_celsius() -> void:
	assert_eq(Thermometer.caption(28.44), "28.4 °C")
