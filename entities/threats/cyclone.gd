class_name Cyclone
extends Threat
## Sea cyclone (GDD §7.3): fast and perfectly straight.


func _init() -> void:
	kind = ThreatSchedule.Type.CYCLONE
	radius = Game.actors.cyclone_radius
	speed = Game.actors.cyclone_speed
	turn_noise = 0.0
	color = Color(0.45, 0.85, 0.95, 0.8)
