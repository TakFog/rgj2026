class_name CoralShapes
extends RefCounted
## Coral footprints as cell offsets from the coral origin cell (GDD §5.2).

const SHAPES := {
	&"single": [Vector2i(0, 0)],
	&"domino": [Vector2i(0, 0), Vector2i(1, 0)],
	&"ell": [Vector2i(0, 0), Vector2i(0, 1), Vector2i(1, 1)],
	&"square": [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)],
	&"tee": [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(1, 1)],
}


static func ids() -> Array[StringName]:
	var result: Array[StringName] = []
	for id in SHAPES.keys():
		result.append(id)
	return result


## Absolute cells covered by shape `id` placed with its origin at `origin`.
static func cells_at(id: StringName, origin: Vector2i) -> Array[Vector2i]:
	assert(SHAPES.has(id), "Unknown coral shape %s" % id)
	var result: Array[Vector2i] = []
	for offset in SHAPES[id]:
		result.append(origin + offset)
	return result
