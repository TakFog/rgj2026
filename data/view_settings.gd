class_name ViewSettings
extends Resource
## Camera projection parameters, tuned by the designer (GDD §4.1).

@export var x_axis := Vector2(1, 0)
@export var y_axis := Vector2(-0.5, 0.5)
@export var pixels_per_unit := 1.25
## Camera zoom (< 1 zooms out). Fills the screen height with the map's water so
## no empty seabed shows above or below, while still leaving sea around the
## island so incoming threats are visible before they reach it (GDD §7).
@export var zoom := 1.0
