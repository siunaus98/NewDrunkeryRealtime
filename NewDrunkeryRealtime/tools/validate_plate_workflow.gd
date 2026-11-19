extends SceneTree

const Items = preload("res://Scripts/Kitchen/TestItemDefs.gd")
const Context = preload("res://Scripts/Core/LevelContext.gd")
const Carry = preload("res://Scripts/Kitchen/CarryItemRules.gd")
const Focus = preload("res://Scripts/Player/InteractionFocusQuery.gd")
var failures: Array[String] = []
var main: Node
var player: CharacterBody2D
var interaction: RefCounted

func _initialize() -> void:
	call_deferred("_run")

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error(message)

func _stop_ticks(node: Node) -> void:
	node.set_process(false)
	node.set_physics_process(false)
	for child: Node in node.get_children():
		_stop_ticks(child)

func _hold(id: StringName, state: StringName = &"", payload: Dictionary = {}) -> void:
	player.clear_held_item()
	_check(player.pick_up_item(id, Items.get_item_texture(id), state, "", payload), "Setup must put the requested item in hand.")

func _focus(target: Node2D) -> void:
	player.global_position = target.get_interaction_rect_global().get_center() + Vector2(0, 110)
	player.aim_direction = Vector2.UP
	interaction._set_current_interaction_target(target)

