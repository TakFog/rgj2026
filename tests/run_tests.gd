extends SceneTree
## Minimal headless test runner.
## Usage: tools/test.sh  (or: godot --headless --path . -s res://tests/run_tests.gd)
## Runs every `test_*` method of every tests/unit/test_*.gd script.

const TEST_DIR := "res://tests/unit"


func _initialize() -> void:
	var passed := 0
	var failed := 0
	for path in _collect_test_files():
		var script: GDScript = load(path)
		for method in script.get_script_method_list():
			var test_name: String = method["name"]
			if not test_name.begins_with("test_"):
				continue
			var test: TestCase = script.new()
			test.before_each()
			test.call(test_name)
			if test.failures.is_empty():
				passed += 1
			else:
				failed += 1
				for failure in test.failures:
					printerr("FAIL %s::%s - %s" % [path.get_file(), test_name, failure])
	print("%d passed, %d failed" % [passed, failed])
	quit(1 if failed > 0 else 0)


func _collect_test_files() -> Array[String]:
	var files: Array[String] = []
	for file in DirAccess.get_files_at(TEST_DIR):
		if file.begins_with("test_") and file.ends_with(".gd"):
			files.append("%s/%s" % [TEST_DIR, file])
	files.sort()
	return files
