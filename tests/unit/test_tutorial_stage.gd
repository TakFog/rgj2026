extends TestCase


func test_every_step_builds_visuals() -> void:
	var stage := TutorialStage.new()
	for i in TutorialSequence.CAPTIONS.size():
		stage.show_step(i)
		assert_true(stage.sprite_count() > 0, "step %d has no visuals" % i)
	stage.stop()
	assert_eq(stage.sprite_count(), 0)


func test_rebuilding_a_step_does_not_stack_visuals() -> void:
	var stage := TutorialStage.new()
	stage.show_step(0)
	var first := stage.sprite_count()
	stage.show_step(0)
	assert_eq(stage.sprite_count(), first, "show_step must clear before rebuilding")


func test_stage_does_not_join_gameplay_groups() -> void:
	var stage := TutorialStage.new()
	stage.show_step(2)
	for node in stage.visual_nodes():
		for group in [Groups.FISH, Groups.NESTS, Groups.CORALS, Groups.ALGAE, Groups.THREATS]:
			assert_false(node.is_in_group(group), "%s joined %s" % [node.name, group])


func test_stage_fills_the_tutorial_pane() -> void:
	var stage := TutorialStage.new()
	assert_eq(stage.size_flags_horizontal, Control.SIZE_EXPAND_FILL)
	assert_eq(stage.size_flags_vertical, Control.SIZE_EXPAND_FILL)
	assert_true(TutorialStage.STAGE_SIZE.x > 0.0)
	stage.free()
