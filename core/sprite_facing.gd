class_name SpriteFacing
extends RefCounted
## Orients a side-view creature sprite along its screen-space heading: the
## sprite is mirrored when swimming left (so it never turns upside down) and
## tilted toward the heading, up to `max_tilt` radians.
## The art is drawn at an arbitrary angle: `axis` is the direction (texture
## space, radians) from tail to head, `center` the body centre in texture px
## and `length` the body length in texture px.

var center: Vector2
var axis: float
var length: float
var max_tilt: float


func _init(p_center: Vector2, p_axis: float, p_length: float, p_max_tilt: float) -> void:
	center = p_center
	axis = p_axis
	length = p_length
	max_tilt = p_max_tilt


## Texture → local transform drawing the body `screen_length` px long, centred
## on the origin and facing `heading` (screen space). A zero heading faces right.
func transform(heading: Vector2, screen_length: float) -> Transform2D:
	var k := screen_length / length
	var upright := Transform2D(-axis, Vector2(k, k), 0.0, Vector2.ZERO) * Transform2D(0.0, -center)
	var left := heading.x < 0.0
	var angle := heading.angle() if heading != Vector2.ZERO else 0.0
	if left:
		angle = wrapf(angle - PI, -PI, PI)
	var facing := Transform2D(clampf(angle, -max_tilt, max_tilt), Vector2(-1.0 if left else 1.0, 1.0), 0.0, Vector2.ZERO)
	return facing * upright
