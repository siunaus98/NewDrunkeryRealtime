extends SceneTree

const Items = preload("res://Scripts/Kitchen/TestItemDefs.gd")
const Groups = preload("res://Scripts/Orders/OrderGroupDefs.gd")
const Manager = preload("res://Scripts/Orders/OrderManager.gd")
const Context = preload("res://Scripts/Core/LevelContext.gd")
var failures: Array[String] = []

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

func _fixture(id: String, slot: int, dish: StringName, patience: float = 120.0) -> Dictionary:
	return {"order_id": id, "target_slot": slot, "customer_name": "多菜测试客人", "dish_item_id": dish, "patience_duration": patience, "gold_reward": 20, "xp_reward": 10, "reputation_penalty": 25, "recipe_items": Items.instantiate_order_recipe_for_dish(dish)}

func _test_customer_clock() -> void:
	var manager := Manager.new()
	root.add_child(manager)
	manager.set_process(false)
	var one := _fixture("A", 1, Items.DISH_CRISP_PLATE_ID, 90)
	var two := _fixture("B", 1, Items.DISH_RED_ROLL_ID, 120)
	var other := _fixture("C", 2, Items.DISH_SPICED_LAMB_ID, 60)
	manager.set_orders([one, two, other])
	_check(manager.customers.size() == 2 and manager.day_customer_counter == 2, "Multiple dishes in one window must count as one customer.")
	_check(manager.process_take_order_at_slot(1, 0.4) and manager.get_active_orders().is_empty(), "One shared acceptance action must remain incomplete at half duration.")
	_check(manager.process_take_order_at_slot(1, 0.4) and manager.get_active_orders().size() == 2 and manager.get_waiting_orders().size() == 1, "Finishing one action must accept every dish in that window.")
	_check(not manager.take_order_at_slot(1), "An accepted multi-dish customer must not require another order action.")
	manager._process(10)
	var active := manager.get_active_orders()
	_check(active.all(func(order: Dictionary) -> bool: return is_equal_approx(float(order.time_remaining), 110.0)), "Two dishes must use one 120-second customer clock, decremented only once.")
	_check(manager.adjust_order_time("B", -10), "Adjusting a dish's patience must address its customer.")
	_check(manager.get_active_orders().all(func(order: Dictionary) -> bool: return is_equal_approx(float(order.time_remaining), 100.0)), "A patience adjustment must be shared by every dish of that customer.")
	manager.restore_all_active_order_patience_fraction(0.1)
	_check(is_equal_approx(float(manager.get_active_order_for_slot(1).time_remaining), 112), "A group patience restoration must apply once, not once per dish.")
	var completed: Array[Dictionary] = []
	manager.order_completed.connect(func(order: Dictionary) -> void: completed.append(order))
	manager.complete_current_order(1, false, "B")
	_check(completed.is_empty() and manager.get_active_orders().size() == 2, "Off-spec completion must neither consume a request nor pay a reward.")
	manager.complete_current_order(1, true, "B")
	_check(completed.size() == 1 and not bool(completed[0].customer_completed), "Serving one dish must keep the customer present.")
	_check(manager.get_active_orders().size() == 1 and is_equal_approx(float(manager.get_active_orders()[0].time_remaining), 120), "Serving a dish restores shared patience without exceeding the maximum.")
	manager.complete_current_order(1, true, "A")
	_check(completed.size() == 2 and bool(completed[1].customer_completed) and manager.customers.size() == 1, "Only the final dish completes the customer.")
	manager.set_orders([one, two])
	manager.take_order_at_slot(1)
	var expired: Array[Dictionary] = []
	manager.order_expired.connect(func(order: Dictionary) -> void: expired.append(order))
	manager._process(120)
	var penalty: int = 0
	for order: Dictionary in expired:
		penalty += int(order.get("reputation_penalty", 0))
	_check(expired.size() == 2 and not manager.has_active_order() and penalty == 25, "A departing customer must expire all dishes together and penalize reputation once.")
	manager.free()

