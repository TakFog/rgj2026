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


func test_each_hotspot_lights_up_its_painted_shape() -> void:
	var menu := _built_menu()
	var uniforms := ["top_left", "top_right", "bottom_right", "bottom_left"]
	for key: String in MenuHotspots.RECTS:
		var button: Button = menu._hotspots[key]
		var glow := button.get_child(0) as TextureRect
		assert_true(glow != null, key)
		assert_true(glow.texture == menu.MENU_TEXTURE, key)
		var glow_material := glow.material as ShaderMaterial
		assert_true(glow_material != null, key)
		assert_true(glow_material.shader == menu.GLOW_SHADER, key)
		var fraction: Rect2 = MenuHotspots.RECTS[key]
		assert_almost(glow_material.get_shader_parameter("region_position"),
			fraction.position, 0.001, key)
		assert_almost(glow_material.get_shader_parameter("region_size"),
			fraction.size, 0.001, key)
		var corners: Array = MenuHotspots.PILL_CORNERS[key]
		for i in uniforms.size():
			assert_almost(glow_material.get_shader_parameter(uniforms[i]),
				corners[i], 0.001, key)
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
func _built_menu() -> MainMenuScreen:
	var menu := MainMenuScreen.new()
	autofree(menu)
	menu.size = VIEWPORT
	menu.add_child(menu._build_menu_panel())
	menu._layout_art()
	return menu
