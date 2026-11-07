extends TestCase
## The "Come si gioca" reference must cover the GDD §8 interaction table.

func test_rows_cover_the_gdd_interactions() -> void:
	var keys := {}
	for row in TutorialInteractions.ROWS:
		assert_false(row["agent"].is_empty(), "empty agent")
		assert_false(row["target"].is_empty(), "empty target")
		assert_false(row["effect"].is_empty(), "empty effect")
		keys["%s|%s" % [row["agent"], row["target"]]] = true

	for key in [
		"Alga|Corallo",
		"CO2|Corallo",
		"CO2|Alga",
		"CO2|Nido con uova",
		"Busta|Pesce",
		"Busta|Corallo",
		"Ciclone|Pesce o alga",
		"Ciclone|Nido",
		"Ciclone|CO2 o busta",
		"Ciclone|Predatore",
		"Ciclone|Corallo",
		"Predatore|Pesce",
		"Predatore|Nido con uova",
		"Tartaruga|Predatore",
		"Tartaruga|Busta",
		"Tartaruga|Alga",
	]:
		assert_true(keys.has(key), "missing interaction: %s" % key)


func test_rows_have_enough_entries_for_a_real_reference() -> void:
	assert_true(TutorialInteractions.ROWS.size() >= 16)