func _test_assembly_and_delivery() -> void:
	var assembly: Node2D = main.get_node("AssemblyStation")
	var table: Node = main.get_node("PrepTableA")
	assembly.reset_state()
	table.reset_state()
	_focus(assembly)
	for i in range(2):
		_hold(Items.VEG_LEAF_ID, Items.PROCESS_STATE_CUT)
		player._handle_pickup_drop()
	_check(assembly.stored_items.size() == 2 and not player.is_holding_item(), "J deposits individual prepared ingredients without a plate.")
	player._handle_interact()
	_check(assembly.stored_items.size() == 1 and assembly.stored_items[0].item_id == Items.DISH_CRISP_PLATE_ID, "Empty-handed K makes a dish on the station.")
	player._handle_pickup_drop()
	_check(not player.is_holding_item() and assembly.stored_items.size() == 1, "An unplated dish cannot be collected empty-handed.")
	_hold(Items.PLATE_ID)
	player.pick_up_item(Items.VEG_LEAF_ID, Items.get_item_texture(Items.VEG_LEAF_ID), Items.PROCESS_STATE_CUT)
	player._handle_pickup_drop()
	_check(player.get_held_item_id() == Items.PLATE_ID and assembly.stored_items.size() == 1, "A nonempty plate cannot take a finished dish.")
	_hold(Items.PLATE_ID)
	player._handle_pickup_drop()
	_check(player.get_held_item_id() == Items.DISH_CRISP_PLATE_ID and player.get_held_item_payload().get("uses_plate", false) and assembly.stored_items.is_empty(), "Empty-plate J collects a dish and carries exactly that plate.")
	var signature: String = player.get_held_item_recipe_signature()
	_check(table.receive_item_from_player(player) and table.take_item_to_player(player), "A plated dish can be staged and recovered empty-handed.")
	_check(player.get_held_item_payload().get("uses_plate", false) and player.get_held_item_recipe_signature() == signature, "Staging preserves the plate and recipe signature.")
	_check(assembly.receive_item_from_player(player) and assembly.take_item_to_player(player), "An already plated dish may be staged on assembly and recovered without another plate.")
	_check(player.get_held_item_payload().get("uses_plate", false), "Assembly staging must retain an existing dish's plate.")
	var manager: Node = main.get_node("OrderManager")
	manager.set_orders([{"order_id": "plate_delivery", "target_slot": 1, "dish_item_id": Items.DISH_CRISP_PLATE_ID, "recipe_items": Items.get_recipe_for_dish(Items.DISH_CRISP_PLATE_ID)}])
	_check(manager.take_order_at_slot(1), "Plate delivery order must be accepted.")
	var counter: Node2D = main.get_node("TestServingCounter")
	interaction._set_current_interaction_target(counter, {"slot_index": 0})
	player._handle_pickup_drop()
	_check(player.get_held_item_id() == Items.DIRTY_PLATE_ID and not manager.has_active_order_for_slot(1), "Serving consumes food and leaves a dirty plate in hand.")
	# Recipe failure must leave the plate untouched until collection.
	assembly.reset_state()
	_focus(assembly)
	_hold(Items.EGG_ID)
	player._handle_pickup_drop()
	_hold(Items.PLATE_ID)
	player._handle_interact()
	_check(player.get_held_item_id() == Items.PLATE_ID and assembly.stored_items[0].item_id == Items.TRASH_ID, "K may fail while holding an empty plate without consuming it.")
	player._handle_interact()
	_check(assembly.stored_items.size() == 1 and player.get_held_item_id() == Items.PLATE_ID, "Repeated K cannot destroy a completed failure or its plate.")
	player._handle_pickup_drop()
	_check(player.get_held_item_id() == Items.TRASH_ID and player.get_held_item_payload().get("uses_plate", false), "Failed food also requires an empty plate to collect.")
	var sink: Node2D = main.get_node("PlateSink")
	var dirty_before: int = sink.dirty_plates
	_focus(sink)
	player._handle_pickup_drop()
	_check(player.get_held_item_id() == Items.TRASH_ID and player.get_held_item_payload().get("uses_plate", false) and sink.dirty_plates == dirty_before, "The basin must preserve plated food and never discard it.")
	_focus(main.get_node("TrashBin"))
	player._handle_pickup_drop()
	_check(player.get_held_item_id() == Items.DIRTY_PLATE_ID and sink.dirty_plates == dirty_before, "Discarding failed food in the bin leaves the dirty plate in hand.")
	_focus(sink)
	player._handle_pickup_drop()
	_check(not player.is_holding_item() and sink.dirty_plates == dirty_before + 1, "A separate J deposits the dirty plate physically.")
	# Alcohol in a food recipe does not make the result a drink.
	_check(Carry.needs_plate(Items.DISH_SPICED_LAMB_ID) and not Carry.needs_plate(Items.DRINK_DOUBLE_FERMENT_ID), "Plate policy uses the result category, not whether a recipe contains alcohol.")
	assembly.reset_state()
	for entry: Dictionary in Items.get_recipe_for_dish(Items.DRINK_DOUBLE_FERMENT_ID):
		for i in range(int(entry.get("count", 1))):
			_hold(StringName(entry.item_id), StringName(entry.process_state))
			_check(assembly.receive_item_from_player(player), "Drink ingredients can enter by hand.")
	_focus(assembly)
	player._handle_interact()
	_check(assembly.stored_items.size() == 1 and assembly.stored_items[0].item_id == Items.DRINK_DOUBLE_FERMENT_ID, "Drink recipe assembles empty-handed.")
	_hold(Items.PLATE_ID)
	player._handle_pickup_drop()
	_check(player.get_held_item_id() == Items.PLATE_ID and assembly.stored_items.size() == 1, "A plate cannot collect a finished drink.")
	player.clear_held_item()
	player._handle_pickup_drop()
	_check(player.get_held_item_id() == Items.DRINK_DOUBLE_FERMENT_ID and not player.get_held_item_payload().get("uses_plate", false), "Empty hands collect a drink without consuming a plate.")
	manager.set_orders([{"order_id": "drink_delivery", "target_slot": 1, "dish_item_id": Items.DRINK_DOUBLE_FERMENT_ID, "recipe_items": Items.get_recipe_for_dish(Items.DRINK_DOUBLE_FERMENT_ID)}])
	manager.take_order_at_slot(1)
	interaction._set_current_interaction_target(counter, {"slot_index": 0})
	player._handle_pickup_drop()
	_check(not player.is_holding_item() and not manager.has_active_order_for_slot(1), "Serving a drink leaves empty hands, never a dirty plate.")

