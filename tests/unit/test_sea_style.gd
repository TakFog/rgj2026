extends TestCase
## Guards the stone-button label colours: the menu window's navy on the sand
## frame, and a lighter blue once the button is highlighted or selected.

func test_button_colors_match_the_chosen_palette() -> void:
	assert_eq(SeaStyle.BUTTON_FONT_COLOR, Color("#101f25"))
	assert_eq(SeaStyle.BUTTON_HIGHLIGHT_FONT_COLOR, Color("#23434a"))


func test_normal_button_labels_are_navy() -> void:
	var button := Button.new()
	SeaStyle.style_button(button)
	assert_eq(button.get_theme_color(&"font_color"), SeaStyle.BUTTON_FONT_COLOR)
	assert_eq(button.get_theme_color(&"font_focus_color"), SeaStyle.BUTTON_FONT_COLOR)
	button.free()


func test_hover_and_press_lighten_to_blue() -> void:
	var button := Button.new()
	SeaStyle.style_button(button)
	assert_eq(button.get_theme_color(&"font_hover_color"), SeaStyle.BUTTON_HIGHLIGHT_FONT_COLOR)
	assert_eq(button.get_theme_color(&"font_pressed_color"), SeaStyle.BUTTON_HIGHLIGHT_FONT_COLOR)
	assert_eq(button.get_theme_color(&"font_hover_pressed_color"), SeaStyle.BUTTON_HIGHLIGHT_FONT_COLOR)
	button.free()


func test_highlighted_button_labels_are_lighter_blue() -> void:
	var button := Button.new()
	SeaStyle.style_highlighted_button(button)
	assert_eq(button.get_theme_color(&"font_color"), SeaStyle.BUTTON_HIGHLIGHT_FONT_COLOR)
	assert_eq(button.get_theme_color(&"font_focus_color"), SeaStyle.BUTTON_HIGHLIGHT_FONT_COLOR)
	assert_eq(button.get_theme_color(&"font_hover_color"), SeaStyle.BUTTON_HIGHLIGHT_FONT_COLOR)
	button.free()
