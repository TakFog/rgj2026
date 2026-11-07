class_name BalanceActors
extends Resource
## Tunables owned by Dev B (fish, threats, collapse rules).
## Values from GDD; tweak in data/balance_actors.tres.

@export_group("Fish")
@export var fish_radius := 10.0
@export var fish_click_radius := 24.0
## Pick radius used instead of fish_click_radius in touch builds: a fingertip
## covers far more than a mouse pointer.
@export var fish_touch_radius := 48.0
@export var fish_speed := 60.0
## Turning radius (world units) when changing direction: higher = wider curves.
@export var fish_turn_radius := 16.0
## Fraction of a frame's move that must survive sliding along an obstacle the
## fish grazed while following a route; less counts as blocked.
@export var fish_min_slide_ratio := 0.3
## Speed multiplier at temperature 1.0 (linear from 1.0 at temperature 0).
@export var fish_speed_hot_factor := 0.5
@export var fish_wander_min_seconds := 1.5
@export var fish_wander_max_seconds := 4.0
@export var idle_after_order_seconds := 2.0
@export var eat_seconds := 3.0
@export var fertilize_seconds := 3.0
@export var starve_seconds := 60.0
@export var hunger_bar_threshold := 0.5
@export var maturity_seconds := 45.0
## Hunger ratio from which a wandering fish swims to the nearest algae by itself.
@export var seek_food_threshold := 0.5
## Seconds a hungry fish waits before looking again when no algae is reachable.
@export var seek_retry_seconds := 1.0
## Minimum seconds between two autonomous fertilizations. The Fish node clamps
## it to at least twice the nest hatching time.
@export var reproduce_cooldown_seconds := 40.0
## Straight-line distance (world units) within which an empty nest is noticed.
@export var reproduce_nest_radius := 128.0

@export_group("Predator")
## Feature flag: set to false to turn the carnivorous predator off entirely.
@export var predator_enabled := true
## Seconds between two predator arrivals (at most predator_max_count at once).
@export var predator_interval := 70.0
@export var predator_max_count := 1
## Bigger than half a cell, so one-cell corridors between corals keep it out.
@export var predator_radius := 22.0
@export var predator_speed := 45.0
@export var predator_turn_radius := 24.0
## Satiety needed before it leaves the island.
@export var predator_satiety := 6.0
## Satisfaction per prey. Eggs are worth juvenile × eggs that would hatch.
@export var predator_juvenile_satisfaction := 1.0
@export var predator_adult_satisfaction := 2.0
## Leaves after this many seconds on the island even if not sated.
@export var predator_hunt_seconds := 45.0
## Pause after each bite.
@export var predator_bite_pause_seconds := 1.0
## How often it re-picks its prey and re-plans the route (prey moves).
@export var predator_replan_seconds := 0.5
## Extra distance beyond touching at which a bite lands.
@export var predator_bite_margin := 4.0

@export_group("Turtle")
## Feature flag: set to false to turn the sea turtle helper off entirely.
@export var turtle_enabled := true
## Seconds between two turtle arrivals (at most turtle_max_count at once).
@export var turtle_interval := 60.0
@export var turtle_max_count := 1
## Like the predator it is wider than half a cell: one-cell coral corridors
## keep it out.
@export var turtle_radius := 20.0
## Faster than the predator, so it can catch it.
@export var turtle_speed := 70.0
@export var turtle_turn_radius := 22.0
## Seconds to eat one algae (fish take eat_seconds).
@export var turtle_eat_seconds := 0.6
## Leaves after eating this many algae; 0 = no limit.
@export var turtle_max_algae := 0
## Leaves after this many seconds on the island.
@export var turtle_stay_seconds := 30.0
## How often it re-picks its job and re-plans the route (targets move).
@export var turtle_replan_seconds := 0.5
## Extra distance beyond touching at which it rams a threat or eats an algae.
@export var turtle_reach_margin := 4.0
## Straight-line distance within which it goes after a hunting predator.
@export var turtle_predator_aggro_radius := 160.0
## Straight-line distance within which it goes after a plastic bag.
@export var turtle_bag_aggro_radius := 320.0
## Chance (0..1) that a run starts with an early turtle rush. 0 disables it.
@export_range(0.0, 1.0) var turtle_rush_chance := 0.2
## Seconds into the run when the first rush turtle arrives.
@export var turtle_rush_seconds := 15.0
## Rush turtles in one event. The rush ignores `turtle_max_count` on purpose:
## that cap limits the normal helper cadence, not this event.
@export var turtle_rush_count := 2
## Seconds between two rush turtles, so they arrive as a group, not one frame.
@export var turtle_rush_spacing_seconds := 1.5
## Rush turtles leave after eating this many algae (0 = no limit, like
## `turtle_max_algae`). It keeps the rush hungry but finite, so a player who
## reacts can keep one algae alive until the group leaves.
@export var turtle_rush_max_algae := 4

@export_group("Collapse")
@export var collapse_grace_seconds := 10.0

@export_group("Threats")
@export var co2_radius := 60.0
@export var co2_speed := 40.0
## Max random heading change in radians per second.
@export var co2_turn_noise := 0.6
## Fraction of `co2_turn_noise` applied while the cloud is outside the playable
## island, so it crosses the open seabed almost straight.
@export_range(0.0, 1.0) var co2_outside_turn_scale := 0.1
@export var co2_interval_cold := 30.0
@export var co2_interval_hot := 8.0
@export var co2_coral_damage := 50.0
## If true the cloud disappears after damaging its first coral. Default false:
## it keeps going through the reef and damages every coral it touches, each one
## only once.
@export var co2_dies_on_coral := false
@export var bag_radius := 16.0
@export var bag_speed := 20.0
@export var bag_turn_noise := 2.0
## Cosmetic tumble of the bag sprite around its centre, in radians per second
## (peak). 0 freezes the bag. Never affects movement.
@export var bag_spin_speed := 1.5
@export var bag_interval := 40.0
@export var bag_coral_damage := 35.0
@export var cyclone_radius := 40.0
@export var cyclone_speed := 160.0
@export var cyclone_interval_cold := 90.0
@export var cyclone_interval_hot := 30.0