func _test_collection_and_split() -> void:
	var table: Node2D = main.get_node("PrepTableA")
	table.reset_state()
	_hold(Items.PLATE_ID)
	for id: StringName in [Items.VEG_LEAF_ID, Items.EGG_ID]:
		_check(player.pick_up_item(id, Items.get_item_texture(id), Items.PROCESS_STATE_CUT), "Processed food can enter a plate.")
	table.receive_item_from_player(player)
	_focus(table)
	player._handle_interact()
	_check(player.get_held_item_id() == Items.EGG_ID and Array(table.item_payload.items).size() == 1, "K on a staged plate removes the last-added portion while leaving the plate.")
	player._handle_interact()
	_check(Array(table.item_payload.items).size() == 1, "Occupied hands cannot remove another plate portion.")
	player.clear_held_item()
	player._handle_pickup_drop()
	_check(player.get_held_item_id() == Items.PLATE_ID and Array(player.get_held_item_payload().items).size() == 1 and not table.has_item, "J takes the whole remaining plate.")
	# Use actual focus selection to detect a rejected raw item turning J into drop.
	var loose: Node2D = load("res://Scenes/Restaurant/loose_item.tscn").instantiate()
	main.add_child(loose)
	_stop_ticks(loose)
	loose.position = Vector2(3000, 1100)
	loose.setup_item(Items.EGG_ID, Items.get_item_texture(Items.EGG_ID))
	player.global_position = loose.global_position + Vector2(0, 100)
	var result: Dictionary = Focus.select_target(player, [loose], true, player.global_position, Vector2.UP, 190.0, PI * 0.25)
	_check(result.get("target") == loose, "Raw food remains a focus target for a held plate, despite being uncollectible.")
	interaction._set_current_interaction_target(loose)
	player._handle_pickup_drop()
	_check(player.get_held_item_id() == Items.PLATE_ID and not loose.is_queued_for_deletion(), "J on raw food neither collects it nor drops the plate.")
	loose.setup_item(Items.EGG_ID, Items.get_item_texture(Items.EGG_ID), Items.PROCESS_STATE_CUT)
	player._handle_pickup_drop()
	_check(loose.is_queued_for_deletion() and Array(player.get_held_item_payload().items).size() == 2, "J collects a prepared ground portion.")
	var plate: Node2D = load("res://Scenes/Restaurant/loose_item.tscn").instantiate()
	main.add_child(plate)
	_stop_ticks(plate)
	plate.setup_item(Items.PLATE_ID, Items.get_item_texture(Items.PLATE_ID), &"", "", player.get_held_item_payload())
	player.clear_held_item()
	interaction._set_current_interaction_target(plate)
	player._handle_interact()
	_check(player.get_held_item_id() == Items.EGG_ID and Array(plate.item_payload.items).size() == 1 and not plate.is_queued_for_deletion(), "Ground-plate K splits last-in-first-out without consuming the plate.")
	plate.queue_free()
	var assembly: Node2D = main.get_node("AssemblyStation")
	assembly.reset_state()
	_focus(assembly)
	_hold(Items.PLATE_ID)
	for i in range(6):
		player.pick_up_item(Items.VEG_LEAF_ID, Items.get_item_texture(Items.VEG_LEAF_ID), Items.PROCESS_STATE_CUT)
	player._handle_interact()
	_check(Array(player.get_held_item_payload().items).is_empty() and assembly.stored_items.size() == 6, "K unloads a full plate without making it dirty.")
	player.pick_up_item(Items.EGG_ID, Items.get_item_texture(Items.EGG_ID), Items.PROCESS_STATE_CUT)
	player._handle_interact()
	_check(Array(player.get_held_item_payload().items).size() == 1 and assembly.stored_items.size() == 6, "Insufficient assembly capacity rejects the entire unload atomically.")
	# Both a partly filled plate and a full plate can still be put down on
	# open ground, retaining their contents and physical plate on recovery.
	for count: int in [1, 6]:
		_hold(Items.PLATE_ID)
		for i in range(count):
			player.pick_up_item(Items.VEG_LEAF_ID, Items.get_item_texture(Items.VEG_LEAF_ID), Items.PROCESS_STATE_CUT)
		player.global_position = Vector2(3700, 1000)
		interaction.floor_interaction_position = Vector2(3820, 1000)
		interaction._set_current_interaction_target(null)
		var before: Array[Node] = get_nodes_in_group("loose_items")
		interaction.handle_pickup_drop(Vector2.RIGHT)
		_check(not player.is_holding_item(), "J on open ground must put down a plate with %d portions." % count)
		var dropped: Node
		for candidate: Node in get_nodes_in_group("loose_items"):
			if not before.has(candidate) and not candidate.is_queued_for_deletion():
				dropped = candidate
		_check(dropped != null, "Ground drop must create the physical plate.")
		if dropped != null:
			_stop_ticks(dropped)
			_check(dropped.take_item_to_player(player) and Array(player.get_held_item_payload().items).size() == count, "Ground roundtrip preserves every portion in the plate.")

