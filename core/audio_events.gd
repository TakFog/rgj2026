class_name AudioEvents
extends RefCounted
## Sound effects, as event name -> takes. One take is picked at random per play;
## files that do not exist are skipped. Adding an event here also needs an entry
## in the audio settings (see docs/audio.md).

const TAKES := {
	&"placement": [ # placing any inventory item, unless its kind has its own event
		"res://assets/audio/corallo/c0.wav",
		"res://assets/audio/corallo/c1.wav",
		"res://assets/audio/corallo/c2.wav",
		"res://assets/audio/corallo/c3.wav",
	],
	&"placement_nest": [ # placing a nest (nido)
		"res://assets/audio/nido/nido0.wav",
	],
	&"placement_algae": [ # placing an algae
		"res://assets/audio/alga/alga.wav",
	],
	&"predator_ate": [ # a predator bites a fish or a nest's eggs
		"res://assets/audio/eat/eat.wav",
	],
	&"item_hover": [ # clicking an inventory item to start placing it
		"res://assets/audio/item/item_hover.wav",
	],
	&"item_available": [ # an inventory slot refills
		"res://assets/audio/item/i0.wav",
		"res://assets/audio/item/i1.wav",
		"res://assets/audio/item/i2.wav",
	],
	&"cyclone_wind": [ # looping wind while a cyclone is on screen
		"res://assets/audio/wind/wind.wav",
	],
	&"cyclone_hit": [ # a cyclone destroys something
		"res://assets/audio/wind_hit.wav",
	],
	&"co2_gone": [ # a CO2 cloud disappears
		"res://assets/audio/co2/fart.wav",
	],
	&"bag_destroyed": [ # a plastic bag pops
		"res://assets/audio/busta/b0.wav",
	],
}

## Event for placing an item of `kind` (an InventoryModel kind): its own
## `placement_<kind>` when it has takes, otherwise the generic `placement`.
static func placement_event(kind: StringName) -> StringName:
	var specific := StringName("placement_%s" % kind)
	return specific if TAKES.has(specific) else &"placement"
