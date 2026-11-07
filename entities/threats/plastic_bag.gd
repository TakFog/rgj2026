class_name PlasticBag
extends Threat
## Plastic bag (GDD §7.2): small, very slow, wobbly path.

## Temporary art, until the designer's sprite is ready.
const TEXTURE := preload("res://assets/sprites/temp/plastic_bag.png")


func _init() -> void:
	kind = ThreatSchedule.Type.BAG
	radius = Game.actors.bag_radius
	speed = Game.actors.bag_speed
	turn_noise = Game.actors.bag_turn_noise
	color = Color(0.95, 0.95, 0.95, 0.85)
	texture = TEXTURE
