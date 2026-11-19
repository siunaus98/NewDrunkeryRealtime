extends RefCounted

const Items = preload("res://Scripts/Kitchen/TestItemDefs.gd")
const Carry = preload("res://Scripts/Kitchen/CarryItemRules.gd")
const LOOSE = preload("res://Scenes/Restaurant/loose_item.tscn")

static func held(player: Node) -> Dictionary:
	if not player.is_holding_item():
		return {}
	return {"item_id": player.get_held_item_id(), "process_state": player.get_held_item_process_state(), "recipe_signature": player.get_held_item_recipe_signature(), "payload": Carry.payload_from(player).duplicate(true)}

static func give(player: Node, item: Dictionary) -> bool:
	if item.is_empty():
		return false
	var id := StringName(item.item_id)
	return player.pick_up_item(id, Items.get_item_texture(id), StringName(item.get("process_state", &"")), String(item.get("recipe_signature", "")), Dictionary(item.get("payload", {})).duplicate(true))

static func drop(parent: Node, at: Vector2, item: Dictionary) -> Node2D:
	var loose: Node2D = LOOSE.instantiate()
	parent.add_child(loose)
	loose.global_position = at
	var id := StringName(item.item_id)
	loose.setup_item(id, Items.get_item_texture(id), StringName(item.get("process_state", &"")), String(item.get("recipe_signature", "")), Dictionary(item.get("payload", {})).duplicate(true))
	return loose

static func copyable(item: Dictionary) -> bool:
	if item.is_empty():
		return false
	var id := StringName(item.item_id)
	if id == Items.SEASONING_BOX_ID:
		id = StringName(item.get("payload", {}).get("item_id", &""))
	return Items.is_ingredient(id) and not Items.is_boss_ingredient(id)

static func transportable(item: Dictionary) -> bool:
	return not item.is_empty() and (Items.is_ingredient(StringName(item.item_id)) or StringName(item.item_id) == Items.SEASONING_BOX_ID)
