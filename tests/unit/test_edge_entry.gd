extends TestCase

const ISLAND := Rect2(0, 0, 640, 640)
## Visible world area: a sheared quad around the island, like the oblique view.
const VISIBLE := [Vector2(-400, -300), Vector2(900, -300), Vector2(1300, 940), Vector2(-100, 940)]


func _visible() -> PackedVector2Array:
	return PackedVector2Array(VISIBLE)


func _distance_to_border(point: Vector2, polygon: PackedVector2Array) -> float:
	var best := INF
	for i in polygon.size():
		var closest := Geometry2D.get_closest_point_to_segment(point, polygon[i], polygon[(i + 1) % polygon.size()])
		best = minf(best, point.distance_to(closest))
	return best


func test_points_lie_on_visible_border() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	for i in 200:
		var entry := EdgeEntry.random(rng, _visible(), ISLAND)
		assert_almost(_distance_to_border(entry.point, _visible()), 0.0, 0.01, str(entry.point))


func test_heading_ray_hits_the_island() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in 200:
		var entry := EdgeEntry.random(rng, _visible(), ISLAND)
		var far := entry.point + Vector2.from_angle(entry.heading) * 10000.0
		var hits := Geometry2D.intersect_polyline_with_polygon(
			PackedVector2Array([entry.point, far]),
			PackedVector2Array([ISLAND.position, Vector2(ISLAND.end.x, 0), ISLAND.end, Vector2(0, ISLAND.end.y)]))
		assert_false(hits.is_empty(), "heading %s from %s misses" % [entry.heading, entry.point])


func test_uses_every_side() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var sides := {}
	var polygon := _visible()
	for i in 400:
		var entry := EdgeEntry.random(rng, polygon, ISLAND)
		for s in polygon.size():
			var closest := Geometry2D.get_closest_point_to_segment(entry.point, polygon[s], polygon[(s + 1) % polygon.size()])
			if entry.point.distance_to(closest) < 0.01:
				sides[s] = true
	assert_eq(sides.size(), 4)


func test_same_seed_gives_same_entry() -> void:
	var a := RandomNumberGenerator.new()
	var b := RandomNumberGenerator.new()
	a.seed = 99
	b.seed = 99
	var first := EdgeEntry.random(a, _visible(), ISLAND)
	var second := EdgeEntry.random(b, _visible(), ISLAND)
	assert_almost(first.point, second.point)
	assert_almost(first.heading, second.heading)
