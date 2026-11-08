extends TestCase
## Guards the project-wide typeface: all text uses Archivo, the free
## stand-in for Britannic Bold, resolved through the project theme.

const THEME_PATH := "res://ui/ui_theme.tres"
## Symbols the UI actually prints: è é Ì ° ₂ · − — →
const UI_CODEPOINTS: Array[int] = [0x00E8, 0x00E9, 0x00CC, 0x00B0, 0x2082, 0x00B7, 0x2212, 0x2014, 0x2192]


func test_project_theme_uses_archivo() -> void:
	assert_eq(ProjectSettings.get_setting("gui/theme/custom"), THEME_PATH)
	var theme := load(THEME_PATH) as Theme
	assert_true(theme != null, "ui_theme.tres must load")
	if theme == null:
		return
	var variation := theme.default_font as FontVariation
	assert_true(variation != null, "default_font must be a FontVariation")
	if variation == null:
		return
	assert_true(variation.base_font.get_font_name().contains("Archivo"))
	var tag := TextServerManager.get_primary_interface().name_to_tag("wght")
	assert_eq(int(variation.variation_opentype.get(tag, 0)), 900,
			"wght must be set under its OpenType tag, not the 'wght' text")
	# A key the engine ignores leaves the width at the font's default instance
	# (SemiBold 600), so compare the active axis against the base font directly.
	assert_true(variation.get_char_size(0x2082, 16).x > variation.base_font.get_char_size(0x2082, 16).x,
			"wght 900 must render wider than the font's default instance")


func test_theme_font_has_every_ui_glyph() -> void:
	var theme := load(THEME_PATH) as Theme
	if theme == null or theme.default_font == null:
		assert_true(false, "theme font missing")
		return
	for codepoint in UI_CODEPOINTS:
		assert_true(theme.default_font.has_char(codepoint),
				"Archivo must contain U+%04X" % codepoint)


func test_label_inherits_project_font() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var label := Label.new()
	label.text = "CO₂"
	tree.root.add_child(label)
	autofree(label)
	var theme := load(THEME_PATH) as Theme
	assert_true(theme != null)
	if theme == null:
		return
	assert_eq(label.get_theme_default_font(), theme.default_font)


func test_fish_warning_uses_project_font() -> void:
	var theme := load(THEME_PATH) as Theme
	assert_true(theme != null)
	if theme == null:
		return
	assert_eq(FishVisual.warning_font(), theme.default_font)
