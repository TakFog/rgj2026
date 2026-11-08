class_name TutorialIcons
extends RefCounted
## Shared icon textures for the "Come si gioca" chips and stage. Reuses the
## game's own sprites so the reference looks like the reef, not a generic UI.

const CO2_TEXTURE := preload("res://assets/sprites/temp/co2_cloud.svg")

## The funnel frame used as the cyclone chip icon (the most readable one).
const CYCLONE_ICON_FRAME := 3
static var _cyclone_icon: AtlasTexture

const HEIGHTS := {
	&"fish": 70.0,
	&"coral": 140.0,
	&"algae": 105.0,
	&"nest": 130.0,
	&"nest_eggs": 130.0,
	&"co2": 100.0,
	&"bag": 80.0,
	&"cyclone": 110.0,
	&"predator": 120.0,
	&"turtle": 100.0,
}


static func texture(id: StringName) -> Texture2D:
	match id:
		&"fish": return FishVisual.TEXTURE
		&"coral": return Coral.CORAL_TEXTURE
		&"algae": return Algae.TEXTURE
		&"nest": return Nest.EMPTY_TEXTURE
		&"nest_eggs": return Nest.EGGS_TEXTURE
		&"co2": return CO2_TEXTURE
		&"bag": return PlasticBag.TEXTURE
		&"cyclone": return _cyclone_icon_texture()
		&"predator": return PredatorVisual.TEXTURE
		&"turtle": return TurtleVisual.TEXTURE
		_: return null


static func height(id: StringName) -> float:
	return HEIGHTS.get(id, 100.0)


## The cyclone ships as a horizontal spritesheet, so the chip needs one frame.
static func _cyclone_icon_texture() -> AtlasTexture:
	if _cyclone_icon == null:
		var frame_width := float(Cyclone.TEXTURE.get_width()) / CycloneVisual.FRAMES
		_cyclone_icon = AtlasTexture.new()
		_cyclone_icon.atlas = Cyclone.TEXTURE
		_cyclone_icon.region = Rect2(
			CYCLONE_ICON_FRAME * frame_width, 0.0,
			frame_width, float(Cyclone.TEXTURE.get_height()))
	return _cyclone_icon
