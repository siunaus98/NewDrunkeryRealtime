extends SceneTree

const Items = preload("res://Scripts/Kitchen/TestItemDefs.gd")
const Carry = preload("res://Scripts/Kitchen/CarryItemRules.gd")
const Context = preload("res://Scripts/Core/LevelContext.gd")
const Focus = preload("res://Scripts/Player/InteractionFocusQuery.gd")
var failures: Array[String] = []
var main: Node
var player: CharacterBody2D

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

func _hold(id: StringName, state: StringName = &"", data: Dictionary = {}) -> void:
	player.clear_held_item()
	_check(player.pick_up_item(id, Items.get_item_texture(id), state, "", data), "Test item must enter an empty hand.")

func _entries() -> Array:
	return player.get_held_item_payload().get("items", [])

func _test_grid_layout() -> void:
	var map: Node2D = main.get_node("PrototypeMap")
	var occupied: Dictionary = {}
	for facility: Node in main.get_children():
		if not facility is Node2D or not facility.has_method("get_layout_footprint"):
			continue
		var footprint: Vector2i = facility.get_layout_footprint()
		var corner: Vector2 = map.to_local(facility.global_position) / map.tile_size - Vector2(footprint) * 0.5
		_check(corner.is_equal_approx(corner.round()), "Facility footprint must align with grid edges: %s" % facility.name)
		for y in range(footprint.y):
			for x in range(footprint.x):
				var cell := Vector2i(corner.round()) + Vector2i(x, y)
				_check(not occupied.has(cell), "Facilities must not share a reserved grid cell: %s / %s" % [facility.name, occupied.get(cell, "")])
				occupied[cell] = facility.name
	var sink: Node2D = main.get_node("PlateSink")
	var rack: Node2D = sink.get_node("CleanPlateRack")
	_check(sink.get_layout_footprint() == Vector2i(2, 1), "Plate fixture reserves exactly two horizontal cells.")
	var clean_cell: Vector2i = map.get_cell_for_point(rack.global_position)
	var wash_cell: Vector2i = map.get_cell_for_point(sink.get_interaction_rect_global().get_center())
	_check(wash_cell == clean_cell + Vector2i.RIGHT, "Clean rack and basin each occupy one neighboring cell.")
	_check(map.is_cell_reserved_for_fixed_layout(clean_cell) and map.is_cell_reserved_for_fixed_layout(wash_cell), "Both plate cells must reject other facility placement.")

func _test_plate_focus() -> void:
	var sink: Node2D = main.get_node("PlateSink")
	var rack: Node2D = sink.get_node("CleanPlateRack")
	player.clear_held_item()
	for target: Node2D in [rack, sink]:
		player.global_position = target.get_interaction_rect_global().get_center() + Vector2(0, 110)
		var result: Dictionary = Focus.select_target(player, [rack, sink], false, player.global_position, Vector2.UP, 190.0, PI * 0.25)
		_check(result.get("target") == target, "Actual focus must select the cell in front of the player: %s" % target.name)
		player.interaction_controller._set_current_interaction_target(result.get("target"))
		if target == rack:
			player.interaction_controller.handle_pickup_drop(Vector2.UP)
			_check(player.get_held_item_id() == Items.PLATE_ID, "J at the clean cell collects a real plate.")
			rack.receive_item_from_player(player)
		else:
			player.interaction_controller.handle_pickup_drop(Vector2.UP)
			_check(not player.is_holding_item(), "J at the basin must never collect a clean plate.")
	player.interaction_controller._set_current_interaction_target(null)

