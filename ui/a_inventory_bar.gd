class_name InventoryBar
extends HBoxContainer
## Bottom-centre inventory: one InventoryCard per slot, showing the item's art
## and a radial refill indicator (GDD §9).
## Pausable: no placing while the game is paused.

const SEPARATION := 14
const BOTTOM_MARGIN := 18

var inventory: InventorySystem
var placement: PlacementController
var _cards: Array[InventoryCard] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	add_theme_constant_override("separation", SEPARATION)
	for i in inventory.model.slots.size():
		var card := InventoryCard.new()
		card.pressed.connect(placement.begin.bind(i))
		add_child(card)
		_cards.append(card)
	inventory.model.item_available.connect(_on_item_available)
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	grow_vertical = Control.GROW_DIRECTION_BEGIN
	set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM, Control.PRESET_MODE_MINSIZE, BOTTOM_MARGIN)


func _process(_delta: float) -> void:
	for i in _cards.size():
		_cards[i].show_slot(inventory.model.item(i), inventory.model.refill_ratio(i), placement.active_slot == i)


func _on_item_available(index: int) -> void:
	_cards[index].pop()
