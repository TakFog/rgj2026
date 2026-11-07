class_name TurtleRush
extends RefCounted
## Early-run turtle rush (GDD §7). With `turtle_rush_chance`, a small group of
## turtles arrives shortly after the run starts instead of the usual single
## helper. The turtles come one after another (not all on the same frame), and
## each leaves after `turtle_rush_max_algae` algae. Because they arrive before
## the algae have spread, an unanswered rush can eat the algae population down
## to zero and collapse the reef ("Le alghe si sono estinte.").
##
## Pure scheduling: the spawner owns the RNG, edges and factory calls.

var _remaining := 0
var _next_in := 0.0
var _spacing := 0.0


## Rolls the rush once, at the start of the run. A chance of 0 never rushes;
## 1 always does.
func _init(cfg: BalanceActors, rng: RandomNumberGenerator) -> void:
	if cfg.turtle_rush_count <= 0 or cfg.turtle_rush_chance <= 0.0:
		return
	if rng.randf() >= cfg.turtle_rush_chance:
		return
	_remaining = cfg.turtle_rush_count
	_next_in = cfg.turtle_rush_seconds
	_spacing = maxf(cfg.turtle_rush_spacing_seconds, 0.0)


## True when this run rolled a rush that has not finished spawning.
func is_active() -> bool:
	return _remaining > 0


## Advances the schedule and returns how many turtles the spawner must create
## now. A long frame (hitch, hidden tab) may release more than one; the whole
## group is still released eventually and never more than `turtle_rush_count`.
func tick(delta: float) -> int:
	if _remaining <= 0:
		return 0
	_next_in -= delta
	if _next_in > 0.0:
		return 0
	var spawned := 0
	if _spacing <= 0.0:
		# A zero spacing means "all at once"; avoid an unbounded loop below.
		spawned = _remaining
		_remaining = 0
		return spawned
	while _remaining > 0:
		_remaining -= 1
		spawned += 1
		_next_in += _spacing
		if _next_in > 0.0:
			break
	return spawned