func _test_hand_to_plate_and_station_storage() -> void:
	var table: Node2D = main.get_node("PrepTableA")
	table.reset_state()
	_hold(Items.PLATE_ID)
	table.receive_item_from_player(player)
	_focus(table)
	_hold(Items.MEAT_RED_ID, Items.PROCESS_STATE_ROAST_MEDIUM)
	player._handle_pickup_drop()
	_check(not player.is_holding_item() and table.item_id == Items.PLATE_ID and Array(table.item_payload.items).size() == 1, "J puts a hand-held prepared portion into a plate on a table.")
	_check(table.item_payload.items[0].process_state == Items.PROCESS_STATE_ROAST_MEDIUM, "Reverse plate transfer preserves exact maturity.")
	_hold(Items.SEASONING_BOX_ID, &"", Carry.seasoning(Items.SUN_SEED_ID, Items.PROCESS_STATE_GRIND_FINE))
	player._handle_pickup_drop()
	_check(Array(table.item_payload.items).size() == 2 and int(player.get_held_item_payload().servings) == 3, "Hand-held seasoning deposits one serving and retains the rest of the box.")
	_hold(Items.EGG_ID)
	player._handle_pickup_drop()
	_check(player.get_held_item_id() == Items.EGG_ID and Array(table.item_payload.items).size() == 2, "Raw hand-held food cannot enter a staged plate.")
	_hold(Items.DRINK_GOLD_ALE_ID)
	player._handle_pickup_drop()
	_check(player.get_held_item_id() == Items.DRINK_GOLD_ALE_ID and Array(table.item_payload.items).size() == 2, "Hand-held wine cannot enter a staged plate.")
	var loose: Node2D = load("res://Scenes/Restaurant/loose_item.tscn").instantiate()
	main.add_child(loose)
	_stop_ticks(loose)
	loose.position = Vector2(3000, 1100)
	loose.setup_item(Items.PLATE_ID, Items.get_item_texture(Items.PLATE_ID))
	_hold(Items.VEG_LEAF_ID, Items.PROCESS_STATE_CUT)
	var result: Dictionary = Focus.select_target(player, [loose], true, loose.global_position + Vector2(0, 100), Vector2.UP, 190.0, PI * 0.25)
	_check(result.get("target") == loose, "A ground plate can be focused while holding a prepared portion.")
	interaction._set_current_interaction_target(loose)
	for i in range(6):
		_hold(Items.VEG_LEAF_ID, Items.PROCESS_STATE_CUT)
		player._handle_pickup_drop()
	_check(not player.is_holding_item() and Array(loose.item_payload.items).size() == 6, "Six hand-held portions fill a ground plate without replacing it.")
	_hold(Items.EGG_ID, Items.PROCESS_STATE_CUT)
	result = Focus.select_target(player, [loose], true, loose.global_position + Vector2(0, 100), Vector2.UP, 190.0, PI * 0.25)
	_check(result.get("target") == loose, "A full ground plate keeps focus so a rejected deposit cannot become a ground drop.")
	player._handle_pickup_drop()
	_check(player.get_held_item_id() == Items.EGG_ID and Array(loose.item_payload.items).size() == 6 and not loose.is_queued_for_deletion(), "A full ground plate rejects a seventh portion without losing either item.")
	loose.queue_free()
	for station_name: String in ["TestCooker", "GrindCooker"]:
		var station: Node2D = main.get_node(station_name)
		for state: StringName in [Items.PROCESS_STATE_CUT, Items.PROCESS_STATE_ROAST_MEDIUM, Items.PROCESS_STATE_GRIND_FINE]:
			station.reset_state()
			_focus(station)
			_hold(Items.MEAT_RED_ID, state)
			player._handle_pickup_drop()
			_check(not player.is_holding_item() and station.has_item and not station.processing_active, "Manual station stores completed prepared food without enabling processing: %s / %s" % [station_name, state])
			player._handle_interact()
			station.process_hold_interaction(player, 30.0)
			station._process(30.0)
			_check(station.has_item and station.item_process_state == state and not station.processing_active, "K and elapsed time cannot reprocess stored prepared food.")
			player._handle_pickup_drop()
			_check(not station.has_item and player.get_held_item_id() == (Items.SEASONING_BOX_ID if state == Items.PROCESS_STATE_GRIND_FINE else Items.MEAT_RED_ID), "Stored prepared food remains immediately retrievable.")
			if state == Items.PROCESS_STATE_GRIND_FINE:
				_check(int(player.get_held_item_payload().servings) == 1, "Staging one ground portion cannot multiply it into four servings.")
		station.reset_state()
		_focus(station)
		_hold(Items.SEASONING_BOX_ID, &"", {"item_id": Items.SUN_SEED_ID, "process_state": Items.PROCESS_STATE_GRIND_FINE, "servings": 3})
		player._handle_pickup_drop()
		_check(not player.is_holding_item() and station.batch_servings == 3 and not station.processing_active, "Manual stations store whole finished seasoning boxes without processing.")
		_hold(Items.PLATE_ID)
		for i in range(3):
			player._handle_pickup_drop()
		_check(not station.has_item and Array(player.get_held_item_payload().items).size() == 3, "Staged seasoning preserves all three servings during plate collection.")
		station.reset_state()
		_hold(Items.PLATE_ID)
		player.pick_up_item(Items.MEAT_RED_ID, Items.get_item_texture(Items.MEAT_RED_ID), Items.PROCESS_STATE_ROAST_MEDIUM)
		player._handle_pickup_drop()
		_check(station.has_item and not station.processing_active and Array(player.get_held_item_payload().items).is_empty(), "Prepared portions can also be staged from a held plate.")
		player._handle_pickup_drop()
		_check(not station.has_item and Array(player.get_held_item_payload().items).size() == 1, "Staged portions can be collected back onto the held plate.")
	var roast: Node2D = main.get_node("BakeCooker")
	roast.reset_state()
	_focus(roast)
	for state: StringName in [Items.PROCESS_STATE_CUT, Items.PROCESS_STATE_GRIND_FINE]:
		_hold(Items.MEAT_RED_ID, state)
		player._handle_pickup_drop()
		_check(not roast.has_item and player.is_holding_item(), "Auto-roast station must not accept incompatible food as passive storage.")
	_hold(Items.SEASONING_BOX_ID, &"", Carry.seasoning(Items.SUN_SEED_ID, Items.PROCESS_STATE_GRIND_FINE))
	_check(not roast.can_receive_item(player), "Auto-roast station cannot store seasoning boxes.")
	_hold(Items.MEAT_RED_ID)
	player._handle_pickup_drop()
	_check(roast.has_item and roast.processing_active, "Normal raw roasting remains automatic.")
	roast.reset_state()
	player.clear_held_item()

