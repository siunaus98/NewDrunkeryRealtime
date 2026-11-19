extends Node

const TestItemDefs = preload("res://Scripts/Kitchen/TestItemDefs.gd")
const MapMechanismDefs = preload("res://Scripts/Core/MapMechanismDefs.gd")
const LOOSE_ITEM_SCENE := preload("res://Scenes/Restaurant/loose_item.tscn")

var scene_root: Node
var player: Node
var storage_manager: Node
var battle_manager: Node
var station_nodes: Array[Node] = []
var initial_loot_slots: Array[Dictionary] = []
var starting_stock_initialized: bool = false

func set_scene_refs(
	new_scene_root: Node,
	new_player: Node,
	new_storage_manager: Node,
	new_battle_manager: Node,
	new_station_nodes: Array[Node] = []
) -> void:
	scene_root = new_scene_root
	player = new_player
	storage_manager = new_storage_manager
	battle_manager = new_battle_manager
	station_nodes = new_station_nodes

func cache_initial_loot_slots() -> void:
	if scene_root == null or not initial_loot_slots.is_empty():
		return

	for node in get_tree().get_nodes_in_group("loose_items"):
		if not is_instance_valid(node):
			continue
		var item_id: StringName = _extract_loose_item_id(node)
		var category: String = _get_slot_category_for_item(item_id)
		if category == "":
			continue
		initial_loot_slots.append({
			"position": node.global_position,
			"category": category
		})

func reset_for_selected_group(run_context: LevelContext) -> void:
	if run_context == null:
		return
	_reset_player_state()
	_reset_storage_state()
	_reset_all_station_states()
	_respawn_loot_for_selected_group(run_context)

func reset_for_night(current_day_index: int, night_starting_stock_per_item: int) -> void:
	_reset_player_state()
	_reset_all_station_states()
	if not starting_stock_initialized:
		_fill_night_starting_stock(current_day_index, night_starting_stock_per_item)
		starting_stock_initialized = true

func build_progression_snapshot(run_context: LevelContext, current_day_index: int, progression_state: Object = null, advance_day: bool = true) -> Dictionary:
	if progression_state == null:
		return {
			"gold": 0,
			"xp": 0,
			"level": 1,
			"xp_for_next_level": 20,
			"day_index": current_day_index,
			"blessing_points": 0,
			"blessing_refreshes": 3,
			"skill_refreshes": 3,
			"small_skill_variant": &"rush_order",
			"big_skill_variant": &"steady_pot",
			"pending_small_skill_upgrade": false,
			"pending_big_skill_upgrade": false,
			"seen_blessings": {},
			"owned_blessings": {},
			"forged_attributes": {},
			"map_mechanism_order": MapMechanismDefs.get_all_ids(),
			"menu_drink_ids": [
				TestItemDefs.DRINK_OASIS_WINE_ID,
				TestItemDefs.DRINK_GOLD_ALE_ID,
				TestItemDefs.DRINK_QINGMEI_WINE_ID
			],
			"menu_non_drink_ids": [TestItemDefs.DISH_CRISP_PLATE_ID, TestItemDefs.DISH_RED_ROLL_ID],
			"menu_dish_ids": [
				TestItemDefs.DRINK_OASIS_WINE_ID,
				TestItemDefs.DRINK_GOLD_ALE_ID,
				TestItemDefs.DRINK_QINGMEI_WINE_ID,
				TestItemDefs.DISH_CRISP_PLATE_ID,
				TestItemDefs.DISH_RED_ROLL_ID
			]
		}
	# Keep the authoritative snapshot schema in RunProgressionState. New state
	# must survive day transitions without duplicating every field here.
	var snapshot: Dictionary = progression_state.get_snapshot()
	snapshot["day_index"] = current_day_index + 1 if run_context != null and advance_day else current_day_index
	return snapshot

func _reset_player_state() -> void:
	if player != null and player.has_meta("facility_vehicle"):
		var vehicle: Node = player.get_meta("facility_vehicle")
		if is_instance_valid(vehicle):
			vehicle._try_exit()
	if player != null and player.has_method("clear_held_item"):
		player.clear_held_item()
	if player != null and player.has_method("reset_temporary_state"):
		player.reset_temporary_state()

