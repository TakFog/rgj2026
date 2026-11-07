extends TestCase
## The title screen's invisible hotspots must line up with the painted buttons.

const VIEWPORT := Vector2(1280, 720)


func test_builds_one_hotspot_per_painted_button() -> void:
	var menu := _built_menu()
	assert_eq(menu._hotspots.size(), MenuHotspots.RECTS.size())
	for key: String in MenuHotspots.RECTS:
		assert_true(menu._hotspots.has(key), key)
	assert_true(menu._play_button == menu._hotspots["play"])


func test_hotspots_sit_on_the_painted_buttons() -> void:
	var menu := _built_menu()
	for key: String in MenuHotspots.RECTS:
		var button: Button = menu._hotspots[key]
		var expected := MenuHotspots.hotspot_rect(VIEWPORT, key)
		var actual := menu._art_box.position + button.position
		assert_almost(actual, expected.position, 0.01, key)
		assert_almost(button.size, expected.size, 0.01, key)


func test_each_hotspot_shows_its_menu_label() -> void:
	var menu := _built_menu()
	var expected := {
		"play": "INIZIA",
		"tutorial": "COME SI GIOCA",
		"settings": "IMPOSTAZIONI",
		"credits": "CREDITI",
		"exit": "ESCI",
	}
	for key: String in expected:
		var label := menu._hotspots[key].get_node_or_null("Label") as Label
		assert_true(label != null, key)
		assert_eq(label.text, expected[key], key)
		assert_eq(label.horizontal_alignment, HORIZONTAL_ALIGNMENT_CENTER, key)
		assert_eq(label.vertical_alignment, VERTICAL_ALIGNMENT_CENTER, key)
		assert_eq(label.mouse_filter, Control.MOUSE_FILTER_IGNORE, key)


func test_menu_labels_scale_with_the_painted_buttons() -> void:
	var big := _built_menu(Vector2(1280, 720))
	var small := _built_menu(Vector2(640, 360))
	var big_label := big._hotspots["play"].get_node("Label") as Label
	var small_label := small._hotspots["play"].get_node("Label") as Label
	assert_true(big_label.get_theme_font_size("font_size")
		> small_label.get_theme_font_size("font_size"))


func test_menu_labels_fit_inside_their_hotspots() -> void:
	var menu := _built_menu()
	for key: String in MenuHotspots.RECTS:
		var label := menu._hotspots[key].get_node("Label") as Label
		var font := ThemeDB.fallback_font
		var font_size := label.get_theme_font_size("font_size")
		var text_width := font.get_string_size(
			label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		var button: Button = menu._hotspots[key]
		assert_true(text_width <= button.size.x, key)


func test_each_hotspot_lights_up_its_painted_shape() -> void:
	var menu := _built_menu()
	for key: String in MenuHotspots.RECTS:
		var button: Button = menu._hotspots[key]
		var glow := button.get_child(0) as TextureRect
		assert_true(glow != null, key)
		var region := glow.texture as AtlasTexture
		assert_true(region != null, key)
		assert_true(region.atlas == menu.MENU_TEXTURE, key)
		assert_eq(region.region, MenuHotspots.hotspot_region(key), key)
		var glow_material := glow.material as CanvasItemMaterial
		assert_true(glow_material != null, key)
		assert_true(
			glow_material.blend_mode == CanvasItemMaterial.BLEND_MODE_ADD, key)
		assert_false(glow.visible, key)


func test_the_exit_hotspot_is_never_hidden() -> void:
	var menu := _built_menu()
	var exit_button: Button = menu._hotspots["exit"]
	assert_true(exit_button.visible)
	assert_eq(exit_button.focus_mode, Control.FOCUS_ALL)
	assert_true(menu._art_box.get_node_or_null("ExitCover") == null)


func test_each_hotspot_runs_its_menu_action() -> void:
	var menu := _built_menu()
	var expected := {
		"play": "_on_play_pressed",
		"tutorial": "_on_tutorial_pressed",
		"settings": "_on_settings_pressed",
		"credits": "_on_credits_pressed",
		"exit": "_on_exit_pressed",
	}
	for key: String in expected:
		var button: Button = menu._hotspots[key]
		var connections := button.pressed.get_connections()
		assert_eq(connections.size(), 1, key)
		var handler: Callable = connections[0]["callable"]
		assert_eq(String(handler.get_method()), expected[key], key)


## A menu screen with its panel built, laid out for VIEWPORT, not in the tree.
func _built_menu(viewport := VIEWPORT) -> MainMenuScreen:
	var menu := MainMenuScreen.new()
	autofree(menu)
	menu.size = viewport
	menu.add_child(menu._build_menu_panel())
	menu._layout_art()
	return menu
