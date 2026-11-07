extends TestCase


func test_every_interaction_builds_visuals() -> void:
	var stage := TutorialStage.new()
	autofree(stage)
	for row in TutorialInteractions.ROWS:
		stage.show_interaction(row)
		assert_true(stage.sprite_count() > 0, "interaction %s has no visuals" % row["id"])
	stage.stop()
	assert_eq(stage.sprite_count(), 0)


func test_rebuilding_an_interaction_does_not_stack_visuals() -> void:
	var stage := TutorialStage.new()
	autofree(stage)
	stage.show_interaction(TutorialInteractions.ROWS[0])
	var first := stage.sprite_count()
	stage.show_interaction(TutorialInteractions.ROWS[0])
	assert_eq(stage.sprite_count(), first, "show_interaction must clear before rebuilding")


func test_stage_does_not_join_gameplay_groups() -> void:
	var stage := TutorialStage.new()
	autofree(stage)
	stage.show_interaction(TutorialInteractions.ROWS[2])
	for node in stage.visual_nodes():
		for group in [Groups.FISH, Groups.NESTS, Groups.CORALS, Groups.ALGAE, Groups.THREATS]:
			assert_false(node.is_in_group(group), "%s joined %s" % [node.name, group])


func test_predator_draws_above_nest() -> void:
	var stage := TutorialStage.new()
	autofree(stage)
	var row := {}
	for candidate in TutorialInteractions.ROWS:
		if candidate["id"] == &"predator_eggs":
			row = candidate
	stage.show_interaction(row)
	var predator_z := -100
	var nest_z := 100
	for node in stage.visual_nodes():
		var sprite := node as Sprite2D
		if sprite == null:
			continue
		if sprite.texture == PredatorVisual.TEXTURE:
			predator_z = sprite.z_index
		elif sprite.texture == Nest.EGGS_TEXTURE:
			nest_z = sprite.z_index
	assert_true(nest_z > 0, "nest must stay above the seabed, got z %d" % nest_z)
	assert_true(predator_z > nest_z, "predator %d, nest %d" % [predator_z, nest_z])


func test_stage_fills_the_tutorial_pane() -> void:
	var stage := TutorialStage.new()
	autofree(stage)
	assert_eq(stage.size_flags_horizontal, Control.SIZE_EXPAND_FILL)
	assert_eq(stage.size_flags_vertical, Control.SIZE_EXPAND_FILL)
	assert_true(TutorialStage.STAGE_SIZE.x > 0.0)
