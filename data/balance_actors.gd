class_name BalanceActors
extends Resource
## Tunables owned by Dev B (fish, threats, collapse rules).
## Values from GDD; tweak in data/balance_actors.tres.

@export_group("Fish")
@export var fish_radius := 10.0
@export var fish_click_radius := 24.0
@export var fish_speed := 60.0
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

@export_group("Collapse")
@export var collapse_grace_seconds := 10.0

@export_group("Threats")
@export var co2_radius := 60.0
@export var co2_speed := 40.0
## Max random heading change in radians per second.
@export var co2_turn_noise := 0.6
@export var co2_interval_cold := 30.0
@export var co2_interval_hot := 8.0
@export var co2_coral_damage := 50.0
## If true the cloud disappears after damaging its first coral; if false it keeps
## going and damages every coral it touches, each one only once.
@export var co2_dies_on_coral := true
@export var bag_radius := 16.0
@export var bag_speed := 20.0
@export var bag_turn_noise := 2.0
@export var bag_interval := 40.0
@export var bag_coral_damage := 35.0
@export var cyclone_radius := 40.0
@export var cyclone_speed := 160.0
@export var cyclone_interval_cold := 90.0
@export var cyclone_interval_hot := 30.0