func _test_serving_patience() -> void:
	var manager := Manager.new()
	root.add_child(manager)
	manager.set_process(false)
	var orders: Array = [
		_fixture("wine", 1, Items.DRINK_OASIS_WINE_ID),
		_fixture("mixed_drink", 1, Items.DRINK_ROYAL_AGED_ID),
		_fixture("food_with_wine", 1, Items.DISH_WINE_PLATTER_ID),
		_fixture("dessert", 1, Items.DISH_STONEFLOWER_FROZEN_ID),
		_fixture("last", 1, Items.DISH_RED_ROLL_ID),
		_fixture("other", 2, Items.DISH_RED_ROLL_ID)
	]
	manager.set_orders(orders)
	manager.take_order_at_slot(1)
	manager.take_order_at_slot(2)
	manager._process(80)
	manager.complete_current_order(1, false, "wine")
	_check(is_equal_approx(float(manager.get_active_order_for_slot(1).time_remaining), 40), "Rejected serving restores no patience.")
	manager.complete_current_order(1, true, "wine")
	_check(is_equal_approx(float(manager.get_active_order_for_slot(1).time_remaining), 52), "Barrel drink restores ten percent of maximum patience, not missing patience.")
	manager.complete_current_order(1, true, "wine")
	_check(is_equal_approx(float(manager.get_active_order_for_slot(1).time_remaining), 52), "Repeated delivery of a completed request restores nothing.")
	manager.complete_current_order(1, true, "mixed_drink")
	_check(is_equal_approx(float(manager.get_active_order_for_slot(1).time_remaining), 64), "Combined drinks also restore ten percent.")
	manager.complete_current_order(1, true, "food_with_wine")
	_check(is_equal_approx(float(manager.get_active_order_for_slot(1).time_remaining), 88), "Food containing wine still restores twenty percent.")
	manager.complete_current_order(1, true, "dessert")
	_check(is_equal_approx(float(manager.get_active_order_for_slot(1).time_remaining), 112), "Desserts restore twenty percent.")
	_check(is_equal_approx(float(manager.get_active_order_for_slot(2).time_remaining), 40), "Serving one customer cannot restore another customer's patience.")
	manager.complete_current_order(1, true, "last")
	_check(not manager.customers.has("slot:1"), "Final dish completes the customer without leaving a timer.")
	manager.free()

func _test_exact_recipes() -> void:
	for recipe: Dictionary in Items.get_recipes():
		var authored: Array = recipe.ingredients.duplicate(true)
		for sample in range(24):
			var required: Array = Items.instantiate_order_recipe_for_dish(recipe.output_item_id)
			var actual: Array[Dictionary] = []
			var varied: int = 0
			for index in range(required.size()):
				var entry: Dictionary = required[index]
				_check(Array(entry.get("accepted_process_states", [])).is_empty(), "Customer recipes must never contain a maturation range: %s" % recipe.output_item_id)
				if StringName(entry.process_state) != StringName(authored[index].process_state):
					varied += 1
				for portion in range(int(entry.get("count", 1))):
					actual.append({"item_id": entry.item_id, "process_state": entry.process_state})
			if int(recipe.difficulty) >= 3:
				_check(varied <= 1, "Advanced orders may vary only one component; all others have fixed menu states.")
			_check(Items.signature_matches_recipe(Items.get_recipe_signature(actual), required), "An exactly prepared customer recipe must be accepted.")
			for index in range(actual.size()):
				var old: StringName = actual[index].process_state
				var family := Items.get_process_family(old)
				if family not in [&"roast", &"grind"]:
					continue
				actual[index].process_state = (Items.PROCESS_STATE_ROAST_WELL if old != Items.PROCESS_STATE_ROAST_WELL else Items.PROCESS_STATE_ROAST_RARE) if family == &"roast" else (Items.PROCESS_STATE_GRIND_FINE if old != Items.PROCESS_STATE_GRIND_FINE else Items.PROCESS_STATE_GRIND_COARSE)
				_check(not Items.signature_matches_recipe(Items.get_recipe_signature(actual), required), "Changing even one portion's maturation must be rejected: %s" % recipe.output_item_id)
				actual[index].process_state = old
		_check(recipe.ingredients == authored, "Generating exact customer recipes must not change the menu's allowed variants.")