func _test_occupied_hands_at_plate_rack() -> void:
	var sink: Node2D = main.get_node("PlateSink")
	var rack: Node2D = sink.get_node("CleanPlateRack")
	var cases: Array[Dictionary] = [
		{"id": Items.DISH_CRISP_PLATE_ID, "payload": {"uses_plate": true}},
		{"id": Items.TRASH_ID, "payload": {"uses_plate": true}},
		{"id": Items.DRINK_DOUBLE_FERMENT_ID},
		{"id": Items.EGG_ID},
		{"id": Items.MEAT_RED_ID, "state": Items.PROCESS_STATE_ROAST_MEDIUM},
		{"id": Items.DIRTY_PLATE_ID},
		{"id": Items.SEASONING_BOX_ID, "payload": Carry.seasoning(Items.SUN_SEED_ID, Items.PROCESS_STATE_GRIND_FINE)},
		{"id": Items.PLATE_ID, "payload": {"items": [Carry.portion(Items.EGG_ID, Items.PROCESS_STATE_CUT)]}}
	]
	for stock: int in [3, 0]:
		sink.clean_plates = stock
		sink._refresh()
		for entry: Dictionary in cases:
			_hold(entry.id, entry.get("state", &""), entry.get("payload", {}))
			var payload: Dictionary = player.get_held_item_payload()
			var loose_before: Array[Node] = get_nodes_in_group("loose_items")
			_focus(rack)
			for _press in range(3):
				# Recompute actual focus each time: a forced target hides the bug.
				interaction.update_current_interaction_target(player._get_interaction_origin(), Vector2.UP, player.interaction_radius, player.interaction_angle_degrees, player.floor_interaction_radius)
				_check(interaction.get_current_interaction_target() == rack, "Occupied hands must keep rack focus, including an empty rack.")
				player._handle_pickup_drop()
			_check(player.get_held_item_id() == entry.id and player.get_held_item_payload() == payload and player.get_held_item_process_state() == entry.get("state", &""), "Rack J preserves the held item, its portions and maturity.")
			_check(sink.clean_plates == stock, "Occupied hands must not consume or return a rack plate.")
			_check(get_nodes_in_group("loose_items") == loose_before, "Rejected rack interaction must not drop anything on the ground.")
			for loose: Node in get_nodes_in_group("loose_items"):
				if not loose_before.has(loose):
					loose.free()
	player.clear_held_item()
	sink.reset_state()
	_focus(rack)
	player._handle_pickup_drop()
	_check(player.get_held_item_id() == Items.PLATE_ID and sink.clean_plates == 2, "Empty hands can still take exactly one clean plate.")
	player._handle_pickup_drop()
	_check(not player.is_holding_item() and sink.clean_plates == 3, "An empty clean plate can still be returned.")

