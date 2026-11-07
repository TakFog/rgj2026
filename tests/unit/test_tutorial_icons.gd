extends TestCase
## Every interaction icon must resolve to one of the game's own textures.

func test_every_icon_has_a_texture() -> void:
	for id in [
		&"fish", &"coral", &"algae", &"nest", &"nest_eggs",
		&"co2", &"bag", &"cyclone", &"predator", &"turtle",
	]:
		assert_true(TutorialIcons.texture(id) != null, "missing icon: %s" % id)
		assert_true(TutorialIcons.height(id) > 0.0, "missing height: %s" % id)


func test_unknown_icon_returns_null() -> void:
	assert_eq(TutorialIcons.texture(&"nope"), null)
