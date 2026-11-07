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
	&"item_available": [ # an inventory slot refills
		"res://assets/audio/item/i0.wav",
		"res://assets/audio/item/i1.wav",
		"res://assets/audio/item/i2.wav",
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
