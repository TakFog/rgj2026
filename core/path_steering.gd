class_name PathSteering
extends RefCounted
## Curved swimming (GDD §5.4): the heading turns toward the target with a
## bounded turning radius instead of snapping. Near the target the radius
## shrinks to at most half the remaining distance, so the circle the fish swims
## on always passes through the target and it never orbits around it. Pure.


## `heading` turned toward `to_target` after swimming `distance` world units
## with turning radius `turn_radius`. Returns a unit vector.
static func turn(heading: Vector2, to_target: Vector2, distance: float, turn_radius: float) -> Vector2:
	var target_distance := to_target.length()
	if target_distance <= 0.0:
		return heading
	var radius := minf(turn_radius, target_distance * 0.5)
	if radius <= 0.0:
		return to_target / target_distance
	var max_angle := distance / radius
	var angle := heading.angle_to(to_target)
	return heading.rotated(clampf(angle, -max_angle, max_angle)).normalized()