func _test_special_clock() -> void:
	for group: Dictionary in Groups.create_default_order_groups():
		var with_guest: Dictionary = Groups.append_boss_special_orders(group, &"scarab")
		var first_orders: Array = with_guest.waves[0].orders
		_check(first_orders.all(func(order: Dictionary) -> bool: return not bool(order.get("special_guest", false))) and with_guest.boss_special_orders.size() == 3, "The special guest must stay outside opening waves until the day clock ends.")
	var manager := Manager.new()
	root.add_child(manager)
	manager.set_process(false)
	manager.set_orders(Groups.get_boss_special_orders(&"scarab"))
	manager._process(15)
	_check(manager.take_order_at_slot(1) and manager.get_active_orders().size() == 1 and manager.get_waiting_orders().size() == 2, "A special customer accepts only its first course.")
	_check(manager.get_active_orders().all(func(order: Dictionary) -> bool: return is_equal_approx(float(order.time_remaining), 600.0)), "The cooking allowance must remain intact until the special customer is accepted.")
	_check(not manager.adjust_order_time("BOSS-01", 100), "Blessing adjustments must not change a special customer's clock.")
	manager.restore_all_active_order_patience_fraction(1)
	_check(is_equal_approx(manager.special_guest_time_remaining, 600), "Bulk patience restoration must skip special customers.")
	manager._process(300)
	_check(manager.special_guest_pressure_active and manager.get_active_orders().all(func(order: Dictionary) -> bool: return is_equal_approx(float(order.time_remaining), 300.0)), "Special pressure must start at the one shared half-patience threshold.")
	manager.complete_current_order(1, true, "BOSS-01")
	_check(manager.special_guest_active and manager.get_active_orders().size() == 1 and manager.get_waiting_orders().size() == 1 and is_equal_approx(manager.special_guest_time_remaining, 300), "Serving a special dish promotes the next course without resetting patience.")
	manager._process(301)
	_check(manager.has_active_order() and is_zero_approx(manager.special_guest_time_remaining), "A special customer must remain after its clock reaches zero.")
	var penalties: Array[int] = []
	manager.special_guest_penalty_tick.connect(func(amount: int) -> void: penalties.append(amount))
	manager.set_orders(Groups.get_boss_special_orders(&"scarab"))
	manager._process(60.0)
	_check(manager.get_waiting_orders().size() == 3 and manager.special_guest_overdue and penalties.is_empty(), "Acceptance timeout must retain the guest and start gradual loss without an immediate penalty.")
	_check(not manager.special_guest_pressure_active, "An unaccepted overdue guest must not yet accelerate ordinary customers.")
	manager._process(4.99)
	_check(penalties.is_empty(), "The first reputation loss must wait a full five overdue seconds.")
	manager._process(0.02)
	_check(penalties == [1], "An overdue special guest must cost one reputation per five seconds.")
	_check(manager.take_order_at_slot(1) and manager.get_active_orders().size() == 1 and manager.get_waiting_orders().size() == 2, "A special guest must remain available for acceptance after its order timer expires.")
	manager._process(5.0)
	_check(penalties == [1, 1] and is_equal_approx(manager.special_guest_time_remaining, 595.0), "Late acceptance grants the cooking allowance but cannot erase the overdue penalty.")
	manager.clear_orders()
	penalties.clear()
	var regular := _fixture("paid", 2, Items.DISH_CRISP_PLATE_ID, 1000.0)
	manager.set_orders([regular])
	manager.take_order_at_slot(2)
	manager.add_orders(Groups.get_boss_special_orders(&"scarab"))
	manager.take_order_at_slot(1)
	manager._process(300.0)
	var before: float = manager.get_active_order_for_slot(2).time_remaining
	manager._process(4.0)
	_check(is_equal_approx(before - float(manager.get_active_order_for_slot(2).time_remaining), 5.0), "Half patience must accelerate ordinary cooking patience by exactly twenty-five percent.")
	manager._process(296.0)
	_check(manager.special_guest_overdue and penalties.is_empty(), "Cooking patience expiry must also begin a fresh five-second penalty interval.")
	var unpaid := _fixture("unpaid", 3, Items.DISH_CRISP_PLATE_ID)
	manager.add_orders([unpaid])
	_check(int(manager.get_active_order_for_slot(2).gold_reward) == 20 and int(manager.get_waiting_order_for_slot(3).gold_reward) == 0, "Only customers arriving after the special deadline lose rewards; existing customers retain theirs.")
	manager._process(5.0)
	_check(penalties == [1] and manager.get_active_orders().filter(func(order: Dictionary) -> bool: return bool(order.get("special_guest", false))).size() == 1 and manager.get_waiting_orders().filter(func(order: Dictionary) -> bool: return bool(order.get("special_guest", false))).size() == 2, "Cooking expiry must retain the current course and future courses while gradually costing reputation.")
	manager.complete_current_order(1, true, "BOSS-01")
	manager.complete_current_order(1, true, "BOSS-02")
	manager.complete_current_order(1, true, "BOSS-03")
	manager._process(10.0)
	_check(penalties == [1] and not manager.special_guest_active, "Finishing all dishes must stop future overdue penalties.")
	manager.clear_orders()
	_check(not manager.special_guest_overdue and manager.get_special_guest_clock().is_empty(), "Day cleanup must reset every special deadline and penalty state.")
	manager.free()

