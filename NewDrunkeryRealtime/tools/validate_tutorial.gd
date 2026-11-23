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
	check(actor.get_held_item_id() == id and actor.get_held_item_process_state() == Items.PROCESS_STATE_CUT, "Finished cut output returns to hand")

func check_lesson_layout() -> void:
	var expected: Dictionary = tutorial.LAYOUTS[tutorial.step]
	var map: Node = main.get_node("PrototypeMap")
	check(map.map_regions.size() == 1 and map.get_world_bounds().size == tutorial.MAP_SIZES[tutorial.step], "Lesson has its own compact map")
	for name: String in tutorial.facility_templates:
		check(is_instance_valid(main.get_node_or_null(name)) == expected.has(name), "Lesson %d only instantiates needed facility: %s" % [tutorial.step + 1, name])
	check(tutorial.lesson_nodes.size() == expected.size(), "Previous lesson facilities have been freed")
	for node: Node2D in tutorial.lesson_nodes:
		check(map.is_point_in_kitchen_zone(node.global_position), "Current facility lies inside lesson map")
		check(node.is_visible_in_tree(), "Required facility is visible: " + String(node.name))
	check(tutorial.lesson_body.text.split("\n").size() <= 2 and tutorial.lesson_body.text.length() < 180, "Only a short current-action instruction is shown")
	check(not is_instance_valid(main.get_node_or_null("StorageCabinetDesertBird")), "Unrelated ingredient cabinet removed")

