class_name EdgeEntry
extends RefCounted
## Where a threat enters (GDD §7): a random point on the border of the visible
## world area (the seabed around the island) and a heading aimed at a random
## point of the island, so the player sees it coming across the seabed.

var point: Vector2
var heading: float


## `visible` is the visible world area as a convex polygon (any winding);
## the entry point is picked along its perimeter, weighted by side length.
static func random(rng: RandomNumberGenerator, visible: PackedVector2Array, island: Rect2) -> EdgeEntry:
	var perimeter := 0.0
	for i in visible.size():
		perimeter += visible[i].distance_to(visible[(i + 1) % visible.size()])
	var along := rng.randf_range(0.0, perimeter)
	var entry := EdgeEntry.new()
	for i in visible.size():
		var a := visible[i]
		var b := visible[(i + 1) % visible.size()]
		var length := a.distance_to(b)
		if along <= length or i == visible.size() - 1:
			entry.point = a.lerp(b, clampf(along / length, 0.0, 1.0))
			break
		along -= length
	var target := island.position + Vector2(rng.randf(), rng.randf()) * island.size
	entry.heading = (target - entry.point).angle()
	return entry
