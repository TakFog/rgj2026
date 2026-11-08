class_name Cyclone
extends Threat
## Sea cyclone (GDD §7.3): fast and perfectly straight.

## The 9-frame funnel spritesheet (frames are laid out horizontally).
const TEXTURE := preload("res://assets/sprites/cyclone.png")
## Funnel tint, shared with the tutorial's reference vignette.
const COLOR := Color(0.6, 0.9, 1.0, 0.9)


func _init() -> void:
	kind = ThreatSchedule.Type.CYCLONE
	radius = Game.actors.cyclone_radius
	speed = Game.actors.cyclone_speed
	turn_noise = 0.0
	color = COLOR
	texture = TEXTURE


## The swirling funnel, its spiral ground shadow and orbiting spray. All
## cosmetic: the contact footprint stays the threat's collision circle.
func _make_visual() -> Node2D:
	var visual := CycloneVisual.new()
	visual.setup(radius, color, TEXTURE)
	_body = visual.body
	return visual


## Cyclones are perfectly straight (GDD §7.3): they keep their heading even
## while crossing the open seabed and exiting the game area, so inward
## steering is disabled. They only stop when destroyed by a coral or once
## they leave the visible seabed.
func _steer_inward(p_heading: float, _delta: float) -> float:
	return p_heading
