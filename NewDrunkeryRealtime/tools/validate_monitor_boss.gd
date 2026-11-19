extends SceneTree

const Items = preload("res://Scripts/Kitchen/TestItemDefs.gd")
const Groups = preload("res://Scripts/Orders/OrderGroupDefs.gd")
const Food = preload("res://Scripts/Enemies/MonitorFoodAccess.gd")
const Cargo = preload("res://Scripts/Facilities/FacilityItems.gd")
var failures: Array[String] = []
var main: Node

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

func table_at(point: Vector2, id: StringName = Items.MEAT_RED_ID, payload: Dictionary = {}) -> Node2D:
	var table: Node2D = load("res://Scenes/Restaurant/test_table.tscn").instantiate()
	main.add_child(table)
	table.global_position = point
	table.item_id = id
	table.item_texture = Items.get_item_texture(id)
	table.item_payload = payload.duplicate(true)
	table.has_item = true
	table._update_item_visual()
	return table

func _run() -> void:
	main = load("res://Scenes/Main/main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	await process_frame
	stop_ticks(main)
	paused = false
	var flow: Node = main.get_node("LevelFlowController")
	flow.progression_state.day_index = 6
	var group: Dictionary = flow._build_order_group_for_current_menu(Groups.create_default_order_groups(2)[0])
	check(group.final_boss and group.boss_enhanced_map_mechanism_id == &"monitor" and group.boss_special_orders.size() == 3, "Day seven selects the monitor and one three-dish guest")
	check(group.menu_dish_ids.has(Items.DISH_MONITOR_ROYAL_BANQUET_ID) and not group.allowed_meats.has(Items.MONITOR_TENDERLOIN_ID) and not group.allowed_veggies.has(Items.MONITOR_TENDERLOIN_ID), "Special recipe supplied without spawning boss ingredients as normal resources")
	for wave: Dictionary in group.waves:
		check(wave.orders.all(func(order: Dictionary) -> bool: return order.dish_item_id != Items.DISH_MONITOR_ROYAL_BANQUET_ID), "Final special dish never enters ordinary requests")
	var battle: Node = main.get_node("BattleManager")
	battle.configure_for_order_group(group)
	battle.spawn_scheduled_boss()
	var boss: CharacterBody2D = get_first_node_in_group("monitor_bosses")
	check(boss != null and boss.current_health == 36000 and boss.drop_item_id == Items.MONITOR_TENDERLOIN_ID, "Real managed boss has correct health and special drop")
	if boss == null:
		quit(1)
		return
	stop_ticks(boss)
	var tongue: Node2D = boss.tongue
	var kitchen: Rect2 = boss.prototype_map.get_kitchen_zone_bounds()
	for source: Node in get_nodes_in_group("pickup_drop_targets"):
		if source is Node2D and kitchen.has_point(source.global_position) and not Food.candidates(self, Rect2(source.global_position - Vector2.ONE, Vector2.ONE * 2)).is_empty():
			source.hide()
	var first := table_at(kitchen.get_center(), Items.MEAT_RED_ID)
	var second := table_at(kitchen.get_center() + Vector2(260, 0), Items.VEG_ROOT_ID)
	var health_before: int = boss.current_health
	# A complete item cannot be swapped for another after lock-on.
	var options := Food.candidates(self, kitchen)
	check(not options.is_empty(), "Real table food is visible to theft query")
	var target: Dictionary = options[0]
	var target_table: Node = target.source.get_ref()
	target_table.item_id = Items.EGG_ID
	check(not Food.valid(target) and Food.consume(target).is_empty(), "Replacing food invalidates its transaction")
	# Containers lose one portion, dishes leave their physical plate behind.
	var seasoning := table_at(kitchen.get_center() + Vector2(0, 260), Items.SEASONING_BOX_ID, {"item_id": Items.MUSHROOM_ID, "process_state": Items.PROCESS_STATE_GRIND_FINE, "servings": 4})
	var box_target := Food.candidates(self, Rect2(seasoning.global_position - Vector2.ONE, Vector2.ONE * 2))[0]
	var eaten := Food.consume(box_target)
	check(not eaten.is_empty() and seasoning.item_payload.servings == 3 and eaten.payload.servings == 1, "Eating seasoning removes exactly one portion")
	var plated := table_at(kitchen.get_center() - Vector2(0, 260), Items.DISH_RED_ROLL_ID, {"uses_plate": true})
	var plate_target := Food.candidates(self, Rect2(plated.global_position - Vector2.ONE, Vector2.ONE * 2))[0]
	eaten = Food.consume(plate_target)
	check(plated.item_id == Items.DIRTY_PLATE_ID and not bool(eaten.payload.get("uses_plate", false)), "Eating a plated dish preserves one dirty plate without duplicating it")
	check(not Food.edible({"item_id": Items.MONITOR_TENDERLOIN_ID}) and not Food.edible({"item_id": Items.DISH_MONITOR_ROYAL_BANQUET_ID}), "Special food and its finished dish are protected")
	var assembly: Node2D = get_first_node_in_group("assembly_stations")
	assembly.show()
	assembly.stored_items.assign([
		{"item_id": Items.VEG_ROOT_ID, "process_state": Items.PROCESS_STATE_CUT, "recipe_signature": "", "payload": {}},
		{"item_id": Items.MEAT_RED_ID, "process_state": Items.PROCESS_STATE_ROAST_WELL, "recipe_signature": "", "payload": {}}
	])
	assembly._update_item_visual()
	for source: Node in get_nodes_in_group("pickup_drop_targets"):
		if source is Node2D and source != assembly and kitchen.has_point(source.global_position):
			source.hide()
	var assembly_targets := Food.candidates(self, kitchen)
	var assembly_food := Food.consume_many(assembly_targets)
	check(assembly.stored_items.is_empty() and assembly_food.size() == 2 and assembly_food.all(func(item: Dictionary) -> bool: return not item.is_empty()), "Simultaneous food transactions preserve both assembly slots")
	var stack: Node2D = preload("res://Scripts/Facilities/FacilityCatalog.gd").create(&"stack_table")
	main.add_child(stack)
	stack.global_position = kitchen.get_center()
	stack.count = 20
	stack.seasoning = true
	stack.stored = {"item_id": Items.SEASONING_BOX_ID, "process_state": &"", "recipe_signature": "", "payload": {"item_id": Items.MUSHROOM_ID, "process_state": Items.PROCESS_STATE_GRIND_FINE, "servings": 4}}
	var stack_targets := Food.candidates(self, Rect2(stack.global_position - Vector2.ONE, Vector2.ONE * 2))
	check(not stack_targets.is_empty(), "Stack facility exposes its available food")
	if not stack_targets.is_empty():
		Food.consume(stack_targets[0])
		check(stack.count == 19, "Stack facility loses one portion rather than the stored batch")
	# The three production stations and assembly table use their real storage APIs.
	for cooker: Node2D in get_nodes_in_group("cooking_stations"):
		cooker.show()
		cooker.has_item = true
		cooker.item_id = Items.MUSHROOM_ID
		cooker.item_process_state = Items.PROCESS_STATE_GRIND_FINE
		cooker.batch_servings = 4
		var choices := Food.candidates(self, Rect2(cooker.global_position - Vector2.ONE, Vector2.ONE * 2))
		check(not choices.is_empty(), "Cooker contents can be targeted")
		if not choices.is_empty():
			Food.consume(choices[0])
			check(cooker.has_item and cooker.batch_servings == 3, "Cooker seasoning theft consumes one serving")
		cooker._clear_item()
	# Bait selects food on the arena floor and preserves container conservation.
	for loose: Node in get_nodes_in_group("loose_items"):
		loose.hide()
	var bait_position: Vector2 = boss._get_safe_arena_bounds().get_center()
	boss.global_position = bait_position
	var bait_food := Cargo.drop(main, bait_position + Vector2(40, 0), {"item_id": Items.DISH_RED_ROLL_ID, "process_state": &"", "payload": {}, "recipe_signature": ""})
	boss._find_bait()
	check(not boss.bait.is_empty(), "Real floor dish attracts the monitor")
	boss._eat_bait()
	check(boss.eating_remaining == 3.0 + clampi(Items.get_dish_difficulty(Items.DISH_RED_ROLL_ID), 1, 3) * 2.0 and bait_food.is_queued_for_deletion(), "Dish creates quality-based eating opening")
	health_before = boss.current_health
	boss.receive_hit(100)
	check(boss.current_health == health_before - 100, "Body damage does not gain a second meal multiplier")
	# Normal arena skills resolve and retain collision-safe movement.
	var player: Node2D = main.get_node("Player")
	player.global_position = boss.global_position + Vector2(240, 0)
	boss.player = player
	for skill: int in [boss.Attack.STING, boss.Attack.SWEEP, boss.Attack.RUSH]:
		boss.eating_remaining = 0
		boss.start_attack(skill)
		boss._resolve_attack()
		if skill == boss.Attack.RUSH:
			for frame in range(120):
				boss._physics_process(1.0 / 60.0)
		check(boss._get_safe_arena_bounds().grow(1).has_point(boss.global_position), "Active skills remain inside arena bounds")
	var drops_before := get_nodes_in_group("loose_items").size()
	boss.receive_hit(999999)
	check(boss.is_dead and get_nodes_in_group("loose_items").size() == drops_before + 3, "Defeat drops three manually carried special ingredients")
	# Complete all three exact requests through the actual serving counter.
	flow.run_context.initialize(group)
	flow.run_context.state = 7
	var manager: Node = main.get_node("OrderManager")
	manager.set_orders(group.boss_special_orders)
	manager.take_order_at_slot(1)
	var counter: Node = main.get_node("TestServingCounter")
	counter.focused_slot_index = 0
	var required: Array = manager.get_active_orders()
	for order: Dictionary in required:
		player.clear_held_item()
		var portions: Array[Dictionary] = []
		for entry: Dictionary in order.recipe_items:
			for count in int(entry.get("count", 1)):
				portions.append({"item_id": entry.item_id, "process_state": entry.process_state})
		var dish := StringName(order.dish_item_id)
		player.pick_up_item(dish, Items.get_item_texture(dish), &"", Items.get_recipe_signature(portions), {"uses_plate": not Items.is_drink(dish)})
		check(counter.receive_item_from_player(player), "Final guest accepts actual exact dish")
	check(flow.run_context.state == 10 and manager.customers.is_empty() and flow.progression_state.day_index == 6, "Guest completion wins demo without advancing to day eight")
	check(flow.overlay_controller.overlay_title_label.text.contains("通关"), "Victory screen explicitly shows demo completion")
	paused = false
	main.queue_free()
	await process_frame
	print("MONITOR BOSS: %d failures; managed spawn, food transactions, food conservation, bait, skills, drops and final guest victory" % failures.size())
	quit(0 if failures.is_empty() else 1)
