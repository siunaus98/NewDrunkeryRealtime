extends SceneTree

const Defs = preload("res://Scripts/Progression/NightEventDefs.gd")
const State = preload("res://Scripts/Progression/NightEventState.gd")
const Items = preload("res://Scripts/Kitchen/TestItemDefs.gd")
const Context = preload("res://Scripts/Core/LevelContext.gd")
const Orders = preload("res://Scripts/Orders/OrderGroupDefs.gd")
const Aid = preload("res://Scripts/Enemies/SandSpiritAid.gd")
const Adapter = preload("res://Scripts/Core/LevelFlowInputAdapter.gd")
const Blessings = preload("res://Scripts/Progression/BlessingDefs.gd")
var failures: Array[String] = []
var flow: Node
var controller: Node
var main: Node

class Victim extends Node2D:
	var damage_taken: int = 0
	var is_dead: bool = false
	func receive_hit(damage: int, _direction: Vector2) -> void:
		damage_taken += damage

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error(message)

func settle() -> void:
	for index in range(6):
		await process_frame

func stop_ticks(node: Node) -> void:
	node.set_process(false)
	node.set_physics_process(false)
	for child: Node in node.get_children():
		stop_ticks(child)

func stage(id: StringName, day: int = 1) -> void:
	paused = false
	flow.progression_state.day_index = day
	var events = flow.progression_state.events
	events.reset()
	events.night_index = day
	events.event_id = id
	flow.run_context.state = Context.LevelState.NIGHT_REST
	controller.spawned_night = -1
	controller.refresh_night()
	flow._sync_owned_blessings_to_player()
	flow.overlay_controller.set_transition_visible(false)
	flow.input_release_guard_active = false

func choose(id: StringName) -> void:
	for index in range(controller.options.size()):
		if controller.options[index].id == id:
			controller._on_choice_selected(index)
			return
	check(false, "Missing option %s" % id)

func capture(name: String) -> void:
	if OS.get_cmdline_user_args().has("--capture"):
		await settle()
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://_artifact_work/%s.png" % name)

