extends TestCase


class FakeFish:
	extends RefCounted
	var holding: Object = null

	func holds(algae: Object) -> bool:
		return holding == algae


var algae: RefCounted
var me: FakeFish
var other: FakeFish


func before_each() -> void:
	algae = RefCounted.new()
	me = FakeFish.new()
	other = FakeFish.new()


func test_free_when_nobody_ate_it() -> void:
	assert_false(Algae.taken_by_other(null, algae, me))


func test_taken_while_other_fish_holds_it() -> void:
	other.holding = algae
	assert_true(Algae.taken_by_other(other, algae, me))


func test_not_taken_by_the_eater_itself() -> void:
	me.holding = algae
	assert_false(Algae.taken_by_other(me, algae, me))


func test_released_when_eater_lets_go() -> void:
	other.holding = algae
	other.holding = null
	assert_false(Algae.taken_by_other(other, algae, me))


func test_released_when_eater_holds_something_else() -> void:
	other.holding = RefCounted.new()
	assert_false(Algae.taken_by_other(other, algae, me))


func test_released_when_eater_is_freed() -> void:
	var node := Node.new()
	node.free()
	assert_false(Algae.taken_by_other(node, algae, me))
