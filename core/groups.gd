class_name Groups
extends RefCounted
## Scene-tree group names. GameState counts populations through these groups.

const CORALS := &"corals"
const ALGAE := &"algae"
const FISH := &"fish"
const NESTS := &"nests"
const THREATS := &"threats"
const PREDATORS := &"predators"
## The node playing the background music (Main's Music player).
const MUSIC := &"music"
const TURTLES := &"turtles"
## In-game HUD widgets (thermometer, inventory bar) hidden while the main menu is open.
const GAMEPLAY_HUD := &"gameplay_hud"
## The PopulationMonitor of the current run (lets the debug overlay end the run).
const POPULATION_MONITOR := &"population_monitor"
