extends SceneTree

var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error(message)

func stop_ticks(node: Node) -> void:
	node.set_process(false)
	node.set_physics_process(false)
	for child: Node in node.get_children():
		stop_ticks(child)

func run() -> void:
	var title: Node = load("res://Scenes/Main/game_start.tscn").instantiate()
	root.add_child(title)
	current_scene = title
	await process_frame
	check(title.current_mode == title.ScreenMode.TITLE, "Normal launch opens the title")
	title._show_prepare()
	title._start_run()
	for frame in range(5):
		await process_frame
	var main: Node = current_scene
	stop_ticks(main)
	paused = false
	var flow: Node = main.get_node("LevelFlowController")
	var actor: Node = main.get_node("Player")
	var state: RefCounted = flow.progression_state
	check(state.day_index == 0 and state.gold == 12 and state.level == 1 and state.xp == 0, "Fresh day one uses original gold and no bonus XP")
	check(state.get_owned_blessing_ids().is_empty() and state.blessing_points == 0, "Fresh run has no test blessings or free blessing points")
	check(actor.skill_controller.ultimate_energy == 0, "Title entry does not fill ultimate energy")
	check(not bool(main.run_setup.get("start_ultimate_full", true)), "Run setup has no full-ultimate override")
	check(state.events.PLAYTEST_BATCH == 0 and flow.night_event_controller._night_event_ids().is_empty(), "First night does not spawn all test NPCs")
	check(not flow.overlay_controller.debug_label.visible and not actor.show_item_push_debug and not actor.show_interaction_range, "Normal UI hides debug overlays")
	check(flow.get_patience_speed_playtest_multiplier() == 1.0, "Patience uses normal speed")
	check(flow.test_start_day_index == -1, "No forced test day")
	for day in range(7):
		state.day_index = day
		flow._refresh_order_groups_for_current_day()
		check(not flow.order_groups.is_empty(), "Day %d offers an order group" % (day + 1))
		if flow.order_groups.is_empty():
			continue
		var group: Dictionary = flow._build_order_group_for_current_menu(flow.order_groups[0])
		check(float(group.get("prepare_duration", flow.prepare_phase_duration)) == 60 and float(group.get("service_duration", flow.service_phase_duration)) == 260, "Day %d retains normal preparation and service times" % (day + 1))
		if day == 0:
			check(group.boss_enhanced_map_mechanism_id == &"", "Normal day one does not force a boss")
		if day == 3:
			check(group.boss_enhanced_map_mechanism_id == state.get_map_mechanism_order()[0], "Day four preserves the scheduled small boss")
		if day == 6:
			check(group.final_boss and group.boss_enhanced_map_mechanism_id == &"monitor", "Day seven preserves the final boss")
	state.day_index = 1
	flow.night_event_controller.refresh_night()
	await process_frame
	check(flow.night_event_controller._night_event_ids().size() == 1, "Following night uses a single normal random event")
	var item: Node = load("res://Scenes/Restaurant/loose_item.tscn").instantiate()
	main.add_child(item)
	check(not item.show_interaction_debug, "Loose items hide debug geometry by default")
	main.queue_free()
	await process_frame
	print("NORMAL DEMO ENTRY: %d failures; real title entry, resources, ultimate, events, timers, day-four/day-seven bosses and debug defaults" % failures.size())
	quit(0 if failures.is_empty() else 1)
