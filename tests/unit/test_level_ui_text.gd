extends TestCase
## Player-facing level text: countdown and level cards.

func test_countdown_rounds_up_until_zero() -> void:
	assert_eq(Hud.format_countdown(60.0), "01:00")
	assert_eq(Hud.format_countdown(59.9), "01:00")
	assert_eq(Hud.format_countdown(0.1), "00:01")
	assert_eq(Hud.format_countdown(0.0), "00:00")
	assert_eq(Hud.format_countdown(-2.0), "00:00")


func test_unlocked_level_card_shows_mechanic_and_duration() -> void:
	var level := LevelCatalog.at(0)
	assert_eq(LevelSelectScreen.row_text(0, level, true, 0.0),
		"1. La barriera — 01:00\nPesci, coralli, alghe e nidi")


func test_level_card_shows_the_record() -> void:
	var level := LevelCatalog.at(1)
	assert_eq(LevelSelectScreen.row_text(1, level, true, 42.0),
		"2. L'acqua si scalda — 01:30\nLa temperatura sale: i coralli la rallentano  ·  Record 00:42")


func test_locked_level_card_hides_the_mechanic() -> void:
	var level := LevelCatalog.at(2)
	assert_eq(LevelSelectScreen.row_text(2, level, false, 0.0),
		"3. Il mare aperto — 02:00\nBloccato")


func test_sandbox_card_shows_the_mechanics_and_the_global_record() -> void:
	var sandbox := LevelCatalog.sandbox()
	assert_eq(LevelSelectScreen.sandbox_text(sandbox, 0.0),
		"Sandbox\nTutte le meccaniche, senza limite di tempo")
	assert_eq(LevelSelectScreen.sandbox_text(sandbox, 125.0),
		"Sandbox\nTutte le meccaniche, senza limite di tempo  ·  Record 02:05")


func test_clear_screen_wording() -> void:
	assert_eq(LevelClearScreen.title_for(false), "Livello completato")
	assert_eq(LevelClearScreen.title_for(true), "Campagna completata")
	assert_eq(LevelClearScreen.primary_label(false), "Prossimo livello")
	assert_eq(LevelClearScreen.primary_label(true), "Torna al menu")