func _test_recipes() -> void:
	var fixed_counts: Dictionary = {2: 0, 3: 0}
	var variant_counts: Dictionary = {2: 0, 3: 0}
	for recipe: Dictionary in Items.get_recipes():
		var dish_id: StringName = recipe.output_item_id
		var portions: int = 0
		var boss_portions: int = 0
		var complexity: bool = false
		var has_variable_maturation: bool = false
		for entry: Dictionary in recipe.ingredients:
			portions += int(entry.get("count", 1))
			if Items.is_boss_ingredient(StringName(entry.item_id)):
				boss_portions += int(entry.get("count", 1))
			complexity = complexity or not Array(entry.get("accepted_process_states", [])).is_empty() or Items.is_barrel_drink(StringName(entry.item_id))
			has_variable_maturation = has_variable_maturation or not Array(entry.get("accepted_process_states", [])).is_empty()
		if int(recipe.difficulty) >= 2 and boss_portions == 0 and not Items.is_drink(dish_id):
			var counts: Dictionary = variant_counts if complexity else fixed_counts
			counts[int(recipe.difficulty)] += 1
		var expected: int = 2
		if int(recipe.difficulty) == 2:
			expected = 3 if complexity else 4
		elif int(recipe.difficulty) == 3:
			expected = 6 if boss_portions > 0 else (4 if complexity else 5)
		_check(portions == expected, "Wrong portion count for %s: %d expected %d" % [dish_id, portions, expected])
		_check(boss_portions <= 1, "Boss dishes use exactly one boss ingredient.")
		var authored_recipe: Array = recipe.ingredients.duplicate(true)
		for _sample in range(40):
			var order_recipe: Array = Items.instantiate_order_recipe_for_dish(dish_id)
			if not has_variable_maturation:
				_check(order_recipe == authored_recipe, "Fixed recipes must stay identical for every customer: %s" % dish_id)
			var families: Dictionary = {}
			var varied: int = 0
			var actual: Array[Dictionary] = []
			for index in range(order_recipe.size()):
				var entry: Dictionary = order_recipe[index]
				var authored_variable: bool = not Array(authored_recipe[index].get("accepted_process_states", [])).is_empty()
				var state: StringName = StringName(entry.process_state)
				var family: StringName = Items.get_process_family(state)
				var allowed: Array = entry.get("accepted_process_states", [])
				if family in [&"roast", &"grind"]:
					_check(allowed.is_empty(), "Every customer component must specify exactly one maturation.")
					if authored_variable and state != StringName(authored_recipe[index].process_state):
						varied += 1
					if int(recipe.difficulty) == 2:
						_check(not families.has(family) or families[family] == state, "Medium dish must share family maturation.")
						families[family] = state
				for _portion in range(int(entry.get("count", 1))):
					actual.append({"item_id": entry.item_id, "process_state": allowed.pick_random() if not allowed.is_empty() else state})
			if int(recipe.difficulty) == 3:
				_check(varied <= 1, "Only one advanced component may vary from its fixed menu state: %s" % dish_id)
			_check(Items.matches_recipe(actual, order_recipe), "An allowed recipe must assemble.")
			_check(Items.signature_matches_recipe(Items.get_recipe_signature(actual), order_recipe), "Delivery must accept actual legal maturations.")
		_check(recipe.ingredients == authored_recipe, "Generating customer variants must never mutate the menu recipe: %s" % dish_id)
	for difficulty: int in [2, 3]:
		_check(int(fixed_counts[difficulty]) >= int(variant_counts[difficulty]) and int(variant_counts[difficulty]) > 0, "Each normal food tier must retain both routes, with at least half fixed for preparation.")

func _test_prepared_fixed_dishes() -> void:
	var assembly: Node = main.get_node("AssemblyStation")
	var table: Node = main.get_node("PrepTableA")
	var orders: Node = main.get_node("OrderManager")
	orders.active_orders.clear()
	orders.waiting_orders.clear()
	main.get_node("LevelFlowController").run_context.state = Context.LevelState.PREPARE_PHASE
	for dish_id: StringName in [Items.DISH_DILL_SAND_POTATO_CUP_ID, Items.DISH_SPICED_LAMB_ID]:
		assembly.reset_state()
		table.reset_state()
		_hold(Items.PLATE_ID)
		var recipe: Array = Items.get_recipe_for_dish(dish_id)
		for entry: Dictionary in recipe:
			for count in range(int(entry.get("count", 1))):
				_check(player.pick_up_item(entry.item_id, Items.get_item_texture(entry.item_id), entry.process_state), "Prepared repeated portions must all fit the transport plate.")
		_check(assembly.interact_with_player(player), "Prepared fixed ingredients can be unloaded before any customer arrives.")
		_check(assembly.stored_items.size() == (4 if Items.get_dish_difficulty(dish_id) == 2 else 5), "Each repeated ingredient counts as a separate portion.")
		_check(assembly.interact_with_player(player) and assembly.take_item_to_player(player), "Fixed dishes can be made and plated before orders exist.")
		_check(player.get_held_item_id() == dish_id, "Preparation must produce the intended fixed dish.")
		_check(table.receive_item_from_player(player) and table.take_item_to_player(player), "Prepared plated dishes remain valid after storage.")
		var signature: String = player.get_held_item_recipe_signature()
		for sample in range(20):
			_check(Items.signature_matches_recipe(signature, Items.instantiate_order_recipe_for_dish(dish_id)), "One prepared dish must satisfy every later customer for the same fixed recipe.")
	player.clear_held_item()
	assembly.reset_state()
	table.reset_state()
	main.get_node("LevelFlowController").run_context.state = Context.LevelState.WAVE_ACTIVE

