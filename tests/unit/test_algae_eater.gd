extends TestCase


class FakeFish:
	extends RefCounted
	var eating: Object = null

	func is_eating(algae: Object) -> bool:
		return eating == algae


var algae: RefCounted
var me: FakeFish
var other: FakeFish


func before_each() -> void:
	algae = RefCounted.new()
	me = FakeFish.new()
	other = FakeFish.new()


func test_free_when_nobody_ate_it() -> void:
	assert_false(Algae.taken_by_other(null, algae, me))


func test_taken_while_other_fish_eats_it() -> void:
	other.eating = algae
	assert_true(Algae.taken_by_other(other, algae, me))


func test_not_taken_by_the_eater_itself() -> void:
	me.eating = algae
	assert_false(Algae.taken_by_other(me, algae, me))


func test_released_when_eater_stops_eating() -> void:
	other.eating = algae
	other.eating = null
	assert_false(Algae.taken_by_other(other, algae, me))


func test_released_when_eater_eats_something_else() -> void:
	other.eating = RefCounted.new()
	assert_false(Algae.taken_by_other(other, algae, me))


func test_released_when_eater_is_freed() -> void:
	var node := Node.new()
	node.free()
	assert_false(Algae.taken_by_other(node, algae, me))
