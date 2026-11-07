class_name ThreatRules
extends RefCounted
## GDD §8 interaction table for threats, as pure data. Every damage is instant
## on contact. Combinations not listed here do nothing.

enum Target { NONE, CORAL, ALGAE, FISH, NEST, THREAT }
enum Effect { NOTHING, DAMAGE_CORAL, DESTROY, ABSORB_CO2, KILL_EGGS }


## What happens to the touched target, and whether the threat disappears.
class Outcome:
	var effect: int
	var amount: float
	var threat_dies: bool

	func _init(p_effect: int, p_amount: float, p_threat_dies: bool) -> void:
		effect = p_effect
		amount = p_amount
		threat_dies = p_threat_dies


## `already_hit` is true when this threat already touched this target before
## (only used for "CO2 damages each coral once"). `nest_has_eggs` only matters for NEST.
static func resolve(kind: int, target: int, actors: BalanceActors, already_hit: bool, nest_has_eggs: bool) -> Outcome:
	match kind:
		ThreatSchedule.Type.CO2:
			match target:
				Target.CORAL:
					if not already_hit:
						return Outcome.new(Effect.DAMAGE_CORAL, actors.co2_coral_damage, false)
				Target.ALGAE:
					return Outcome.new(Effect.ABSORB_CO2, 0.0, true)
				Target.NEST:
					if nest_has_eggs:
						return Outcome.new(Effect.KILL_EGGS, 0.0, false)
		ThreatSchedule.Type.BAG:
			match target:
				Target.FISH:
					return Outcome.new(Effect.DESTROY, 0.0, false)
				Target.CORAL:
					return Outcome.new(Effect.DAMAGE_CORAL, actors.bag_coral_damage, true)
		ThreatSchedule.Type.CYCLONE:
			match target:
				Target.CORAL:
					return Outcome.new(Effect.DESTROY, 0.0, true)
				Target.FISH, Target.ALGAE, Target.NEST, Target.THREAT:
					return Outcome.new(Effect.DESTROY, 0.0, false)
	return Outcome.new(Effect.NOTHING, 0.0, false)


## Classifies a touched node by its group (P0 contract: every entity is in one group).
static func target_of(node: Node) -> int:
	if node.is_in_group(Groups.CORALS):
		return Target.CORAL
	if node.is_in_group(Groups.ALGAE):
		return Target.ALGAE
	if node.is_in_group(Groups.FISH):
		return Target.FISH
	if node.is_in_group(Groups.NESTS):
		return Target.NEST
	if node.is_in_group(Groups.THREATS):
		return Target.THREAT
	return Target.NONE
