extends TestCase


func test_format_time() -> void:
	assert_eq(Hud.format_time(0.0), "00:00")
	assert_eq(Hud.format_time(125.7), "02:05")


func test_is_critical() -> void:
	assert_true(Hud.is_critical(0))
	assert_true(Hud.is_critical(1))
	assert_false(Hud.is_critical(2))


func test_warning_text_for_coral() -> void:
	assert_eq(Hud.warning_text(&"corals", 6.2, -1.0), "Coralli a zero! Collasso tra 7 s")


func test_warning_text_fish_without_eggs_has_no_hint() -> void:
	assert_eq(Hud.warning_text(&"fish", 9.5, -1.0), "Pesci a zero! Collasso tra 10 s")


func test_warning_text_fish_eggs_in_time() -> void:
	assert_eq(Hud.warning_text(&"fish", 9.5, 4.0),
		"Pesci a zero! Collasso tra 10 s\nUova in schiusa tra 4 s (in tempo)")


func test_warning_text_fish_eggs_too_late() -> void:
	assert_eq(Hud.warning_text(&"fish", 3.0, 12.0),
		"Pesci a zero! Collasso tra 3 s\nUova in schiusa tra 12 s (troppo tardi)")
