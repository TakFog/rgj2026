extends TestCase


func test_alive_in_rejects_freed_entity() -> void:
	var node := Node.new()
	node.free()
	assert_false(Fish._alive_in(node, Groups.ALGAE))


func test_alive_in_rejects_null() -> void:
	assert_false(Fish._alive_in(null, Groups.ALGAE))


func test_alive_in_requires_group() -> void:
	var node := Node.new()
	assert_false(Fish._alive_in(node, Groups.ALGAE))
	node.add_to_group(Groups.ALGAE)
	assert_true(Fish._alive_in(node, Groups.ALGAE))
	node.free()