func _test_plate_transfers() -> void:
	var sink: Node = main.get_node("PlateSink")
	var rack: Node = sink.get_node("CleanPlateRack")
	var table: Node = main.get_node("PrepTableA")
	var assembly: Node = main.get_node("AssemblyStation")
	player.clear_held_item()
	_check(rack.take_item_to_player(player) and sink.clean_plates == 2, "Taking a plate decrements rack once.")
	for i in range(6):
		_check(player.pick_up_item(Items.VEG_LEAF_ID, Items.get_item_texture(Items.VEG_LEAF_ID), Items.PROCESS_STATE_CUT), "Plate accepts six separate portions.")
	_check(not player.pick_up_item(Items.EGG_ID, null), "A full plate rejects a seventh item.")
	_check(table.receive_item_from_player(player), "A loaded plate can be staged whole.")
	_check(table.take_item_to_player(player) and _entries().size() == 6, "Taking a staged plate preserves all portions.")
	for entry: Dictionary in _entries():
		_check(entry.process_state == Items.PROCESS_STATE_CUT, "Processed state survives a table roundtrip.")
	assembly.stored_items.append(Carry.portion(Items.EGG_ID, &""))
	_check(not assembly.interact_with_player(player) and _entries().size() == 6 and assembly.stored_items.size() == 1, "Rejected dump must be atomic.")
	assembly.reset_state()
	_check(assembly.interact_with_player(player), "Six portions fit an empty assembly station via K.")
	_check(assembly.stored_items.size() == 6 and player.get_held_item_id() == Items.PLATE_ID and _entries().is_empty(), "Unloading leaves an empty clean plate in hand.")
	player.clear_held_item()
	_check(assembly.interact_with_player(player), "Invalid ingredients can be assembled empty-handed.")
	_hold(Items.PLATE_ID)
	_check(assembly.take_item_to_player(player) and player.get_held_item_id() == Items.TRASH_ID and player.get_held_item_payload().get("uses_plate", false), "Failed dish collection consumes a clean plate.")
	_check(not sink.receive_item_from_player(player) and player.get_held_item_id() == Items.TRASH_ID, "The basin must never discard plated food.")
	_check(main.get_node("TrashBin").receive_item_from_player(player) and player.get_held_item_id() == Items.DIRTY_PLATE_ID and sink.dirty_plates == 0, "Discarding failed food in the bin leaves its dirty plate in hand.")
	_check(sink.dirty_plates == 0, "A dirty plate must never teleport into the sink.")
	_check(table.receive_item_from_player(player) and table.take_item_to_player(player), "Dirty plates can be staged and recovered.")
	_check(not rack.can_receive_item(player), "Dirty plates must go to the basin, never the clean rack.")
	_check(sink.receive_item_from_player(player) and sink.dirty_plates == 1, "Only physical deposit puts dirty plates in the sink.")
	player.global_position = sink.get_interaction_rect_global().get_center() + Vector2(0, 110)
	sink.process_hold_interaction(player, 4.0)
	_check(sink.dirty_plates == 1 and is_equal_approx(sink.wash_progress, 4.0), "Four seconds must not finish a five-second wash.")
	sink.process_hold_interaction(player, 1.0)
	_check(sink.dirty_plates == 1, "Two players cannot double progress in one frame.")
	await process_frame
	player.global_position += Vector2(1000, 0)
	_check(not sink.process_hold_interaction(player, 10.0) and is_equal_approx(sink.wash_progress, 4.0), "Leaving the sink pauses wash progress.")
	await process_frame
	_check(is_equal_approx(sink.wash_progress, 4.0), "The sink must not wash autonomously.")
	player.global_position = rack.global_position + Vector2(-110, 0)
	_check(not sink.process_hold_interaction(player, 10.0), "Standing by the clean rack cannot wash plates in the other cell.")
	player.global_position = sink.get_interaction_rect_global().get_center() + Vector2(0, 110)
	sink.process_hold_interaction(player, 0.9)
	_check(sink.dirty_plates == 1, "4.9 seconds remains unfinished.")
	await process_frame
	sink.process_hold_interaction(player, 0.1)
	_check(sink.dirty_plates == 0 and sink.clean_plates == 3, "Exactly five active seconds restores one clean plate.")
	assembly.reset_state()
	_check(rack.take_item_to_player(player), "Washed plate is automatically available at the clean rack again.")
	_check(not assembly.receive_item_from_player(player) and player.get_held_item_id() == Items.PLATE_ID, "An empty plate is never dirtied at assembly.")
	_check(not sink.can_receive_item(player), "Clean plates do not go into the basin.")
	_check(rack.receive_item_from_player(player) and sink.clean_plates == 3, "An empty clean plate can be returned to the rack.")
	_check(rack.take_item_to_player(player), "Ground transport starts with a real rack plate.")
	player.pick_up_item(Items.EGG_ID, Items.get_item_texture(Items.EGG_ID), Items.PROCESS_STATE_ROAST_MEDIUM)
	var item: Node2D = load("res://Scenes/Restaurant/loose_item.tscn").instantiate()
	main.add_child(item)
	_stop_ticks(item)
	item.setup_item(player.get_held_item_id(), player.get_held_item_texture(), player.get_held_item_process_state(), "", player.get_held_item_payload())
	player.clear_held_item()
	_check(item.take_item_to_player(player) and _entries().size() == 1 and _entries()[0].process_state == Items.PROCESS_STATE_ROAST_MEDIUM, "Ground transport preserves plate contents and maturity.")
	_check(table.receive_item_from_player(player), "Stage circulating plate before daily reset.")
	main.get_node("LevelFlowController").run_setup_controller._reset_player_state()
	main.get_node("LevelFlowController").run_setup_controller._reset_all_station_states()
	_check(not table.has_item and sink.clean_plates == 3, "Phase reset restores exactly three plates and clears staged containers.")

