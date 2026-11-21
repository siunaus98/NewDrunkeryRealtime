extends SceneTree

const Context = preload("res://Scripts/Core/LevelContext.gd")
const Items = preload("res://Scripts/Kitchen/TestItemDefs.gd")
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
	var main: Node = load("res://Scenes/Main/main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	await process_frame
	stop_ticks(main)
	paused = false
	var flow: Node = main.get_node("LevelFlowController")
	flow.input_release_guard_active = false
	flow.day_transition_active = false
	var actor: CharacterBody2D = main.get_node("Player")
	var combat: RefCounted = actor.combat_controller
	var no_blessings: Array[StringName] = []
	actor.set_owned_blessings_for_run(no_blessings)
	for day in range(7):
		flow.progression_state.day_index = day
		flow._refresh_order_groups_for_current_day()
		var group: Dictionary = flow._build_order_group_for_current_menu(flow.order_groups[0])
		var boss_day := StringName(group.get("boss_enhanced_map_mechanism_id", &"")) != &""
		check(float(group.get("service_duration", flow.service_phase_duration)) == (260.0 if boss_day else 180.0), "Day %d shortens only normal service" % (day + 1))
		check(float(group.get("prepare_duration", flow.prepare_phase_duration)) == 60, "Preparation remains 60 seconds")
	flow.progression_state.day_index = 0
	flow._refresh_order_groups_for_current_day()
	flow.run_context.initialize(flow._build_order_group_for_current_menu(flow.order_groups[0]))
	flow.run_context.state = Context.LevelState.WAVE_ACTIVE
	actor.global_position = Vector2(2400, 1400)
	var region: Node
	for node: Node in main.find_children("*", "Node", true, false):
		if node.get_script() == load("res://Scripts/Forage/ForageRegion.gd") and node.region_id == &"near":
			region = node
	check(region != null, "Near-region fixture exists")
	var point: Node2D = load("res://Scenes/Forage/forage_point.tscn").instantiate()
	region.add_child(point)
	point.global_position = actor.global_position + Vector2(80, 0)
	point.set_process(false)
	point.remove_after_attempt = true
	point.storage_manager = main.get_node("StorageManager")
	region.active_points.append(point)
	var completions: Array[bool] = []
	point.forage_finished.connect(func(_point: Node, success: bool) -> void: completions.append(success))
	point.forage_finished.connect(region._on_point_finished)
	var stock_before: int = point.storage_manager.get_stock(Items.VEG_LEAF_ID)
	for attempt in range(3):
		check(point.interact_with_player(actor), "Interrupted forage point can be restarted")
		point.process_hold_interaction(actor, 1.0)
		point._cancel_search()
		check(not point.is_queued_for_deletion() and region.active_points.has(point) and point.state == point.ForageState.IDLE and point.search_progress == 0, "Cancellation retains original region point and clears progress")
	check(completions.is_empty() and point.storage_manager.get_stock(Items.VEG_LEAF_ID) == stock_before, "Cancellation grants no resources and no completion signal")
	point.interact_with_player(actor)
	point._start_selection()
	actor.global_position += Vector2(500, 0)
	point._process(0.01)
	check(not point.is_queued_for_deletion() and point.state == point.ForageState.IDLE and point.active_options.is_empty(), "Leaving during choice cancels without consuming point")
	actor.global_position = point.global_position - Vector2(80, 0)
	point.interact_with_player(actor)
	actor.interaction_controller._set_current_interaction_target(point)
	combat.current_health = 10
	combat.bonus_health_regen = 5
	combat.health_regen_remainder = 0
	combat.dash_time_remaining = 0.1
	combat.is_attack_button_held = true
	var origin: Vector2 = actor.global_position
	check(actor.take_damage(1000, Vector2.RIGHT), "Fatal damage is applied")
	check(actor.is_downed() and combat.current_health == 0 and is_equal_approx(combat.downed_remaining, 10), "Fatal damage starts ten-second zero-health stun")
	Input.action_press("move_right")
	Input.action_press("primary_attack")
	Input.action_press("dash")
	Input.action_press("skill_big")
	actor._process(0)
	actor._physics_process(0.5)
	check(actor.global_position.is_equal_approx(origin) and not combat.is_dash_active() and not combat.is_attack_button_held, "Actual held inputs cannot move, charge or dash during downed stun")
	for action: StringName in [&"move_right", &"primary_attack", &"dash", &"skill_big"]:
		Input.action_release(action)
	check(not point.is_queued_for_deletion() and region.active_points.has(point) and point.state == point.ForageState.IDLE, "Fatal hit cancels forage but preserves point")
	check(not combat.is_attack_button_held and not combat.is_dash_active(), "Fatal hit cancels attack charge and dash")
	check(not combat.try_attack(Vector2.RIGHT, func(_p: Vector2) -> bool: return true) and not combat.try_dash(Vector2.RIGHT, Vector2.RIGHT), "Downed player cannot attack or dash")
	actor.fill_ultimate_energy()
	check(not actor.skill_controller.try_activate_small() and not actor.skill_controller.try_activate_big(), "Neither skill can bypass fatal stun")
	actor.heal_for_blessings(100)
	check(combat.current_health == 0, "Healing cannot bypass downed timer")
	check(not actor.take_damage(1000, Vector2.LEFT) and combat.downed_remaining == 10, "Further hits do not restart stun")
	actor.apply_contact_push(Vector2.RIGHT, 100)
	actor.apply_conveyor_motion(Vector2(100, 0))
	actor.apply_quicksand_spawn_pull(origin + Vector2(100, 0), 100)
	check(not actor.apply_wind_sand_jump(Vector2(100, 0)) and not actor.apply_storm_launch(Vector2.RIGHT, 300, 20, 2, null), "Downed body ignores hostile and wind-pad displacement")
	actor._physics_process(1.0)
	check(actor.global_position.is_equal_approx(origin), "Downed player remains at the same world position")
	actor._process(9.99)
	check(actor.is_downed() and combat.current_health == 0, "No early revival or passive regeneration")
	actor._process(0.02)
	check(not actor.is_downed() and combat.current_health == 1 and not combat.downed_label.visible and actor.global_position.is_equal_approx(origin), "Revives with exactly one health in place")
	check(not actor.take_damage(20), "Brief revival protection prevents immediate repeated knockdown")
	combat.tick_cooldowns(1.01)
	combat.bonus_health_regen = 0
	combat.current_health = 1
	check(actor.take_damage(1000) and actor.is_downed(), "Later fatal hit starts a fresh downed cycle")
	# Night reset must cancel a pending revival, not restore one health later.
	flow._enter_night_rest()
	check(not actor.is_downed() and combat.current_health == actor.get_current_max_health(), "Night fills health and cancels downed state")
	paused = false
	actor._process(12)
	check(combat.current_health == actor.get_current_max_health(), "Old revival timer cannot overwrite night healing")
	# Held dishes and their plate payload survive the stun; night reset has its
	# existing independent cleanup rules.
	actor.clear_held_item()
	actor.pick_up_item(Items.MEAT_RED_ID, Items.get_item_texture(Items.MEAT_RED_ID))
	combat.current_health = 1
	actor.take_damage(1000)
	actor._process(10)
	check(actor.get_held_item_id() == Items.MEAT_RED_ID and combat.current_health == 1, "Held ingredient survives knockdown and revival")
	actor.clear_held_item()
	combat.reset_temporary_state()
	# Existing once-per-day fatal protection resolves before knockdown.
	var blessing_defs = load("res://Scripts/Progression/BlessingDefs.gd")
	var survival: Array[StringName] = [blessing_defs.get_id_by_title("一线生机")]
	actor.set_owned_blessings_for_run(survival)
	actor.blessing_controller.begin_day()
	combat.current_health = 1
	actor.take_damage(1000)
	check(not actor.is_downed() and combat.current_health == 1 and actor.blessing_controller.daily_cheat_death_used, "Existing fatal-protection blessing keeps its once-per-day priority")
	actor.set_owned_blessings_for_run(no_blessings)
	point.interact_with_player(actor)
	point._start_selection()
	var selected: Dictionary = point.active_options[0].duplicate()
	var before_yield: int = point.storage_manager.get_stock(selected.item_id)
	point._select_option(selected)
	check(point.is_queued_for_deletion() and not region.active_points.has(point) and point.storage_manager.get_stock(selected.item_id) > before_yield, "Successful harvest still awards yield and consumes region point")
	main.queue_free()
	await process_frame
	print("DAY/DOWNED/FORAGE: %d failures; normal vs boss timing, interruption persistence, fatal stun, action locks, in-place revival, held items and nightly healing" % failures.size())
	quit(0 if failures.is_empty() else 1)
