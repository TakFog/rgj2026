extends TestCase


func test_bag_has_no_shadow() -> void:
	assert_false(PlasticBag.new().show_shadow)


func test_co2_cloud_and_cyclone_keep_their_shadow() -> void:
	assert_true(Co2Cloud.new().show_shadow)
	assert_true(Cyclone.new().show_shadow)


func test_bag_without_setup_does_not_crash_when_animating() -> void:
	var bag := PlasticBag.new()
	bag._animate_body(0.1)
	assert_true(true, "reached without a script error")