func _test_seasoning() -> void:
	var grind: Node = main.get_node("GrindCooker")
	var table: Node = main.get_node("PrepTableA")
	var assembly: Node = main.get_node("AssemblyStation")
	_hold(Items.SUN_SEED_ID)
	_check(grind.receive_item_from_player(player), "Grinder accepts a raw ingredient.")
	grind._advance_processing(grind.hold_process_duration, player)
	_check(player.get_held_item_id() == Items.SEASONING_BOX_ID and int(player.get_held_item_payload().get("servings", 0)) == 4, "One completed grind yields four fine seasoning servings.")
	_check(table.receive_item_from_player(player), "Seasoning box can be stored.")
	_hold(Items.PLATE_ID)
	_check(table.take_item_to_player(player) and _entries().size() == 1 and int(table.item_payload.servings) == 3, "Plate removes exactly one serving from a box.")
	_check(_entries()[0].process_state == Items.PROCESS_STATE_GRIND_FINE, "Seasoning retains exact maturity on the plate.")
	player.clear_held_item()
	_check(table.take_item_to_player(player), "Empty hands take the remaining box whole.")
	_check(assembly.receive_item_from_player(player) and int(player.get_held_item_payload().get("servings", 0)) == 2, "Assembly consumes one portion and keeps the remaining box in hand.")
	_check(assembly.stored_items.size() == 1 and assembly.stored_items[0].item_id == Items.SUN_SEED_ID, "Assembly stores a food portion, never a box.")
	assembly.reset_state()
	_hold(Items.SUN_SEED_ID)
	grind.receive_item_from_player(player)
	grind._advance_processing(grind.hold_process_duration * 0.6, player)
	_check(grind.take_item_to_player(player) and int(player.get_held_item_payload().get("servings", 0)) == 4, "Early coarse takeout is a four-serving box.")
	_check(grind.receive_item_from_player(player), "A coarse batch can be reinserted for finer grinding.")
	grind._advance_processing(grind.hold_process_duration, player)
	_check(int(player.get_held_item_payload().get("servings", 0)) == 4 and player.get_held_item_payload().get("process_state") == Items.PROCESS_STATE_GRIND_FINE, "Regrinding preserves servings instead of multiplying yield.")
	player.clear_held_item()
	grind.reset_state()
	_hold(Items.SUN_SEED_ID)
	_check(grind.receive_item_from_player(player), "Raw portions enter the grinder by hand.")
	_hold(Items.PLATE_ID)
	grind._advance_processing(grind.hold_process_duration, null)
	for count in range(4):
		_check(grind.take_item_to_player(player), "All four portions remain collectible from the finished batch.")
	_check(_entries().size() == 4 and not grind.has_item, "Repeated collection conserves the finished four-portion batch.")
	player.clear_held_item()

