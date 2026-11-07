class_name BalanceEcosystem
extends Resource
## Tunables owned by Dev A (grid, corals, algae, nests, inventory, temperature).
## Values from GDD; tweak in data/balance_ecosystem.tres.

@export_group("Grid")
@export var grid_size := Vector2i(20, 20)
@export var cell_size := 32.0

@export_group("Coral")
@export var coral_max_oxygen := 100.0
@export var coral_regen_per_sec := 0.5

@export_group("Algae")
@export var algae_growth_interval_cold := 12.0
@export var algae_growth_interval_hot := 4.0
@export var algae_growth_jitter := 0.2
@export var algae_max_count := 200
@export var algae_coral_damage := 10.0

@export_group("Nest")
@export var nest_hatch_seconds := 20.0
@export var nest_hatch_count := 3

@export_group("Inventory")
@export var inventory_slots := 4
@export var slot_refill_seconds := 8.0
@export var weight_coral := 50.0
@export var weight_algae := 40.0
@export var nest_base_weight := 20.0

@export_group("Temperature")
## Normalised temperature per second with no corals: reaches 1.0 in ~8 minutes.
@export var temp_base_rate := 1.0 / 480.0
@export var temp_slow_per_cell := 0.03
@export var temp_max_slowdown := 0.6
@export var temp_display_min_c := 26.0
@export var temp_display_max_c := 32.0