func run() -> void:
	var title: Node = load("res://Scenes/Main/game_start.tscn").instantiate()
	root.add_child(title)
	current_scene = title
	await process_frame
	check(title.title_menu_buttons.size() == 4 and title.title_menu_buttons[2].text == "教学模式", "Title has keyboard-accessible tutorial entry")
	title.selected_title_menu_index = 2
	title._activate_selected_title_menu_item()
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
	check(main.get_node("PrototypeMap").get_world_bounds().size == Vector2(1024, 640), "Tutorial map is compact")
	check(not is_instance_valid(main.get_node_or_null("ForageRegionLeft")) and get_nodes_in_group("enemies").is_empty(), "No random region or combat waves in tutorial")
	check(not has_meta("run_setup"), "Tutorial entry setup is consumed and cannot contaminate next run")
	check_lesson_layout()
	tutorial.advance()
	check(tutorial.step == 0, "Incomplete lesson cannot advance")
	cut(Items.VEG_LEAF_ID)
	tutorial._update_objectives()
	var barrel: Node = main.get_node("FixedBarrelLeftA")
	hold(Items.VEG_LEAF_ID)
	check(barrel.receive_item_from_player(actor), "Tutorial barrel accepts raw sprout")
	barrel._advance_fill(5.0)
	check(barrel.take_item_to_player(actor), "Tutorial barrel yields actual wine")
	tutorial.advance()
	check(tutorial.step == 1, "Cut and barrel operations unlock roast lesson")
	check_lesson_layout()
	var roast: Node = main.get_node("BakeCooker")
	actor.global_position = roast.global_position + Vector2(0, 80)
	hold(Items.RICE_ID)
	check(roast.receive_item_from_player(actor), "Roaster accepts wheat")
	# Resolve authored cooking states through the station's own advancement.
	for index in range(500):
		if roast.item_process_state == Items.PROCESS_STATE_ROAST_WELL: break
		roast._process(.1)
	check(roast.take_item_to_player(actor), "Roasted wheat can be taken")
	tutorial._update_objectives()
	var grind: Node = main.get_node("GrindCooker")
	actor.global_position = grind.global_position + Vector2(0, 80)
	hold(Items.EGG_ID)
	check(grind.receive_item_from_player(actor), "Grinder accepts plum")
	for index in range(100): grind.process_hold_interaction(actor, .1)
	tutorial.advance()
	check(tutorial.step == 2, "Roast and grind unlock assembly")
	check_lesson_layout()
	var assembly: Node = main.get_node("AssemblyStation")
	for index in range(2):
		main.get_node("TestTable" if index == 0 else "TutorialPrepTable").take_item_to_player(actor)
		check(assembly.receive_item_from_player(actor), "Assembly receives actual cut sprout")
	check(assembly.interact_with_player(actor), "Actual combination creates cold plate")
	check(not assembly.can_take_item(actor), "Finished dish requires plate")
	main.get_node("PlateSink").rack.take_item_to_player(actor)
	check(assembly.take_item_to_player(actor), "Clean plate collects finished dish")
	tutorial.advance()
	check(tutorial.step == 3 and actor.get_held_item_id() == Items.DISH_CRISP_PLATE_ID, "Service lesson supplies its own plated dish")
	check_lesson_layout()
	var counter: Node = main.get_node("TestServingCounter")
	actor.global_position = counter.global_position + Vector2(0, 90)
	for index in range(8):
		counter.focused_slot_index = 0
		counter.process_hold_interaction(actor, .2)
		await process_frame
	check(not flow.order_manager.active_orders.is_empty(), "Actual counter accepts tutorial order")
	counter.focused_slot_index = 0
	check(counter.receive_item_from_player(actor), "Actual customer accepts plated cold dish")
	check(actor.get_held_item_id() == Items.DIRTY_PLATE_ID, "Serving returns dirty plate")
	var sink: Node = main.get_node("PlateSink")
	check(sink.receive_item_from_player(actor), "Dirty plate enters purification basin")
	actor.global_position = sink.to_global(sink.WASH_OFFSET) + Vector2(0, 90)
	for index in range(32):
		sink.process_hold_interaction(actor, .2)
		await process_frame
	tutorial.advance()
	check(tutorial.step == 4, "Acceptance, service and washing unlock income lesson")
	check_lesson_layout()
	check(flow.progression_state.gold > tutorial.baseline_gold, "Real service grants gold")
	check(int(tutorial.events.get(&"earned_gold", 0)) > 0 and int(tutorial.events.get(&"earned_xp", 0)) > 0, "Income lesson displays actual awarded gold and XP")
	var merchant: Node = main.get_node("NightMerchant")
	check(merchant.is_visible_in_tree() and merchant.is_pickup_drop_focusable(actor), "Merchant is visible and interactable in its own lesson")
	check(merchant.interact_with_player(actor), "Real merchant interaction opens shop")
	for index in range(4):
		flow.night_shop_controller.selected_shop_category_index = index
		tutorial._process(.016)
	flow._close_night_shop_overlay()
	tutorial.advance()
	check(tutorial.step == 5, "Visiting all shop categories unlocks forage")
	check_lesson_layout()
	var old_point: Node = tutorial.forage
	actor.global_position = old_point.global_position + Vector2(0, 80)
	old_point.interact_with_player(actor)
	old_point.process_hold_interaction(actor, 1.0)
	tutorial._reset_practice()
	check(tutorial.step == 5 and tutorial.forage != old_point and old_point.is_queued_for_deletion(), "Resetting an unfinished gathering task creates a fresh point without changing lesson")
	actor.global_position = tutorial.forage.global_position + Vector2(0, 80)
	tutorial.forage.interact_with_player(actor)
	tutorial.forage.process_hold_interaction(actor, 4.0)
	tutorial.forage._select_option(tutorial.forage.active_options[0])
	tutorial.advance()
	check(tutorial.step == 6, "Actual gathering unlocks combat")
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
	var drops := get_nodes_in_group("loose_items")
	check(not drops.is_empty(), "Defeated tutorial enemy spawns physical meat")
	if not drops.is_empty(): drops.back().take_item_to_player(actor)
	tutorial.advance()
	check(tutorial.step == 7, "Dash, kill and actual loot unlock skills")
	check_lesson_layout()
	check(actor.skill_controller.try_activate_small(), "Small skill uses actual magic and cooldown")
	check(actor.skill_controller.try_activate_big(), "Tutorial provision allows real ultimate activation")
	tutorial.advance()
	check(tutorial.step == 8, "Both skills unlock night lesson")
	check_lesson_layout()
	check(flow.progression_state.has_pending_menu_offer() and flow.get_blessing_points() > 0, "Night lesson supplies recipe choice and blessing point")
	check(flow.night_event_controller.npcs.has(&"furnace"), "Actual night visitor exists in tutorial")
	flow.handle_night_rest_interaction(&"task_book")
	flow._confirm_selected_menu_dish()
	check(flow.progression_state.menu_non_drink_ids.size() == 3, "Tutorial menu choice uses actual confirmation handler")
	flow._return_from_menu_overlay()
	flow.handle_night_rest_interaction(&"blessing_statue")
	flow._confirm_selected_blessing()
	flow.night_event_controller.open_dialogue(&"furnace")
	var choices: Array = flow.night_event_controller.options
	flow.night_event_controller._on_choice_selected(choices.size() - 1)
	tutorial._update_objectives()
	check(tutorial.ready_to_advance, "All nine lessons can finish through real systems")
	tutorial._reset_practice()
	await settle()
	check(not tutorial.ready_to_advance and flow.progression_state.menu_non_drink_ids.size() == 2 and flow.get_owned_blessing_ids().is_empty(), "Night retry restores uncompleted menu and blessing objectives")
	check(flow.night_event_controller.npcs.size() == 1, "Night retry replaces rather than duplicates visitor")
	if OS.get_cmdline_user_args().has("--capture"):
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://_artifact_work/tutorial"))
		root.content_scale_size = Vector2i(1920, 1080)
		root.size = Vector2i(1280, 720)
		for lesson in range(9):
			tutorial.step = lesson
			tutorial._reset_practice()
			await settle()
			check_lesson_layout()
			if lesson == 7:
				check(flow.run_status_hud.magic_panel.position.y > tutorial.panel.position.y + tutorial.panel.size.y, "Skill lesson magic meter clears instruction panel")
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://_artifact_work/tutorial/lesson_%d.png" % (lesson + 1))
	tutorial._leave()
	await settle()
	check(current_scene.get_script() == load("res://Scripts/UI/GameStartController.gd") and not has_meta("run_setup"), "Leaving tutorial returns to a fresh title")
	current_scene._start_run()
	await settle()
	var normal_flow: Node = current_scene.get_node("LevelFlowController")
	check(not normal_flow.tutorial_mode and not current_scene.get_node("PrototypeMap").tutorial_mode, "A subsequent real run restores the full map and normal progression")
	check(normal_flow.progression_state.gold == 12 and normal_flow.progression_state.get_menu_non_drink_ids().size() == 2 and normal_flow.progression_state.get_owned_blessing_ids().is_empty(), "Teaching supplies and blessings never leak into a normal run")
	current_scene.queue_free()
	paused = false
	await process_frame
	print("TUTORIAL: %d failures; nine lessons, real stations/orders/shop/forage/combat/skills/menu/blessing/visitor" % errors.size())
	quit(0 if errors.is_empty() else 1)

