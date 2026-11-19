extends RefCounted

## Food transactions for the monitor boss. Never impersonate a player: eating
## cannot award work energy, trigger blessings or take an entire container.
const Items = preload("res://Scripts/Kitchen/TestItemDefs.gd")
const Carry = preload("res://Scripts/Kitchen/CarryItemRules.gd")
const Table = preload("res://Scripts/Kitchen/TestTable.gd")
const Cooker = preload("res://Scripts/Kitchen/TestCooker.gd")
const Assembly = preload("res://Scripts/Kitchen/AssemblyStation.gd")
const Loose = preload("res://Scripts/Kitchen/LooseItem.gd")
const Stack = preload("res://Scripts/Facilities/StackFacility.gd")

static func candidates(tree: SceneTree, bounds: Rect2, loose_only: bool = false) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for source: Node in tree.get_nodes_in_group("pickup_drop_targets"):
		if not source is Node2D or source.is_queued_for_deletion() or not source.is_visible_in_tree():
			continue
		if preload("res://Scripts/Facilities/FacilityWorkPause.gd").is_paused(source):
			continue
		if not bounds.has_point(source.global_position) or (loose_only and not source is Loose):
			continue
		if source is Stack and not source.active():
			continue
		var entries := _entries(source)
		for slot: int in entries.size():
			var item: Dictionary = entries[slot]
			if edible(item):
				result.append({"source": weakref(source), "slot": slot, "item": item.duplicate(true), "position": _position(source, slot)})
	return result

static func edible(item: Dictionary) -> bool:
	var id := StringName(item.get("item_id", &""))
	if id == Items.PLATE_ID:
		return Array(item.get("payload", {}).get("items", [])).any(func(entry: Dictionary) -> bool: return edible(entry))
	if id == Items.SEASONING_BOX_ID:
		return int(item.get("payload", {}).get("servings", 0)) > 0 and not Items.is_boss_ingredient(StringName(item.payload.get("item_id", &"")))
	if Items.is_boss_ingredient(id):
		return false
	if Items.is_dish(id):
		# Protect both special ingredients and completed special dishes.
		for component: Dictionary in Items.get_recipe_for_dish(id):
			if Items.is_boss_ingredient(StringName(component.item_id)):
				return false
		return not Items.is_drink(id)
	return Items.is_ingredient(id) or id == Items.TRASH_ID

static func quality(item: Dictionary) -> int:
	var id := StringName(item.get("item_id", &""))
	if id == Items.PLATE_ID:
		for entry: Dictionary in item.get("payload", {}).get("items", []):
			if edible(entry):
				return quality(entry)
	if Items.is_dish(id):
		return 3
	if id == Items.TRASH_ID:
		return 0
	return 1 if Items.is_raw_state(StringName(item.get("process_state", &""))) and id != Items.SEASONING_BOX_ID else 2

static func valid(target: Dictionary) -> bool:
	var source: Node = target.source.get_ref()
	if not is_instance_valid(source) or source.is_queued_for_deletion() or not source.is_visible_in_tree():
		return false
	if preload("res://Scripts/Facilities/FacilityWorkPause.gd").is_paused(source):
		return false
	var entries := _entries(source)
	var slot: int = target.slot
	return slot < entries.size() and entries[slot] == target.item and _position(source, slot).distance_to(target.position) < 16.0 and edible(entries[slot])

static func consume(target: Dictionary) -> Dictionary:
	if not valid(target):
		return {}
	return _consume_validated(target)

static func consume_many(targets: Array[Dictionary]) -> Array[Dictionary]:
	# Validate all locks before changing an assembly table's item positions.
	# Remove from the back so taking one entry cannot shift another locked slot.
	var result: Array[Dictionary] = []
	var indices: Array[int] = []
	for index in targets.size():
		result.append({})
		if not targets[index].is_empty() and valid(targets[index]):
			indices.append(index)
	indices.sort_custom(func(a: int, b: int) -> bool: return int(targets[a].slot) > int(targets[b].slot))
	for index in indices:
		result[index] = _consume_validated(targets[index])
	return result

static func _consume_validated(target: Dictionary) -> Dictionary:
	var source: Node = target.source.get_ref()
	var item: Dictionary = target.item.duplicate(true)
	var eaten := item.duplicate(true)
	eaten.get("payload", {}).erase("uses_plate")
	var id := StringName(item.item_id)
	if id == Items.PLATE_ID:
		var portions: Array = item.payload.get("items", [])
		for index in portions.size():
			if edible(portions[index]):
				eaten = portions[index].duplicate(true)
				portions.remove_at(index)
				break
		item.payload["items"] = portions
	elif id == Items.SEASONING_BOX_ID:
		eaten.payload.servings = 1
		item.payload.servings = int(item.payload.servings) - 1
		if int(item.payload.servings) <= 0:
			item = {}
	elif bool(item.get("payload", {}).get("uses_plate", false)):
		item = {"item_id": Items.DIRTY_PLATE_ID, "process_state": &"", "recipe_signature": "", "payload": {}}
	else:
		item = {}
	_write(source, int(target.slot), item)
	return eaten

static func _entries(source: Node) -> Array:
	if source.has_method("get_monitor_food_entries"):
		return source.get_monitor_food_entries()
	if source is Assembly:
		return source.stored_items
	if source is Stack:
		return [source.stored] if source.count > 0 and not source.stored.is_empty() else []
	if source is Loose or ((source is Table or source is Cooker) and source.has_item):
		var item: Dictionary = {"item_id": source.item_id, "process_state": source.item_process_state, "recipe_signature": "" if source is Cooker else source.item_recipe_signature, "payload": source.item_payload.duplicate(true)}
		if source is Cooker and Items.get_process_family(source.item_process_state) == &"grind":
			item.item_id = Items.SEASONING_BOX_ID
			item.payload = Carry.seasoning(source.item_id, source.item_process_state, source.item_payload)
			if source.batch_servings >= 0:
				item.payload.servings = source.batch_servings
		return [item]
	return []

static func _position(source: Node2D, slot: int) -> Vector2:
	if source is Assembly:
		return source.item_sprites.to_global(source._get_item_local_position(slot, source.stored_items.size()))
	if source is Cooker:
		return source.item_sprite.global_position
	if source is Table:
		return source.meat_sprite.global_position
	return source.global_position

static func _write(source: Node, slot: int, item: Dictionary) -> void:
	if source.has_method("set_monitor_food"):
		source.set_monitor_food(slot, item)
	elif source is Assembly:
		if item.is_empty():
			source.stored_items.remove_at(slot)
		else:
			source.stored_items[slot] = item
		source._update_item_visual()
	elif source is Stack:
		source.count -= 1
		if source.count <= 0:
			source.stored = {}
	elif source is Cooker:
		if not item.is_empty() and StringName(item.item_id) == Items.SEASONING_BOX_ID:
			source.batch_servings = int(item.payload.servings)
			source.processing_active = false
			source._update_item_visual()
		else:
			source._clear_item()
	elif item.is_empty():
		if source is Loose:
			source.queue_free()
		else:
			source.reset_state()
	else:
		source.item_id = StringName(item.item_id)
		source.item_texture = Items.get_item_texture(source.item_id)
		source.item_process_state = StringName(item.get("process_state", &""))
		source.item_recipe_signature = String(item.get("recipe_signature", ""))
		source.item_payload = item.get("payload", {}).duplicate(true)
		source._update_item_visual()
