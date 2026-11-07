class_name Hud
extends Control
## Population counters (top left, flashing red when <= 1), survival time (top
## centre) and the collapse warning below it (GDD §3, §9, roadmap contract #10).

const NAMES := {&"corals": "Coralli", &"algae": "Alghe", &"fish": "Pesci", &"nests": "Nidi"}
const FLASH_PERIOD := 0.5
const CRITICAL_COLOR := Color(1.0, 0.3, 0.3)

var monitor: PopulationMonitor
var _counter_labels: Dictionary = {} # StringName -> Label
var _counts: Dictionary = {} # StringName -> int
var _score_label: Label
var _warning_label: Label
var _flash_time := 0.0


static func display_name(population: StringName) -> String:
	return NAMES.get(population, String(population))


static func format_time(seconds: float) -> String:
	var whole := floori(seconds)
	return "%02d:%02d" % [floori(whole / 60.0), whole % 60]


static func is_critical(count: int) -> bool:
	return count <= 1


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
	monitor.counts_changed.connect(_on_counts_changed)
	monitor.score_changed.connect(_on_score_changed)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_counters()
	_score_label = _make_centered_label(12.0, 32)
	_score_label.text = format_time(0.0)
	_warning_label = _make_centered_label(56.0, 24)
	_warning_label.add_theme_color_override("font_color", CRITICAL_COLOR)
	_warning_label.visible = false


func _process(delta: float) -> void:
	_flash_time += delta
	var flash_on := fmod(_flash_time, FLASH_PERIOD) < FLASH_PERIOD * 0.5
	for population: StringName in _counter_labels:
		var label: Label = _counter_labels[population]
		var critical := is_critical(_counts.get(population, 99))
		label.modulate = CRITICAL_COLOR if critical and flash_on else Color.WHITE
	_update_warning()


func _update_warning() -> void:
	if monitor == null or monitor.tracker == null:
		return
	var population := monitor.tracker.most_urgent()
	if population == &"":
		_warning_label.visible = false
		return
	var hatch := monitor.soonest_hatch_seconds() if population == Groups.FISH else -1.0
	_warning_label.text = warning_text(population, monitor.tracker.time_left(population), hatch)
	_warning_label.visible = true


func _on_counts_changed(counts: Dictionary) -> void:
	_counts = counts
	for population: StringName in counts:
		if _counter_labels.has(population):
			var label: Label = _counter_labels[population]
			label.text = "%s: %d" % [display_name(population), counts[population]]


func _on_score_changed(seconds: float) -> void:
	_score_label.text = format_time(seconds)


func _build_counters() -> void:
	var box := VBoxContainer.new()
	box.position = Vector2(16, 16)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(box)
	for population in PopulationMonitor.POPULATIONS:
		var label := Label.new()
		label.add_theme_font_size_override("font_size", 22)
		label.text = "%s: -" % display_name(population)
		box.add_child(label)
		_counter_labels[population] = label


func _make_centered_label(top: float, font_size: int) -> Label:
	var label := Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	add_child(label)
	label.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	label.offset_top = top
	label.offset_bottom = top + font_size * 2.5
	return label
