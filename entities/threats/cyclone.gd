class_name Cyclone
extends Threat
## Sea cyclone (GDD §7.3): fast and perfectly straight.

## Temporary art, until the designer's sprite is ready.
const TEXTURE := preload("res://assets/sprites/temp/cyclone.png")


func _init() -> void:
	kind = ThreatSchedule.Type.CYCLONE
	radius = Game.actors.cyclone_radius
	speed = Game.actors.cyclone_speed
	turn_noise = 0.0
	color = Color(0.45, 0.85, 0.95, 0.8)
	texture = TEXTURE


## Cyclones are perfectly straight (GDD §7.3): they keep their heading even
## while crossing the open seabed and exiting the game area, so inward
## steering is disabled. They only stop when destroyed by a coral or once
## they leave the visible seabed.
func _steer_inward(p_heading: float, _delta: float) -> float:
	return p_heading
