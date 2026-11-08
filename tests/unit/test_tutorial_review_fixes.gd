extends TestCase


func test_loop_covers_the_longest_vignette() -> void:
	assert_true(TutorialScreen.LOOP_SECONDS >= TutorialStage.FADE_START + TutorialStage.FADE_SECONDS,
			"the tutorial must not cut a vignette before its fade-out ends")


func test_stage_clips_its_actors() -> void:
	var stage := TutorialStage.new()
	assert_true(stage.clip_contents)
	stage.free()


func test_resize_moves_the_current_vignette() -> void:
	var stage := TutorialStage.new()
	stage.size = TutorialStage.STAGE_SIZE
	stage.show_interaction(TutorialInteractions.ROWS[0])
	var layer := stage.visual_nodes()[0].get_parent() as Node2D
	assert_eq(layer.position, Vector2.ZERO)
	stage.size = TutorialStage.STAGE_SIZE + Vector2(100, 50)
	# Outside the tree Control does not send RESIZED by itself.
	stage._notification(Control.NOTIFICATION_RESIZED)
	assert_eq(layer.position, Vector2(50, 36))
	stage.show_interaction(TutorialInteractions.ROWS[1])
	assert_eq(layer.position, Vector2.ZERO, "a rebuilt vignette uses the new size")
	stage.free()


func test_only_the_selected_chip_is_highlighted() -> void:
	InputActions.register()
	var tree := Engine.get_main_loop() as SceneTree
	var screen := TutorialScreen.new()
	tree.root.add_child(screen)
	# _ready only runs on add_child once the tree itself is ready.
	if not screen.is_node_ready():
		screen._ready()
	screen.open(TutorialScreen.Mode.REVIEW)
	screen._select_interaction(3)
	var chips: Array[Button] = screen.get("_chips")
	var rows: Array[int] = screen.get("_chip_rows")
	var highlighted := 0
	for i in chips.size():
		var lit := chips[i].get_theme_color(&"font_color") == SeaStyle.BUTTON_HIGHLIGHT_FONT_COLOR
		if lit:
			highlighted += 1
			assert_eq(rows[i], 3)
	assert_eq(highlighted, 1)
	# Chips share one set of styleboxes instead of allocating their own.
	assert_true(chips[0].get_theme_stylebox(&"pressed") == chips[1].get_theme_stylebox(&"pressed"))
	screen.close()
	screen.free()
