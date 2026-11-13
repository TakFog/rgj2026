extends TestCase
## The game-over card names the population that collapsed and summarises the run.


func test_cause_names_each_population() -> void:
	assert_eq(GameOverScreen.cause_text(&"corals"), "I coralli si sono sgretolati.")
	assert_eq(GameOverScreen.cause_text(&"algae"), "Le alghe si sono estinte.")
	assert_eq(GameOverScreen.cause_text(&"fish"), "I pesci sono morti di fame.")
	assert_eq(GameOverScreen.cause_text(&"nests"), "Non è rimasto nessun nido.")


func test_unknown_population_has_a_fallback_cause() -> void:
	assert_eq(GameOverScreen.cause_text(&""), "La barriera si è fermata.")


func test_counts_are_summarised_in_a_stable_order() -> void:
	var counts := {&"nests": 2, &"fish": 3, &"corals": 0, &"algae": 14}
	assert_eq(GameOverScreen.format_counts(counts), "Coralli 0  ·  Alghe 14  ·  Pesci 3  ·  Nidi 2")


func test_empty_counts_are_empty() -> void:
	assert_eq(GameOverScreen.format_counts({}), "")


func test_restart_label_depends_on_the_mode() -> void:
	assert_eq(GameOverScreen.restart_label(0), "Riprova livello")
	assert_eq(GameOverScreen.restart_label(-1), "Ricomincia")
