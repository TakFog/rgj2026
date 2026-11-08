class_name LevelDirector
extends Node
## Runs the current level's time limit (GDD §3). When the countdown reaches zero
## with the reef alive it stops the population monitor, saves progress and
## announces the clear; if a population collapses first, the run is lost and the
## countdown stops. Pausable: the clock advances with delta only, so a pause or
## an open menu freezes it.

signal time_changed(seconds_left: float)
signal level_cleared(index: int, level: LevelDefinition)

var monitor: PopulationMonitor
var index := 0
var level: LevelDefinition
var clock: LevelClock

var _last_displayed_second := -1
var _finished := false


func _ready() -> void:
	index = LevelSession.clamp_current()
	level = LevelSession.current()
	clock = LevelClock.new(level.duration_seconds)
	if monitor != null:
		monitor.game_over.connect(_on_game_over)
	_emit_time()


func _process(delta: float) -> void:
	if _finished:
		return
	var cleared := clock.tick(Game.frame_step(delta))
	_emit_time()
	if cleared:
		_finish()


func time_left() -> float:
	return clock.remaining if clock != null else 0.0


## Seconds spent in this level (time limit minus time left).
func elapsed() -> float:
	return clock.elapsed() if clock != null else 0.0


func is_finished() -> bool:
	return _finished


func _emit_time() -> void:
	# The HUD only shows whole seconds; emitting every frame would redraw the
	# same string 60 times per second.
	var shown := ceili(clock.remaining)
	if shown == _last_displayed_second:
		return
	_last_displayed_second = shown
	time_changed.emit(clock.remaining)


func _finish() -> void:
	_finished = true
	# Keep a collapse countdown that is already running from ending the run on
	# the same frame the timer clears.
	if monitor != null:
		monitor.stop()
	# Clearing sets the level's record to the full time limit; later failed
	# attempts cannot beat it.
	UserSettings.submit_level_best(index, level.duration_seconds)
	UserSettings.mark_level_cleared(index, LevelCatalog.COUNT)
	level_cleared.emit(index, level)
	get_tree().paused = true


## A collapse won the race: stop the clock (the game-over screen freezes the tree).
func _on_game_over(_population: StringName, _score_seconds: float) -> void:
	_finished = true
