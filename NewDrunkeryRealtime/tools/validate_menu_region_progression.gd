extends SceneTree

const Items = preload("res://Scripts/Kitchen/TestItemDefs.gd")
const Sources = preload("res://Scripts/Core/IngredientSourceDefs.gd")
const State = preload("res://Scripts/Core/RunProgressionState.gd")
const Groups = preload("res://Scripts/Orders/OrderGroupDefs.gd")
const Codex = preload("res://Scripts/UI/CodexCatalog.gd")
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error(message)

func check_pool(ids: Array[StringName], day: int) -> void:
	for id in ids:
		check(Sources.get_dish_stage(id) <= Sources.get_menu_stage(day), "Day %d cannot offer later-region recipe %s" % [day + 1, id])

func run() -> void:
	var state := State.new()
	state.reset(12, 0, 619)
	check(state.menu_drink_ids.size() == 3 and state.menu_non_drink_ids == [Items.DISH_CRISP_PLATE_ID, Items.DISH_WHITE_PLATE_ID], "Opening menu keeps three basic wines and local poultry main")
	check_pool(state.get_menu_dish_ids(), 0)
	for id in state.menu_drink_ids:
		check(Items.get_barrel_input_item_id(id) in Sources.get_forage_items(&"near"), "All three starting wines can be brewed from central forage")
	check(Sources.get_forage_items(&"near") == [Items.VEG_LEAF_ID, Items.RICE_ID, Items.EGG_ID], "Central forage replaces potato with wheat")
	check(Items.VEG_ROOT_ID in Sources.get_forage_items(&"right") and Items.RICE_ID not in Sources.get_forage_items(&"right"), "Potato moves to eastern forage")
	var all_offered: Array[StringName] = state.menu_non_drink_ids.duplicate()
	for day in range(7):
		state.day_index = day
		var pool := state.create_next_non_drink_offer(1000)
		check(not pool.is_empty(), "Every day has non-drink choices")
		check_pool(pool, day)
		if day in [2, 4]:
			check(pool.all(func(id: StringName) -> bool: return Sources.get_dish_stage(id) == Sources.get_menu_stage(day)), "New-region checkpoint actually introduces its ingredients")
		for id in pool:
			if id not in all_offered:
				all_offered.append(id)
		for roll in range(20):
			state.create_next_non_drink_offer()
			check_pool(state.pending_menu_offer_ids, day)
			state.menu_refreshes = 3
			state.refresh_menu_offer()
			check_pool(state.pending_menu_offer_ids, day)
		for old_id in state.get_menu_dish_ids():
			check_pool(state.event_menu_candidates(old_id, &"higher"), day)
			check_pool(state.event_menu_candidates(old_id, &"lower"), day)
		state.create_next_drink_offer(1000)
		check_pool(state.pending_menu_offer_ids, day)
		if day in [1, 2, 4]:
			check(not state.pending_menu_offer_ids.is_empty(), "Scheduled wine progression has options")
			var expected_stage := 1 if day == 1 else (2 if day == 2 else 0)
			if expected_stage > 0:
				check(state.pending_menu_offer_ids.all(func(id: StringName) -> bool: return Sources.get_dish_stage(id) == expected_stage), "Wine checkpoint introduces intended region")
			check(state.should_offer_drink_menu_update(), "Wine checkpoint opens before selection")
			check(state.choose_menu_offer(0), "Wine checkpoint selection succeeds")
			check(not state.should_offer_drink_menu_update(), "Wine checkpoint does not repeat after selection")
	for id in Items.DISH_IDS:
		check(not Items.get_item_description(id).is_empty(), "All recipes have current descriptions: %s" % id)
		check(Items.get_item_texture(id) != null, "All recipe icons load: %s" % id)
		if not Items.is_drink(id) and not state._is_special_recipe(id):
			check(id in all_offered, "Every ordinary dish remains reachable: %s" % id)
		var recipe: Array = Items.get_recipe_for_dish(id)
		if recipe.is_empty():
			continue
		var expanded: Array[Dictionary] = []
		for entry: Dictionary in recipe:
			for count in int(entry.get("count", 1)):
				expanded.append({"item_id": entry.item_id, "process_state": entry.process_state})
		var matched := Items.find_matching_recipe_with_alternate_completion(expanded)
		check(matched.get("output_item_id", &"") == id, "Recipe resolves to its own dish without collisions: %s" % id)
	for mechanism: StringName in [&"quicksand", &"scarab", &"sandstorm"]:
		var orders := Groups.get_boss_special_orders(mechanism)
		check(orders.size() == 3, "Small boss has three courses")
		for index in range(orders.size()):
			var id := StringName(orders[index].dish_item_id)
			check(Items.get_item_category(id) == [&"drink", &"small_plate", &"main_dish"][index], "Small boss uses wine / appetizer / main")
			for entry: Dictionary in Items.get_display_recipe_for_dish(id):
				var ingredient := StringName(entry.item_id)
				if Items.is_barrel_drink(ingredient):
					ingredient = Items.get_barrel_input_item_id(ingredient)
				if not Items.is_boss_ingredient(ingredient):
					check(Sources.get_ingredient_stage(ingredient) <= 2, "Day-four special guest cannot require eastern ingredients")
	for entry: Dictionary in Codex.get_ingredient_entries():
		if not Items.is_boss_ingredient(entry.id):
			check(String(entry.body).contains(Sources.format_source_hint(entry.id)), "Codex uses actual ingredient sources")
	var main: Node = load("res://Scenes/Main/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	main.process_mode = Node.PROCESS_MODE_DISABLED
	for node: Node in main.find_children("*", "Node2D", true, false):
		if node.get_script() == load("res://Scripts/Forage/ForageRegion.gd"):
			check(node.forage_item_ids == Sources.get_forage_items(node.region_id), "Actual region and source table agree: %s" % node.region_id)
			for point: Node in node.active_points:
				check(point.forage_item_ids == node.forage_item_ids, "Spawned forage point inherits current region ingredients")
	# A complete run exercises category caps, replacements, refresh and snapshots.
	for seed in range(20):
		state.reset(12, 0, seed)
		for day in range(7):
			state.day_index = day
			if state.should_offer_drink_menu_update():
				state.create_next_drink_offer()
				check(state.choose_menu_offer(0), "Full-run wine selection")
			state.create_next_non_drink_offer()
			check_pool(state.pending_menu_offer_ids, day)
			check(state.choose_menu_offer(0), "Full-run food selection and category replacement")
			for category: StringName in state.NON_DRINK_MENU_CAPS:
				check(state.get_menu_category_count(category) <= state.get_menu_category_capacity(category), "Menu category cap survives full run")
			var restored := State.new()
			restored.reset(12)
			restored.apply_snapshot(state.get_snapshot())
			check(restored.get_menu_dish_ids() == state.get_menu_dish_ids(), "Snapshot preserves revised menu without restoring old lamb main")
	main.queue_free()
	await process_frame
	print("MENU REGION PROGRESSION: %d failures; local three wines, middle/west/east pools, refresh/events, every recipe, actual forage, small boss courses, 20 full runs and snapshots" % failures.size())
	quit(0 if failures.is_empty() else 1)