func _test_live_delivery_and_hud(main: Node) -> void:
	var manager: Node = main.get_node("OrderManager")
	var player: Node = main.get_node("Player")
	var counter: Node = main.get_node("TestServingCounter")
	var hud: Node = main.get_node("OrderHud")
	var flow: Node = main.get_node("LevelFlowController")
	flow.run_context.state = Context.LevelState.PREPARE_PHASE
	var a := _fixture("first", 1, Items.DISH_CRISP_PLATE_ID)
	var b := _fixture("second", 1, Items.DISH_SPICED_LAMB_ID)
	var c := _fixture("third", 1, Items.DISH_CAMEL_DOUBLE_ROAST_ID)
	manager.set_orders([a, b, c])
	_check(hud.order_cards.is_empty(), "Unaccepted dishes must not be exposed as active order cards.")
	manager.take_order_at_slot(1)
	_check(hud.order_cards.size() == 1, "A multi-dish customer must have one card and one patience bar.")
	var card: Panel = hud.order_cards.values()[0]
	_check(card.get_node("Dishes").get_child_count() == 3, "One acceptance must reveal all requested dishes together.")
	for row: Control in card.get_node("Dishes").get_children():
		_check(row.get_node("DishIcon").size == Vector2(54, 54), "Dish textures must respect the compact card size.")
		for panel: Panel in row.get_node("RecipeIconsRow").get_children():
			_check(panel.get_node("IngredientIcon").size.x <= 44, "Ingredient artwork must fit its reserved slot.")
			var process_icon: TextureRect = panel.get_node_or_null("ProcessIcon")
			if process_icon != null:
				_check(process_icon.texture != null and process_icon.size.is_equal_approx(Vector2(26, 26)), "Processing requirements must use a readable compact icon: %s" % process_icon.size)
			_check(panel.get_child_count() <= 2 and not panel.get_children().any(func(child: Node) -> bool: return child is Label), "Recipe slots must not fall back to visible processing text.")
	var bar: ColorRect = card.get_node("PatienceBarFrame/PatienceBarFill")
	manager._process(30)
	_check(is_equal_approx(bar.size.x / card.get_node("PatienceBarFrame").size.x, 0.75), "The shared card must display the live customer timer.")
	var entries: Array[Dictionary] = []
	for entry: Dictionary in b.recipe_items:
		for portion in range(int(entry.get("count", 1))):
			entries.append({"item_id": entry.item_id, "process_state": entry.process_state})
	var exact := Items.get_recipe_signature(entries)
	entries[0].process_state = Items.PROCESS_STATE_ROAST_RARE
	var wrong := Items.get_recipe_signature(entries)
	counter.focused_slot_index = 0
	player.clear_held_item()
	player.pick_up_item(Items.DISH_SPICED_LAMB_ID, Items.get_item_texture(Items.DISH_SPICED_LAMB_ID), &"", wrong, {"uses_plate": true})
	_check(not counter.can_receive_item(player) and not counter.receive_item_from_player(player), "A dish with the wrong maturation must not be served.")
	_check(player.get_held_item_id() == Items.DISH_SPICED_LAMB_ID and player.get_held_item_recipe_signature() == wrong and manager.get_active_orders().size() == 3, "Rejected delivery must preserve the dish, plate, signature, and all requests.")
	player.clear_held_item()
	player.pick_up_item(Items.DISH_SPICED_LAMB_ID, Items.get_item_texture(Items.DISH_SPICED_LAMB_ID), &"", exact, {"uses_plate": true})
	_check(counter.receive_item_from_player(player) and player.get_held_item_id() == Items.DIRTY_PLATE_ID, "The second requested dish must be serveable before the first and return a dirty plate.")
	_check(manager.get_active_orders().size() == 2 and manager.get_active_orders().all(func(order: Dictionary) -> bool: return is_equal_approx(float(order.time_remaining), 114.0)), "Out-of-order delivery restores twenty percent to the shared customer clock.")
	_check(hud.order_cards.size() == 1 and hud.order_cards.values()[0].get_node("Dishes").get_child_count() == 2, "Serving must remove only that dish from the shared card.")
	var updated_card: Panel = hud.order_cards.values()[0]
	_check(is_equal_approx(updated_card.get_node("PatienceBarFrame/PatienceBarFill").size.x / updated_card.get_node("PatienceBarFrame").size.x, 0.95), "HUD immediately displays restored shared patience.")
	player.clear_held_item()
	# A fully departing group must finish recording all expired dishes before
	# the level-flow callback advances to the next wave.
	flow.run_context.initialize({"waves": [{"orders": [a, b, c]}, {"orders": [a]}]})
	flow.run_context.state = Context.LevelState.WAVE_ACTIVE
	manager.set_orders([a, b, c])
	manager.take_order_at_slot(1)
	manager._process(120)
	_check(flow.run_context.failed_orders == 3 and flow.run_context.reputation == 75 and flow.run_context.current_wave_index == 1, "Customer timeout must record all dishes, one reputation penalty, and exactly one wave transition.")

