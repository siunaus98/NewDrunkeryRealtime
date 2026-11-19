extends SceneTree

const State = preload("res://Scripts/Core/RunProgressionState.gd")
const Defs = preload("res://Scripts/Progression/RunModifierDefs.gd")
const Context = preload("res://Scripts/Core/LevelContext.gd")
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error(message)

func settle() -> void:
	for index in range(6):
		await process_frame

func run() -> void:
	var state := State.new()
	state.reset(100, 0, 381)
	var modifiers = state.modifiers
	check(not modifiers.needs_global_choice(0), "No global contract before the first day")
	for day in range(7):
		modifiers.ensure_offers(day)
		check(modifiers.day_offers.size() == (1 if day in [0, 3, 6] else 3), "Fixed Boss days and introductory day; three difficulties on other days")
		var preserved: Array = modifiers.day_offers.duplicate(true)
		modifiers.ensure_offers(day)
		check(modifiers.day_offers == preserved, "Reopening does not reroll daily risks or rewards")
		if day == 0:
			continue
		check(modifiers.global_choices.size() == 3, "Each night offers three global buffs")
		var pair: Dictionary = modifiers.choose_global(1, day)
		check(not pair.is_empty() and pair.buff.tier == pair.debuff.tier, "Random cost matches the selected risk tier")
		check(pair.buff.key != pair.debuff.key, "A contract does not cancel its own buff")
		check(modifiers.choose_global(0, day).is_empty(), "Each night grants at most one contract")
		if day not in [3, 6]:
			check(modifiers.day_offers[1].reward != modifiers.day_offers[2].reward, "The two bonus days have distinct reward directions")
			check(modifiers.day_offers[1].tier < modifiers.day_offers[2].tier, "Hard difficulty always has stronger rewards and risk")
			modifiers.choose_day(2, day)
			var key := StringName(modifiers.selected_day.debuff.key)
			var global_value: float = modifiers.multiplier(key, day, false)
			check(is_equal_approx(modifiers.multiplier(key, day), global_value * float(modifiers.selected_day.debuff.multiplier)), "Daily and global modifiers combine")
			check(is_equal_approx(modifiers.multiplier(key, day + 1), global_value), "Daily risks expire across days")
			modifiers.settle_success(day)
			var forge_count: int = modifiers.pending_forges.size()
			modifiers.settle_success(day)
			check(modifiers.pending_forges.size() == forge_count, "Success rewards settle only once")
	var restored := State.new()
	restored.reset(0)
	var setup: Node = preload("res://Scripts/Core/RunSetupController.gd").new()
	root.add_child(setup)
	state.day_index = 6
	var snapshot: Dictionary = setup.build_progression_snapshot(null, 6, state, false)
	restored.apply_snapshot(snapshot)
	check(restored.modifiers.snapshot() == modifiers.snapshot(), "All contracts, offers and forge rewards survive the actual day snapshot")
	check(restored.modifiers.global_history.size() == 6, "Six night contracts persist")
	var reset_copy := State.new()
	reset_copy.reset(0)
	check(reset_copy.modifiers.global_history.is_empty() and reset_copy.modifiers.pending_forges.is_empty(), "A new run clears all contract effects and rewards")
	setup.queue_free()

	root.size = Vector2i(1920, 1080)
	var main: Node = load("res://Scenes/Main/main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	await settle()
	var flow: Node = main.get_node("LevelFlowController")
	flow.progression_state.day_index = 1
	flow.progression_state.modifiers.reset(945)
	flow.post_result_menu_update_step = 2
	check(flow._open_next_post_result_menu_update(), "After the menu, the flow opens the global choice")
	check(flow._get_state() == Context.LevelState.GLOBAL_MODIFIER_SELECT, "A dedicated flow state owns the choice")
	flow._handle_flow_input_action(preload("res://Scripts/Core/LevelFlowInputAdapter.gd").Action.CANCEL)
	check(flow._get_state() == Context.LevelState.GLOBAL_MODIFIER_SELECT, "An unresolved mandatory contract cannot be skipped")
	var selector: Node = flow.global_modifier_select_controller
	if OS.get_cmdline_user_args().has("--capture"):
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://_artifact_work/night_contract_offers.png")
	selector.handle_click(0)
	flow._confirm_global_modifier()
	check(selector.mode == &"reveal", "Confirmation reveals the cost before night preparation")
	await settle()
	if OS.get_cmdline_user_args().has("--capture"):
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://_artifact_work/night_contract_reveal.png")
	flow._confirm_global_modifier()
	check(flow._get_state() == Context.LevelState.NIGHT_REST, "Acknowledging the cost enters night preparation")
	flow._enter_order_group_select()
	await settle()
	check(flow.order_groups.size() == 3, "The assembly table offers three daily difficulties")
	if OS.get_cmdline_user_args().has("--capture"):
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://_artifact_work/night_difficulty.png")
	flow.order_group_select_controller.handle_click(2)
	flow._confirm_selected_group()
	flow.day_transition_active = false
	flow._enter_prepare_phase()
	var runtime_modifiers = flow.progression_state.modifiers
	# Fixed effects ensure these checks exercise real bonuses and costs rather
	# than accidentally verifying only neutral multipliers from a random offer.
	var runtime_snapshot: Dictionary = runtime_modifiers.snapshot()
	runtime_snapshot.global_history = [
		{"day_index": 1, "buff": Defs.effect(&"work", 2, true), "debuff": Defs.effect(&"patience", 2, false)},
		{"day_index": 2, "buff": Defs.effect(&"attack", 2, true), "debuff": Defs.effect(&"enemy_attack", 2, false)},
		{"day_index": 3, "buff": Defs.effect(&"move", 2, true), "debuff": Defs.effect(&"enemy_move", 2, false)},
		{"day_index": 4, "buff": Defs.effect(&"gold", 2, true), "debuff": Defs.effect(&"reputation", 2, false)}]
	runtime_modifiers.restore(runtime_snapshot)
	check(is_equal_approx(flow.player.get_work_progress_multiplier(), flow.player.skill_controller.get_work_progress_multiplier() * flow.get_run_modifier_multiplier(&"work")), "Actual manual work receives the run speed modifier")
	check(is_equal_approx(flow.player.get_station_cook_progress_multiplier(&"cut"), flow.player.get_cook_progress_multiplier()), "Cooking work uses the same modifier without applying it twice")
	var attack_before: int = flow.player.combat_controller.get_current_attack_damage()
	var move_before: float = flow.player.get_current_move_speed()
	runtime_modifiers.global_multipliers[&"attack"] *= 2
	runtime_modifiers.global_multipliers[&"move"] *= 2
	check(flow.player.combat_controller.get_current_attack_damage() == attack_before * 2, "Actual attacks use current run modifiers")
	check(is_equal_approx(flow.player.get_current_move_speed(), move_before * 2), "Actual movement uses current run modifiers")
	runtime_modifiers.restore(runtime_snapshot)
	var normal := preload("res://Scripts/Orders/OrderGroupDefs.gd")._order("modifier-test", 1, preload("res://Scripts/Kitchen/TestItemDefs.gd").DISH_RED_ROLL_ID, 0)
	flow.order_manager.add_orders([normal])
	var expected: float = float(normal.patience_duration) * flow.get_run_modifier_multiplier(&"patience")
	check(is_equal_approx(float(flow.order_manager.customers["slot:1"].patience_duration), expected), "Actual normal customers receive the patience modifier")
	flow.order_manager.clear_orders()
	var special: Array = preload("res://Scripts/Orders/OrderGroupDefs.gd").get_boss_special_orders(&"quicksand")
	flow.order_manager.add_orders(special)
	check(is_equal_approx(flow.order_manager.special_guest_patience_duration, 600.0), "Boss customer retains the independent patience clock")
	flow.order_manager.clear_orders()
	flow.run_context.state = Context.LevelState.WAVE_ACTIVE
	var previous_gold: int = flow.progression_state.gold
	var previous_total_xp: int = flow.progression_state.xp
	flow._apply_served_dish_rewards({"gold_reward": 100, "xp_reward": 0})
	check(flow.progression_state.gold - previous_gold == roundi(100 * flow.get_run_modifier_multiplier(&"gold")), "Actual serving rewards apply the selected bonuses")
	check(flow.progression_state.xp == previous_total_xp, "Zero rewards remain zero")
	var before_reputation: int = flow.run_context.reputation
	flow._on_special_guest_penalty_tick(3)
	check(before_reputation - flow.run_context.reputation == ceili(3 * flow.get_run_modifier_multiplier(&"reputation")), "Actual special guest penalties use reputation modifiers")
	# Exercise attack fields for every normal/elite enemy and all Bosses.
	for scene_path: String in ["chicken_enemy", "pig_enemy", "slam_enemy", "ranged_enemy", "bullet_hell_enemy", "bruiser_enemy", "sniper_enemy", "orbiter_enemy", "splitter_enemy", "sandworm_boss", "scorpion_boss", "vulture_boss", "monitor_boss"]:
		var enemy: Node = load("res://Scenes/Enemies/%s.tscn" % scene_path).instantiate()
		var speed: float = float(enemy.get("move_speed"))
		var damages: Dictionary = {}
		for property in enemy.get_property_list():
			if StringName(property.name) in [&"contact_damage", &"dash_damage", &"slam_damage", &"lingering_hazard_damage", &"projectile_damage", &"bullet_damage", &"skill_damage", &"bite_damage"]:
				damages[property.name] = int(enemy.get(property.name))
		Defs.apply_enemy(enemy, {&"enemy_move": 1.2, &"enemy_attack": 1.3})
		check(is_equal_approx(float(enemy.get("move_speed")), speed * 1.2), "%s receives movement modifiers" % scene_path)
		for property: String in damages:
			check(int(enemy.get(property)) == roundi(float(damages[property]) * 1.3), "%s %s receives damage modifiers" % [scene_path, property])
		enemy.free()
	# Free forge rewards use the normal player-choice UI and survive until claimed.
	flow._enter_night_rest()
	runtime_modifiers.pending_forges.assign([&"silver", &"gold", &"diamond"])
	var gold_before: int = flow.progression_state.gold
	flow._open_night_shop_overlay()
	for tier: StringName in [&"silver", &"gold", &"diamond"]:
		check(flow.night_shop_controller.pending_forge_tier == tier, "Free forge retains the promised quality")
		flow.night_shop_controller.confirm_forge_selection(0)
	check(runtime_modifiers.pending_forges.is_empty(), "Each reward forge is redeemed once")
	check(flow.progression_state.gold == gold_before, "Reward forges cost no gold")
	flow._close_night_shop_overlay()
	flow._open_global_modifier_overlay(true)
	await settle()
	check(flow.global_modifier_select_controller.mode == &"history", "Existing contracts can be reviewed at the assembly table")
	paused = false
	main.queue_free()
	await process_frame
	print("NIGHT MODIFIERS: %d failures; offers, tier matching, expiry, snapshots, flow, rewards, patience, enemies, forge redemption" % failures.size())
	quit(0 if failures.is_empty() else 1)
