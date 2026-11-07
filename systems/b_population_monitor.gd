class_name PopulationMonitor
extends Node
## Counts the four map populations every frame (roadmap contract #9), drives the
## CollapseTracker, accumulates the score (seconds survived) and ends the run.
## Pausable: score and countdowns freeze while the tree is paused.

signal counts_changed(counts: Dictionary)
signal score_changed(seconds: float)
signal countdown_started(population: StringName)
signal countdown_cancelled(population: StringName)
signal game_over(population: StringName, score_seconds: float)

const POPULATIONS: Array[StringName] = [Groups.CORALS, Groups.ALGAE, Groups.FISH, Groups.NESTS]

var tracker: CollapseTracker
var counts: Dictionary = {} # StringName -> int
var score_seconds := 0.0
var is_over := false


## Smallest positive eggs_time_left() among `nests`, or -1.0 if no nest has eggs.
static func soonest_hatch(nests: Array) -> float:
	var best := -1.0
	for nest in nests:
		var left: float = nest.eggs_time_left()
		if left > 0.0 and (best < 0.0 or left < best):
			best = left
	return best


func _ready() -> void:
	tracker = CollapseTracker.new(Game.actors.collapse_grace_seconds)
	tracker.countdown_started.connect(func(p: StringName) -> void: countdown_started.emit(p))
	tracker.countdown_cancelled.connect(func(p: StringName) -> void: countdown_cancelled.emit(p))
	tracker.collapsed.connect(_on_collapsed)


func _process(delta: float) -> void:
	if is_over:
		return
	score_seconds += delta
	score_changed.emit(score_seconds)
	var new_counts := {}
	for population in POPULATIONS:
		var count := get_tree().get_nodes_in_group(population).size()
		new_counts[population] = count
		tracker.report(population, count)
	if new_counts != counts:
		counts = new_counts
		counts_changed.emit(counts)
	tracker.tick(delta)


## Seconds until the first nest hatches, or -1.0 (fish-rescue hint, contract #10).
func soonest_hatch_seconds() -> float:
	return soonest_hatch(get_tree().get_nodes_in_group(Groups.NESTS))


func _on_collapsed(population: StringName) -> void:
	is_over = true
	game_over.emit(population, score_seconds)
	get_tree().paused = true
