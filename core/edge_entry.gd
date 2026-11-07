class_name EdgeEntry
extends RefCounted
## Where a threat enters the map (GDD §7): a random point on one of the four
## world edges and a heading pointing inward, randomised within ±spread radians.

var point: Vector2
## Unit vector perpendicular to the chosen edge, pointing into the world.
var inward: Vector2
var heading: float


static func random(rng: RandomNumberGenerator, world_size: Vector2, spread: float) -> EdgeEntry:
	var entry := EdgeEntry.new()
	match rng.randi_range(0, 3):
		0: # top
			entry.point = Vector2(rng.randf_range(0.0, world_size.x), 0.0)
			entry.inward = Vector2.DOWN
		1: # bottom
			entry.point = Vector2(rng.randf_range(0.0, world_size.x), world_size.y)
			entry.inward = Vector2.UP
		2: # left
			entry.point = Vector2(0.0, rng.randf_range(0.0, world_size.y))
			entry.inward = Vector2.RIGHT
		_: # right
			entry.point = Vector2(world_size.x, rng.randf_range(0.0, world_size.y))
			entry.inward = Vector2.LEFT
	entry.heading = entry.inward.angle() + rng.randf_range(-spread, spread)
	return entry
