extends SceneTree

const Groups = preload("res://Scripts/Orders/OrderGroupDefs.gd")
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
	for child in node.get_children():
		stop_ticks(child)

func run() -> void:
	check(OS.get_cmdline_user_args().has("--test-monitor"), "Test must exercise actual command-line entry")
	check(not String(ProjectSettings.get_setting("editor/run/main_run_args", "")).contains("--test-monitor"), "Editor defaults do not force every run into the final Boss test")
	var main: Node = load("res://Scenes/Main/main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	await process_frame
	stop_ticks(main)
	paused = false
	var flow: Node = main.get_node("LevelFlowController")
	var battle: Node = main.get_node("BattleManager")
	flow.progression_state.day_index = 0
	var group: Dictionary = flow._build_order_group_for_current_menu(Groups.create_default_order_groups(0)[0])
	check(group.final_boss and group.boss_enhanced_map_mechanism_id == &"monitor" and group.prepare_duration == 8.0, "First day receives monitor and eight-second preparation")
	battle.reset_runtime_state()
	flow.run_context.selected_order_group = group
	flow._enter_prepare_phase()
	check(battle.boss_mechanism_id == &"monitor" and not battle.boss_spawned, "Prepare entry configures boss without spawning early")
	# Exercise the real preparation timer; do not invoke spawn_scheduled_boss directly.
	for frame in range(239):
		flow._process(1.0 / 60.0)
	check(not battle.boss_spawned, "No boss before halfway mark")
	for frame in range(3):
		flow._process(1.0 / 60.0)
	check(battle.boss_spawned and get_nodes_in_group("monitor_bosses").size() == 1, "Monitor automatically appears at four seconds during preparation")
	var boss: Node = get_first_node_in_group("monitor_bosses")
	if boss != null:
		stop_ticks(boss)
		check(boss.facility_tongue.pause_duration == 10, "Spawned boss uses latest ten-second repairable saliva skill")
	flow._process(0.5)
	check(get_nodes_in_group("monitor_bosses").size() == 1, "Repeated prepare ticks cannot duplicate boss")
	main.queue_free()
	await process_frame
	print("MONITOR PLAYTEST ENTRY: %d failures; editor args, first-day override, automatic four-second spawn and current saliva skill" % failures.size())
	quit(0 if failures.is_empty() else 1)
