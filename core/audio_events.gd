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
		"res://assets/audio/co2/bubble_pop.mp3",
	],
	&"bag_destroyed": [ # a plastic bag pops
		"res://assets/audio/busta/b0.wav",
	],
	&"ui_click": [ # menu, pause and restart buttons
		"res://assets/audio/ui_click/click_0.wav",
	],
	&"ui_cancel": [ # cancelling placement or a selection
		"res://assets/audio/ui_cancel/cancel.wav",
	],
	&"ui_denied": [ # an invalid placement or a disabled inventory slot
		"res://assets/audio/ui_denied/denied.wav",
	],
	&"fish_select": [ # clicking a fish to control it
		"res://assets/audio/fish_select/select_0.wav",
		"res://assets/audio/fish_select/select_1.wav",
	],
	&"fish_order": [ # sending a selected fish to a point
		"res://assets/audio/fish_order/order.wav",
	],
	&"fish_eat": [ # a fish eats an algae
		"res://assets/audio/fish_eat/eat_0.wav",
		"res://assets/audio/fish_eat/eat_1.wav",
	],
	&"turtle_eat": [ # the turtle eats an algae, slower than a fish
		"res://assets/audio/turtle_eat/eat_0.wav",
		"res://assets/audio/turtle_eat/eat_1.wav",
	],
	&"eggs_laid": [ # a fish fertilizes a nest
		"res://assets/audio/eggs_laid/laid.wav",
	],
	&"eggs_hatched": [ # nest eggs hatch into juveniles
		"res://assets/audio/eggs_hatched/hatch.wav",
	],
	&"eggs_died": [ # nest eggs die from heat or CO2
		"res://assets/audio/eggs_died/died.wav",
	],
	&"fish_matured": [ # a juvenile becomes an adult
		"res://assets/audio/fish_matured/matured.wav",
	],
	&"fish_died": [ # a fish starves
		"res://assets/audio/fish_died/died.wav",
	],
	&"coral_hit": [ # a coral takes damage
		"res://assets/audio/coral_hit/hit.wav",
	],
	&"coral_destroyed": [ # a coral suffocates and crumbles
		"res://assets/audio/coral_destroyed/crumble.wav",
	],
	&"algae_spread": [ # an algae expands to a new cell
		"res://assets/audio/algae_spread/spread.wav",
	],
	&"predator_arrive": [ # a predator enters the island
		"res://assets/audio/predator_arrive/growl.wav",
	],
	&"predator_leave": [ # a sated or scared predator swims away
		"res://assets/audio/predator_leave/leave.wav",
	],
	&"bag_arrive": [ # a plastic bag drifts into view
		"res://assets/audio/bag_arrive/arrive.wav",
	],
	&"co2_arrive": [ # a CO2 cloud drifts into view
		"res://assets/audio/co2_arrive/arrive.wav",
	],
	&"threat_impact": [ # a bag or CO2 cloud hits something
		"res://assets/audio/threat_impact/impact.wav",
	],
	&"turtle_arrive": [ # the sea turtle arrives to help
		"res://assets/audio/turtle_arrive/arrive.wav",
	],
	&"turtle_ram": [ # the turtle rams the predator away
		"res://assets/audio/turtle_ram/ram.wav",
	],
	&"collapse_warning": [ # a population hits zero and its countdown starts
		"res://assets/audio/collapse_warning/warning.wav",
	],
	&"collapse_cancelled": [ # a population recovers before the collapse
		"res://assets/audio/collapse_cancelled/cancelled.wav",
	],
}

## Event for placing an item of `kind` (an InventoryModel kind): its own
## `placement_<kind>` when it has takes, otherwise the generic `placement`.
static func placement_event(kind: StringName) -> StringName:
	var specific := StringName("placement_%s" % kind)
	return specific if TAKES.has(specific) else &"placement"
