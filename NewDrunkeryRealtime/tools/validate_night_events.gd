extends SceneTree

const State = preload("res://Scripts/Core/RunProgressionState.gd")
const Context = preload("res://Scripts/Core/LevelContext.gd")
const InputAdapter = preload("res://Scripts/Core/LevelFlowInputAdapter.gd")
const Items = preload("res://Scripts/Kitchen/TestItemDefs.gd")
var failures: Array[String] = []
var flow: Node
var events_controller: Node

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error(message)

func settle() -> void:
	for index in range(6):
		await process_frame

func stage_event(id: StringName, day: int = 1) -> void:
	flow.progression_state.day_index = day
	flow.progression_state.events.night_index = day
	flow.progression_state.events.event_id = id
	flow.progression_state.events.resolved = false
	flow.progression_state.modifiers.resolved_global_day = day
	flow._enter_night_rest()
	events_controller.spawned_night = -1
	events_controller.refresh_night()
	flow.input_release_guard_active = false
	flow.overlay_controller.set_transition_visible(false)
	paused = false

func select_option(id: StringName) -> void:
	for index in range(events_controller.options.size()):
		if events_controller.options[index].id == id:
			events_controller._on_choice_selected(index)
			return
	check(false, "Missing dialogue choice: %s" % id)

func run() -> void:
	var state := State.new()
	state.reset(1000, 1, 852)
	var picked: Array[StringName] = []
	for day in range(1, 5):
		state.events.ensure_night(day, 852)
		var id: StringName = state.events.event_id
		check(id not in picked, "First four completed events do not repeat")
		picked.append(id)
		state.events.ensure_night(day, 321)
		check(id == state.events.event_id, "Reopening retains event content")
		state.events.complete(&"test", "test")
	state.events.ensure_night(0, 852)
	check(state.events.event_id == &"", "No event before day one service")
	state.day_index = 2
	state.create_next_non_drink_offer()
	var old := state.pending_menu_offer_ids.duplicate()
	check(state.refresh_menu_offer(), "Normal menu offers can be refreshed")
	check(state.menu_refreshes == 2 and state.pending_menu_offer_ids != old, "Menu refresh costs one shared charge and changes candidates")
	var snapshot := state.get_snapshot()
	var restored := State.new()
	restored.reset(0)
	restored.apply_snapshot(snapshot)
	check(restored.menu_refreshes == 2 and restored.pending_menu_offer_ids == state.pending_menu_offer_ids, "Offers and global refresh budget survive snapshots")
	check(restored.events.snapshot() == state.events.snapshot(), "Event history and modifiers survive snapshots")
	state._clear_pending_menu_offer()
	check(not state.refresh_menu_offer() and state.menu_refreshes == 2, "Viewing the menu cannot spend a refresh")
	var drinks_state := State.new()
	drinks_state.reset(0, 1, 99)
	check(drinks_state.create_event_menu_offer(Items.DRINK_OASIS_WINE_ID, &"higher"), "Engraver can replace a drink within its own category")
	var paid_snapshot := drinks_state.get_snapshot()
	restored.apply_snapshot(paid_snapshot)
	check(restored.pending_menu_offer_ids == drinks_state.pending_menu_offer_ids and restored.event_menu_target == Items.DRINK_OASIS_WINE_ID, "A paid target and its fixed choices survive restoring state")
	check(restored.choose_menu_offer(0), "Restored paid replacement remains usable")
	var replaced_snapshot := restored.get_snapshot()
	drinks_state.apply_snapshot(replaced_snapshot)
	check(not drinks_state.has_menu_dish(Items.DRINK_OASIS_WINE_ID), "Snapshot defaults never resurrect an intentionally replaced starting drink")
	for long_term: bool in [false, true]:
		state.events.investment.clear()
		check(state.events.begin_investment(101, long_term, 1), "Investment principal can be recorded once on night one")
		var due_day := 4 if long_term else 3
		check(not state.events.investment_due(due_day - 1) and state.events.collect_investment(due_day - 1) == 0, "Principal cannot be claimed before maturity")
		check(state.events.collect_investment(due_day) == roundi(101 * (3.0 if long_term else 1.5)), "Investment returns total principal times the agreed factor")
		check(state.events.collect_investment(due_day) == 0, "Repayment cannot be duplicated")

	root.size = Vector2i(1920, 1080)
	var main: Node = load("res://Scenes/Main/main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	await settle()
	flow = main.get_node("LevelFlowController")
	events_controller = flow.night_event_controller
	if flow.progression_state.events.INITIAL_NIGHT_PLAYTEST:
		await validate_initial_playtest()
		await validate_event_presence()
	stage_event(&"furnace")
	await settle()
	check(is_instance_valid(events_controller.host_facility), "Furnace spirit has a roast station host")
	check(events_controller.npc.global_position.distance_to(events_controller.host_facility.global_position) < 300, "Furnace spirit appears beside a roast station")
	flow.player.pick_up_item(Items.PLATE_ID, Items.get_item_texture(Items.PLATE_ID))
	flow.player.interaction_controller._set_current_interaction_target(events_controller.npc)
	flow.player.interaction_controller.handle_pickup_drop(Vector2.UP)
	check(flow.player.get_held_item_id() == Items.PLATE_ID, "Actual J interaction opens dialogue without consuming the held plate")
	flow.player.clear_held_item()
	check(paused and flow._get_state() == Context.LevelState.NIGHT_EVENT, "Dialogue uses a dedicated paused flow state")
	if OS.get_cmdline_user_args().has("--capture"):
		await settle()
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://_artifact_work/night_event_dialogue.png")
	select_option(&"core")
	check(is_equal_approx(flow.progression_state.events.roast_speed, 1.3), "Furnace core boosts roasting")
	check(is_equal_approx(flow.progression_state.events.burn_speed, 1.5), "Only the explicit risky event shortens burn tolerance")
	select_option(&"done")
	check(flow.progression_state.events.resolved, "Completed event persists")
	var furnace_count: int = flow.progression_state.events.history.size()
	events_controller.refresh_night()
	check(not events_controller.npc.visible and flow.progression_state.events.history.size() == furnace_count, "Completed NPC cannot award twice")
	var roast: Node = main.get_node("BakeCooker")
	roast.has_item = true
	roast.item_id = Items.MEAT_RED_ID
	roast.item_process_state = roast.output_process_state
	roast.processing_active = false
	roast.overcook_progress = 0
	roast._advance_overcook(1)
	check(is_equal_approx(roast.overcook_progress, roast._get_required_overcook_progress() * 1.5 / roast.overcook_duration), "Actual overcook update receives only the event burn multiplier")

	stage_event(&"porcelain", 2)
	await settle()
	var sink: Node = events_controller.host_facility
	var initial_plates: int = sink.clean_plates
	events_controller.open_dialogue()
	if OS.get_cmdline_user_args().has("--capture"):
		await settle()
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://_artifact_work/night_porcelain_dialogue.png")
	select_option(&"buy")
	check(sink.clean_plates == initial_plates + 1 and sink.event_plate_bonus == 1, "Buying adds one physical clean plate")
	select_option(&"done")
	var plate_count: int = sink.clean_plates
	events_controller.refresh_night()
	check(sink.clean_plates == plate_count, "Refreshing scene presence cannot duplicate plates")
	sink.reset_state()
	check(sink.clean_plates == sink.STARTING_PLATES + 1, "Phase resets keep purchased plate capacity")
	stage_event(&"porcelain", 3)
	events_controller.open_dialogue()
	select_option(&"sell")
	check(sink.event_plate_bonus == 0 and sink.clean_plates == sink.STARTING_PLATES, "Selling removes exactly one plate")
	select_option(&"done")
	check(is_equal_approx(flow.progression_state.events.wash_speed, 1.0), "Opposite cleaning trades multiply consistently")

	stage_event(&"engraver", 4)
	flow.progression_state.gold = 1000
	flow.progression_state._clear_pending_menu_offer()
	events_controller.open_dialogue()
	if OS.get_cmdline_user_args().has("--capture"):
		await settle()
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://_artifact_work/night_engraver_dialogue.png")
	select_option(&"same")
	check(flow.progression_state.gold == 1000, "Browsing original recipes is free")
	var target := StringName(events_controller.options[0].id)
	select_option(target)
	check(flow.progression_state.gold == 940, "Engraver charges before showing new recipes")
	check(flow._get_state() == Context.LevelState.MENU_DISH_SELECT and flow.menu_update_is_mandatory, "Paid replacement reuses the mandatory recipe selector")
	check(not flow.progression_state.refresh_menu_offer(), "Paid engraver offer cannot be rerolled")
	if OS.get_cmdline_user_args().has("--capture"):
		await settle()
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://_artifact_work/night_engraver_menu.png")
	var paid_offers: Array = flow.progression_state.pending_menu_offer_ids.duplicate()
	flow._handle_flow_input_action(InputAdapter.Action.CANCEL)
	check(flow._get_state() == Context.LevelState.MENU_DISH_SELECT, "Paid choice cannot be cancelled after entry")
	flow._enter_order_group_select()
	check(flow._get_state() == Context.LevelState.MENU_DISH_SELECT and flow.progression_state.pending_menu_offer_ids == paid_offers, "Starting service cannot bypass a paid choice or reroll candidates")
	var new_dish: StringName = paid_offers[0]
	check(Items.get_item_category(target) == Items.get_item_category(new_dish), "Replacement retains the dish category")
	flow.menu_dish_select_controller.focused_column = 0
	flow.menu_dish_select_controller.offer_selection_index = 0
	flow.menu_dish_select_controller.last_confirm_frame = -1
	flow._confirm_selected_menu_dish()
	check(flow.progression_state.has_menu_dish(new_dish) and not flow.progression_state.has_menu_dish(target), "Paid selection replaces the specified dish without adding a slot")
	check(flow.progression_state.events.resolved and flow._get_state() == Context.LevelState.NIGHT_EVENT, "Exchange finishes through NPC result dialogue")
	select_option(&"done")

	stage_event(&"gambler", 5)
	flow.progression_state.events.daily_charm = false
	events_controller.open_dialogue()
	if OS.get_cmdline_user_args().has("--capture"):
		await settle()
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://_artifact_work/night_gambler_dialogue.png")
	select_option(&"wager")
	select_option(&"done")
	flow.progression_state.events.record_income(5, 100)
	check(flow.progression_state.events.settle_wager(5) == 150 and flow.progression_state.events.daily_charm, "Successful wager grants coins and permanent daily charm")
	check(flow.progression_state.events.settle_wager(5) == 0, "Wager settles at most once")
	var events = flow.progression_state.events
	events.begin_wager(6)
	events.record_income(6, 111)
	check(events.on_customer_expired(6, "customer-a"), "Charm covers first ordinary customer")
	check(events.on_customer_expired(6, "customer-a"), "All outstanding orders of that customer share charm coverage")
	check(not events.on_customer_expired(6, "customer-b"), "Second customer receives no daily protection")
	check(events.settle_wager(6) == -56, "Protected customer still loses the no-expiration wager")
	check(events.on_customer_expired(7, "customer-c"), "Daily charm resets on the next day")
	# Real order-manager signals must distinguish new visitors to the same slot.
	flow.progression_state.day_index = 6
	events.charm_used_day = -1
	events.begin_wager(6)
	flow.run_context.state = Context.LevelState.WAVE_ACTIVE
	flow.run_context.selected_order_group = {"boss_special_guest": true}
	flow.run_context.reputation = 100
	flow.order_manager.clear_orders()
	var order_defs = preload("res://Scripts/Orders/OrderGroupDefs.gd")
	var first: Dictionary = order_defs._order("event-first", 1, Items.DISH_RED_ROLL_ID, 0)
	var extra: Dictionary = order_defs._order("event-extra", 1, Items.DISH_CRISP_PLATE_ID, 0)
	first.reputation_penalty = 10
	extra.reputation_penalty = 10
	flow.order_manager.add_orders([first, extra])
	flow.order_manager._expire_customer("slot:1")
	check(flow.run_context.reputation == 100, "Actual multi-dish expiration is fully covered once")
	var next: Dictionary = order_defs._order("event-next", 1, Items.DISH_RED_ROLL_ID, 0)
	next.reputation_penalty = 10
	flow.order_manager.add_orders([next])
	flow.order_manager._expire_customer("slot:1")
	check(flow.run_context.reputation == 90, "A later visitor to the protected window still loses reputation")
	flow._on_special_guest_penalty_tick(2)
	check(flow.run_context.reputation == 88, "Special guest pressure is never covered by the charm")
	flow._apply_served_dish_rewards({"gold_reward": 80, "xp_reward": 0})
	check(int(events.wager.income) == 80, "Actual dish reward application records wager income")
	check(events.settle_wager(6) == -40, "Real customer expirations trigger the wager's income loss")

	stage_event(&"furnace", 3)
	flow.progression_state.events.begin_investment(100, false, 1)
	events_controller.refresh_night()
	check(events_controller.active_id == &"repayment", "Matured merchant appears inside tavern before optional events")
	events_controller.open_dialogue()
	check(not events_controller.options.any(func(option: Dictionary) -> bool: return option.id == &"decline"), "Mandatory repayment cannot be declined")
	events_controller.close_dialogue()
	flow._enter_order_group_select()
	check(flow._get_state() == Context.LevelState.NIGHT_REST, "Unclaimed repayment blocks opening the next day")
	events_controller.open_dialogue()
	var before: int = flow.progression_state.gold
	select_option(&"collect")
	check(flow.progression_state.gold == before + 150, "Mandatory merchant pays principal and interest through dialogue")
	select_option(&"done")
	check(not events_controller.blocks_next_day(), "Collecting repayment unlocks the next day")
	check(events_controller.active_id == &"furnace", "Repayment does not consume the night's optional event")

	main.free()
	await process_frame
	print("NIGHT EVENTS VALIDATION: %s" % ("PASS" if failures.is_empty() else str(failures)))
	quit(0 if failures.is_empty() else 1)

func validate_event_presence() -> void:
	flow.input_release_guard_active = false
	flow.overlay_controller.set_transition_visible(false)
	var events = flow.progression_state.events
	var visitor: StaticBody2D = events_controller.npcs[&"engraver"]
	await physics_frame
	check(visitor.collision_layer == (4 | 16), "Visible NPC blocks player and loose-item physics")
	var placement = preload("res://Scripts/Player/FacilityPlacementQuery.gd")
	var feet: Rect2 = Rect2(visitor.global_position + Vector2(-8, 0), Vector2(16, 16))
	check(not placement._is_facility_placement_clear(flow.player, main_facility(), feet), "NPC footprint prevents placing a facility over it")
	var gold: int = flow.progression_state.gold
	visitor.interact_with_player(flow.player)
	events_controller.handle_action(InputAdapter.Action.CANCEL)
	check(visitor.visible and visitor.collision_layer != 0 and not events.is_complete(&"engraver"), "K closes dialogue while preserving NPC and event")
	visitor.interact_with_player(flow.player)
	var dialogue: CanvasLayer = events_controller.dialogue
	check(events_controller.options[2].id == &"lower" and dialogue.rows[2].disabled, "Starting menu cannot be downgraded")
	events_controller.handle_action(InputAdapter.Action.DOWN)
	check(dialogue.selected_index == 1, "Navigation reaches the next enabled offer")
	events_controller.handle_action(InputAdapter.Action.DOWN)
	check(dialogue.selected_index == 3, "One press skips disabled downgrade and reaches decline")
	events_controller.handle_action(InputAdapter.Action.UP)
	check(dialogue.selected_index == 1, "Reverse navigation also skips disabled downgrade")
	events_controller.handle_action(InputAdapter.Action.RIGHT)
	check(dialogue.selected_index == 3, "Horizontal navigation also skips disabled offers")
	events_controller.handle_action(InputAdapter.Action.DOWN)
	check(dialogue.selected_index == 0, "Enabled choices wrap from last to first")
	events_controller.handle_action(InputAdapter.Action.UP)
	check(dialogue.selected_index == 3, "Enabled choices wrap from first to last")
	events_controller.close_dialogue()
	flow.progression_state.gold = 0
	visitor.interact_with_player(flow.player)
	check(dialogue.selected_index == 3, "Opening dialogue selects the first enabled option when all trades are unaffordable")
	events_controller.handle_action(InputAdapter.Action.UP)
	check(dialogue.selected_index == 3, "Navigation skips several disabled offers and stays on the sole enabled choice")
	events_controller.close_dialogue()
	flow.progression_state.gold = gold
	visitor.interact_with_player(flow.player)
	select_option(&"same")
	check(events_controller.options.any(func(option: Dictionary) -> bool: return option.id == &"decline"), "Unpaid recipe choice can still be declined")
	select_option(&"decline")
	check(not visitor.visible and visitor.collision_layer == 0, "Declining removes NPC artwork and collision")
	check(events.is_complete(&"engraver") and flow.progression_state.gold == gold, "Declining consumes only the event, with no money or reward")
	await physics_frame
	check(placement._is_facility_placement_clear(flow.player, main_facility(), feet), "Declining immediately frees the NPC footprint for facilities")
	events_controller.refresh_night()
	check(not visitor.visible, "Declined NPC does not return when refreshing night")
	var restored = events.get_script().new()
	restored.restore(events.snapshot())
	check(restored.is_complete(&"engraver"), "Decline persists in run snapshots")
	check(events_controller.npcs[&"gambler"].visible, "Declining one event does not consume another")
	# Align two outsiders beyond the right screen edge to verify card packing.
	var rect: Rect2 = root.get_visible_rect()
	var outsiders: Array[StringName] = [&"gambler", &"porcelain"]
	var old_positions: Array[Vector2] = []
	for id: StringName in outsiders:
		var other: Node2D = events_controller.npcs[id]
		old_positions.append(other.global_position)
		other.global_position = other.get_canvas_transform().affine_inverse() * Vector2(rect.end.x + 600, rect.get_center().y) + Vector2(0, 48)
	events_controller.sync_presence()
	var first: Control = events_controller.indicators.cards[outsiders[0]]
	var second: Control = events_controller.indicators.cards[outsiders[1]]
	check(first.visible and second.visible and not first.get_rect().intersects(second.get_rect()), "Offscreen event cards remain separate on the same edge")
	for card: Control in [first, second]:
		check(rect.encloses(card.get_rect()) and card.get_node("Arrow").position.x > card.size.x, "Event card stays onscreen with an outward direction arrow")
	if OS.get_cmdline_user_args().has("--capture"):
		await settle()
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://_artifact_work/night_event_edge_prompts.png")
	var gambler: Node2D = events_controller.npcs[&"gambler"]
	gambler.global_position = gambler.get_canvas_transform().affine_inverse() * rect.get_center() + Vector2(0, 48)
	events_controller.sync_presence()
	check(not first.visible, "Event edge card hides once its NPC enters the screen")
	flow.run_context.state = Context.LevelState.WAVE_ACTIVE
	events_controller.sync_presence()
	check(not first.visible and not second.visible and gambler.collision_layer == 0, "Business hides event cards and disables NPC collisions")
	flow.run_context.state = Context.LevelState.NIGHT_REST
	for index in range(outsiders.size()):
		events_controller.npcs[outsiders[index]].global_position = old_positions[index]
	events.reset()
	events_controller.refresh_night()

func main_facility() -> Node2D:
	return current_scene.get_node("BakeCooker") as Node2D

func validate_initial_playtest() -> void:
	var events = flow.progression_state.events
	check(flow.progression_state.day_index == 0 and events_controller.npcs.size() == 4, "Initial night spawns all four event NPCs")
	flow.input_release_guard_active = false
	flow.overlay_controller.set_transition_visible(false)
	var positions: Array[Vector2] = []
	for id: StringName in events.FIRST_BATCH:
		var visitor: Node2D = events_controller.npcs[id]
		check(visitor.visible, "Initial event is available: %s" % id)
		check(visitor.collision_layer == (4 | 16), "Initial NPC has player and item collision")
		for point: Vector2 in positions:
			check(point.distance_to(visitor.global_position) >= 150.0, "Simultaneous event NPCs do not overlap")
		positions.append(visitor.global_position)
	var first: Dictionary = flow._build_order_group_for_current_menu(flow.order_groups[0])
	check(first.prepare_duration == 5.0 and first.service_duration == 90.0, "First day uses five seconds preparation and ninety seconds service")
	check(StringName(first.get("boss_enhanced_map_mechanism_id", &"")) == &"" and not bool(first.get("boss_special_guest", false)), "First day playtest has no Boss phase")
	var order_defs = preload("res://Scripts/Orders/OrderGroupDefs.gd")
	var patience_order: Dictionary = order_defs._order("patience-playtest", 1, Items.DISH_RED_ROLL_ID, 0)
	flow.progression_state.day_index = 0
	flow.run_context.state = Context.LevelState.WAVE_ACTIVE
	flow.order_manager.clear_orders()
	flow.order_manager.add_orders([patience_order])
	var patience_before: float = float(flow.order_manager.customers["slot:1"].order_take_time_remaining)
	flow.order_manager._process(1.0)
	var patience_after: float = float(flow.order_manager.customers["slot:1"].order_take_time_remaining)
	check(is_equal_approx(patience_before - patience_after, 2.0), "First-day patience test speed is two times normal")
	flow.order_manager.clear_orders()
	flow.progression_state.day_index = 1
	flow._refresh_order_groups_for_current_day()
	var second: Dictionary = flow._build_order_group_for_current_menu(flow.order_groups[0])
	check(second.get("prepare_duration", flow.prepare_phase_duration) == 60.0 and second.get("service_duration", flow.service_phase_duration) == 260.0, "Day two retains normal service durations")
	flow.progression_state.day_index = 0
	flow._refresh_order_groups_for_current_day()
	flow.progression_state.gold = 2000
	flow.run_context.state = Context.LevelState.NIGHT_REST
	events_controller.sync_presence()
	for id: StringName in events.FIRST_BATCH:
		var visitor: Node2D = events_controller.npcs[id]
		visitor.interact_with_player(flow.player)
		check(events_controller.active_id == id and flow._get_state() == Context.LevelState.NIGHT_EVENT, "Each NPC opens its own dialogue")
		match id:
			&"furnace":
				select_option(&"flame")
			&"engraver":
				select_option(&"same")
				select_option(StringName(events_controller.options[0].id))
				check(events_controller.blocks_next_day(), "Initial engraver blocks opening until paid selection is complete")
				flow.menu_dish_select_controller.focused_column = 0
				flow.menu_dish_select_controller.offer_selection_index = 0
				flow.menu_dish_select_controller.last_confirm_frame = -1
				flow._confirm_selected_menu_dish()
			&"porcelain":
				select_option(&"buy")
			&"gambler":
				select_option(&"wager")
		check(events.is_complete(id), "Each initial event completes independently: %s" % id)
		var completed_count: int = events.history.size()
		select_option(&"done")
		check(not visitor.visible, "Only the completed NPC disappears")
		visitor.interact_with_player(flow.player)
		check(events.history.size() == completed_count, "Completed NPC cannot award again")
		for other: StringName in events.FIRST_BATCH:
			check(events_controller.npcs[other].visible == not events.is_complete(other), "Remaining initial NPC availability is independent")
	check(int(events.wager.day) == 0, "Initial wager applies to first service")
	var restored_events = events.get_script().new()
	restored_events.restore(events.snapshot())
	for id: StringName in events.FIRST_BATCH:
		check(restored_events.is_complete(id), "Initial completions survive snapshots")
	# Reset shared rewards before the normal nightly event regressions below.
	events.reset()
	flow._enter_night_rest()
	flow.input_release_guard_active = false
	flow.overlay_controller.set_transition_visible(false)
	flow.run_context.state = Context.LevelState.WAVE_ACTIVE
	events_controller.sync_presence()
	for visitor: Node2D in events_controller.npcs.values():
		check(not visitor.visible, "Initial NPCs hide during business")
	flow.run_context.state = Context.LevelState.NIGHT_REST
