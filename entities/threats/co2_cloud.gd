class_name Co2Cloud
extends Threat
## CO2 cloud (GDD §7.1): large, slow, almost straight with gentle curves.
## Drawn as a soft grey nebula fizzing with soda-like bubbles (see Co2Bubbles).


func _init() -> void:
	kind = ThreatSchedule.Type.CO2
	radius = Game.actors.co2_radius
	speed = Game.actors.co2_speed
	turn_noise = Game.actors.co2_turn_noise
	outside_turn_scale = Game.actors.co2_outside_turn_scale
	color = Color.WHITE


## The fizzy nebula, with no ground shadow. It floats as high as other threats.
func _make_visual() -> Node2D:
	var bubbles := Co2Bubbles.new()
	bubbles.radius_px = radius * Game.VIEW_SETTINGS.pixels_per_unit
	bubbles.tint = color
	bubbles.position = Vector2(0, -HOVER_PX)
	return bubbles
