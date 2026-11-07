class_name AudioEvents
extends RefCounted
## Sound effects, as event name -> takes. One take is picked at random per play;
## files that do not exist are skipped. Adding an event here also needs an entry
## in the audio settings (see docs/audio.md).

const TAKES := {
	&"placement": [ # placing an inventory item
		"res://assets/audio/corallo/c0.wav",
		"res://assets/audio/corallo/c1.wav",
		"res://assets/audio/corallo/c2.wav",
		"res://assets/audio/corallo/c3.wav",
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
