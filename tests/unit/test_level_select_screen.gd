extends TestCase
## The level chooser offers the endless sandbox after the campaign levels.

func before_each() -> void:
	LevelSession.reset()


func after_each() -> void:
	LevelSession.reset()


func test_sandbox_card_is_always_available() -> void:
	var screen := _open_screen()
	var button: Button = screen.get("_sandbox_button")
	assert_true(button != null, "the chooser must build a sandbox card")
	assert_false(button.disabled, "the sandbox is never locked")
	assert_true(button.text.begins_with("Sandbox\n"), button.text)
	screen.free()


func test_sandbox_card_starts_the_sandbox() -> void:
	var screen := _open_screen()
	var chosen: Array[int] = []
	screen.level_chosen.connect(func(index: int) -> void: chosen.append(index))

	var button: Button = screen.get("_sandbox_button")
	button.pressed.emit()

	assert_eq(chosen, [LevelSession.SANDBOX_INDEX])
	screen.free()


## Builds the chooser in the tree (its _ready creates the cards) and refreshes it.
func _open_screen() -> LevelSelectScreen:
	InputActions.register()
	var tree := Engine.get_main_loop() as SceneTree
	var screen := LevelSelectScreen.new()
	tree.root.add_child(screen)
	if not screen.is_node_ready():
		screen._ready()
	screen._refresh()
	return screen
