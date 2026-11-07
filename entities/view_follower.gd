class_name ViewFollower
extends Node2D
## Screen-space visual that tracks a logical-world node through the projection.
## Lives under Game.view (y-sorted); freed automatically with its target.
## Static targets (corals, algae, nests never move) sync once and stop
## processing. Game.projection is only rebuilt by Game.reset(), when the scene
## is reloaded and every follower is recreated; call sync_position() to re-sync
## a static follower if its target or the projection ever changes.

var target: Node2D


## Creates a follower for `p_target`, parents `visual` to it and adds it to Game.view.
## `static_target`: the target never moves, so it is synced once, not every frame.
static func attach(p_target: Node2D, visual: Node2D, static_target: bool = false) -> ViewFollower:
	var follower := ViewFollower.new()
	follower.target = p_target
	follower.add_child(visual)
	Game.view.add_child(follower)
	# After add_child: entering the tree re-enables _process.
	follower.set_process(not static_target)
	follower.sync_position()
	p_target.tree_exiting.connect(follower.queue_free)
	return follower


func _process(_delta: float) -> void:
	if is_instance_valid(target):
		sync_position()


func sync_position() -> void:
	position = Game.projection.to_screen(target.global_position)
