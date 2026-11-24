extends SceneTree

const Items = preload("res://Scripts/Kitchen/TestItemDefs.gd")
const Context = preload("res://Scripts/Core/LevelContext.gd")
var errors: Array[String] = []
var main: Node
var tutorial: Node
var actor: Node2D

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	if not ok:
		errors.append(message)
		push_error(message)

func settle() -> void:
	for index in range(8): await process_frame

func press_key(key: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = key
	event.pressed = true
	root.push_input(event)
	event = InputEventKey.new()
	event.keycode = key
	event.pressed = false
	root.push_input(event)

func hold(id: StringName, state: StringName = &"") -> void:
	actor.clear_held_item()
	actor.pick_up_item(id, Items.get_item_texture(id), state)

func cut(id: StringName) -> void:
	var station: Node = main.get_node("TestCooker")
	station.reset_state()
	actor.global_position = station.global_position + Vector2(0, 80)
	hold(id)
	check(station.receive_item_from_player(actor), "Cut station accepts ingredient")
	for index in range(30): station.interact_with_player(actor)
	check(not actor.is_holding_item() and station.has_item and station.item_process_state == Items.PROCESS_STATE_CUT, "Cut completion leaves food on station and hands empty")
	tutorial._update_objectives()
	check(tutorial.highlight_nodes.has(station) and tutorial.lesson_body.text.contains("主动取走"), "Finished cut remains the next highlighted interaction")
	check(station.take_item_to_player(actor), "J explicitly picks up completed cut food")

func check_lesson_layout() -> void:
	var expected: Dictionary = tutorial.LAYOUTS[tutorial.step]
	var map: Node = main.get_node("PrototypeMap")
	check(main.get_node_or_null("TutorialGuideNPC") == null, "Tutorial has no world guide NPC")
	var portrait: Control = tutorial.guide_portrait
	check(is_instance_valid(portrait) and tutorial.panel.is_ancestor_of(portrait), "Head and hands portrait belongs to bottom dialogue")
	check(portrait.mouse_filter == Control.MOUSE_FILTER_IGNORE, "Portrait never intercepts tutorial controls")
	check(not portrait.get_global_rect().intersects(tutorial.lesson_body.get_global_rect()), "Portrait and instructions do not overlap")
	check(map.map_regions.size() == 1 and map.get_world_bounds().size == tutorial.MAP_SIZES[tutorial.step], "Lesson has its own compact map")
	for name: String in tutorial.facility_templates:
		check(is_instance_valid(main.get_node_or_null(name)) == expected.has(name), "Lesson %d only instantiates needed facility: %s" % [tutorial.step + 1, name])
	check(tutorial.lesson_nodes.size() == expected.size(), "Previous lesson facilities have been freed")
	for node: Node2D in tutorial.lesson_nodes:
		if node.is_in_group("serving_counters"):
			check(not map.is_point_in_playable_area(node.global_position), "Guest table stands outside playable map")
			var art_bounds: Rect2 = node._local_rect_to_global(Rect2(-512, -512, 1024, 1024))
			check(not art_bounds.intersects(tutorial.lesson_bounds), "Entire guest table art stays outside playable floor")
		else:
			check(map.is_point_in_kitchen_zone(node.global_position), "Current facility lies inside lesson map")
		check(node.is_visible_in_tree(), "Required facility is visible: " + String(node.name))
	check(tutorial.lesson_body.text.split("\n").size() <= 2 and tutorial.lesson_body.text.length() < 180, "Only a short current-action instruction is shown")
	if tutorial.step not in [tutorial.SKILLS, tutorial.NIGHT, tutorial.BOSS] and not tutorial.ready_to_advance and not (tutorial.step == tutorial.FORAGE and tutorial.forage.state == tutorial.forage.ForageState.SELECTING):
		check(not tutorial.highlight_nodes.is_empty() and tutorial.target_label.visible, "Next interaction has a visible arrow and pulse highlight")
	check(not is_instance_valid(main.get_node_or_null("StorageCabinetDesertBird")), "Unrelated ingredient cabinet removed")
	check(root.get_visible_rect().encloses(tutorial.panel.get_global_rect()), "Tutorial dialogue including explanation button fits the screen")

func accept_order() -> void:
	var counter: Node = main.get_node("TestServingCounter")
	actor.global_position = Vector2(tutorial.lesson_bounds.position.x + 48, counter.global_position.y)
	var focus: Dictionary = preload("res://Scripts/Player/InteractionFocusQuery.gd").select_target(actor, [counter], actor.is_holding_item(), actor.global_position, Vector2.LEFT, 190, PI / 4)
	check(focus.get("target") == counter and tutorial.lesson_bounds.has_point(actor.global_position), "Guest table can be reached from inside the map")
	counter.set_pickup_drop_focus_data(actor, focus.get("focus_data", {}))
	counter.set_pickup_drop_highlight(true)
	check(counter.lower_sprite.modulate != Color.WHITE and counter.top_sprite.modulate != Color.WHITE, "Approach highlights both table art sprites")
	check(counter.highlight_layer.get_child_count() == 0 and counter.marker_layer.modulate == Color.WHITE, "Interaction area and order markers are not highlighted")
	for index in range(8):
		counter.focused_slot_index = 0
		counter.process_hold_interaction(actor, .2)
		await process_frame
	check(not main.get_node("OrderManager").active_orders.is_empty(), "Guest order accepted")
	main.get_node("OrderHud")._relayout_cards(true)
	for card: Control in main.get_node("OrderHud").order_cards.values():
		check(not card.get_global_rect().intersects(tutorial.panel.get_global_rect()), "Tutorial instructions never cover customer order card")

func deliver() -> bool:
	var counter: Node = main.get_node("TestServingCounter")
	counter.focused_slot_index = 0
	var result: bool = counter.receive_item_from_player(actor)
	tutorial._update_objectives()
	return result

func wash() -> void:
	var sink: Node = main.get_node("PlateSink")
	check(sink.receive_item_from_player(actor), "Dirty plate enters basin")
	actor.global_position = sink.to_global(sink.WASH_OFFSET) + Vector2(0, 90)
	for index in range(32):
		sink.process_hold_interaction(actor, .2)
		await process_frame

func run() -> void:
	var title: Node = load("res://Scenes/Main/game_start.tscn").instantiate()
	root.add_child(title)
	current_scene = title
	await process_frame
	check(title.title_menu_buttons.size() == 4 and title.title_menu_buttons[2].text == "教学模式", "Title has keyboard-accessible tutorial entry")
	title.selected_title_menu_index = 2
	title._activate_selected_title_menu_item()
	await settle()
	check(current_scene.cards.size() == 12, "Tutorial entry opens twelve selectable cards")
	for card: Button in current_scene.cards:
		check(not card.disabled and root.get_visible_rect().encloses(card.get_global_rect()), "Each lesson card is unlocked and inside viewport")
	if OS.get_cmdline_user_args().has("--capture"):
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://_artifact_work/tutorial"))
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://_artifact_work/tutorial/selector.png")
	press_key(KEY_ENTER)
	await settle()
	main = current_scene
	tutorial = main.get_node("TutorialController")
	actor = main.get_node("Player")
	var flow: Node = main.get_node("LevelFlowController")
	check(flow.tutorial_mode and main.get_node("PrototypeMap").tutorial_mode, "Dedicated tutorial uses small map and isolated progression")
	check(not paused and not flow.day_transition_active, "Tutorial starts without night pause or day timer")
	var before_magic: int = flow.magic_current
	flow.magic_current = 0
	flow.magic_regen_remaining = 0
	flow._process(1)
	check(flow.magic_current > 0, "Tutorial preserves real magic regeneration")
	flow.magic_current = before_magic
	check(main.get_node("PrototypeMap").get_world_bounds().size == Vector2(1152, 768), "Tutorial map is compact")
	check(not is_instance_valid(main.get_node_or_null("ForageRegionLeft")) and get_nodes_in_group("enemies").is_empty(), "No random region or combat waves in tutorial")
	check(not has_meta("run_setup"), "Tutorial entry setup is consumed and cannot contaminate next run")
	check_lesson_layout()
	tutorial.advance()
	check(tutorial.step == 0, "Incomplete lesson cannot advance")
	var assembly: Node = main.get_node("AssemblyStation")
	for index in range(2):
		cut(Items.VEG_LEAF_ID)
		check(assembly.receive_item_from_player(actor), "Combination receives player-cut sprouts")
	check(assembly.interact_with_player(actor), "First lesson creates an actual dish")
	check(not actor.is_holding_item() and tutorial._dish_ready(), "First dish stays on assembly awaiting plate lesson")
	tutorial.advance()
	check(tutorial.step == 1, "Dish making leads directly to plate and customer lesson")
	check_lesson_layout()
	assembly = main.get_node("AssemblyStation")
	check(not assembly.can_take_item(actor), "Dish cannot be taken without clean plate")
	tutorial._update_objectives()
	check(tutorial.highlight_nodes.has(main.get_node("TestServingCounter")) and not actor.is_holding_item(), "Second lesson starts by accepting order before picking up plate or dish")
	await accept_order()
	tutorial._update_objectives()
	check(tutorial.highlight_nodes.has(main.get_node("PlateSink").rack), "Exact clean-plate rack highlighted")
	check(main.get_node("PlateSink").rack.take_item_to_player(actor), "Player takes clean plate")
	check(assembly.take_item_to_player(actor), "Player actively plates prepared dish")
	tutorial._update_objectives()
	check(deliver(), "Cold dish serves actual guest")
	check(actor.get_held_item_id() == Items.DIRTY_PLATE_ID, "Serving returns dirty plate")
	await wash()
	tutorial.advance()
	check(tutorial.step == 2 and tutorial.earned_gold > 0 and tutorial.earned_xp > 0, "Service rewards recorded before roast lesson")
	check_lesson_layout()
	var roast: Node = main.get_node("BakeCooker")
	check(not main.get_node("TutorialPrepTableA").has_item and not main.get_node("TutorialPrepTableB").has_item, "Third lesson supplies two empty prep tables")
	check(tutorial.lesson_body.text.contains("第4段") and tutorial.lesson_body.text.contains("全熟"), "Roast explains all maturity stages and burning")
	actor.global_position = roast.global_position + Vector2(0, 80)
	hold(Items.RICE_ID)
	check(roast.receive_item_from_player(actor), "Roaster accepts wheat")
	for index in range(500):
		if roast.item_process_state == Items.PROCESS_STATE_ROAST_WELL: break
		roast._process(.1)
	check(not actor.is_holding_item() and roast.has_item, "Roasting leaves food on station")
	check(roast.take_item_to_player(actor), "Player takes well-done wheat")
	tutorial._update_objectives()
	var grind: Node = main.get_node("GrindCooker")
	actor.global_position = grind.global_position + Vector2(0, 80)
	hold(Items.EGG_ID)
	check(grind.receive_item_from_player(actor), "Grinder accepts plum")
	for index in range(100): grind.process_hold_interaction(actor, .1)
	check(not actor.is_holding_item() and grind.has_item, "Grinding also leaves result for explicit pickup")
	check(grind.take_item_to_player(actor), "Player takes seasoning box")
	tutorial.advance()
	check(tutorial.step == 3, "Fourth lesson introduces wine")
	check_lesson_layout()
	await accept_order()
	var barrel: Node = main.get_node("FixedBarrelLeftA")
	hold(Items.VEG_LEAF_ID)
	check(barrel.receive_item_from_player(actor), "Raw sprout goes directly into barrel")
	barrel._advance_fill(5)
	check(barrel.take_item_to_player(actor) and not actor.get_held_item_payload().get("uses_plate", false), "Wine uses its own cup")
	check(deliver() and not actor.is_holding_item(), "Wine serves without plate or dirty plate")
	var book: Node2D = main.get_node("RecipeBook")
	actor.global_position = book.global_position + Vector2(0, 110)
	var focus: Dictionary = preload("res://Scripts/Player/InteractionFocusQuery.gd").select_target(actor, [book], false, actor.global_position, Vector2.UP, 190, PI / 4)
	check(focus.get("target") == book, "Recipe book is reachable through real interaction focus")
	actor.interaction_controller._set_current_interaction_target(book)
	actor.interaction_controller.handle_interact()
	tutorial._process(.016)
	check(paused and main.codex_controller.current_category == &"dishes", "Dish categories and recipes open with paused gameplay")
	main.codex_controller._close()
	tutorial.advance()
	check(tutorial.step == 4, "Fifth lesson teaches dessert")
	check_lesson_layout()
	await accept_order()
	var customer: Dictionary = flow.order_manager.customers["slot:1"]
	var patience_before: float = customer.time_remaining
	check(is_equal_approx(patience_before, float(customer.patience_duration) * .45), "Dessert lesson deducts patience after accepting order")
	check(main.get_node("TestTable").take_item_to_player(actor), "Practice dessert can be taken")
	check(deliver(), "Dessert offered through real counter")
	check(not flow.order_manager.active_orders.is_empty() and customer.dessert_received and customer.time_remaining > patience_before, "Dessert restores patience while preserving original order")
	check(not flow.order_manager.can_offer_dessert(1, Items.DISH_QINGMEI_SWEET_BOWL_ID, tutorial._prepared_dish(Items.DISH_QINGMEI_SWEET_BOWL_ID).recipe_signature), "Same customer accepts dessert only once")
	check(main.get_node("PlateSink").receive_item_from_player(actor), "Put dirty dessert plate into basin")
	check(main.get_node("TutorialDishTable").take_item_to_player(actor), "Original dish remains available")
	check(deliver(), "Original dish still must be served")
	tutorial.advance()
	check(tutorial.step == 5, "Elite customer lesson follows dessert")
	check_lesson_layout()
	await accept_order()
	var elite: Dictionary = flow.order_manager.customers["slot:1"]
	check(is_equal_approx(float(elite.time_remaining), float(elite.patience_duration) * .45), "Elite starts accepted order with visible patience deficit")
	var order_hud: Node = main.get_node("OrderHud")
	order_hud.set_visibility_mode(false, true)
	for card: Control in order_hud.order_cards.values():
		check(card.get_rect().size.y >= card.get_node("Window").position.y + card.get_node("Window").size.y, "Collapsed elite card contains its enlarged course progress")
	order_hud.set_visibility_mode(true, true)
	for index in range(3):
		var active: Array = flow.order_manager.get_active_orders()
		check(active.size() == 1 and int(active[0].customer_orders_remaining) == 2 - index, "Only current elite course visible with correct remaining count")
		check(not flow.order_manager.take_order_at_slot(1, actor), "Holding or repeating acceptance cannot reveal future elite courses")
		if actor.is_holding_item(): main.get_node("PlateSink").receive_item_from_player(actor)
		check(main.get_node(["TestTable", "TutorialDishTable", "TutorialMainTable"][index]).take_item_to_player(actor), "Take current elite course")
		var before_service: float = elite.time_remaining
		check(deliver(), "Deliver current elite course")
		if index < 2: check(float(elite.time_remaining) > before_service, "Serving elite course restores patience")
	check(flow.order_manager.customers.is_empty(), "Elite customer leaves only after all three courses")
	tutorial.advance()
	check(tutorial.step == tutorial.SHOP, "Shop follows completed service lessons")
	check_lesson_layout()
	var merchant: Node = main.get_node("NightMerchant")
	check(merchant.is_visible_in_tree() and merchant.interact_with_player(actor), "Visible merchant opens actual shop")
	for index in range(4):
		flow.night_shop_controller.selected_shop_category_index = index
		tutorial._process(.016)
	flow._close_night_shop_overlay()
	tutorial.advance()
	check(tutorial.step == tutorial.FORAGE, "Shop leads to forage")
	check_lesson_layout()
	var old_point: Node = tutorial.forage
	actor.global_position = old_point.global_position + Vector2(0, 80)
	old_point.interact_with_player(actor)
	old_point.process_hold_interaction(actor, 1.0)
	tutorial._reset_practice()
	check(tutorial.step == tutorial.FORAGE and tutorial.forage != old_point and old_point.is_queued_for_deletion(), "Resetting an unfinished gathering task creates a fresh point without changing lesson")
	actor.global_position = tutorial.forage.global_position + Vector2(0, 80)
	tutorial.forage.interact_with_player(actor)
	tutorial.forage.process_hold_interaction(actor, 4.0)
	var option_rects: Array[Rect2] = []
	for option: Dictionary in tutorial.forage.active_options:
		var offset: Vector2 = option.offset
		var expected: Dictionary = {KEY_W: Vector2(0, -186), KEY_A: Vector2(-186, 0), KEY_S: Vector2(0, 186), KEY_D: Vector2(186, 0)}
		check(offset == expected[option.key_code], "Forage options follow cardinal WASD directions")
		var rect := Rect2(offset - Vector2(74, 71), Vector2(148, 142))
		for other: Rect2 in option_rects: check(not rect.intersects(other), "Forage cards do not overlap")
		option_rects.append(rect)
	tutorial.forage._select_option(tutorial.forage.active_options[0])
	tutorial.advance()
	check(tutorial.step == tutorial.COMBAT, "Actual gathering unlocks combat")
	check_lesson_layout()
	actor.global_position = tutorial.enemy.global_position - Vector2(100, 0)
	actor.aim_direction = Vector2.RIGHT
	actor._try_dash()
	actor.combat_controller.dash_time_remaining = 0
	for strike in range(3):
		if tutorial.enemy.is_queued_for_deletion(): break
		actor.combat_controller.attack_cooldown_remaining = 0
		actor.combat_controller.try_attack(Vector2.RIGHT, Callable(actor, "_can_damage_target_across_zones"))
	check(tutorial.enemy.is_dead, "Actual player attack geometry kills tutorial enemy")
	await process_frame
	var drops := get_nodes_in_group("battle_drops")
	check(not drops.is_empty(), "Defeated tutorial enemy spawns physical meat")
	if not drops.is_empty():
		actor.global_position = drops.back().global_position
		drops.back()._physics_process(.016)
	check(not actor.is_holding_item() and flow.storage_manager.get_stock(Items.MEAT_WHITE_ID) > tutorial.drop_stock_before, "Touching battle drop collects directly into inventory without J")
	tutorial.advance()
	check(tutorial.step == tutorial.SKILLS, "Dash, kill and actual loot unlock skills")
	check_lesson_layout()
	check(tutorial.info_button.visible and tutorial.lesson_body.text.contains("短冷却"), "Skill lesson explains both roles before practice")
	tutorial._next_info_page()
	var skill_station: Node = main.get_node("TestCooker")
	hold(Items.VEG_LEAF_ID)
	check(skill_station.receive_item_from_player(actor), "Skill comparison supplies ordinary cutting ingredient")
	var baseline_presses := 0
	while skill_station.processing_active and baseline_presses < 20:
		skill_station.interact_with_player(actor)
		baseline_presses += 1
	check(tutorial.events.has(&"skill_cut_before"), "Ordinary cut required before ultimate comparison")
	check(actor.skill_controller.try_activate_small(), "Small skill uses actual magic and cooldown")
	tutorial._update_objectives()
	check(skill_station.take_item_to_player(actor) and main.get_node("TestTable").receive_item_from_player(actor), "First cut can be put on prep table")
	hold(Items.VEG_LEAF_ID)
	check(skill_station.receive_item_from_player(actor), "Second comparison uses same ingredient and station")
	check(actor.skill_controller.try_activate_big(), "Tutorial provision allows real ultimate activation")
	tutorial._update_objectives()
	check(not tutorial.ready_to_advance, "Pressing skill keys alone cannot complete comparison")
	var ultimate_presses := 0
	while skill_station.processing_active and ultimate_presses < 20:
		skill_station.interact_with_player(actor)
		ultimate_presses += 1
	check(ultimate_presses < baseline_presses and ultimate_presses > 0, "Ultimate cuts actually require fewer presses than baseline")
	tutorial.advance()
	check(tutorial.step == tutorial.NIGHT, "Actual before/after cutting unlocks night lesson")
	check_lesson_layout()
	check(not flow.progression_state.has_pending_menu_offer() and flow.get_blessing_points() > 0, "Night explains menu without practical recipe choice")
	check(flow.night_event_controller.npcs.has(&"furnace"), "Actual night visitor exists in tutorial")
	tutorial._next_info_page()
	flow.handle_night_rest_interaction(&"blessing_statue")
	var refreshes: int = flow.progression_state.get_blessing_refreshes()
	check(flow.blessing_select_controller.refresh_selected(), "Actual blessing refresh available")
	check(flow.progression_state.get_blessing_refreshes() == refreshes - 1, "Blessing refresh spends one shared run allowance")
	flow._confirm_selected_blessing()
	flow.night_event_controller.open_dialogue(&"furnace")
	var choices: Array = flow.night_event_controller.options
	flow.night_event_controller._on_choice_selected(choices.size() - 1)
	tutorial._update_objectives()
	check(tutorial.ready_to_advance, "Night blessing and visitor lesson completes")
	tutorial._reset_practice()
	await settle()
	check(not tutorial.ready_to_advance and flow.progression_state.menu_non_drink_ids.size() == 2 and flow.get_owned_blessing_ids().is_empty(), "Night retry restores uncompleted blessing and information objectives")
	check(flow.night_event_controller.npcs.size() == 1, "Night retry replaces rather than duplicates visitor")
	tutorial._skip_to_next()
	check(tutorial.step == tutorial.BOSS and not tutorial.ready_to_advance, "Twelfth lesson introduces bosses")
	for page in range(3): tutorial._next_info_page()
	check(tutorial.ready_to_advance, "Boss introduction completes after all explanation pages")
	if OS.get_cmdline_user_args().has("--capture"):
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://_artifact_work/tutorial"))
		root.content_scale_size = Vector2i(1920, 1080)
		root.size = Vector2i(1280, 720)
		for lesson in range(tutorial.TITLES.size()):
			tutorial.step = lesson
			tutorial._reset_practice()
			await settle()
			check_lesson_layout()
			if lesson == tutorial.SKILLS:
				check(not Rect2(flow.run_status_hud.magic_panel.position, flow.run_status_hud.magic_panel.size).intersects(tutorial.panel.get_global_rect()), "Skill lesson magic meter clears instruction panel")
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://_artifact_work/tutorial/lesson_%d.png" % (lesson + 1))
			if lesson == 0:
				var cut_station: Node = main.get_node("TestCooker")
				hold(Items.VEG_LEAF_ID)
				cut_station.receive_item_from_player(actor)
				for press in range(30): cut_station.interact_with_player(actor)
				await settle()
				await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_png("res://_artifact_work/tutorial/finished_cut.png")
			if lesson == 1:
				await accept_order()
				await settle()
				await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_png("res://_artifact_work/tutorial/service_after_accept.png")
			if lesson in [4, 5]:
				await accept_order()
				await settle()
				await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_png("res://_artifact_work/tutorial/patience_%d.png" % (lesson + 1))
			if lesson == tutorial.FORAGE:
				actor.global_position = tutorial.forage.global_position + Vector2(0, 80)
				tutorial.forage.forage_item_ids.append(Items.MEAT_WHITE_ID)
				tutorial.forage.interact_with_player(actor)
				tutorial.forage.process_hold_interaction(actor, 4.0)
				await settle()
				await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_png("res://_artifact_work/tutorial/forage_options.png")
	else:
		for lesson in range(tutorial.TITLES.size()):
			tutorial.step = lesson
			tutorial._reset_practice()
			await settle()
			check_lesson_layout()
	tutorial._leave()
	await settle()
	check(current_scene.cards.size() == 12 and not has_meta("run_setup"), "Leaving tutorial returns to lesson selection")
	for chosen in range(12):
		current_scene._select(chosen)
		press_key(KEY_ENTER if chosen % 2 == 0 else KEY_SPACE)
		await settle()
		main = current_scene
		tutorial = main.get_node("TutorialController")
		actor = main.get_node("Player")
		check(tutorial.step == chosen, "Reentry opens independently selected lesson")
		check_lesson_layout()
		tutorial._leave()
		await settle()
	press_key(KEY_ESCAPE)
	await settle()
	check(current_scene.get_script() == load("res://Scripts/UI/GameStartController.gd"), "Escape safely returns from selector to title")
	current_scene._start_tutorial()
	await settle()
	press_key(KEY_K)
	await settle()
	check(current_scene.get_script() == load("res://Scripts/UI/GameStartController.gd"), "K safely returns from selector to title")
	current_scene._start_run()
	await settle()
	var normal_flow: Node = current_scene.get_node("LevelFlowController")
	check(not normal_flow.tutorial_mode and not current_scene.get_node("PrototypeMap").tutorial_mode, "A subsequent real run restores the full map and normal progression")
	check(normal_flow.progression_state.gold == 12 and normal_flow.progression_state.get_menu_non_drink_ids().size() == 2 and normal_flow.progression_state.get_owned_blessing_ids().is_empty(), "Teaching supplies and blessings never leak into a normal run")
	current_scene.queue_free()
	paused = false
	await process_frame
	print("TUTORIAL: %d failures; twelve lessons, selector, layouts, real patience/forage/drops/skill comparison/blessing/visitor" % errors.size())
	quit(0 if errors.is_empty() else 1)

