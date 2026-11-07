class_name InventoryModel
extends RefCounted
## Fixed-slot inventory with timed per-slot refill and weighted draws (GDD §5.1).
## An item is a Dictionary: { "kind": StringName, "shape_id": StringName }.
## An empty slot holds an empty Dictionary.

signal changed

const CORAL := &"coral"
const ALGAE := &"algae"
const NEST := &"nest"

var slots: Array[Dictionary] = []
var _refill_left: Array[float] = []
var _eco: BalanceEcosystem
var _rng: RandomNumberGenerator
var _nests_on_map: Callable


## `nests_on_map() -> int` is injected so the model stays testable without a scene.
func _init(eco: BalanceEcosystem, rng: RandomNumberGenerator, nests_on_map: Callable) -> void:
	_eco = eco
	_rng = rng
	_nests_on_map = nests_on_map
	for i in eco.inventory_slots:
		slots.append({})
		_refill_left.append(0.0)


## Fills every empty slot immediately (start of a run).
func fill_all() -> void:
	for i in slots.size():
		if slots[i].is_empty():
			slots[i] = draw()
	changed.emit()


func is_ready(index: int) -> bool:
	return not slots[index].is_empty()


func item(index: int) -> Dictionary:
	return slots[index]


## Removes the item from the slot and starts that slot's refill timer.
func take(index: int) -> Dictionary:
	var taken := slots[index]
	slots[index] = {}
	_refill_left[index] = _eco.slot_refill_seconds
	changed.emit()
	return taken


func tick(delta: float) -> void:
	var refilled := false
	for i in slots.size():
		if not slots[i].is_empty():
			continue
		_refill_left[i] -= delta
		if _refill_left[i] <= 0.0:
			slots[i] = draw()
			refilled = true
	if refilled:
		changed.emit()


## 0.0 right after use, 1.0 when the slot is full.
func refill_ratio(index: int) -> float:
	if is_ready(index):
		return 1.0
	return clampf(1.0 - _refill_left[index] / _eco.slot_refill_seconds, 0.0, 1.0)


func nests_in_inventory() -> int:
	var count := 0
	for slot in slots:
		if slot.get("kind") == NEST:
			count += 1
	return count


## nest_base_weight / (1 + nests on map + nests in inventory).
func nest_weight() -> float:
	return _eco.nest_base_weight / (1.0 + _nests_on_map.call() + nests_in_inventory())


## Weighted random item. Corals get a random shape.
func draw() -> Dictionary:
	var coral_weight := _eco.weight_coral
	var algae_weight := _eco.weight_algae
	var roll := _rng.randf() * (coral_weight + algae_weight + nest_weight())
	if roll < coral_weight:
		var ids := CoralShapes.ids()
		return {"kind": CORAL, "shape_id": ids[_rng.randi_range(0, ids.size() - 1)]}
	if roll < coral_weight + algae_weight:
		return {"kind": ALGAE, "shape_id": &""}
	return {"kind": NEST, "shape_id": &""}
