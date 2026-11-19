extends RefCounted

## Container contents travel as a separate payload; dish signatures keep their
## existing meaning. All payloads are copied at ownership boundaries.
const Items = preload("res://Scripts/Kitchen/TestItemDefs.gd")
const ProcessRules = preload("res://Scripts/Kitchen/CookerProcessRules.gd")
const PLATE_CAPACITY: int = 6
const GRIND_SERVINGS: int = 4

static func is_plate(item_id: StringName) -> bool:
	return item_id in [Items.PLATE_ID, Items.DIRTY_PLATE_ID]

static func can_collect(plate_payload: Dictionary, item_id: StringName, state: StringName, payload: Dictionary) -> bool:
	if Array(plate_payload.get("items", [])).size() >= PLATE_CAPACITY:
		return false
	if item_id == Items.SEASONING_BOX_ID:
		return int(payload.get("servings", 0)) > 0 and Items.is_ingredient(StringName(payload.get("item_id", &"")))
	return Items.is_ingredient(item_id) and not Items.is_raw_state(state) and state != Items.PROCESS_STATE_BURNT

static func needs_plate(item_id: StringName) -> bool:
	return (Items.is_dish(item_id) and not Items.is_drink(item_id)) or item_id == Items.TRASH_ID

static func can_load_dish(plate_payload: Dictionary, item_id: StringName, payload: Dictionary) -> bool:
	return needs_plate(item_id) and not bool(payload.get("uses_plate", false)) and Array(plate_payload.get("items", [])).is_empty()

static func can_put_into_plate(player: Node, item_id: StringName, payload: Dictionary) -> bool:
	return item_id == Items.PLATE_ID and player.is_holding_item() and can_collect(payload, player.get_held_item_id(), player.get_held_item_process_state(), payload_from(player))

static func put_into_plate(player: Node, item_id: StringName, payload: Dictionary) -> bool:
	if not can_put_into_plate(player, item_id, payload):
		return false
	var incoming_id: StringName = player.get_held_item_id()
	var incoming_payload: Dictionary = payload_from(player)
	var entries: Array = payload.get("items", []).duplicate(true)
	entries.append(portion(incoming_id, player.get_held_item_process_state(), player.get_held_item_recipe_signature(), incoming_payload))
	payload["items"] = entries
	player.clear_held_item()
	if incoming_id == Items.SEASONING_BOX_ID and int(incoming_payload.get("servings", 0)) > 1:
		incoming_payload["servings"] = int(incoming_payload.servings) - 1
		player.pick_up_item(incoming_id, Items.get_item_texture(incoming_id), &"", "", incoming_payload)
	return true

static func can_take_last_portion(player: Node, item_id: StringName, payload: Dictionary) -> bool:
	return item_id == Items.PLATE_ID and not player.is_holding_item() and not Array(payload.get("items", [])).is_empty()

static func take_last_portion(player: Node, item_id: StringName, payload: Dictionary) -> bool:
	if not can_take_last_portion(player, item_id, payload):
		return false
	var entries: Array = payload.get("items", [])
	var entry: Dictionary = entries.back()
	if not player.pick_up_item(StringName(entry.item_id), Items.get_item_texture(StringName(entry.item_id)), StringName(entry.get("process_state", &"")), String(entry.get("recipe_signature", "")), entry.get("payload", {})):
		return false
	entries.pop_back()
	payload["items"] = entries
	return true

static func portion(item_id: StringName, state: StringName, signature: String = "", payload: Dictionary = {}) -> Dictionary:
	if item_id == Items.SEASONING_BOX_ID:
		item_id = StringName(payload.get("item_id", &""))
		state = StringName(payload.get("process_state", &""))
		signature = ""
	var metadata: Dictionary = payload.duplicate(true)
	# Container fields describe the batch, not the single portion inside a plate.
	for key: String in ["item_id", "process_state", "servings"]:
		metadata.erase(key)
	return {"item_id": item_id, "process_state": state, "recipe_signature": signature, "texture": Items.get_item_texture(item_id), "payload": metadata}

static func is_collecting(player: Node) -> bool:
	return player != null and player.has_method("get_held_item_id") and player.get_held_item_id() == Items.PLATE_ID

static func payload_from(player: Node) -> Dictionary:
	return player.get_held_item_payload() if player.has_method("get_held_item_payload") else {}

static func seasoning(item_id: StringName, state: StringName, metadata: Dictionary = {}) -> Dictionary:
	var result: Dictionary = metadata.duplicate(true)
	result.merge({"item_id": item_id, "process_state": state, "servings": GRIND_SERVINGS}, true)
	return result

static func take_leaves_box(player: Node, item_id: StringName, payload: Dictionary) -> bool:
	return is_collecting(player) and item_id == Items.SEASONING_BOX_ID and int(payload.get("servings", 0)) > 1

static func find_processable_portion(payload: Dictionary, station_state: StringName) -> int:
	var entries: Array = payload.get("items", [])
	for i in range(entries.size()):
		var entry: Dictionary = entries[i]
		if Items.is_ingredient(StringName(entry.get("item_id", &""))) and ProcessRules.can_accept_process_state(station_state, StringName(entry.get("process_state", &""))):
			return i
	return -1

static func remove_plate_portion(player: Node, index: int) -> void:
	var data: Dictionary = payload_from(player)
	var entries: Array = data.get("items", [])
	entries.remove_at(index)
	data["items"] = entries
	player.set_held_item_payload(data)
