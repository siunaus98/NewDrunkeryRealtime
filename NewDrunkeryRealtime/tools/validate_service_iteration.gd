extends SceneTree

const Schedule = preload("res://Scripts/Orders/CustomerArrivalSchedule.gd")
const Items = preload("res://Scripts/Kitchen/TestItemDefs.gd")
const Groups = preload("res://Scripts/Orders/OrderGroupDefs.gd")
const Context = preload("res://Scripts/Core/LevelContext.gd")
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error(message)

func settle() -> void:
	for frame in range(10):
		await process_frame

func stop_ticks(node: Node) -> void:
	node.set_process(false)
	node.set_physics_process(false)
	for child: Node in node.get_children():
		stop_ticks(child)

func run() -> void:
	var schedule := Schedule.new()
	schedule.reset(3, 1042)
	for pair in range(500):
		schedule.arrived()
		var first := schedule.remaining
		schedule.arrived()
		check(first >= 6 and first <= 34 and schedule.remaining >= 6 and schedule.remaining <= 34, "Arrival gaps stay bounded")
		check(is_equal_approx(first + schedule.remaining, 40), "Two gaps compensate to preserve three visits per minute")
	root.size = Vector2i(1920, 1080)
	var main: Node = load("res://Scenes/Main/main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	await settle()
	stop_ticks(main)
	paused = false
	var flow: Node = main.get_node("LevelFlowController")
	flow.input_release_guard_active = false
	flow.day_transition_active = false
	var manager: Node = main.get_node("OrderManager")
	flow.progression_state.day_index = 0
	flow._refresh_order_groups_for_current_day()
	var group: Dictionary = flow._build_order_group_for_current_menu(flow.order_groups[0])
	flow.run_context.initialize(group)
	flow._enter_prepare_phase()
	flow._process(60)
	check(flow.run_context.state == Context.LevelState.WAVE_ACTIVE and manager.customers.size() == 1, "Service opens with exactly one customer")
	check(manager.default_order_take_patience_duration == 75, "Order-taking patience is 75 seconds")
	var order: Dictionary = manager.get_first_unresolved_order()
	check(float(order.patience_duration) >= 150, "Cooking patience includes a from-zero supply trip")
	manager.take_order_at_slot(int(order.target_slot))
	manager._process(40)
	var retained: float = manager.get_first_unresolved_order().time_remaining
	flow.customer_arrivals.remaining = 0
	flow._tick_customer_arrivals(0)
	check(manager.customers.size() == 2 and is_equal_approx(float(manager.get_active_orders()[0].time_remaining), retained), "Next single arrival preserves existing accepted order and timer")
	flow.customer_arrivals.remaining = 0
	flow._tick_customer_arrivals(0)
	check(manager.customers.size() == 3, "Three free windows fill one arrival at a time")
	flow.customer_arrivals.remaining = 0
	flow._tick_customer_arrivals(500)
	check(manager.customers.size() == 3 and flow.customer_arrivals.remaining == 0, "Full windows wait without accumulating a burst backlog")
	manager.clear_orders()
	flow._tick_customer_arrivals(0)
	check(manager.customers.size() == 1 and flow.customer_arrivals.remaining > 0, "Reopening a window admits only one visitor and restarts normal spacing")
	for visit in range(20):
		manager.clear_orders()
		flow.customer_arrivals.remaining = 0
		flow._tick_customer_arrivals(0)
	check(flow.customer_visit > 20 and flow.run_context.state == Context.LevelState.WAVE_ACTIVE, "Customer stream exceeds authored order count and clearing tables does not finish the day")
	manager.clear_orders()
	flow._handle_wave_order_resolution()
	check(flow.run_context.state == Context.LevelState.WAVE_ACTIVE, "Empty restaurant does not close service")
	flow.day_time_remaining = 30
	flow.run_context.danger_active = true
	flow.run_context.danger_time_remaining = 0.01
	flow.run_context.reputation = 25
	flow._process(2)
	check(flow.run_context.state == Context.LevelState.WAVE_ACTIVE, "Low reputation has no hidden timed defeat")
	flow.day_time_remaining = 0.1
	flow._process(0.2)
	check(flow.run_context.state == Context.LevelState.LEVEL_SUCCESS, "Closing clock succeeds with unresolved customers")
	paused = false
	# A real reputation failure remains distinct from successful closing.
	flow.run_context.initialize(group)
	flow.run_context.state = Context.LevelState.WAVE_ACTIVE
	flow.run_context.reputation = 1
	flow._on_order_expired({"order_id": "last-reputation", "reputation_penalty": 20})
	check(flow.run_context.state == Context.LevelState.LEVEL_FAILED, "Reputation reaching zero still fails")
	paused = false
	# Simulate a complete day with available tables: appointments remain paced
	# across the entire service window instead of exhausting template waves.
	flow.run_context.initialize(group)
	flow._enter_prepare_phase()
	flow._process(60)
	var previous_visit: int = flow.customer_visit
	for tick in range(721):
		manager.clear_orders()
		flow._process(0.25)
		check(flow.customer_visit - previous_visit <= 1, "A frame can admit at most one customer")
		previous_visit = flow.customer_visit
		if flow.run_context.state == Context.LevelState.LEVEL_SUCCESS:
			break
	check(flow.customer_visit >= 9 and flow.customer_visit <= 11 and flow.run_context.state == Context.LevelState.LEVEL_SUCCESS, "Whole-day arrivals follow mean frequency and close successfully: %d visits" % flow.customer_visit)
	paused = false
	# Boss days close normal arrivals but retain the separate guest finale.
	var boss_group := Groups.append_boss_special_orders(group, &"scarab")
	flow.run_context.initialize(boss_group)
	flow._enter_prepare_phase()
	flow._start_wave_phase()
	flow.day_time_remaining = 0.1
	flow._process(0.2)
	check(flow.run_context.state == Context.LevelState.WAVE_ACTIVE and flow.run_context.special_guest_arrived, "Boss day keeps special-guest finale after closing")
	var visits: int = flow.customer_visit
	flow._process(60)
	check(flow.customer_visit == visits and not flow.can_summon_flyer_customer(), "No regular or flyer arrivals after closing")
	flow._on_special_guest_completed()
	check(flow.run_context.state == Context.LevelState.LEVEL_SUCCESS, "Special guest completion settles boss day")
	paused = false
	# Generated elite visits keep the entire course sequence in one slot and
	# receive a combined cooking allowance, while desserts remain hospitality.
	var menu_pool: Array[StringName] = [Items.DRINK_OASIS_WINE_ID, Items.DISH_CRISP_PLATE_ID, Items.DISH_RED_ROLL_ID, Items.DISH_QINGMEI_SWEET_BOWL_ID]
	var rng := RandomNumberGenerator.new()
	rng.seed = 1042
	var elites := 0
	for visit in range(300):
		var courses := Groups.create_arriving_customer(menu_pool.filter(func(id: StringName) -> bool: return not Items.is_dessert(id)), 3, 2, visit, rng)
		check(courses.all(func(dish: Dictionary) -> bool: return int(dish.target_slot) == 2 and not Items.is_dessert(dish.dish_item_id)), "Generated visit stays in one slot and excludes desserts")
		if courses.size() > 1:
			elites += 1
			check(float(courses[0].patience_duration) > Items.get_dish_patience_duration(courses[0].dish_item_id), "Multi-course visitor receives extra cooking patience")
	check(elites > 50, "Continuous generation preserves elite customers")
	# A lamp instantiated through the real shop path must occupy one centered cell.
	check(flow.purchase_support_facility({"facility_type": &"lamp", "title": "明光灯"}), "Shop spawns lamp")
	var lamp: Node2D
	for facility: Node in get_nodes_in_group("support_facilities"):
		if facility.facility_type == &"lamp":
			lamp = facility
	check(lamp != null and lamp.get_layout_footprint() == Vector2i.ONE and lamp.body_size == Vector2(104, 104), "Lamp footprint and collider occupy one cell")
	var map: Node2D = main.get_node("PrototypeMap")
	var local: Vector2 = map.to_local(lamp.global_position) / map.get_tile_size()
	check(is_equal_approx(local.x - floorf(local.x), .5) and is_equal_approx(local.y - floorf(local.y), .5), "Lamp is centered inside its cell")
	check(not lamp.is_in_group("conveyor_facilities"), "Lamp is never registered as conveyor")
	# Render and inspect third candidate after real layout settles.
	flow.run_context.state = Context.LevelState.MENU_DISH_SELECT
	flow._set_overlay_layout_mode(true)
	flow._set_overlay_visible(true)
	var menu: Node = flow.menu_dish_select_controller
	var offers: Array[StringName] = [Items.DISH_ROYAL_ROAST_PLATE_ID, Items.DISH_STONEFLOWER_COLD_PLATE_ID, Items.DISH_MONITOR_ROYAL_BANQUET_ID]
	menu.prepare_for_open(offers, flow.progression_state.get_menu_dish_ids(), 5, -1)
	menu.move_replace_selection(1)
	menu.move_replace_selection(1)
	await settle()
	var scroll: ScrollContainer = menu.menu_scroll_containers[0]
	var row: Control = menu.menu_row_controls[0][2]
	var visible_rect: Rect2 = scroll.get_global_rect().intersection(flow.overlay_controller.cards_scroll.get_global_rect()).intersection(Rect2(Vector2.ZERO, Vector2(root.size)))
	check(visible_rect.encloses(row.get_global_rect()), "Third candidate and final recipe line fit the actual visible viewport: row=%s view=%s" % [row.get_global_rect(), visible_rect])
	if OS.get_cmdline_user_args().has("--render-service-menu"):
		await RenderingServer.frame_post_draw
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://_artifact_work/service_iteration"))
		root.get_texture().get_image().save_png("res://_artifact_work/service_iteration/third_menu.png")
	main.queue_free()
	await process_frame
	print("SERVICE ITERATION: %d failures; compensated single arrivals, continuous service, closing success, boss finale, patience, lamp and third menu row" % failures.size())
	quit(0 if failures.is_empty() else 1)
