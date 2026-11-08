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


func test_cyclone_agent_uses_the_animated_visual() -> void:
	var stage := TutorialStage.new()
	autofree(stage)
	stage.show_interaction(_row(&"cyclone_fish_algae"))
	var agent: Node2D = stage.get("_agent")
	assert_true(agent is CycloneVisual, "the tutorial cyclone must use the game's animated visual")
	if not (agent is CycloneVisual):
		return
	var body := (agent as CycloneVisual).body
	assert_true(body != null, "the tutorial cyclone funnel is missing")
	if body != null:
		assert_true(body.material is ShaderMaterial, "the tutorial funnel must use the swirl shader")
		if body.material is ShaderMaterial:
			assert_true((body.material as ShaderMaterial).shader == CycloneVisual.SHADER,
				"the tutorial funnel must use the cyclone swirl shader")


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


func test_predator_fish_leaves_blood() -> void:
	var stage := TutorialStage.new()
	autofree(stage)
	stage.show_interaction(_row(&"predator_fish"))
	stage._hit_effect(&"predator_fish", stage.get("_target"))
	var found := false
	for node in stage.visual_nodes():
		if node is BloodBurst:
			found = true
	assert_true(found, "predator eating a fish must leave blood")


func test_only_a_predator_fish_kill_bleeds() -> void:
	var stage := TutorialStage.new()
	autofree(stage)
	stage.show_interaction(_row(&"bag_fish"))
	stage._hit_effect(&"bag_fish", stage.get("_target"))
	for node in stage.visual_nodes():
		assert_false(node is BloodBurst, "a bag kill must not bleed")


func test_stage_fills_the_tutorial_pane() -> void:
	var stage := TutorialStage.new()
	autofree(stage)
	assert_eq(stage.size_flags_horizontal, Control.SIZE_EXPAND_FILL)
	assert_eq(stage.size_flags_vertical, Control.SIZE_EXPAND_FILL)
	assert_true(TutorialStage.STAGE_SIZE.x > 0.0)


func test_hatching_empties_the_nest() -> void:
	var stage := TutorialStage.new()
	stage.show_interaction(_row(&"fish_nest"))
	var nest: Sprite2D = stage.get("_nest")
	# Drive the vignette past the hatch without waiting for real frames.
	var tree := Engine.get_main_loop() as SceneTree
	var tween := tree.create_tween()
	tween.set_parallel(true)
	stage._animate_nest(tween)
	tween.custom_step(3.5)
	assert_eq(nest.texture, Nest.EMPTY_TEXTURE, "nest must be empty after the eggs hatch")
	stage.free()


func test_turtle_faces_the_way_it_swims() -> void:
	var stage := TutorialStage.new()
	stage.show_interaction(_row(&"turtle_predator"))
	var turtle: Sprite2D = null
	for node in stage.visual_nodes():
		var sprite := node as Sprite2D
		if sprite != null and sprite.texture == TurtleVisual.TEXTURE:
			turtle = sprite
	assert_true(turtle != null, "turtle visual missing")
	if turtle != null:
		assert_true(turtle.scale.x < 0.0, "turtle must face right; its texture faces left")
	stage.free()


func _row(id: StringName) -> Dictionary:
	for row in TutorialInteractions.ROWS:
		if row["id"] == id:
			return row
	return {}
