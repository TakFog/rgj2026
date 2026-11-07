class_name ViewFollower
extends Node2D
## Screen-space visual that tracks a logical-world node through the projection.
## Lives under Game.view (y-sorted); freed automatically with its target.

var target: Node2D


## Creates a follower for `p_target`, parents `visual` to it and adds it to Game.view.
static func attach(p_target: Node2D, visual: Node2D) -> ViewFollower:
	var follower := ViewFollower.new()
	follower.target = p_target
	follower.add_child(visual)
	Game.view.add_child(follower)
	follower.sync_position()
	p_target.tree_exiting.connect(follower.queue_free)
	return follower


func _process(_delta: float) -> void:
	if is_instance_valid(target):
		sync_position()


func sync_position() -> void:
	position = Game.projection.to_screen(target.global_position)
