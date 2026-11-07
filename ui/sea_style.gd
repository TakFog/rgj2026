class_name SeaStyle
extends RefCounted
## Shared look for menu widgets (buttons, sliders, panels) so menus match the
## sea-themed HUD cards: deep-teal fill, sea-glass rim, sand highlights
## (palette from InventoryCard). Styles are built in code; no theme resource.

const CORNER_RADIUS := InventoryCard.CORNER_RADIUS
const BG_COLOR := InventoryCard.BG_COLOR
const RIM_COLOR := InventoryCard.RIM_COLOR
const SAND_COLOR := InventoryCard.SAND_COLOR
const CAPTION_COLOR := InventoryCard.CAPTION_COLOR
const SHADOW_COLOR := InventoryCard.SHADOW_COLOR
const PRESSED_BG_COLOR := Color(0.05, 0.17, 0.19, 0.95)
const DISABLED_BG_COLOR := InventoryCard.BG_EMPTY_COLOR
const HOVER_TEXT_COLOR := Color(1, 1, 1)

const BUTTON_PADDING := Vector2(18, 7)
const PANEL_PADDING := Vector2(32, 26)
const TRACK_HEIGHT := 7
const GRABBER_RADIUS := 10

## Shared menu typography and layout. Screens use these instead of their own
## near-duplicate sizes, so title, pause, settings, credits and game over match.
const HERO_TITLE_FONT_SIZE := 42
const TITLE_FONT_SIZE := 34
const BODY_FONT_SIZE := 20
const BUTTON_FONT_SIZE := 22
const BUTTON_SIZE := Vector2(200, 52)
const MENU_SEPARATION := 18
## Same translucent navy backdrop for every full-screen menu overlay.
const OVERLAY_COLOR := Color(0.02, 0.05, 0.1, 0.85)
## Divider under a menu title: a short sea-glass rule, not a full-width
## separator. Keeps its decorative role without reading as default chrome.
const DIVIDER_COLOR := Color(0.47, 0.8, 0.78, 0.3)
const DIVIDER_WIDTH := 72.0


## Rounded card box: deep-teal fill, sea-glass rim at `rim_alpha`, soft shadow.
static func card_box(rim_alpha: float = 0.6, border := 3) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = BG_COLOR
	box.border_color = Color(RIM_COLOR, rim_alpha)
	box.set_border_width_all(border)
	box.set_corner_radius_all(CORNER_RADIUS)
	box.shadow_color = SHADOW_COLOR
	box.shadow_size = 4
	box.shadow_offset = Vector2(0, 2)
	box.anti_aliasing = true
	return box


## Large card used as the backdrop of a menu panel.
static func panel_box() -> StyleBoxFlat:
	var box := card_box(0.6, 2)
	box.shadow_size = 10
	box.shadow_offset = Vector2(0, 4)
	box.content_margin_left = PANEL_PADDING.x
	box.content_margin_right = PANEL_PADDING.x
	box.content_margin_top = PANEL_PADDING.y
	box.content_margin_bottom = PANEL_PADDING.y
	return box


## Applies the shared menu-title look (sand, centred) at `font_size`.
static func style_title(label: Label, font_size := TITLE_FONT_SIZE) -> void:
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", SAND_COLOR)


## Applies the shared menu-body look (caption colour, centred) at `font_size`.
static func style_body(label: Label, font_size := BODY_FONT_SIZE) -> void:
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", CAPTION_COLOR)


## The short sea-glass rule used under every menu title.
static func divider() -> ColorRect:
	var line := ColorRect.new()
	line.color = DIVIDER_COLOR
	line.custom_minimum_size = Vector2(DIVIDER_WIDTH, 1)
	line.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return line


