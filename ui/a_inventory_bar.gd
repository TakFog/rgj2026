class_name InventoryBar
extends HBoxContainer
## Top-left inventory: one InventoryCard per slot, showing the item's art
## and a radial refill indicator (GDD §9).
## Pausable: no placing while the game is paused.

const SEPARATION := 12
const MARGIN := 20

var inventory: InventorySystem
var placement: PlacementController
var _cards: Array[InventoryCard] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	add_theme_constant_override("separation", SEPARATION)
	for i in inventory.model.slots.size():
		var card := InventoryCard.new()
		# Touch builds have no number keys, so no shortcut badge.
		card.hotkey = 0 if Platform.is_touch() else i + 1
		# Press starts placement and arms a drag; releasing over the reef places.
		card.button_down.connect(placement.begin_drag.bind(i))
		add_child(card)
		_cards.append(card)
	inventory.model.item_available.connect(_on_item_available)
	grow_horizontal = Control.GROW_DIRECTION_END
	grow_vertical = Control.GROW_DIRECTION_END
	set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT, Control.PRESET_MODE_MINSIZE, MARGIN)


func _process(_delta: float) -> void:
	for i in _cards.size():
		_cards[i].show_slot(inventory.model.item(i), inventory.model.refill_ratio(i), placement.active_slot == i)


func _on_item_available(index: int) -> void:
	_cards[index].pop()
