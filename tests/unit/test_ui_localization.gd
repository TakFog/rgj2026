extends TestCase
## Guards the player-facing language: the title and the F3 labels are Italian.

func test_game_title_is_italian() -> void:
	assert_eq(MainMenuScreen.GAME_TITLE, "Ideologia Marina")


func test_debug_flag_labels_are_italian() -> void:
	var overlay := DebugOverlay.new()
	assert_eq(overlay._flag_label("predator_enabled", true), "Predatore attivo: SÌ")
	assert_eq(overlay._flag_label("show_paths", false), "Mostra percorsi: NO")
	overlay.free()


func test_fish_state_labels_are_italian() -> void:
	var overlay := DebugOverlay.new()
	assert_eq(overlay._state_name(FishBrain.State.WANDER), "VAGA")
	assert_eq(overlay._state_name(FishBrain.State.SEEKING_FOOD), "CERCA CIBO")
	overlay.free()


func test_turtle_state_labels_are_italian() -> void:
	var overlay := DebugOverlay.new()
	assert_eq(overlay._turtle_state_name(TurtleBrain.State.HELPING), "AIUTA")
	assert_eq(overlay._turtle_state_name(TurtleBrain.State.LEAVING), "SE NE VA")
	overlay.free()
