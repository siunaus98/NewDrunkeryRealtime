extends SceneTree

const Items = preload("res://Scripts/Kitchen/TestItemDefs.gd")
const Carry = preload("res://Scripts/Kitchen/CarryItemRules.gd")
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error(message)

func _run() -> void:
	var main: Node = load("res://Scenes/Main/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	paused = false
	main.process_mode = Node.PROCESS_MODE_DISABLED
	var player: Node = main.get_node("Player")
	player.clear_held_item()
	player.pick_up_item(Items.PLATE_ID, Items.get_item_texture(Items.PLATE_ID))
	var view: RefCounted = player.interaction_controller.held_item_bubble
	_check(not view.panel.visible, "Empty plates have no contents bubble.")
	var states: Array[StringName] = [Items.PROCESS_STATE_CUT, Items.PROCESS_STATE_ROAST_RARE, Items.PROCESS_STATE_ROAST_MEDIUM, Items.PROCESS_STATE_ROAST_WELL, Items.PROCESS_STATE_GRIND_COARSE, Items.PROCESS_STATE_GRIND_FINE]
	for index in range(6):
		_check(player.pick_up_item(Items.MEAT_RED_ID, Items.get_item_texture(Items.MEAT_RED_ID), states[index]), "Plate accepts each processed portion.")
		_check(view.panel.visible and view.slots[index].visible, "Adding a portion refreshes the bubble immediately.")
		_check(view.slots[index].get_node("Process").texture == Items.get_process_icon_texture(states[index]), "Repeated ingredients retain their individual processing states.")
	_check(view.panel.size.x == 324.0, "Six portions fit the bounded single-row bubble.")
	Carry.remove_plate_portion(player, 5)
	_check(not view.slots[5].visible, "Removing a portion refreshes the bubble.")
	player.set_held_item_payload({"items": []})
	_check(not view.panel.visible, "Unloading a plate clears its bubble.")
	player.clear_held_item()
	var ingredients: Array[Dictionary] = [
		{"item_id": Items.MEAT_RED_ID, "process_state": Items.PROCESS_STATE_ROAST_RARE},
		{"item_id": Items.MEAT_RED_ID, "process_state": Items.PROCESS_STATE_ROAST_RARE},
		{"item_id": Items.MUSHROOM_ID, "process_state": Items.PROCESS_STATE_GRIND_FINE},
		{"item_id": Items.VEG_LEAF_ID, "process_state": Items.PROCESS_STATE_CUT},
		{"item_id": Items.DRINK_OASIS_WINE_ID, "process_state": Items.PROCESS_STATE_NONE}]
	player.pick_up_item(Items.DISH_RED_ROLL_ID, Items.get_item_texture(Items.DISH_RED_ROLL_ID), &"", Items.get_recipe_signature(ingredients), {"uses_plate": true})
	var visible_slots: int = 0
	for slot: Control in view.slots:
		if slot.visible:
			visible_slots += 1
	_check(visible_slots == 5, "Dishes show every actual portion, including cut and drink ingredients.")
	_check(view.dish_icon.visible and view.dish_icon.texture == Items.get_item_texture(Items.DISH_RED_ROLL_ID), "A separate dish icon identifies the finished recipe.")
	var rare_count: int = 0
	for slot: Control in view.slots:
		if slot.visible and slot.get_node("Process").texture == Items.get_process_icon_texture(Items.PROCESS_STATE_ROAST_RARE):
			rare_count += 1
	_check(rare_count == 2, "Dish maturity comes from actual ingredients rather than the default recipe.")
	var dish_entries: Array[Dictionary] = entries_for_dish(player)
	var has_cut: bool = false
	var has_drink: bool = false
	for entry: Dictionary in dish_entries:
		has_cut = has_cut or entry.process_state == Items.PROCESS_STATE_CUT
		has_drink = has_drink or entry.item_id == Items.DRINK_OASIS_WINE_ID
	_check(has_cut and has_drink, "Completed recipe contents retain cut state and the exact drink identity.")
	player.clear_held_item()
	_check(not view.panel.visible, "Serving or dropping a dish clears the bubble.")
	player.pick_up_item(Items.SEASONING_BOX_ID, Items.get_item_texture(Items.SEASONING_BOX_ID), &"", "", Carry.seasoning(Items.MUSHROOM_ID, Items.PROCESS_STATE_GRIND_COARSE))
	_check(view.slots[0].get_node("Ingredient").texture == Items.get_item_texture(Items.MUSHROOM_ID), "Held seasoning identifies its original ingredient.")
	_check(view.slots[0].get_node("Process").texture == Items.get_process_icon_texture(Items.PROCESS_STATE_GRIND_COARSE), "Held seasoning shows its grind state.")
	var mark: Node = player.interaction_controller.held_item_process_mark
	_check(mark.process_state == Items.PROCESS_STATE_GRIND_COARSE, "Seasoning box visual state follows its payload.")
	for child: Node in mark.get_children():
		_check(not child is TextureRect, "Physical food overlays must not duplicate floating maturity badges.")
	_check(mark.count_label.text == "4", "Removing maturity badges preserves seasoning portions.")
	player.clear_held_item()
	main.queue_free()
	await process_frame
	print("Held item bubble: %d failures" % failures.size())
	quit(0 if failures.is_empty() else 1)

func entries_for_dish(player: Node) -> Array[Dictionary]:
	return player.interaction_controller.held_item_bubble.contents(player.get_held_item_id(), player.get_held_item_process_state(), player.get_held_item_recipe_signature(), player.get_held_item_payload())