func _test_fixed_and_shop() -> void:
	var flow: Node = main.get_node("LevelFlowController")
	flow.run_context.state = Context.LevelState.WAVE_ACTIVE
	for station: Node2D in get_nodes_in_group("cooking_stations"):
		var start: Vector2 = station.global_position
		for _step in range(10):
			station._process(1.0)
		_check(station.global_position == start, "Cookers must remain fixed during service.")
	flow.run_context.state = Context.LevelState.NIGHT_REST
	_check(flow.purchase_kitchen_upgrade({"upgrade_id": &"station_speed"}), "Station upgrade callback succeeds.")
	for kind: StringName in [&"cut_station", &"roast_station", &"grind_station", &"prep_table"]:
		_check(flow.purchase_support_facility({"facility_type": kind}), "Equipment purchase must find a legal kitchen position: %s" % kind)
		await physics_frame
	for station: Node in get_nodes_in_group("cooking_stations"):
		_check(is_equal_approx(station.processing_speed_multiplier, 1.15), "Upgrade affects existing and future cookers equally.")
	var roast: Node = main.get_node("BakeCooker")
	_hold(Items.MEAT_RED_ID)
	roast.receive_item_from_player(player)
	roast._advance_processing(roast.auto_process_duration * 0.5, null)
	_check(roast.progress_view.station_bar.maturity_icon.texture == Items.get_process_icon_texture(roast.item_process_state), "Roast progress explicitly displays actual current maturity as an icon.")
	var bounds: Rect2 = main.get_node("PrototypeMap").get_kitchen_zone_bounds()
	_check(bounds.size == Vector2(2304, 1280), "Expanded kitchen uses the new dimensions.")
	_check(is_equal_approx(player.move_speed, 336.0) and is_equal_approx(flow.service_phase_duration, 260.0), "Initial pacing applies to player and formal service.")
	_test_grid_layout()

