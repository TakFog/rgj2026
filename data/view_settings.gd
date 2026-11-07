class_name ViewSettings
extends Resource
## Camera projection parameters, tuned by the designer (GDD §4.1).

@export var x_axis := Vector2(1, 0)
@export var y_axis := Vector2(-0.5, 0.5)
@export var pixels_per_unit := 1.25
## Camera zoom (< 1 zooms out). Just enough to keep the map's dark border off
## the top and bottom of the screen, while leaving sea around the island so
## incoming threats are visible before they reach it (GDD §7).
@export var zoom := 0.9
