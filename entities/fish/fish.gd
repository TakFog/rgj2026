class_name Fish
extends CharacterBody2D
## Fish: free-moving actor (GDD §5.4). Stub until Dev B's fish plan.
## CONTRACT (used by Dev A nest, Dev B threats): setup(), is_adult(), destroy().

signal destroyed

var adult := true


func setup(world_position: Vector2, p_adult: bool) -> void:
	position = world_position
	adult = p_adult


func _ready() -> void:
	collision_layer = Layers.FISH
	collision_mask = Layers.WALL | Layers.CORAL | Layers.ALGAE
	add_to_group(Groups.FISH)
	var circle := CircleShape2D.new()
	circle.radius = Game.actors.fish_radius
	var shape := CollisionShape2D.new()
	shape.shape = circle
	add_child(shape)
	ViewFollower.attach(self, PlaceholderShape.circle(position, Game.actors.fish_radius, Color(0.3, 0.7, 1.0)))


func is_adult() -> bool:
	return adult


func destroy() -> void:
	if is_queued_for_deletion():
		return
	remove_from_group(Groups.FISH)
	destroyed.emit()
	queue_free()