func _test_dispatch_and_sources() -> void:
	main.get_node("LevelFlowController").run_context.state = Context.LevelState.WAVE_ACTIVE
	var storage: Node = main.get_node("StorageManager")
	var cabinet: Node = main.get_node("StorageCabinetSunnyBerry")
	var allowed: Array[StringName] = [Items.EGG_ID]
	cabinet.set_menu_allowed_item_ids(allowed)
	storage.add_stock(Items.EGG_ID, 10)
	_hold(Items.PLATE_ID)
	var before: int = storage.get_stock(Items.EGG_ID)
	var interaction: RefCounted = player.interaction_controller
	interaction._set_current_interaction_target(cabinet)
	interaction.handle_pickup_drop(Vector2.RIGHT)
	_check(_entries().is_empty() and storage.get_stock(Items.EGG_ID) == before and player.get_held_item_id() == Items.PLATE_ID, "J cannot collect raw food into a plate or drop the plate.")
	for _portion in range(5):
		cabinet.take_item_to_player(player)
	before = storage.get_stock(Items.EGG_ID)
	_check(not cabinet.take_item_to_player(player) and storage.get_stock(Items.EGG_ID) == before, "A full plate cannot consume cabinet stock.")
	var barrel: Node = main.get_node("FixedBarrelLeftA")
	barrel.reset_state()
	barrel.current_drink_item_id = Items.DRINK_QINGMEI_WINE_ID
	barrel.serving_count = 2
	_hold(Items.PLATE_ID)
	player.pick_up_item(Items.EGG_ID, Items.get_item_texture(Items.EGG_ID), Items.PROCESS_STATE_ROAST_MEDIUM)
	interaction._set_current_interaction_target(barrel)
	interaction.handle_pickup_drop(Vector2.RIGHT)
	_check(_entries().size() == 1 and barrel.serving_count == 2 and barrel.queued_fill_count == 0, "Plates cannot collect wine or feed a ready barrel.")
	barrel.serving_count = 0
	interaction.handle_pickup_drop(Vector2.RIGHT)
	_check(_entries().size() == 1 and barrel.queued_fill_count == 0, "Plates contain no raw portions to feed an empty barrel.")
	var assembly: Node = main.get_node("AssemblyStation")
	assembly.reset_state()
	interaction._set_current_interaction_target(assembly)
	interaction.handle_pickup_drop(Vector2.RIGHT)
	_check(player.get_held_item_id() == Items.PLATE_ID and assembly.stored_items.is_empty(), "J no longer dumps a loaded plate at assembly.")
	player._handle_interact()
	_check(player.get_held_item_id() == Items.PLATE_ID and _entries().is_empty() and assembly.stored_items.size() == 1, "Actual K dispatch unloads the plate and keeps it clean.")
	player.clear_held_item()
	var sink: Node2D = main.get_node("PlateSink")
	player.global_position = sink.get_interaction_rect_global().get_center() + Vector2(0, 110)
	player.aim_direction = Vector2.UP
	interaction._set_current_interaction_target(sink)
	main.get_node("LevelFlowController").run_context.state = Context.LevelState.WAVE_ACTIVE
	sink.clean_plates = 2
	sink.dirty_plates = 1
	player._handle_interact()
	_check(player.get_carried_facility_node() == sink, "K at a dirty basin carries the whole fixture instead of washing.")
	player.facility_carry_controller.cancel_carry()
	interaction._set_current_interaction_target(null)