func run() -> void:
	# Exercise the content pool over many seeds: no cancelling pairs or repeats,
	# one offer at each risk tier, and deterministic reopening.
	var found_drop: bool = false
	for seed_value in range(200):
		var choices: Array[Dictionary] = Defs.chaos_choices(seed_value)
		check(choices == Defs.chaos_choices(seed_value), "Chaos choices are stable for a run seed")
		var buffs: Dictionary = {}
		var debuffs: Dictionary = {}
		var tiers: Dictionary = {}
		for choice: Dictionary in choices:
			check(not buffs.has(choice.buff.key) and not debuffs.has(choice.debuff.key), "A night offers distinct buff and penalty axes")
			check(choice.buff.key != choice.debuff.key, "An offer cannot cancel its own benefit")
			check(not tiers.has(choice.tier), "The three choices cover three risk tiers")
			check(choice.debuff.key not in [&"service_duration", &"skill_frequency", &"patience"], "Rejected penalties cannot reappear")
			buffs[choice.buff.key] = true
			debuffs[choice.debuff.key] = true
			tiers[choice.tier] = true
			found_drop = found_drop or choice.buff.key == &"ordinary_drop"
	check(found_drop, "Ordinary ingredient drops are included in the benefit pool")
	var event_state := State.new()
	var sample := {"buff": {"key": &"work", "multiplier": 1.4}, "debuff": {"key": &"attack", "multiplier": 0.7}}
	event_state.apply_chaos(sample, 1)
	for day in [1, 2, 3]:
		check(is_equal_approx(event_state.get_event_multiplier(&"attack", day), 0.7), "Penalty applies during exactly the next three services")
	check(is_equal_approx(event_state.get_event_multiplier(&"attack", 4), 1.0), "Penalty expires on the fourth service")
	check(is_equal_approx(event_state.get_event_multiplier(&"work", 4), 1.4), "Permanent benefit remains after penalty expiry")
	check(is_equal_approx(event_state.get_event_multiplier(&"attack", 1, false), 1.0), "Service penalties do not apply at night")
	var restored := State.new()
	restored.restore(event_state.snapshot())
	check(restored.snapshot() == event_state.snapshot(), "Permanent bonuses and three-day penalties survive snapshots")

	root.size = Vector2i(1920, 1080)
	main = load("res://Scenes/Main/main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	await settle()
	flow = main.get_node("LevelFlowController")
	controller = flow.night_event_controller
	if State.SECOND_NIGHT_PLAYTEST:
		check(not String(ProjectSettings.get_setting("editor/run/main_run_args", "")).contains("--test-monitor"), "Default editor launch no longer forces final Boss and title return")
		for item_id: StringName in controller._get_event_ingredient_ids():
			check(flow.storage_manager.get_stock(item_id) == 30, "Event playtest begins with thirty portions per unlocked ingredient")
		check(flow.progression_state.level == 4 and flow.progression_state.get_blessing_points() == 3, "Event playtest supplies XP-driven levels and three normal blessing choices")
		check(flow.progression_state.get_owned_blessing_ids().size() == 2, "Devil blessing trades are available immediately in the playtest")
		check(controller.npcs.size() == 4, "Initial playtest spawns the four second-batch visitors")
		var positions: Array[Vector2] = []
		for id: StringName in State.SECOND_BATCH:
			var visitor: Node2D = controller.npcs[id]
			check(visitor.visible and visitor.collision_layer != 0, "Initial visitor is visible and solid: %s" % id)
			for point: Vector2 in positions:
				check(point.distance_to(visitor.global_position) >= 150, "Visitors do not overlap")
			positions.append(visitor.global_position)
	stop_ticks(main)
	for id: StringName in State.SECOND_BATCH:
		check(load("res://ArtResource/Events/%s.svg" % id) is Texture2D, "Event artwork exists: %s" % id)

	for id: StringName in [&"half", &"all"]:
		stage(&"merchant")
		flow.progression_state.gold = 101
		controller.open_dialogue()
		choose(id)
		var principal: int = 50 if id == &"half" else 101
		var due: int = 3 if id == &"half" else 4
		check(flow.progression_state.gold == 101 - principal, "Merchant charges only the agreed principal")
		check(flow.progression_state.events.investment.due_day == due, "Merchant retains the agreed return date")
		check(flow.progression_state.events.collect_investment(due - 1) == 0, "Investment cannot be collected early")
		check(flow.progression_state.events.collect_investment(due) == roundi(principal * (1.5 if id == &"half" else 3.0)), "Merchant repays the agreed total")
		check(flow.progression_state.events.collect_investment(due) == 0, "Repayment cannot be claimed twice")
		choose(&"done")
	stage(&"merchant")
	flow.progression_state.gold = 1
	check(not controller._can_choose(&"half") and controller._can_choose(&"all"), "A zero-coin half investment is disabled")

	for id: StringName in [&"health", &"blessing", &"blessings"]:
		stage(&"devil")
		flow.progression_state.owned_shop_blessings.clear()
		flow.progression_state.add_blessing(&"blessing_001")
		flow.progression_state.add_blessing(&"blessing_002")
		flow._sync_owned_blessings_to_player()
		flow.progression_state.gold = 0
		var health: int = flow.player.get_current_max_health()
		main._open_blessings_from_pause()
		main.codex_controller._close()
		var owned_before: Array[StringName] = flow.progression_state.get_owned_blessing_ids()
		controller.open_dialogue()
		choose(id)
		check(flow.progression_state.gold == {&"health": 100, &"blessing": 160, &"blessings": 280}[id], "Devil pays the reduced reward")
		if id == &"health":
			check(flow.player.get_current_max_health() == health - 20, "Health trade removes exactly 20 maximum health")
			flow._sync_owned_blessings_to_player()
			check(flow.player.get_current_max_health() == health - 20, "Restoring event health penalty is idempotent")
		else:
			var remaining: int = 1 if id == &"blessing" else 0
			check(flow.progression_state.get_owned_blessing_ids().size() == remaining, "Devil removes the agreed number of distinct blessings")
			check(flow.player.get_blessing_controller().owned.size() == remaining, "Removed blessings stop applying to the player")
			check(main.codex_controller.owned_blessing_ids.size() == remaining, "Previously viewed blessing list updates immediately after the trade")
			for blessing_id: StringName in owned_before:
				if blessing_id not in flow.progression_state.get_owned_blessing_ids():
					check(controller.dialogue.body_label.text.contains(Blessings.get_definition(blessing_id).title), "Trade result names every removed blessing")
			await capture("devil_removed_blessings")
			main._open_blessings_from_pause()
			var entries: Array = main.codex_controller._get_blessing_entries()
			check(entries.size() == maxi(remaining, 1), "Reopening owned blessings shows the reduced inventory")
			check(main.codex_controller.list_container.get_child_count() == maxi(remaining, 1), "Stale blessing buttons are removed immediately")
			await capture("devil_remaining_blessings")
			main.codex_controller._close()
		var gold: int = flow.progression_state.gold
		controller._on_choice_selected(0)
		check(flow.progression_state.gold == gold, "A completed event cannot pay twice")
		controller.close_dialogue()
	stage(&"devil")
	flow.progression_state.owned_shop_blessings.clear()
	check(not controller._can_choose(&"blessing") and not controller._can_choose(&"blessings"), "Missing blessings disable trades")
	for blessing_id: StringName in [&"blessing_001", &"blessing_002", &"blessing_003", &"blessing_004", &"blessing_005"]:
		flow.progression_state.add_blessing(blessing_id)
	flow._sync_owned_blessings_to_player()
	controller.open_dialogue()
	choose(&"blessings")
	check(main.codex_controller.owned_blessing_ids.size() == 3 and flow.player.get_blessing_controller().owned.size() == 3, "Trading two of five blessings preserves exactly the other three in runtime and UI")
	var snapshot: Dictionary = flow.progression_state.get_snapshot()
	flow.progression_state.apply_snapshot(snapshot)
	check(flow.progression_state.get_owned_blessing_ids().size() == 3 and main.codex_controller.owned_blessing_ids.size() == 3, "Snapshot restoration cannot resurrect traded blessings")
	controller.close_dialogue()

	var storage: Node = flow.storage_manager
	check_locked_event_stock()
	var boss_id: StringName = &""
	for item_id: StringName in Items.get_all_ingredient_ids():
		if Items.is_boss_ingredient(item_id):
			boss_id = item_id
			break
	for id: StringName in [&"patience", &"grind", &"aid"]:
		stage(&"sand_spirit")
		storage.clear_all()
		storage.add_stock(Items.TEST_ITEM_ID, 35)
		storage.add_stock(boss_id, 9)
		controller.open_dialogue()
		choose(id)
		var cost: int = {&"patience": 10, &"grind": 20, &"aid": 30}[id]
		check(storage.get_stock(Items.TEST_ITEM_ID) == 35 - cost, "Sand spirit charges the exact ordinary ingredient count")
		check(storage.get_stock(boss_id) == 9, "Sand spirit never removes Boss ingredients")
		if id == &"patience":
			check_patience_decay()
		elif id == &"grind":
			check_grind_yield()
		else:
			check(flow.progression_state.events.sand_spirit_aid, "Sand spirit aid persists for later services")
		controller.close_dialogue()
	storage.clear_all()
	check(not controller._can_choose(&"patience"), "Insufficient ordinary ingredients disable trades")
	check(not controller._consume_random_ordinary_ingredients(10), "Rejected sand trade cannot partially remove ingredients")

	stage(&"prankster")
	controller.open_dialogue()
	var fixed: Array = controller.options.duplicate(true)
	await capture("second_events_chaos")
	controller.close_dialogue()
	controller.open_dialogue()
	check(fixed == controller.options, "Closing chaos dialogue cannot reroll its offers")
	var chosen: Dictionary = controller.options[0].duplicate(true)
	choose(StringName(chosen.id))
	var events = flow.progression_state.events
	check(is_equal_approx(events.get_event_multiplier(chosen.buff.key, 1), chosen.buff.multiplier), "Chosen chaos benefit takes effect")
	check(is_equal_approx(events.get_event_multiplier(chosen.debuff.key, 3), chosen.debuff.multiplier), "Chosen penalty persists for the third service")
	check(is_equal_approx(events.get_event_multiplier(chosen.debuff.key, 4), 1.0), "Chosen penalty expires after three services")
	controller.close_dialogue()
	await check_aid_support()
	var battle: Node = flow.battle_manager
	check(battle._ordinary_drop_count(3, 1.0) == 3 and battle._ordinary_drop_count(3, 2.0) == 6, "Drop bonus preserves fixed base drops and supports guaranteed extra portions")
	var drops: int = 0
	battle.rng.seed = 195
	for index in range(10000):
		drops += battle._ordinary_drop_count(1, 1.4)
	check(drops > 13700 and drops < 14300, "Fractional ordinary drop bonuses follow their displayed expected yield")
	paused = false
	main.free()
	await process_frame
	if State.SECOND_NIGHT_PLAYTEST:
		await check_multiday_playtest()
	print("SECOND NIGHT EVENTS VALIDATION: %s" % ("PASS" if failures.is_empty() else str(failures)))
	quit(0 if failures.is_empty() else 1)

func check_patience_decay() -> void:
	flow.run_context.state = Context.LevelState.WAVE_ACTIVE
	var manager: Node = flow.order_manager
	manager.clear_orders()
	var order: Dictionary = Orders._order("sand-decay", 1, Items.DISH_RED_ROLL_ID, 0)
	manager.add_orders([order])
	var customer: Dictionary = manager.customers["slot:1"]
	var before: float = customer.order_take_time_remaining
	manager._process(1.0)
	check(is_equal_approx(before - float(customer.order_take_time_remaining), 0.85), "Sand benefit slows actual waiting patience without reducing the total")
	customer.accepted = true
	before = customer.time_remaining
	manager._process(1.0)
	check(is_equal_approx(before - float(customer.time_remaining), 0.85), "Sand benefit also slows actual accepted-order patience")
	manager.clear_orders()
	order.special_guest = true
	manager.add_orders([order])
	before = manager.customers["slot:1"].order_take_time_remaining
	manager._process(1.0)
	check(is_equal_approx(before - float(manager.customers["slot:1"].order_take_time_remaining), 1.0), "Special guest waiting timer remains independent")
	manager.clear_orders()
	flow.run_context.state = Context.LevelState.NIGHT_REST

func check_grind_yield() -> void:
	var station: Node = load("res://Scenes/Restaurant/grind_cooker.tscn").instantiate()
	main.add_child(station)
	stop_ticks(station)
	var player: Node = flow.player
	player.clear_held_item()
	player.pick_up_item(Items.TEST_ITEM_ID, null)
	check(station.receive_item_from_player(player), "New batch enters the grind station")
	station.process_progress = station.required_process_progress * station.stage_thresholds[0]
	station._update_stage_process_state()
	check(station.batch_servings == 6, "A new raw batch yields four plus two portions")
	check(station.take_item_to_player(player), "Coarse batch can be removed")
	check(player.get_held_item_payload().servings == 6, "Extra portions travel with the batch")
	for index in range(3):
		check(station.receive_item_from_player(player), "Existing box can return to the station")
		station.process_progress = station.required_process_progress
		station._update_stage_process_state()
		check(station.take_item_to_player(player), "Box can be removed after fine grinding")
		check(player.get_held_item_payload().servings == 6, "Reinsertion and fine grinding cannot farm more portions")
	player.clear_held_item()
	station.free()

func check_aid_support() -> void:
	var old_position: Vector2 = flow.player.global_position
	var map: Node = flow.level_refs.get_prototype_map()
	var battle_point: Vector2 = map.get_region_bounds(&"near").get_center()
	flow.player.global_position = battle_point
	var aid := Aid.new()
	main.add_child(aid)
	aid.set_process(false)
	aid.setup(flow.player)
	var victim := Victim.new()
	main.add_child(victim)
	victim.add_to_group("enemies")
	victim.global_position = battle_point + Vector2(200, 0)
	var second := Victim.new()
	main.add_child(second)
	second.add_to_group("enemies")
	second.global_position = victim.global_position + Vector2(60, 0)
	aid.cooldown_remaining = 0.0
	aid._process(0.01)
	check(aid.visible and aid.windup_remaining > 0 and victim.damage_taken == 0, "Sand spirit appears in battle and visibly channels before attacking")
	aid._process(1.0)
	check(victim.damage_taken == aid.attack_damage and second.damage_taken == aid.attack_damage, "Sand spirit strikes enemies in an area for its strengthened damage")
	check(aid.global_position.distance_to(flow.player.global_position) < 110, "Sand spirit stays beside the player when attacking")
	var camera: Camera2D = root.get_camera_2d()
	var old_camera_position: Vector2 = camera.global_position
	camera.global_position = battle_point
	camera.reset_smoothing()
	await capture("sand_spirit_support")
	camera.global_position = old_camera_position
	camera.reset_smoothing()
	aid._process(0.1)
	check(victim.damage_taken == aid.attack_damage, "Sand spirit attacks respect their cooldown")
	flow.player.global_position = map.get_kitchen_zone_bounds().get_center()
	aid.cooldown_remaining = 0.0
	aid._process(1.0)
	check(not aid.visible and aid.target == null, "Sand spirit disappears and cannot attack from the kitchen")
	flow.player.global_position = battle_point
	aid._process(0.01)
	check(aid.visible and aid.windup_remaining > 0, "Reentering battle restores the companion")
	victim.free()
	aid._process(1.0)
	check(aid.target == null, "A disappearing target safely cancels the channel")
	second.free()
	aid.free()
	flow.player.global_position = old_position

func check_locked_event_stock() -> void:
	var storage: Node = flow.storage_manager
	storage.clear_all()
	var locked: Node = null
	var unlocked: Node = null
	for cabinet: Node in get_nodes_in_group("storage_facilities"):
		if not cabinet.menu_item_enabled:
			locked = cabinet
		elif cabinet.is_ordinary_stock_event_source():
			unlocked = cabinet
	check(locked != null and unlocked != null, "Test scene has locked and unlocked cabinets")
	if locked == null or unlocked == null:
		return
	storage.add_stock(locked.stored_item_id, 35)
	storage.add_stock(unlocked.stored_item_id, 5)
	check(controller._get_ordinary_ingredient_total() == 5, "Hidden stock in locked stone cabinets is excluded from event totals")
	check(not controller._consume_random_ordinary_ingredients(10), "Locked stock cannot fund a trade")
	check(storage.get_stock(unlocked.stored_item_id) == 5 and storage.get_stock(locked.stored_item_id) == 35, "Rejected trades leave both inventories untouched")
	storage.add_stock(unlocked.stored_item_id, 25)
	check(controller._consume_random_ordinary_ingredients(30), "Unlocked stock can fund the whole trade")
	check(storage.get_stock(locked.stored_item_id) == 35, "Even repeated random deductions never touch a locked cabinet")
	var allowed: Array[StringName] = []
	allowed.assign(locked.menu_allowed_item_ids.keys())
	allowed.append(locked.stored_item_id)
	locked.set_menu_allowed_item_ids(allowed)
	check(controller._get_ordinary_ingredient_total() == 35, "Stock becomes eligible when its cabinet is unlocked")
	allowed.erase(locked.stored_item_id)
	locked.set_menu_allowed_item_ids(allowed)

func check_multiday_playtest() -> void:
	# Run both investment paths through real result snapshots and menu/night
	# transitions. No direct day_index writes: the production flow advances it.
	for plan: StringName in [&"half", &"all"]:
		main = load("res://Scenes/Main/main.tscn").instantiate()
		root.add_child(main)
		current_scene = main
		await settle()
		stop_ticks(main)
		flow = main.get_node("LevelFlowController")
		controller = flow.night_event_controller
		flow.input_release_guard_active = false
		paused = false
		controller.open_dialogue(&"merchant")
		choose(plan)
		choose(&"done")
		var payout: int = flow.progression_state.events.investment.payout
		var due: int = flow.progression_state.events.investment.due_day
		controller.open_dialogue(&"prankster")
		var selected: Dictionary = controller.options[0].duplicate(true)
		choose(StringName(selected.id))
		choose(&"done")
		for day in range(5):
			check(flow.progression_state.day_index == day, "Real settlement advances to the next day")
			if day == due:
				check(controller._night_event_ids() == [&"repayment"], "Matured merchant actually appears after short-service days")
				flow._enter_order_group_select()
				check(flow._get_state() == Context.LevelState.NIGHT_REST, "Repayment still blocks opening before collection")
				controller.open_dialogue(&"repayment")
				var gold: int = flow.progression_state.gold
				choose(&"collect")
				check(flow.progression_state.gold == gold + payout, "Matured merchant pays through the real multi-day flow")
				choose(&"done")
			if flow.progression_state.has_pending_skill_upgrade():
				flow._enter_blessing_select()
				check(flow.active_skill_upgrade_kind == (&"small" if day == 2 else &"big"), "Normal skill upgrade milestones remain available")
				flow._confirm_selected_skill_upgrade()
				check(not flow.progression_state.has_pending_skill_upgrade(), "Selecting a skill upgrade unlocks the next service")
			if flow.progression_state.modifiers.needs_global_choice(day):
				flow._open_global_modifier_overlay()
				flow.global_modifier_select_controller.move_selection(1)
				flow.global_modifier_select_controller.last_confirm_frame = -1
				flow._confirm_global_modifier()
				flow._close_global_modifier_overlay()
			flow._enter_order_group_select()
			check(flow._get_state() == Context.LevelState.ORDER_GROUP_SELECT, "Next day remains selectable after event tests (day=%d state=%d pending=%s global=%s)" % [day, flow._get_state(), flow.progression_state.pending_menu_offer_kind, flow.progression_state.modifiers.needs_global_choice(day)])
			flow.order_group_select_controller.last_confirm_frame = -1
			if flow.order_group_select_controller.get_active_group_index() < 0:
				flow.order_group_select_controller.move_selection(1)
			flow._confirm_selected_group()
			var group: Dictionary = flow.run_context.selected_order_group
			check(group.prepare_duration == 5.0 and group.service_duration == 20.0, "All first five event-test days have short service")
			check(not bool(group.get("boss_special_guest", false)) and group.boss_enhanced_map_mechanism_id == &"", "The fourth test day cannot get stuck waiting for Boss service")
			flow._update_day_transition(1.0)
			var actual: float = flow.progression_state.events.get_event_multiplier(selected.debuff.key, day)
			check(is_equal_approx(actual, selected.debuff.multiplier if day < 3 else 1.0), "Chaos penalty survives real day snapshots and expires after service three")
			flow._process(5.1)
			check(flow._get_state() == Context.LevelState.WAVE_ACTIVE, "Short preparation starts actual customer service")
			var level: int = flow.progression_state.level
			var xp: int = flow.progression_state.xp
			flow._apply_served_dish_rewards({"xp_reward": 60, "gold_reward": 20})
			check(flow.progression_state.level > level or flow.progression_state.xp > xp, "Serving during the test still grants XP and level-ups")
			flow._process(float(group.service_duration))
			check(flow._get_state() == Context.LevelState.LEVEL_SUCCESS, "Test service naturally completes on its timer")
			flow._handle_flow_input_action(Adapter.Action.CONFIRM)
			check(current_scene == main, "Actual settlement confirmation keeps the run instead of returning to title")
			for step in range(4):
				if not flow.progression_state.has_pending_menu_offer():
					break
				check(flow.progression_state.choose_menu_offer(0), "Daily menu progression remains usable")
				if not flow._open_next_post_result_menu_update():
					flow._enter_night_rest()
			if flow._get_state() == Context.LevelState.GLOBAL_MODIFIER_SELECT:
				flow.global_modifier_select_controller.move_selection(1)
				flow.global_modifier_select_controller.last_confirm_frame = -1
				flow._confirm_global_modifier()
				flow._close_global_modifier_overlay()
			check(flow._get_state() == Context.LevelState.NIGHT_REST, "Settlement returns to playable night preparation")
		main.free()
		paused = false
		await process_frame
