class_name Hud
extends Control
## Survival time (top centre) and the collapse warning below it (GDD §3, §9,
## roadmap contract #10).

const NAMES := {&"corals": "Coralli", &"algae": "Alghe", &"fish": "Pesci", &"nests": "Nidi"}
const CRITICAL_COLOR := Color(1.0, 0.45, 0.4)
const SCORE_COLOR := Color(0.94, 0.97, 0.94)
const SCORE_FONT_SIZE := 30
const WARNING_FONT_SIZE := 22
## Top edge shared with the inventory cards and the thermometer.
const TOP := 20.0
## A dark outline keeps the free-floating HUD text readable over the reef.
const OUTLINE_SIZE := 5
const OUTLINE_COLOR := Color(0.01, 0.04, 0.05, 0.75)
## The warning only needs to change when the displayed second changes; the
## countdown itself advances every frame in the tracker.
const WARNING_REFRESH_SECONDS := 0.1

var monitor: PopulationMonitor
var _score_label: Label
var _warning_label: Label
var _warning_elapsed := WARNING_REFRESH_SECONDS
var _warning_text := ""
var _warning_visible := false


static func display_name(population: StringName) -> String:
	return NAMES.get(population, String(population))


static func format_time(seconds: float) -> String:
	var whole := floori(seconds)
	return "%02d:%02d" % [floori(whole / 60.0), whole % 60]


## Collapse warning text. `hatch_seconds` < 0 means "no eggs" (no hint shown).
static func warning_text(population: StringName, seconds_left: float, hatch_seconds: float) -> String:
	var text := "%s a zero! Collasso tra %d s" % [display_name(population), ceili(seconds_left)]
	if population == Groups.FISH and hatch_seconds >= 0.0:
		var verdict := "in tempo" if hatch_seconds <= seconds_left else "troppo tardi"
		text += "\nUova in schiusa tra %d s (%s)" % [ceili(hatch_seconds), verdict]
	return text


## Connect to a monitor. Safe to call before the HUD enters the tree.
func bind(p_monitor: PopulationMonitor) -> void:
	monitor = p_monitor
	monitor.score_changed.connect(_on_score_changed)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_score_label = _make_centered_label(TOP, SCORE_FONT_SIZE)
	_score_label.text = format_time(0.0)
	_score_label.add_theme_color_override("font_color", SCORE_COLOR)
	_warning_label = _make_centered_label(TOP + SCORE_FONT_SIZE + 8.0, WARNING_FONT_SIZE)
	_warning_label.add_theme_color_override("font_color", CRITICAL_COLOR)
	_warning_label.visible = false


func _process(delta: float) -> void:
	_warning_elapsed += delta
	if _warning_elapsed < WARNING_REFRESH_SECONDS:
		return
	_warning_elapsed = 0.0
	_update_warning()


func _update_warning() -> void:
	if monitor == null or monitor.tracker == null:
		return
	var population := monitor.tracker.most_urgent()
	if population == &"":
		if _warning_visible:
			_warning_label.visible = false
			_warning_visible = false
		return
	var hatch := monitor.soonest_hatch_seconds() if population == Groups.FISH else -1.0
	var text := warning_text(population, monitor.tracker.time_left(population), hatch)
	if text != _warning_text:
		_warning_text = text
		_warning_label.text = text
	if not _warning_visible:
		_warning_label.visible = true
		_warning_visible = true


func _on_score_changed(seconds: float) -> void:
	_score_label.text = format_time(seconds)


func _make_centered_label(top: float, font_size: int) -> Label:
	var label := Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_constant_override("outline_size", OUTLINE_SIZE)
	label.add_theme_color_override("font_outline_color", OUTLINE_COLOR)
	add_child(label)
	label.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	label.offset_top = top
	label.offset_bottom = top + font_size * 2.5
	return label