func _test_plate_carry() -> void:
	var sink: Node2D = main.get_node("PlateSink")
	var rack: Node2D = sink.get_node("CleanPlateRack")
	var controller: RefCounted = player.facility_carry_controller
	var origin: Vector2 = sink.global_position
	var rack_offset: Vector2 = rack.position
	sink.wash_progress = 2.0
	sink._refresh()
	player.clear_held_item()
	player.aim_direction = Vector2.UP
	player.global_position = rack.global_position + Vector2(0, 110)
	player.interaction_controller._set_current_interaction_target(rack)
	_check(player._find_movable_facility_target() == sink, "Clean side must select the whole fixture for carrying, not its child rack.")
	player._handle_interact()
	_check(player.get_carried_facility_node() == sink and sink.is_carried, "K on the clean side lifts both cells even with dirty plates in the basin.")
	_check(not sink.is_visible_in_tree() and not rack.is_visible_in_tree() and sink.collision_layer == 0 and rack.collision_layer == 0, "Both cells must hide and disable collisions together.")
	_check(not rack.can_take_item(player) and not rack.is_pickup_drop_focusable(player) and not sink.is_pickup_drop_focusable(player), "A hidden carried fixture must never offer stale pickup or wash targets.")
	_check(not sink.process_hold_interaction(player, 10.0) and is_equal_approx(sink.wash_progress, 2.0), "Carrying pauses washing without clearing progress.")
	_check(sink.get_facility_preview_data().body_size == Vector2(248, 116), "Carry preview represents both cells.")
	var sprites: Array[Dictionary] = controller.get_sprite_previews()
	var has_body: bool = false
	var clean_icons: int = 0
	var dirty_icons: int = 0
	for data: Dictionary in sprites:
		if data.texture == sink.get_node("StationSprite").texture:
			has_body = data.source_size == Vector2(256, 144) and data.silhouette_texture != null
		elif data.texture == Items.get_item_texture(Items.PLATE_ID):
			clean_icons += 1
		elif data.texture == Items.get_item_texture(Items.DIRTY_PLATE_ID):
			dirty_icons += 1
	_check(has_body and clean_icons == 2 and dirty_icons == 1, "Carry ghosts must capture the entire shared cabinet and its current clean/dirty plates.")
	var hand: Node2D = player.facility_preview_controller.get_hand_preview_root()
	_check(hand.visible and hand.get_child_count() == sprites.size() and hand.get_child(0) is Sprite2D, "Hand preview must use the complete artwork rather than a generic rectangle.")
	controller.cancel_carry()
	_check(sink.global_position == origin and rack.position == rack_offset and not sink.is_carried and rack.is_visible_in_tree(), "Cancel restores the complete fixture to its original location.")
	_check(sink.collision_layer == (4 | 16) and rack.collision_layer == (4 | 16), "Cancel restores both collision bodies.")
	_check(sink.clean_plates == 2 and sink.dirty_plates == 1 and is_equal_approx(sink.wash_progress, 2.0), "Inventory and partial wash progress survive cancellation.")
	player._handle_interact()
	_check(player.get_carried_facility_node() == sink, "Fixture can be picked up again after cancellation.")
	player.interaction_controller._set_current_interaction_target(null)
	var map: Node2D = main.get_node("PrototypeMap")
	var bounds: Rect2 = map.get_kitchen_zone_bounds()
	var found: bool = false
	for y in range(1, int(bounds.size.y / map.tile_size.y) - 1):
		for x in range(2, int(bounds.size.x / map.tile_size.x) - 2):
			player.global_position = bounds.position + Vector2(x + 0.5, y + 0.5) * map.tile_size - player.get_node("CollisionShape2D").position
			await physics_frame
			controller.refresh_placement()
			if controller.can_place_facility() and controller.get_placement_position() != origin:
				found = true
				break
		if found:
			break
	_check(found, "Whole fixture must have a legal two-cell relocation in the expanded kitchen.")
	if found:
		var destination: Vector2 = controller.get_placement_position()
		player._handle_interact()
		_check(not player.is_carrying_facility() and sink.global_position == destination, "K commits whole-fixture relocation through the standard placement route.")
		_check(rack.global_position == destination + rack_offset and sink.collision_layer == (4 | 16) and rack.collision_layer == (4 | 16), "Rack follows the basin and both collisions restore at destination.")
		_check(sink.clean_plates == 2 and sink.dirty_plates == 1 and is_equal_approx(sink.wash_progress, 2.0), "Relocation preserves all plate and wash state.")
		_test_grid_layout()
		player.global_position = sink.get_interaction_rect_global().get_center() + Vector2(0, 110)
		await process_frame
		_check(sink.process_hold_interaction(player, 3.0) and sink.clean_plates == 3 and sink.dirty_plates == 0, "Washing resumes and finishes after moving the complete fixture.")
		player.interaction_controller._set_current_interaction_target(sink)
		player.aim_direction = Vector2.UP
		player._handle_interact()
		_check(player.get_carried_facility_node() == sink, "K at an empty basin can also lift the complete fixture.")
	controller.cancel_carry()
	player.interaction_controller._set_current_interaction_target(null)

func _run() -> void:
	_test_recipes()
	main = load("res://Scenes/Main/main.tscn").instantiate()
	root.add_child(main)
	await physics_frame
	await physics_frame
	paused = false
	_stop_ticks(main)
	player = main.get_node("Player")
	main.get_node("LevelFlowController").run_context.state = Context.LevelState.WAVE_ACTIVE
	_test_grid_layout()
	_test_plate_focus()
	_test_prepared_fixed_dishes()
	await _test_plate_transfers()
	_test_seasoning()
	await _test_fixed_and_shop()
	_test_dispatch_and_sources()
	await _test_plate_carry()
	main.queue_free()
	await process_frame
	if failures.is_empty():
		print("PASS: kitchen recipes, plate transfers, attended washing, whole two-cell fixture carrying and relocation, preserved wash state, batch grinding, grid layout, equipment and roast UI.")
	quit(0 if failures.is_empty() else 1)
