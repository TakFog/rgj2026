class_name PlasticBag
extends Threat
## Plastic bag (GDD §7.2): small, very slow, wobbly path. Its sprite tumbles
## around its own centre like a bag caught in the current, and it floats with no
## ground shadow. Both are purely cosmetic.

## Temporary art, until the designer's sprite is ready.
const TEXTURE := preload("res://assets/sprites/temp/plastic_bag.png")

var _spin: TumbleSpin


func _init() -> void:
	kind = ThreatSchedule.Type.BAG
	radius = Game.actors.bag_radius
	speed = Game.actors.bag_speed
	turn_noise = Game.actors.bag_turn_noise
	color = Color(0.95, 0.95, 0.95, 0.85)
	texture = TEXTURE
	show_shadow = false


## The tumble is cosmetic: it shares the spawn RNG only so a seeded run looks
## the same every time, and never feeds back into the heading.
func setup(entry: EdgeEntry, rng: RandomNumberGenerator) -> void:
	super.setup(entry, rng)
	_spin = TumbleSpin.new(Game.actors.bag_spin_speed, rng)


func _animate_body(delta: float) -> void:
	if _spin == null or _body == null:
		return
	_body.rotation = _spin.step(delta)