func _test_trash_bin() -> void:
	# The earlier delivery completes its test wave; restore daytime permissions.
	main.get_node("LevelFlowController").run_context.state = Context.LevelState.WAVE_ACTIVE
	var bin: Node2D = main.get_node("TrashBin")
	var sink: Node2D = main.get_node("PlateSink")
	_focus(bin)
	for id: StringName in [Items.EGG_ID, Items.TRASH_ID, Items.DRINK_GOLD_ALE_ID, Items.SEASONING_BOX_ID]:
		_hold(id, &"", Carry.seasoning(Items.SUN_SEED_ID, Items.PROCESS_STATE_GRIND_FINE) if id == Items.SEASONING_BOX_ID else {})
		player._handle_pickup_drop()
		_check(not player.is_holding_item(), "Bin J discards an unwanted item: %s" % id)
	_hold(Items.DISH_CRISP_PLATE_ID, &"", {"uses_plate": true})
	_focus(sink)
	var result: Dictionary = Focus.select_target(player, [sink], true, player.global_position, Vector2.UP, 190.0, PI * 0.25)
	_check(result.get("target") == sink, "Basin keeps focus while holding a dish so J cannot silently become a ground drop.")
	player._handle_pickup_drop()
	_check(player.get_held_item_id() == Items.DISH_CRISP_PLATE_ID and player.get_held_item_payload().get("uses_plate", false), "Basin J preserves both a normal dish and its plate.")
	_focus(bin)
	player._handle_pickup_drop()
	_check(player.get_held_item_id() == Items.DIRTY_PLATE_ID, "Discarding a normal plated dish returns its dirty plate.")
	player._handle_pickup_drop()
	_check(player.get_held_item_id() == Items.DIRTY_PLATE_ID, "Bin cannot delete a dirty plate.")
	_hold(Items.PLATE_ID)
	player._handle_pickup_drop()
	_check(player.get_held_item_id() == Items.PLATE_ID, "Bin cannot delete an empty clean plate.")
	for i in range(3):
		player.pick_up_item(Items.VEG_LEAF_ID, Items.get_item_texture(Items.VEG_LEAF_ID), Items.PROCESS_STATE_CUT)
	player._handle_pickup_drop()
	_check(player.get_held_item_id() == Items.PLATE_ID and Array(player.get_held_item_payload().items).is_empty(), "Discarding prepared portions preserves the clean transport plate.")
	player.clear_held_item()
	var origin: Vector2 = bin.global_position
	player._handle_interact()
	_check(player.get_carried_facility_node() == bin and bin.is_carried and bin.collision_layer == 0 and not bin.is_visible_in_tree(), "Bin K uses normal movable-facility pickup.")
	_check(not player.facility_carry_controller.get_sprite_previews().is_empty(), "Bin carry ghost uses its real artwork.")
	player.facility_carry_controller.cancel_carry()
	_check(bin.global_position == origin and bin.collision_layer == (4 | 16) and bin.is_visible_in_tree() and not bin.is_carried, "Bin cancellation restores its position, collision and visibility.")