func _run() -> void:
	_test_customer_clock()
	_test_serving_patience()
	_test_exact_recipes()
	_test_special_clock()
	var main: Node = load("res://Scenes/Main/main.tscn").instantiate()
	root.add_child(main)
	await physics_frame
	_stop_ticks(main)
	paused = false
	_test_live_delivery_and_hud(main)
	if "--capture" in OS.get_cmdline_user_args():
		var preview := SubViewport.new()
		preview.size = Vector2i(1920, 1080)
		preview.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		root.add_child(preview)
		main.reparent(preview)
		var manager: Node = main.get_node("OrderManager")
		manager.set_orders(Groups.get_boss_special_orders(&"scarab"))
		main.get_node("LevelFlowController").overlay_controller.set_transition_visible(false)
		main.get_node("OrderHud").set_visibility_mode(true, true)
		for frame in range(3):
			await process_frame
			RenderingServer.force_draw(false)
		preview.get_texture().get_image().save_png("res://../_artifact_work/boss_guest_pacing_20261019/special_waiting.png")
		manager.take_order_at_slot(1)
		for frame in range(3):
			await process_frame
			RenderingServer.force_draw(false)
		preview.get_texture().get_image().save_png("res://../_artifact_work/boss_guest_pacing_20261019/special_accepted.png")
	main.queue_free()
	await process_frame
	if failures.is_empty():
		print("PASS: one acceptance, shared clocks, drink 10% / dish 20% serving restoration, special clock isolation, out-of-order delivery, exact maturation, rejected dish preservation, and grouped HUD.")
	quit(0 if failures.is_empty() else 1)
