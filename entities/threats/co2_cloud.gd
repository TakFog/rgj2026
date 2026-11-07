class_name Co2Cloud
extends Threat
## CO2 cloud (GDD §7.1): large, slow, almost straight with gentle curves.


func _init() -> void:
	kind = ThreatSchedule.Type.CO2
	radius = Game.actors.co2_radius
	speed = Game.actors.co2_speed
	turn_noise = Game.actors.co2_turn_noise
	color = Color(0.6, 0.6, 0.65, 0.75)
