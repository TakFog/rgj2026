class_name TestCase
extends RefCounted
## Base class for unit tests. Methods whose name starts with `test_` are run
## by tests/run_tests.gd, each on a fresh instance. A test may `await` (e.g.
## `await Engine.get_main_loop().process_frame`); the runner waits for it.

var failures: Array[String] = []
var _autofree: Array[Object] = []


## Called before every test method. Override to build fixtures.
func before_each() -> void:
	pass


## Called after every test method, even when it failed. Override to clean up.
func after_each() -> void:
	pass


## Registers a node (or any non-RefCounted object) to be freed by the runner
## after the test, so tests don't leak orphan nodes.
func autofree(obj: Object) -> void:
	_autofree.append(obj)


## Frees every object registered with autofree(). Called by the runner.
func free_autofree() -> void:
	for obj in _autofree:
		if is_instance_valid(obj) and not (obj is RefCounted):
			obj.free()
	_autofree.clear()


func assert_true(value: bool, msg: String = "") -> void:
	if not value:
		failures.append("expected true. %s" % msg)


func assert_false(value: bool, msg: String = "") -> void:
	if value:
		failures.append("expected false. %s" % msg)


func assert_eq(actual: Variant, expected: Variant, msg: String = "") -> void:
	if not (typeof(actual) == typeof(expected) and actual == expected):
		failures.append("expected %s (%s), got %s (%s). %s" % [
			str(expected), type_string(typeof(expected)),
			str(actual), type_string(typeof(actual)), msg])


func assert_almost(actual: Variant, expected: Variant, eps: float = 0.001, msg: String = "") -> void:
	var ok := false
	if actual is float or actual is int:
		ok = absf(float(actual) - float(expected)) <= eps
	elif actual is Vector2:
		ok = (actual as Vector2).distance_to(expected) <= eps
	if not ok:
		failures.append("expected ~%s, got %s. %s" % [str(expected), str(actual), msg])
