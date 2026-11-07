extends SceneTree
## Entry point of the jam trailer recorder (tools/trailer.sh). Loads the main
## scene with --smoke-play (no title menu), then adds the trailer director that
## plays the run and draws the captions. Run it through Godot's Movie Maker
## (--write-movie) so every frame is captured at a fixed frame rate.

## Loaded at runtime, not preloaded: a -s script is compiled before the
## autoloads (Game) are registered, and the director depends on them.
const DIRECTOR_PATH := "res://tools/trailer/trailer_director.gd"


func _initialize() -> void:
	change_scene_to_file("res://main/main.tscn")
	var director := (load(DIRECTOR_PATH) as GDScript).new() as Node
	director.name = "TrailerDirector"
	root.add_child.call_deferred(director)
