extends TestCase
## The inventory slots must be reachable from the keyboard (1-4).


func _keycodes(action: StringName) -> Array[int]:
	var keycodes: Array[int] = []
	for event in InputMap.action_get_events(action):
		if event is InputEventKey:
			keycodes.append((event as InputEventKey).physical_keycode)
	return keycodes


func test_slots_are_bound_to_number_row_and_keypad() -> void:
	InputActions.register()
	for i in InputActions.SLOTS.size():
		var codes := _keycodes(InputActions.SLOTS[i])
		assert_true(codes.has(KEY_1 + i), "%s missing number-row key" % InputActions.SLOTS[i])
		assert_true(codes.has(KEY_KP_1 + i), "%s missing keypad key" % InputActions.SLOTS[i])


func test_slot_actions_are_distinct() -> void:
	var seen := {}
	for action in InputActions.SLOTS:
		assert_false(seen.has(action), "duplicate action %s" % action)
		seen[action] = true
