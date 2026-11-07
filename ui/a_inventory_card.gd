class_name InventoryCard
extends BaseButton
## One inventory slot drawn as a sea-themed card (GDD §9): the item's own art
## (corals in their actual footprint, seen through the game's oblique view),
## a caption, and a radial refill ring while the slot is empty.
## Fully custom-drawn: no default Godot button styling.

const CARD_SIZE := Vector2(104, 114)
const CORNER_RADIUS := 14
const CAPTION_HEIGHT := 22.0
const CAPTION_FONT_SIZE := 14
const ICON_PADDING := 10.0
## Radius of the keyboard-shortcut badge drawn in the top-left corner.
const SHORTCUT_RADIUS := 10.0
const SHORTCUT_FONT_SIZE := 12
## Hover and selection lift the card, in pixels; eased toward the target.
const HOVER_LIFT := 3.0
const SELECTED_LIFT := 7.0
const LIFT_SPEED := 12.0
const POP_SECONDS := 0.2

## Palette sampled from the painted reef: deep teal water, sea-glass rim,
## warm sand. Muted on purpose: the cards should sit under the reef, not
## compete with it.
const BG_COLOR := Color(0.045, 0.13, 0.155, 0.9)
const BG_EMPTY_COLOR := Color(0.035, 0.09, 0.11, 0.72)
const RIM_COLOR := Color(0.47, 0.8, 0.78)
const SAND_COLOR := Color(0.98, 0.78, 0.45)
const SHADOW_COLOR := Color(0.0, 0.03, 0.04, 0.5)
const CAPTION_COLOR := Color(0.88, 0.94, 0.91)
const SEABED_COLOR := Color(0.98, 0.78, 0.45, 0.06)

const NAMES := {
	InventoryModel.CORAL: "Corallo",
	InventoryModel.ALGAE: "Alga",
	InventoryModel.NEST: "Nido",
}

var item: Dictionary = {}
var refill_ratio := 1.0
var selected := false
## Keyboard shortcut shown on the card (1-4); 0 hides the badge.
var hotkey := 0

var _lift := 0.0
var _style := StyleBoxFlat.new()


## Screen-space centres of the cells of coral shape `id`, in cell units,
## projected with the view axes and sorted back to front (draw order).
static func coral_icon_cells(id: StringName, x_axis: Vector2, y_axis: Vector2) -> Array[Vector2]:
	var projection := ViewProjection.new(x_axis, y_axis, 1.0)
	var result: Array[Vector2] = []
	for cell in CoralShapes.cells_at(id, Vector2i.ZERO):
		result.append(projection.to_screen(Vector2(cell)))
	result.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.y < b.y or (a.y == b.y and a.x < b.x))
	return result


static func caption(p_item: Dictionary) -> String:
	return NAMES.get(p_item.get("kind", &""), "")


func _ready() -> void:
	custom_minimum_size = CARD_SIZE
	focus_mode = Control.FOCUS_NONE
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	pivot_offset = CARD_SIZE * 0.5
	_style.set_corner_radius_all(CORNER_RADIUS)
	_style.anti_aliasing = true
	mouse_entered.connect(queue_redraw)
	mouse_exited.connect(queue_redraw)


## Updates what the card shows; redraws only when something changed.
func show_slot(p_item: Dictionary, p_ratio: float, p_selected: bool) -> void:
	if p_item == item and is_equal_approx(p_ratio, refill_ratio) and p_selected == selected:
		return
	item = p_item
	refill_ratio = p_ratio
	selected = p_selected
	disabled = item.is_empty()
	mouse_default_cursor_shape = Control.CURSOR_ARROW if disabled else Control.CURSOR_POINTING_HAND
	queue_redraw()


## Small bounce when the slot refills.
func pop() -> void:
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector2.ONE * 1.12, POP_SECONDS * 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "scale", Vector2.ONE, POP_SECONDS * 0.6).set_trans(Tween.TRANS_SINE)


func _process(delta: float) -> void:
	var target := 0.0
	if selected:
		target = SELECTED_LIFT
	elif is_hovered() and not disabled:
		target = HOVER_LIFT
	if not is_equal_approx(_lift, target):
		_lift = move_toward(_lift, target, maxf(absf(target - _lift), 0.5) * LIFT_SPEED * delta)
		queue_redraw()


func _draw() -> void:
	draw_set_transform(Vector2(0, -_lift))
	_draw_frame()
	if item.is_empty():
		_draw_refill()
	else:
		_draw_icon(_icon_rect())
		_draw_caption()
	_draw_shortcut()
	draw_set_transform(Vector2.ZERO)


## Number badge in the top-left corner so the 1-4 shortcuts are discoverable.
func _draw_shortcut() -> void:
	if hotkey <= 0:
		return
	var center := Vector2(SHORTCUT_RADIUS + 4.0, SHORTCUT_RADIUS + 4.0)
	draw_circle(center, SHORTCUT_RADIUS, Color(BG_COLOR, 0.95))
	draw_arc(center, SHORTCUT_RADIUS, 0.0, TAU, 24, Color(RIM_COLOR, 0.8), 2.0, true)
	var font := get_theme_default_font()
	var text := str(hotkey)
	var text_size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, SHORTCUT_FONT_SIZE)
	var baseline := center + Vector2(-text_size.x * 0.5, SHORTCUT_FONT_SIZE * 0.35)
	draw_string(font, baseline, text, HORIZONTAL_ALIGNMENT_LEFT, -1, SHORTCUT_FONT_SIZE, CAPTION_COLOR)


