extends "res://Scripts/Facilities/FacilityBase.gd"

var count := 0
var seasoning := false

func _process(delta: float) -> void:
	super._process(delta)
	status.text = str(count)

func can_receive_item(player: Node) -> bool:
	if not active():
		return false
	var item := Cargo.held(player)
	if not Cargo.transportable(item):
		return false
	var box := StringName(item.item_id) == Cargo.Items.SEASONING_BOX_ID
	var amount := int(item.payload.get("servings", 0)) if box else 1
	if count == 0:
		return amount > 0 and amount <= (20 if box else 5)
	return box == seasoning and _key(item) == _key(stored) and count + amount <= (20 if seasoning else 5)

func _key(item: Dictionary) -> String:
	var box := StringName(item.item_id) == Cargo.Items.SEASONING_BOX_ID
	return "%s:%s" % [item.payload.get("item_id", &"") if box else item.item_id, item.payload.get("process_state", &"") if box else item.get("process_state", &"")]

func receive_item_from_player(player: Node) -> bool:
	if not can_receive_item(player):
		return false
	var incoming := Cargo.held(player)
	seasoning = StringName(incoming.item_id) == Cargo.Items.SEASONING_BOX_ID
	if count == 0:
		stored = incoming
	else:
		# Merging must not erase a rewarded marker from either source.
		stored.payload["process_energy_rewarded"] = bool(stored.payload.get("process_energy_rewarded", false)) or bool(incoming.payload.get("process_energy_rewarded", false))
	count += int(incoming.payload.servings) if seasoning else 1
	player.clear_held_item()
	return true

func take_item_to_player(player: Node) -> bool:
	if not can_take_item(player):
		return false
	var output := stored.duplicate(true)
	var amount := mini(count, 4) if seasoning and not Cargo.Carry.is_collecting(player) else 1
	if seasoning:
		output.payload.servings = amount
	if not Cargo.give(player, output):
		return false
	count -= amount
	if count <= 0:
		stored = {}
	return true

func get_interaction_button_prompt(_player: Node) -> String:
	return "J 存取同种同加工食材 · 5份/20份小料 / K 搬起"
