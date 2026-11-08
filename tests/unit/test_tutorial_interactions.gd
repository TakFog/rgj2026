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
		assert_true(_valid_end(row["agent_end"]), "bad agent end: %s" % row["agent_end"])
		assert_true(_valid_end(row["target_end"]), "bad target end: %s" % row["target_end"])
		keys["%s|%s" % [row["agent"], row["target"]]] = true

	for key in [
		"Alga|Corallo",
		"CO₂|Corallo",
		"CO₂|Alga",
		"CO₂|Nido con uova",
		"Busta|Pesce",
		"Busta|Corallo",
		"Ciclone|Pesce, alga, nido e predatore",
		"Ciclone|Corallo",
		"Predatore|Pesce",
		"Predatore|Nido con uova",
		"Tartaruga|Predatore",
		"Tartaruga|Busta",
		"Tartaruga|Alga",
	]:
		assert_true(keys.has(key), "missing interaction: %s" % key)


func test_rows_have_enough_entries_for_a_real_reference() -> void:
	assert_true(TutorialInteractions.ROWS.size() >= 15)


func test_cyclone_rows_are_compacted_into_one_sweep() -> void:
	var ids := {}
	for row in TutorialInteractions.ROWS:
		ids[row["id"]] = true
	for old in [
		&"cyclone_fish_algae", &"cyclone_nest", &"cyclone_threat", &"cyclone_predator",
	]:
		assert_false(ids.has(old), "%s must be folded into the cyclone sweep" % old)
	assert_true(ids.has(&"cyclone_rampage"), "the compacted cyclone row is missing")
	assert_true(ids.has(&"cyclone_coral"),
			"the coral destroying the cyclone keeps its own row")


func test_turtle_leaves_the_predator_on_stage() -> void:
	var row := _row(&"turtle_predator")
	assert_eq(row["agent_end"], "stay")
	assert_eq(row["target_end"], "leave")


func _valid_end(value: String) -> bool:
	return value in ["stay", "vanish", "leave", "pass", "damage", "empty", "grow"]


func _row(id: StringName) -> Dictionary:
	for row in TutorialInteractions.ROWS:
		if row["id"] == id:
			return row
	return {}
