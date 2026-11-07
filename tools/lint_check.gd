extends SceneTree
## Loads every GDScript file and exits 1 if any fails to compile.
## With `-- --list-warnings` it instead prints the "warn"-level warning settings,
## which tools/lint.sh escalates to errors via a temporary override.cfg (headless
## Godot only prints warnings whose level is "error").

const WARNINGS_PREFIX := "debug/gdscript/warnings/"
const LEVEL_WARN := 1


func _initialize() -> void:
	if "--list-warnings" in OS.get_cmdline_user_args():
		_list_warnings()
		quit(0)
		return
	var failed := 0
	var checked := 0
	for path in _collect("res://"):
		if path == get_script().resource_path:
			continue
		checked += 1
		var script := load(path) as Script
		if script == null or not script.can_instantiate():
			failed += 1
	print("lint: checked %d scripts, %d failed" % [checked, failed])
	quit(1 if failed > 0 else 0)


func _list_warnings() -> void:
	for prop in ProjectSettings.get_property_list():
		var key: String = prop["name"]
		var value: Variant = ProjectSettings.get_setting(key)
		if key.begins_with(WARNINGS_PREFIX) and value is int and value == LEVEL_WARN:
			print("warning-key %s" % key.trim_prefix("debug/"))


func _collect(dir_path: String) -> PackedStringArray:
	var out := PackedStringArray()
	for sub in DirAccess.get_directories_at(dir_path):
		if sub.begins_with(".") or sub == "addons":
			continue
		out.append_array(_collect(dir_path.path_join(sub)))
	for file in DirAccess.get_files_at(dir_path):
		if file.get_extension() == "gd":
			out.append(dir_path.path_join(file))
	return out