func _draw_frame() -> void:
	var hovered := is_hovered() and not disabled
	_style.bg_color = BG_EMPTY_COLOR if item.is_empty() else BG_COLOR
	_style.set_border_width_all(3 if selected else 2)
	if selected:
		_style.border_color = SAND_COLOR
		_style.shadow_color = Color(SAND_COLOR, 0.3)
		_style.shadow_size = 9
		_style.shadow_offset = Vector2.ZERO
	elif hovered:
		_style.border_color = Color(RIM_COLOR, 0.9)
		_style.shadow_color = Color(RIM_COLOR, 0.18)
		_style.shadow_size = 7
		_style.shadow_offset = Vector2.ZERO
	else:
		_style.border_color = Color(RIM_COLOR, 0.18 if item.is_empty() else 0.45)
		# No drop shadow at rest: the thin rim is enough, and avoids a heavy
		# dashboard look over the bright reef.
		_style.shadow_color = SHADOW_COLOR
		_style.shadow_size = 0
		_style.shadow_offset = Vector2.ZERO
	draw_style_box(_style, Rect2(Vector2.ZERO, size))


func _icon_rect() -> Rect2:
	var rect := Rect2(Vector2.ZERO, size - Vector2(0, CAPTION_HEIGHT))
	return rect.grow(-ICON_PADDING)


func _draw_caption() -> void:
	var font := get_theme_default_font()
	var color := SAND_COLOR if selected else CAPTION_COLOR
	var baseline := size.y - (CAPTION_HEIGHT - CAPTION_FONT_SIZE) * 0.5 - 6.0
	draw_string(font, Vector2(0, baseline), caption(item), HORIZONTAL_ALIGNMENT_CENTER, size.x, CAPTION_FONT_SIZE, color)


func _draw_icon(area: Rect2) -> void:
	# A soft patch of sand under the art ties the card to the reef map.
	var seabed_center := Vector2(area.get_center().x, area.end.y - area.size.y * 0.12)
	draw_set_transform(seabed_center - Vector2(0, _lift), 0.0, Vector2(1.0, 0.38))
	draw_circle(Vector2.ZERO, area.size.x * 0.5, SEABED_COLOR)
	draw_set_transform(Vector2(0, -_lift))
	match item["kind"]:
		InventoryModel.CORAL:
			_draw_coral(area, item["shape_id"])
		InventoryModel.ALGAE:
			_draw_fitted(Algae.TEXTURE, area)
		InventoryModel.NEST:
			_draw_fitted(Nest.EGGS_TEXTURE, area)


## Texture scaled to fit `area`, keeping its aspect, standing on the bottom.
func _draw_fitted(texture: Texture2D, area: Rect2) -> void:
	var tex_size := Vector2(texture.get_size())
	var k := minf(area.size.x / tex_size.x, area.size.y / tex_size.y)
	var drawn := tex_size * k
	var pos := Vector2(area.get_center().x - drawn.x * 0.5, area.end.y - drawn.y)
	draw_texture_rect(texture, Rect2(pos, drawn), false)


## The coral exactly as placed in game: one rock + tinted coral sprite per cell
## (sprite feet slightly below the cell centre, like PlaceholderShape.add_sprite),
## over its faint footprint, scaled to fit `area`.
func _draw_coral(area: Rect2, shape_id: StringName) -> void:
	var view := Game.VIEW_SETTINGS
	var cells := coral_icon_cells(shape_id, view.x_axis, view.y_axis)
	var footprint := PackedVector2Array()
	var corners := [Vector2(-0.5, -0.5), Vector2(0.5, -0.5), Vector2(0.5, 0.5), Vector2(-0.5, 0.5)]
	var projection := ViewProjection.new(view.x_axis, view.y_axis, 1.0)
	for corner in corners:
		footprint.append(projection.to_screen(corner))
	var tex := Coral.CORAL_TEXTURE
	var sprite_size := Vector2(float(tex.get_width()) / tex.get_height(), 1.0)
	# Bounds of every footprint and sprite, in cell units.
	var bounds := Rect2(cells[0], Vector2.ZERO)
	for center in cells:
		for point in footprint:
			bounds = bounds.expand(center + point)
		bounds = bounds.merge(_sprite_rect(center, sprite_size))
	var k := minf(area.size.x / bounds.size.x, area.size.y / bounds.size.y)
	var offset := area.get_center() - bounds.get_center() * k
	var footprint_color := Coral.HEALTHY_COLOR
	for center in cells:
		var poly := PackedVector2Array()
		for point in footprint:
			poly.append(offset + (center + point) * k)
		draw_colored_polygon(poly, footprint_color)
	for center in cells:
		var rect := _sprite_rect(center, sprite_size)
		rect = Rect2(offset + rect.position * k, rect.size * k)
		draw_texture_rect(Coral.BASE_TEXTURE, rect, false)
		draw_texture_rect(tex, rect, false, Coral.CORAL_HEALTHY_TINT)


static func _sprite_rect(center: Vector2, sprite_size: Vector2) -> Rect2:
	return Rect2(center + Vector2(-sprite_size.x * 0.5, -sprite_size.y * 0.9), sprite_size)


func _draw_refill() -> void:
	var center := size * 0.5
	var radius := minf(size.x, size.y) * 0.26
	draw_circle(center, radius + 6.0, Color(RIM_COLOR, 0.05))
	draw_arc(center, radius, 0.0, TAU, 48, Color(RIM_COLOR, 0.15), 6.0, true)
	draw_arc(center, radius, -PI / 2.0, -PI / 2.0 + TAU * refill_ratio, 48, Color(RIM_COLOR, 0.85), 6.0, true)