## A standard menu button: shared size, font size and sea-card styling.
static func menu_button(text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = BUTTON_SIZE
	button.add_theme_font_size_override("font_size", BUTTON_FONT_SIZE)
	style_button(button)
	return button


## Restyles a Button as a sea card: soft rim at rest, sea-glass lift on hover,
## sand rim when pressed.
static func style_button(button: Button) -> void:
	var normal := _padded(card_box(0.45, 2))
	normal.shadow_size = 0

	var hover := _padded(card_box(0.9, 2))
	hover.shadow_color = Color(RIM_COLOR, 0.2)
	hover.shadow_size = 8
	hover.shadow_offset = Vector2.ZERO

	var pressed := _padded(card_box(1.0, 3))
	pressed.bg_color = PRESSED_BG_COLOR
	pressed.border_color = SAND_COLOR
	pressed.shadow_color = Color(SAND_COLOR, 0.3)
	pressed.shadow_size = 8
	pressed.shadow_offset = Vector2.ZERO

	var disabled := _padded(card_box(0.18, 2))
	disabled.bg_color = DISABLED_BG_COLOR
	disabled.shadow_size = 0

	# Keyboard focus: a thin light ring on the existing rim, not a second
	# outline floating outside the button.
	var focus := StyleBoxFlat.new()
	focus.draw_center = false
	focus.border_color = Color(1, 1, 1, 0.85)
	focus.set_border_width_all(2)
	focus.set_corner_radius_all(CORNER_RADIUS)
	focus.anti_aliasing = true

	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_stylebox_override("hover_pressed", pressed)
	button.add_theme_stylebox_override("disabled", disabled)
	button.add_theme_stylebox_override("focus", focus)
	button.add_theme_color_override("font_color", CAPTION_COLOR)
	button.add_theme_color_override("font_hover_color", HOVER_TEXT_COLOR)
	button.add_theme_color_override("font_focus_color", CAPTION_COLOR)
	button.add_theme_color_override("font_pressed_color", SAND_COLOR)
	button.add_theme_color_override("font_hover_pressed_color", SAND_COLOR)
	button.add_theme_color_override("font_disabled_color", Color(CAPTION_COLOR, 0.35))
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND


## Primary action (e.g. Resume): a sea card that is already lit with the sand
## rim and caption, like a selected inventory card, and glows on hover.
static func style_highlighted_button(button: Button) -> void:
	style_button(button)
	var normal := _padded(card_box(1.0, 2))
	normal.border_color = SAND_COLOR
	normal.shadow_size = 0

	var hover := _padded(card_box(1.0, 3))
	hover.border_color = SAND_COLOR
	hover.shadow_color = Color(SAND_COLOR, 0.35)
	hover.shadow_size = 10
	hover.shadow_offset = Vector2.ZERO

	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_color_override("font_color", SAND_COLOR)
	button.add_theme_color_override("font_focus_color", SAND_COLOR)
	button.add_theme_color_override("font_hover_color", HOVER_TEXT_COLOR)


## Restyles an HSlider: dark rounded track, aqua fill, sand pearl grabber.
static func style_slider(slider: HSlider) -> void:
	var track := StyleBoxFlat.new()
	track.bg_color = Color(0.0, 0.03, 0.07, 0.9)
	track.border_color = Color(RIM_COLOR, 0.35)
	track.set_border_width_all(1)
	track.set_corner_radius_all(TRACK_HEIGHT)
	track.content_margin_top = TRACK_HEIGHT * 0.5
	track.content_margin_bottom = TRACK_HEIGHT * 0.5
	track.anti_aliasing = true

	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(RIM_COLOR, 0.8)
	fill.set_corner_radius_all(TRACK_HEIGHT)
	fill.content_margin_top = TRACK_HEIGHT * 0.5
	fill.content_margin_bottom = TRACK_HEIGHT * 0.5
	fill.anti_aliasing = true

	var fill_highlight: StyleBoxFlat = fill.duplicate()
	fill_highlight.bg_color = RIM_COLOR

	slider.add_theme_stylebox_override("slider", track)
	slider.add_theme_stylebox_override("grabber_area", fill)
	slider.add_theme_stylebox_override("grabber_area_highlight", fill_highlight)
	slider.add_theme_icon_override("grabber", grabber_texture(CAPTION_COLOR))
	slider.add_theme_icon_override("grabber_highlight", grabber_texture(SAND_COLOR))
	slider.add_theme_icon_override("grabber_disabled", grabber_texture(Color(CAPTION_COLOR, 0.35)))
	slider.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND


## Slim sea-glass scrollbar, so long menus do not show Godot's default grey bar.
static func style_scrollbar(bar: ScrollBar) -> void:
	bar.custom_minimum_size.x = 6

	var track := StyleBoxFlat.new()
	track.bg_color = Color(0.0, 0.03, 0.04, 0.18)
	var radius := int(TRACK_HEIGHT * 0.5)
	track.set_corner_radius_all(radius)
	track.anti_aliasing = true

	var grabber := StyleBoxFlat.new()
	grabber.bg_color = Color(RIM_COLOR, 0.35)
	grabber.set_corner_radius_all(radius)
	grabber.anti_aliasing = true

	var grabber_highlight: StyleBoxFlat = grabber.duplicate()
	grabber_highlight.bg_color = Color(RIM_COLOR, 0.6)

	bar.add_theme_stylebox_override("scroll", track)
	bar.add_theme_stylebox_override("grabber", grabber)
	bar.add_theme_stylebox_override("grabber_highlight", grabber_highlight)
	bar.add_theme_stylebox_override("grabber_pressed", grabber_highlight)


## Anti-aliased round grabber: `color` disc with a thin navy ring.
static func grabber_texture(color: Color) -> ImageTexture:
	var size := GRABBER_RADIUS * 2
	var image := Image.create_empty(size, size, false, Image.FORMAT_RGBA8)
	var center := Vector2(GRABBER_RADIUS, GRABBER_RADIUS)
	var ring := Color(0.02, 0.06, 0.11)
	for y in size:
		for x in size:
			var d := (Vector2(x, y) + Vector2(0.5, 0.5)).distance_to(center)
			var alpha := clampf(GRABBER_RADIUS - d, 0.0, 1.0)
			var pixel := color.lerp(ring, clampf(d - (GRABBER_RADIUS - 3.0), 0.0, 1.0))
			image.set_pixel(x, y, Color(pixel, pixel.a * alpha))
	return ImageTexture.create_from_image(image)


static func _padded(box: StyleBoxFlat) -> StyleBoxFlat:
	box.content_margin_left = BUTTON_PADDING.x
	box.content_margin_right = BUTTON_PADDING.x
	box.content_margin_top = BUTTON_PADDING.y
	box.content_margin_bottom = BUTTON_PADDING.y
	return box
