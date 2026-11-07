extends TestCase
## The "Come si gioca" reference must cover the GDD §8 interaction table.

func test_rows_cover_the_gdd_interactions() -> void:
	var keys := {}
	for row in TutorialInteractions.ROWS:
		assert_false(row["agent"].is_empty(), "empty agent")
		assert_false(row["agent_id"].is_empty(), "empty agent id")
		assert_false(row["target"].is_empty(), "empty target")
		assert_false(row["target_id"].is_empty(), "empty target id")
		assert_false(row["short"].is_empty(), "empty short effect")
		assert_false(row["group"].is_empty(), "empty group")
		keys["%s|%s" % [row["agent"], row["target"]]] = true

	for key in [
		"Alga|Corallo",
		"CO₂|Corallo",
		"CO₂|Alga",
		"CO₂|Nido con uova",
		"Busta|Pesce",
		"Busta|Corallo",
		"Ciclone|Pesce o alga",
		"Ciclone|Nido",
		"Ciclone|CO₂ o busta",
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
