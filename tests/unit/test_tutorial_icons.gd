extends TestCase
## Every interaction icon must resolve to one of the game's own textures.

func test_every_icon_has_a_texture() -> void:
	for id in [
		&"fish", &"coral", &"algae", &"nest", &"nest_eggs",
		&"co2", &"bag", &"cyclone", &"predator", &"turtle",
	]:
		assert_true(TutorialIcons.texture(id) != null, "missing icon: %s" % id)
		assert_true(TutorialIcons.height(id) > 0.0, "missing height: %s" % id)


func test_cyclone_icon_crops_a_single_frame() -> void:
	var icon := TutorialIcons.texture(&"cyclone") as AtlasTexture
	assert_true(icon != null, "the cyclone icon must crop one frame")
	if icon != null:
		assert_eq(icon.atlas, Cyclone.TEXTURE)
		assert_almost(icon.region.size.x * CycloneVisual.FRAMES,
			float(Cyclone.TEXTURE.get_width()))


func test_unknown_icon_returns_null() -> void:
	assert_eq(TutorialIcons.texture(&"nope"), null)