func _test_wash_input() -> void:
	var sink: Node2D = main.get_node("PlateSink")
	sink.reset_state()
	_focus(sink)
	_hold(Items.DIRTY_PLATE_ID)
	Input.action_press("pickup_drop")
	player._handle_pickup_drop()
	await process_frame
	interaction.update_held_interaction(6.0)
	_check(sink.dirty_plates == 1 and sink.wash_progress == 0.0, "Holding the deposit J cannot automatically start washing.")
	Input.action_release("pickup_drop")
	interaction.update_held_interaction(0.0)
	Input.action_press("interact")
	await process_frame
	interaction.update_held_interaction(6.0)
	_check(sink.wash_progress == 0.0, "K cannot advance washing.")
	Input.action_release("interact")
	Input.action_press("pickup_drop")
	await process_frame
	interaction.update_held_interaction(4.0)
	_check(is_equal_approx(sink.wash_progress, 4.0), "A fresh held J advances washing.")
	Input.action_release("pickup_drop")
	await process_frame
	interaction.update_held_interaction(3.0)
	_check(is_equal_approx(sink.wash_progress, 4.0), "Releasing J pauses washing.")
	Input.action_press("pickup_drop")
	await process_frame
	interaction.update_held_interaction(1.0)
	_check(sink.dirty_plates == 0 and sink.wash_progress == 0.0, "Five total attended J seconds finish a plate.")
	Input.action_release("pickup_drop")
	interaction.update_held_interaction(0.0)

func _run() -> void:
	main = load("res://Scenes/Main/main.tscn").instantiate()
	root.add_child(main)
	await physics_frame
	await physics_frame
	paused = false
	_stop_ticks(main)
	player = main.get_node("Player")
	interaction = player.interaction_controller
	main.get_node("LevelFlowController").run_context.state = Context.LevelState.WAVE_ACTIVE
	_test_assembly_and_delivery()
	_test_collection_and_split()
	_test_hand_to_plate_and_station_storage()
	_test_occupied_hands_at_plate_rack()
	_test_trash_bin()
	await _test_wash_input()
	main.queue_free()
	await process_frame
	if failures.is_empty():
		print("PASS: bidirectional plate transfers, capacity and portion conservation, manual station storage, roast restrictions, J/K dish workflow, LIFO splitting, delivery and attended washing.")
	quit(0 if failures.is_empty() else 1)