func _reset_station_state(station: Node) -> void:
	if station != null and station.has_method("reset_state"):
		station.reset_state()

func _reset_all_station_states() -> void:
	var all_stations: Array[Node] = station_nodes.duplicate()
	if not is_inside_tree():
		for station: Node in all_stations:
			_reset_station_state(station)
		return
	for group: String in ["kitchen_resettable", "cooking_stations", "new_facilities"]:
		for station: Node in get_tree().get_nodes_in_group(group):
			if not all_stations.has(station):
				all_stations.append(station)
	for station: Node in all_stations:
		_reset_station_state(station)
	# Resetting the rack also resets all circulating containers, once per phase.
	for item: Node in get_tree().get_nodes_in_group("loose_items"):
		if item.get("item_id") in [TestItemDefs.PLATE_ID, TestItemDefs.DIRTY_PLATE_ID, TestItemDefs.SEASONING_BOX_ID]:
			item.queue_free()

func _reset_storage_state() -> void:
	if storage_manager == null:
		return

func _respawn_loot_for_selected_group(run_context: LevelContext) -> void:
	if scene_root == null:
		return

	for node in get_tree().get_nodes_in_group("loose_items"):
		if is_instance_valid(node):
			if bool(node.get("item_payload").get("persistent_purchase", false)):
				continue
			node.queue_free()

	var selected_order_group: Dictionary = run_context.selected_order_group
	var allowed_meats: Array = selected_order_group.get("allowed_meats", [])
	var allowed_veggies: Array = selected_order_group.get("allowed_veggies", [])

	for slot_index in range(initial_loot_slots.size()):
		var slot_data: Dictionary = initial_loot_slots[slot_index]
		if String(slot_data.get("category", "")) == "meat":
			continue
		var item_id: StringName = _get_spawn_item_for_slot(
			String(slot_data.get("category", "")),
			allowed_meats,
			allowed_veggies,
			slot_index
		)
		if item_id == &"":
			continue

		var loose_item: Node2D = LOOSE_ITEM_SCENE.instantiate()
		scene_root.add_child(loose_item)
		if loose_item.has_method("setup_item"):
			loose_item.setup_item(item_id, TestItemDefs.get_item_texture(item_id), TestItemDefs.PROCESS_STATE_NONE)
		loose_item.global_position = slot_data.get("position", Vector2.ZERO)

	if battle_manager != null and battle_manager.has_method("configure_for_order_group"):
		battle_manager.configure_for_order_group(selected_order_group)

func _fill_night_starting_stock(current_day_index: int, night_starting_stock_per_item: int) -> void:
	if storage_manager != null and storage_manager.has_method("fill_test_stock"):
		storage_manager.fill_test_stock(night_starting_stock_per_item)

func _get_spawn_item_for_slot(category: String, allowed_meats: Array, allowed_veggies: Array, slot_index: int) -> StringName:
	match category:
		"meat":
			if allowed_meats.is_empty():
				return &""
			return StringName(allowed_meats[slot_index % allowed_meats.size()])
		"veg":
			if allowed_veggies.is_empty():
				return &""
			return StringName(allowed_veggies[slot_index % allowed_veggies.size()])
		_:
			return &""

func _extract_loose_item_id(node: Node) -> StringName:
	if node.has_method("get_item_id"):
		return node.get_item_id()
	var initial_item_id: Variant = node.get("initial_item_id")
	return StringName(initial_item_id) if initial_item_id != null else &""

func _get_slot_category_for_item(item_id: StringName) -> String:
	if item_id in [TestItemDefs.MEAT_RED_ID, TestItemDefs.MEAT_WHITE_ID, TestItemDefs.SHRIMP_ID, TestItemDefs.CAMEL_MEAT_ID]:
		return "meat"
	if item_id in [
		TestItemDefs.VEG_LEAF_ID,
		TestItemDefs.CABBAGE_ID,
		TestItemDefs.EGG_ID,
		TestItemDefs.VEG_ROOT_ID,
		TestItemDefs.TOFU_ID,
		TestItemDefs.MUSHROOM_ID,
		TestItemDefs.RICE_ID,
		TestItemDefs.SUN_SEED_ID
	]:
		return "veg"
	return ""
