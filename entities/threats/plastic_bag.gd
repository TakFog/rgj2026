class_name PlasticBag
extends Threat
## Plastic bag (GDD §7.2): small, very slow, wobbly path.


func _init() -> void:
	kind = ThreatSchedule.Type.BAG
	radius = Game.actors.bag_radius
	speed = Game.actors.bag_speed
	turn_noise = Game.actors.bag_turn_noise
	color = Color(0.95, 0.95, 0.95, 0.85)
