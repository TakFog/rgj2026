extends SceneTree
## Minimal headless test runner.
## Usage: tools/test.sh  (or: godot --headless --path . -s res://tests/run_tests.gd)
## Runs every `test_*` method of every tests/unit/test_*.gd script, each on a
## fresh TestCase instance: before_each(), the test, after_each(), then frees
## the nodes the test registered with autofree().
##
## A test fails when it records an assertion failure, when an engine or script
## error is raised while it runs (caught through a Logger, since a GDScript
## runtime error only aborts the method), or when it is a coroutine that does
## not finish within TEST_TIMEOUT_MSEC. A test file that fails to load counts
## as one failure. The process always exits: a watchdog quits with an error if
## the whole run exceeds RUN_TIMEOUT_SEC.

const TEST_DIR := "res://tests/unit"
const TEST_TIMEOUT_MSEC := 10000
const RUN_TIMEOUT_SEC := 600.0


## Records every error and script error raised while it is registered.
class ErrorCapture extends Logger:
	var _mutex := Mutex.new()
	var _errors: Array[String] = []

	func _log_error(function: String, file: String, line: int, code: String, rationale: String,
			_editor_notify: bool, error_type: int, script_backtraces: Array[ScriptBacktrace]) -> void:
		if error_type == ERROR_TYPE_WARNING:
			return
		var text := rationale if not rationale.is_empty() else code
		# Prefer the innermost script frame (e.g. the push_error() call site).
		for backtrace in script_backtraces:
			if backtrace.get_frame_count() > 0:
				function = backtrace.get_frame_function(0)
				file = backtrace.get_frame_file(0)
				line = backtrace.get_frame_line(0)
				break
		_mutex.lock()
		_errors.append("%s (at %s:%d in %s)" % [text, file, line, function])
		_mutex.unlock()

	func take() -> Array[String]:
		_mutex.lock()
		var errors: Array[String] = _errors.duplicate()
		_errors.clear()
		_mutex.unlock()
		return errors

	func has_errors() -> bool:
		_mutex.lock()
		var any := not _errors.is_empty()
		_mutex.unlock()
		return any


var _capture := ErrorCapture.new()
var _passed := 0
var _failed := 0
var _leaky_tests := 0
var _finished := false


func _initialize() -> void:
	create_timer(RUN_TIMEOUT_SEC).timeout.connect(_on_watchdog)
	OS.add_logger(_capture)
	await _run_all()
	_finish()


func _run_all() -> void:
	for path in _collect_test_files():
		await _run_file(path)


func _run_file(path: String) -> void:
	_capture.take()
	var script := load(path) as GDScript
	if script == null or not script.can_instantiate():
		var problems: Array[String] = ["script failed to load or compile"]
		problems.append_array(_capture.take())
		_report(path, "<load>", problems)
		return
	for method in script.get_script_method_list():
		var test_name: String = method["name"]
		if test_name.begins_with("test_"):
			await _run_test(path, script, test_name)


func _run_test(path: String, script: GDScript, test_name: String) -> void:
	_capture.take()
	var orphans_before := Node.get_orphan_node_ids().size()
	var instance: Variant = script.new()
	var test := instance as TestCase
	if test == null:
		var load_problems: Array[String] = ["script does not extend TestCase"]
		load_problems.append_array(_capture.take())
		_report(path, test_name, load_problems)
		return
	var problems: Array[String] = []
	await _invoke(test, &"before_each", problems)
	if problems.is_empty() and not _capture.has_errors():
		await _invoke(test, StringName(test_name), problems)
	await _invoke(test, &"after_each", problems)
	test.free_autofree()
	problems.append_array(test.failures)
	for error in _capture.take():
		problems.append("runtime error: %s" % error)
	_report(path, test_name, problems)
	var leaked := Node.get_orphan_node_ids().size() - orphans_before
	if leaked > 0:
		_leaky_tests += 1
		print("LEAK %s::%s - %d orphan node(s) left behind" % [path.get_file(), test_name, leaked])


## Calls `method` on `test`; if it is a coroutine, waits for it to finish
## (or times out, recording a problem).
func _invoke(test: TestCase, method: StringName, problems: Array[String]) -> void:
	var result: Variant = test.call(method)
	if not (result is Object and (result as Object).get_class() == "GDScriptFunctionState"):
		return
	var state := result as Object
	var deadline := Time.get_ticks_msec() + TEST_TIMEOUT_MSEC
	while is_instance_valid(state) and bool(state.call(&"is_valid")):
		if Time.get_ticks_msec() > deadline:
			problems.append("%s() still awaiting after %d ms" % [method, TEST_TIMEOUT_MSEC])
			return
		await process_frame


func _report(path: String, test_name: String, problems: Array[String]) -> void:
	if problems.is_empty():
		_passed += 1
		return
	_failed += 1
	for problem in problems:
		printerr("FAIL %s::%s - %s" % [path.get_file(), test_name, problem])


func _finish() -> void:
	if _finished:
		return
	_finished = true
	OS.remove_logger(_capture)
	if _leaky_tests > 0:
		print("%d test(s) leaked orphan nodes (see LEAK lines)" % _leaky_tests)
	print("%d passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


func _on_watchdog() -> void:
	if _finished:
		return
	printerr("FAIL test run did not finish within %d s" % int(RUN_TIMEOUT_SEC))
	_failed += 1
	_finish()


func _collect_test_files() -> Array[String]:
	var files: Array[String] = []
	for file in DirAccess.get_files_at(TEST_DIR):
		if file.begins_with("test_") and file.ends_with(".gd"):
			files.append("%s/%s" % [TEST_DIR, file])
	files.sort()
	return files
