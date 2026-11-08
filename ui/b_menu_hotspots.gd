class_name MenuHotspots
extends RefCounted
## Where the painted buttons of the title-screen art sit, and how that art is
## fitted on screen. Everything is kept in fractions of the painting, so the
## hotspots follow it at any window size (GDD §9, painted title screen).

## The painting shipped as `assets/ui/menu.png`: the 5699×3341 master in
## `video/MENU.png`, downscaled to 2048 px wide.
const ART_SIZE := Vector2(2048, 1200)

## Hotspot key -> its rect in fractions of the painting, in keyboard focus
## order. Measured from the painted pills' bounding boxes.
const RECTS := {
	"play": Rect2(0.610, 0.234, 0.380, 0.222),
	"settings": Rect2(0.527, 0.527, 0.401, 0.123),
	"tutorial": Rect2(0.471, 0.674, 0.400, 0.114),
	"exit": Rect2(0.373, 0.863, 0.263, 0.092),
	"credits": Rect2(0.655, 0.862, 0.263, 0.092),
}

## Hotspot key -> its painted pill's four corners (top-left, top-right,
## bottom-right, bottom-left), in fractions of the hotspot's rect. The pills
## are parallelograms, so a rectangular glow would sit visibly outside them;
## the menu clips its highlight to this shape instead.
const PILL_CORNERS := {
	"play": [
		Vector2(0.204, 0.0), Vector2(1.002, 0.0),
		Vector2(0.786, 1.0), Vector2(-0.012, 1.0),
	],
	"settings": [
		Vector2(0.100, 0.0), Vector2(0.998, 0.0),
		Vector2(0.884, 1.0), Vector2(-0.018, 1.0),
	],
	"tutorial": [
		Vector2(0.107, 0.0), Vector2(1.001, 0.0),
		Vector2(0.881, 1.0), Vector2(-0.012, 1.0),
	],
	"exit": [
		Vector2(0.195, 0.0), Vector2(1.001, 0.0),
		Vector2(0.786, 1.0), Vector2(-0.020, 1.0),
	],
	"credits": [
		Vector2(0.195, 0.0), Vector2(1.001, 0.0),
		Vector2(0.786, 1.0), Vector2(-0.020, 1.0),
	],
}


## The painting's rectangle on screen: as large as fits, keeping its aspect
## ratio, centred. Empty while the viewport has no size yet.
static func art_box(viewport: Vector2) -> Rect2:
	if viewport.x <= 0.0 or viewport.y <= 0.0:
		return Rect2()
	var scale := minf(viewport.x / ART_SIZE.x, viewport.y / ART_SIZE.y)
	var art_size := ART_SIZE * scale
	return Rect2((viewport - art_size) * 0.5, art_size)


## A hotspot in screen coordinates, inside the painting on `viewport`.
static func hotspot_rect(viewport: Vector2, key: String) -> Rect2:
	var art := art_box(viewport)
	var fraction: Rect2 = RECTS[key]
	return Rect2(art.position + art.size * fraction.position, art.size * fraction.size)


## The same hotspot in texture pixels, used to clip the additive glow.
static func hotspot_region(key: String) -> Rect2:
	var fraction: Rect2 = RECTS[key]
	return Rect2(fraction.position * ART_SIZE, fraction.size * ART_SIZE)
