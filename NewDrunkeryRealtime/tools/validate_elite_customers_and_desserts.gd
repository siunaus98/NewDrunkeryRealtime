extends SceneTree

const Items = preload("res://Scripts/Kitchen/TestItemDefs.gd")
const Groups = preload("res://Scripts/Orders/OrderGroupDefs.gd")
const Manager = preload("res://Scripts/Orders/OrderManager.gd")
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error(message)

func stop_ticks(node: Node) -> void:
	node.set_process(false)
	node.set_physics_process(false)
	for child: Node in node.get_children():
		stop_ticks(child)

func signature_for(dish: StringName) -> String:
	var portions: Array[Dictionary] = []
	for entry: Dictionary in Items.get_recipe_for_dish(dish):
		for index in int(entry.get("count", 1)):
			portions.append({"item_id": entry.item_id, "process_state": entry.process_state})
	return Items.get_recipe_signature(portions)

func _run() -> void:
	var menu: Array[StringName] = [Items.DRINK_OASIS_WINE_ID, Items.DRINK_ROYAL_AGED_ID, Items.DISH_CRISP_PLATE_ID, Items.DISH_RED_ROLL_ID, Items.DISH_STONEFLOWER_FROZEN_ID]
	var total := 0
	var elites := 0
	var patterns: Dictionary = {}
	for day in range(3):
		var source: Dictionary = Groups.create_default_order_groups(day)[0]
		for sample in range(150):
			var group := Groups.build_group_for_menu(source, menu, sample)
			for wave: Dictionary in group.waves:
				var customers: Dictionary = {}
				for order: Dictionary in wave.orders:
					check(not Items.is_dessert(order.dish_item_id), "Desserts never enter generated requests")
					var batch: String = order.customer_batch_id
					if not customers.has(batch):
						customers[batch] = []
					customers[batch].append(order)
				for orders: Array in customers.values():
					check(orders.all(func(order: Dictionary) -> bool: return order.customer_name == orders[0].customer_name), "One customer has one name")
					if day < 2:
						check(orders.size() == 1 and not orders[0].elite_customer, "No elites before day three")
					else:
						total += 1
						if orders[0].elite_customer:
							elites += 1
							var categories: Array = orders.map(func(order: Dictionary) -> StringName: return Items.get_item_category(order.dish_item_id))
							check(categories in [[&"drink", &"small_plate"], [&"drink", &"main_dish"], [&"drink", &"small_plate", &"main_dish"]], "Only the three approved elite combinations")
							patterns[str(categories)] = true
	check(float(elites) / total > 0.24 and float(elites) / total < 0.36 and patterns.size() == 3, "Sampled elite rate is near thirty percent and includes all combinations")
	var only_food: Array[StringName] = [Items.DISH_RED_ROLL_ID]
	var limited := Groups.build_group_for_menu(Groups.create_default_order_groups(2)[0], only_food, 77)
	for wave: Dictionary in limited.waves:
		check(wave.orders.all(func(order: Dictionary) -> bool: return not order.elite_customer and order.dish_item_id == Items.DISH_RED_ROLL_ID), "Missing drink category falls back to valid ordinary customers")
	var main: Node = load("res://Scenes/Main/main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	await process_frame
	stop_ticks(main)
	paused = false
	var flow: Node = main.get_node("LevelFlowController")
	flow.progression_state.day_index = 2
	var group := Groups.build_group_for_menu(Groups.create_default_order_groups(2)[0], menu, 77)
	flow._remap_order_targets_to_unlocked_serving_counters(group)
	var manager: Node = main.get_node("OrderManager")
	var saw_elite := false
	for wave: Dictionary in group.waves:
		var slots: Dictionary = {}
		for order: Dictionary in wave.orders:
			if slots.has(order.customer_batch_id):
				check(slots[order.customer_batch_id] == order.target_slot, "Elite requests share a window after remapping")
			else:
				check(order.target_slot not in slots.values(), "Different customers occupy different windows")
				slots[order.customer_batch_id] = order.target_slot
		manager.set_orders(wave.orders)
		check(manager.customers.size() == slots.size(), "Actual manager preserves generated customer count")
		for slot: int in slots.values():
			manager.take_order_at_slot(slot)
		var hud: Node = main.get_node("OrderHud")
		for customer_id: String in manager.customers:
			if bool(manager.customers[customer_id].get("elite_customer", false)):
				saw_elite = true
				check("精英" in hud.order_cards[customer_id].get_node("CustomerName").text, "Actual generated elite has visible HUD identification")
	check(saw_elite, "Live remapping fixture includes an elite")
	var boss_group := Groups.append_boss_special_orders(group, &"scarab")
	flow._remap_order_targets_to_unlocked_serving_counters(boss_group)
	for wave: Dictionary in boss_group.waves:
		check(wave.orders.all(func(order: Dictionary) -> bool: return int(order.target_slot) > 1), "Regular and elite customers preserve the boss guest's reserved window")
	var fixture := Groups._order("main", 1, Items.DISH_RED_ROLL_ID, 0)
	fixture.patience_duration = 120.0
	manager.set_orders([fixture])
	var player: Node = main.get_node("Player")
	var counter: Node = main.get_node("TestServingCounter")
	counter.focused_slot_index = 0
	var dessert: StringName = Items.DISH_STONEFLOWER_FROZEN_ID
	var signature := signature_for(dessert)
	player.clear_held_item()
	player.pick_up_item(dessert, Items.get_item_texture(dessert), &"", signature, {"uses_plate": true})
	check(not counter.can_receive_item(player), "Unaccepted customers cannot receive dessert")
	manager.take_order_at_slot(1)
	manager._process(60)
	flow.run_context.state = 7
	flow.progression_state.xp = 0
	flow.progression_state.xp_for_next_level = 100000
	var gold_before: int = flow.progression_state.gold
	var xp_before: int = flow.progression_state.xp
	var completed_before: int = flow.run_context.completed_orders
	var wave_before: int = flow.run_context.current_wave_index
	check(counter.receive_item_from_player(player), "Actual counter accepts a legal dessert without a dessert request")
	check(player.get_held_item_id() == Items.DIRTY_PLATE_ID, "Dessert serving returns a dirty plate")
	check(manager.active_orders.size() == 1 and manager.active_orders[0].order_id == "main" and is_equal_approx(float(manager.get_active_order_for_slot(1).time_remaining), 84), "Dessert restores twenty percent without resolving the order")
	check(flow.progression_state.gold == gold_before + Items.get_dish_gold_reward(dessert) and flow.progression_state.xp == xp_before + Items.get_dish_xp_reward(dessert), "Dessert pays its own gold and experience through the actual counter")
	check(flow.run_context.completed_orders == completed_before and flow.run_context.current_wave_index == wave_before and manager.customers.size() == 1, "Dessert does not complete orders, advance waves or dismiss customers")
	gold_before = flow.progression_state.gold
	xp_before = flow.progression_state.xp
	player.clear_held_item()
	player.pick_up_item(dessert, Items.get_item_texture(dessert), &"", signature, {"uses_plate": true})
	check(not counter.receive_item_from_player(player) and player.get_held_item_id() == dessert, "Second dessert rejected without losing food or plate")
	check(flow.progression_state.gold == gold_before and flow.progression_state.xp == xp_before, "Rejected second dessert cannot pay twice")
	manager.set_orders([fixture])
	manager.take_order_at_slot(1)
	check(not manager.can_offer_dessert(1, dessert, "") and not manager.can_offer_dessert(2, dessert, signature), "Invalid dish signature and empty window reject dessert")
	check(manager.offer_dessert(1, dessert, signature) and manager.get_active_order_for_slot(1).time_remaining == 120, "New customer can receive dessert and recovery caps at maximum")
	for mechanism: StringName in [&"quicksand", &"scarab", &"sandstorm"]:
		var special := Groups.get_boss_special_orders(mechanism)
		check(special.all(func(order: Dictionary) -> bool: return not Items.is_dessert(order.dish_item_id)), "Boss guests have no required desserts")
		manager.set_orders(special)
		manager.take_order_at_slot(1)
		manager._process(301)
		var remaining: float = manager.special_guest_time_remaining
		gold_before = flow.progression_state.gold
		xp_before = flow.progression_state.xp
		check(manager.offer_dessert(1, dessert, signature) and manager.special_guest_time_remaining == remaining and manager.special_guest_pressure_active and manager.active_orders.size() == 1 and manager.waiting_orders.size() == 2, "Boss accepts one dessert without altering clock, pressure or required dishes")
		check(flow.progression_state.gold == gold_before + Items.get_dish_gold_reward(dessert) and flow.progression_state.xp == xp_before + Items.get_dish_xp_reward(dessert), "Boss dessert uses its own value without boss-order multipliers")
	for sweet: StringName in [Items.DISH_QINGMEI_SWEET_BOWL_ID, Items.DISH_GOLDEN_BAKED_CAKE_ID, dessert, Items.DISH_SUNRISE_BANQUET_ID, Items.DISH_STONEFLOWER_HONEY_FEAST_ID]:
		manager.set_orders([fixture])
		manager.take_order_at_slot(1)
		gold_before = flow.progression_state.gold
		xp_before = flow.progression_state.xp
		check(manager.offer_dessert(1, sweet, signature_for(sweet)), "Every dessert can be offered")
		check(flow.progression_state.gold == gold_before + Items.get_dish_gold_reward(sweet) and flow.progression_state.xp == xp_before + Items.get_dish_xp_reward(sweet), "Each dessert pays its individual recipe value")
	manager.set_orders([fixture])
	manager.take_order_at_slot(1)
	manager.special_guest_overdue = true
	gold_before = flow.progression_state.gold
	check(manager.offer_dessert(1, dessert, signature) and flow.progression_state.gold == gold_before + Items.get_dish_gold_reward(dessert), "Guests arriving before boss overdue retain dessert rewards")
	for elite: bool in [false, true]:
		manager.clear_orders()
		manager.special_guest_overdue = true
		fixture["elite_customer"] = elite
		manager.add_orders([fixture])
		manager.take_order_at_slot(1)
		gold_before = flow.progression_state.gold
		xp_before = flow.progression_state.xp
		check(manager.offer_dessert(1, dessert, signature), "Post-overdue guest can still receive hospitality")
		check(flow.progression_state.gold == gold_before and flow.progression_state.xp == xp_before, "Post-overdue ordinary and elite guests cannot generate dessert rewards")
	fixture["facility_reward_multiplier"] = 1.05
	manager.set_orders([fixture])
	manager.take_order_at_slot(1)
	gold_before = flow.progression_state.gold
	xp_before = flow.progression_state.xp
	check(manager.offer_dessert(1, dessert, signature, {"flame_blessed": true}), "Flame-blessed dessert accepted")
	check(flow.progression_state.gold == gold_before + roundi(Items.get_dish_gold_reward(dessert) * 1.05 * 1.1) and flow.progression_state.xp == xp_before + roundi(Items.get_dish_xp_reward(dessert) * 1.05 * 1.1), "Dessert applies flyer and flame rewards exactly once")
	flow.progression_state.menu_drink_ids.assign([Items.DRINK_OASIS_WINE_ID])
	flow.progression_state.menu_non_drink_ids.assign([dessert])
	flow.run_context.state = 7
	manager.clear_orders()
	check(flow.summon_flyer_customer() and not Items.is_dessert(manager.waiting_orders[0].dish_item_id), "Flyer customer never requests dessert")
	main.queue_free()
	await process_frame
	print("ELITE/DESSERT: %d failures; elite sample %d/%d, generation, window mapping, hospitality, plate return, limits and boss clock isolation" % [failures.size(), elites, total])
	quit(0 if failures.is_empty() else 1)
