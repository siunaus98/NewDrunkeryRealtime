extends Node

signal stock_changed(item_id: StringName, new_amount: int)
signal inventory_changed()

const TestItemDefs = preload("res://Scripts/Kitchen/TestItemDefs.gd")
const DEFAULT_TEST_STOCK: int = 4
const STOCK_KIND_FRESH: StringName = &"fresh"
const STOCK_KIND_FROZEN: StringName = &"frozen"

var fresh_stock: Dictionary = {}
var frozen_stock: Dictionary = {}
var stock_reservations: Dictionary = {}

func _ready() -> void:
	clear_all()

func clear_all() -> void:
	stock_reservations.clear()
	fresh_stock.clear()
	frozen_stock.clear()
	for item_id in TestItemDefs.get_all_ingredient_ids():
		fresh_stock[item_id] = 0
		frozen_stock[item_id] = 0
	inventory_changed.emit()

func clear_item_stock(item_id: StringName) -> void:
	# Invalidate outstanding scarab reservations together with the stolen stock.
	for id: int in stock_reservations.keys():
		if stock_reservations[id].item == item_id:
			stock_reservations.erase(id)
	fresh_stock[item_id] = 0
	frozen_stock[item_id] = 0
	_emit_item_stock_changed(item_id)
	inventory_changed.emit()

func fill_test_stock(amount_per_item: int = DEFAULT_TEST_STOCK) -> void:
	clear_all()
	var clamped_amount: int = max(amount_per_item, 0)
	for item_id in fresh_stock.keys():
		if TestItemDefs.is_boss_ingredient(item_id):
			continue
		fresh_stock[item_id] = clamped_amount
		_emit_item_stock_changed(item_id)
	inventory_changed.emit()

func add_stock(item_id: StringName, amount: int = 1, stock_kind: StringName = STOCK_KIND_FRESH) -> void:
	if amount <= 0 or not TestItemDefs.is_supported_item(item_id):
		return
	var target_stock: Dictionary = _get_stock_dictionary(stock_kind)
	target_stock[item_id] = _get_stock_from_dictionary(target_stock, item_id) + amount
	if stock_kind == STOCK_KIND_FROZEN:
		frozen_stock = target_stock
	else:
		fresh_stock = target_stock
	_emit_item_stock_changed(item_id)
	inventory_changed.emit()

func consume_stock(item_id: StringName, amount: int = 1, preferred_stock_kind: StringName = STOCK_KIND_FRESH) -> bool:
	if amount <= 0 or get_available_stock(item_id) < amount:
		return false

	var remaining: int = amount
	var stock_order: Array[StringName] = [preferred_stock_kind]
	var fallback_kind: StringName = STOCK_KIND_FROZEN if preferred_stock_kind == STOCK_KIND_FRESH else STOCK_KIND_FRESH
	if fallback_kind != preferred_stock_kind:
		stock_order.append(fallback_kind)

	for stock_kind in stock_order:
		if remaining <= 0:
			break
		var available: int = get_available_stock_by_kind(item_id, stock_kind)
		if available <= 0:
			continue
		var consumed: int = min(available, remaining)
		var target_stock: Dictionary = _get_stock_dictionary(stock_kind)
		target_stock[item_id] = _get_stock_from_dictionary(target_stock, item_id) - consumed
		if stock_kind == STOCK_KIND_FROZEN:
			frozen_stock = target_stock
		else:
			fresh_stock = target_stock
		remaining -= consumed

	if remaining > 0:
		return false

	_emit_item_stock_changed(item_id)
	inventory_changed.emit()
	return true

func _prune_stock_reservations() -> void:
	for id: int in stock_reservations.keys():
		var entry: Dictionary = stock_reservations[id]
		var owner: Object = entry.owner.get_ref()
		if owner == null or (owner is Node and owner.is_queued_for_deletion()) or not entry.valid.is_valid() or not entry.valid.call():
			stock_reservations.erase(id)

func get_available_stock_by_kind(item_id: StringName, kind: StringName, owner: Object = null) -> int:
	_prune_stock_reservations()
	var available := get_stock_by_kind(item_id, kind)
	for id: int in stock_reservations:
		var entry: Dictionary = stock_reservations[id]
		if owner != null and id == owner.get_instance_id():
			continue
		if entry.item == item_id and entry.kind == kind:
			available -= 1
	return maxi(available, 0)

func get_available_stock(item_id: StringName, owner: Object = null) -> int:
	return get_available_stock_by_kind(item_id, STOCK_KIND_FRESH, owner) + get_available_stock_by_kind(item_id, STOCK_KIND_FROZEN, owner)

func reserve_stock(owner: Object, item_id: StringName, valid: Callable) -> bool:
	_prune_stock_reservations()
	var id := owner.get_instance_id()
	if stock_reservations.has(id) and stock_reservations[id].item == item_id:
		return true
	release_stock_reservation(owner)
	if not valid.is_valid() or not valid.call():
		return false
	for kind: StringName in [STOCK_KIND_FRESH, STOCK_KIND_FROZEN]:
		if get_available_stock_by_kind(item_id, kind) > 0:
			stock_reservations[id] = {"owner": weakref(owner), "item": item_id, "kind": kind, "valid": valid}
			return true
	return false

func release_stock_reservation(owner: Object) -> void:
	if is_instance_valid(owner):
		stock_reservations.erase(owner.get_instance_id())

func consume_reserved_stock(owner: Object, item_id: StringName) -> bool:
	_prune_stock_reservations()
	var id := owner.get_instance_id()
	if not stock_reservations.has(id) or stock_reservations[id].item != item_id:
		return false
	var kind: StringName = stock_reservations[id].kind
	stock_reservations.erase(id)
	return consume_stock(item_id, 1, kind)

func get_stock(item_id: StringName) -> int:
	return get_fresh_stock(item_id) + get_frozen_stock(item_id)

func get_fresh_stock(item_id: StringName) -> int:
	return get_stock_by_kind(item_id, STOCK_KIND_FRESH)

func get_frozen_stock(item_id: StringName) -> int:
	return get_stock_by_kind(item_id, STOCK_KIND_FROZEN)

func get_stock_by_kind(item_id: StringName, stock_kind: StringName) -> int:
	var target_stock: Dictionary = _get_stock_dictionary(stock_kind)
	return _get_stock_from_dictionary(target_stock, item_id)

func get_stock_breakdown(item_id: StringName) -> Dictionary:
	return {
		"fresh": get_fresh_stock(item_id),
		"frozen": get_frozen_stock(item_id),
		"total": get_stock(item_id)
	}

func halve_all_stock() -> void:
	for item_id in fresh_stock.keys():
		var available := get_available_stock_by_kind(item_id, STOCK_KIND_FRESH)
		var reserved := get_fresh_stock(item_id) - available
		var halved_amount: int = reserved + maxi(int(floor(float(available) * 0.5)), 0)
		fresh_stock[item_id] = halved_amount
		_emit_item_stock_changed(item_id)
	inventory_changed.emit()

func _get_stock_dictionary(stock_kind: StringName) -> Dictionary:
	return frozen_stock if stock_kind == STOCK_KIND_FROZEN else fresh_stock

func _get_stock_from_dictionary(source_stock: Dictionary, item_id: StringName) -> int:
	return int(source_stock.get(item_id, 0))

func _emit_item_stock_changed(item_id: StringName) -> void:
	stock_changed.emit(item_id, get_stock(item_id))
