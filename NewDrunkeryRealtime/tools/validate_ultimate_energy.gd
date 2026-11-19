extends SceneTree

const Items = preload("res://Scripts/Kitchen/TestItemDefs.gd")
const Energy = preload("res://Scripts/Player/UltimateEnergyRules.gd")
const Carry = preload("res://Scripts/Kitchen/CarryItemRules.gd")
const Context = preload("res://Scripts/Core/LevelContext.gd")
const Scarab = preload("res://Scripts/Enemies/ScarabEnemy.gd")
const BigSkillDefs = preload("res://Scripts/Player/BigSkillDefs.gd")
const MAIN = preload("res://Scenes/Main/main.tscn")
var failures: Array[String] = []
var main: Node
var player: CharacterBody2D
var teammate: CharacterBody2D
var flow: Node

func _initialize() -> void:
	call_deferred("_run")

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error(message)

func _stop_ticks(node: Node) -> void:
	node.set_process(false)
	node.set_physics_process(false)
	for child: Node in node.get_children():
		_stop_ticks(child)

func _hold(id: StringName, state: StringName = &"", payload: Dictionary = {}, actor: Node = null) -> void:
	if actor == null:
		actor = player
	actor.clear_held_item()
	_check(actor.pick_up_item(id, Items.get_item_texture(id), state, "", payload), "Fixture pickup must succeed.")

func _zero_energy() -> void:
	player.skill_controller.ultimate_energy = 0.0
	teammate.skill_controller.ultimate_energy = 0.0

func _expect_energy(actor: Node, expected: float, message: String) -> void:
	_check(is_equal_approx(actor.skill_controller.ultimate_energy, expected), message + " (actual %.3f, expected %.3f)" % [actor.skill_controller.ultimate_energy, expected])

func _test_skills() -> void:
	var skill: RefCounted = player.skill_controller
	_check(not skill.try_activate_big(), "A fresh run cannot activate the ultimate.")
	flow.run_context.state = Context.LevelState.NIGHT_REST
	skill.tick(120.0)
	Energy.award(player, &"wash")
	_expect_energy(player, 0, "Night time and night actions cannot charge the ultimate.")
	flow.run_context.state = Context.LevelState.PREPARE_PHASE
	skill.tick(300.0)
	_expect_energy(player, 150.0, "Passive energy contributes 150 points during a five-minute daytime window.")
	paused = true
	skill.tick(60.0)
	_expect_energy(player, 150.0, "Paused gameplay cannot charge energy.")
	paused = false
	skill.tick(500.0)
	_expect_energy(player, Energy.CAPACITY, "Passive fallback reaches full after 800 seconds.")
	flow.magic_current = 0
	player.storm_controller.stun_remaining = 3.0
	player.quicksand_processing_needs_release = true
	Input.action_press("interact")
	Input.action_press("skill_big")
	player._process(0.0)
	Input.action_release("skill_big")
	Input.action_release("interact")
	_check(skill.is_big_skill_buff_active(), "Ultimate input is reachable during existing control and held work.")
	_check(not player.is_control_immune() and player.storm_controller.blocks_actions() and player.is_quicksand_processing_blocked(), "Baseline ultimate does not cleanse or grant control immunity.")
	_check(flow.magic_current == 0 and not skill.try_activate_big(), "Ultimate costs no magic and cannot overlap itself.")
	_expect_energy(player, 0, "Ultimate activation consumes a full gauge.")
	_check(is_equal_approx(player.get_cook_progress_multiplier(), 2.0), "Ultimate doubles manual work speed.")
	var before: Vector2 = player.global_position
	player.apply_contact_push(Vector2.RIGHT, 50)
	player.apply_quicksand_pull(Vector2(100, 0))
	player.apply_quicksand_spawn_pull(before + Vector2(100, 0), 50)
	player.apply_storm_slow(main, 0.2)
	_check(not player.apply_storm_launch(Vector2.RIGHT, 100, 30, 2, null), "An existing storm stun still blocks a second storm launch.")
	_check(player.global_position != before and player.quicksand_pull_velocity != Vector2.ZERO and player.quicksand_spawn_motion != Vector2.ZERO and is_equal_approx(player.storm_controller.get_speed_multiplier(), 0.2), "Baseline ultimate leaves hostile pushes, pulls and slows active.")
	var health_before: int = player.combat_controller.current_health
	_check(player.take_damage(7, Vector2.RIGHT), "Ultimate is not damage invulnerability.")
	_check(player.combat_controller.current_health == health_before - 7, "Damage still reduces health during the ultimate.")
	player.clear_hostile_control()
	_check(player.apply_storm_launch(Vector2.RIGHT, 100, 30, 2, null), "Baseline ultimate permits a new hostile storm launch.")
	player.clear_hostile_control()
	_check(player.apply_wind_sand_jump(Vector2(10, 0)), "Intentional jump-pad movement is retained.")
	player.wind_jump_remaining = 0.0
	skill.tick(9.9)
	_check(skill.is_big_skill_buff_active(), "Baseline work boost remains active before ten seconds.")
	skill.tick(0.11)
	_check(not player.is_control_immune() and is_equal_approx(player.get_cook_progress_multiplier(), 1.0), "Baseline ultimate work boost ends after ten seconds.")
	flow.magic_current = 10
	_check(skill.try_activate_small(), "Small skill activates with sufficient magic.")
	_check(flow.magic_current == 8 and is_equal_approx(skill.get_move_speed_multiplier(), 1.4) and is_equal_approx(skill.get_small_skill_remaining(), 15.0), "Small skill costs two magic and grants 40 percent speed on a fifteen-second cooldown.")
	_check(is_equal_approx(player.get_cook_progress_multiplier(), 1.0), "Small skill no longer grants cooking speed.")
	skill.tick(2.0)
	_check(is_equal_approx(skill.get_move_speed_multiplier(), 1.0) and not skill.try_activate_small(), "Small movement buff lasts two seconds without resetting its cooldown.")
	skill.tick(13.0)
	_check(skill.try_activate_small(), "Small skill becomes ready at fifteen seconds.")
	skill.ultimate_energy = 37
	player.reset_temporary_state()
	_expect_energy(player, 37, "Day/night temporary reset preserves accumulated energy.")

func _test_processing() -> void:
	_zero_energy()
	var cut: Node = main.get_node("TestCooker")
	var grind: Node = main.get_node("GrindCooker")
	var roast: Node = main.get_node("BakeCooker")
	var table: Node = main.get_node("PrepTableA")
	var assembly: Node = main.get_node("AssemblyStation")
	_hold(Items.VEG_LEAF_ID)
	_check(cut.receive_item_from_player(player), "Raw item enters cutting station.")
	for i in range(cut.required_interact_presses):
		cut._advance_processing(0.0, player, true)
	_expect_energy(player, 5, "A completed cut grants one processing reward.")
	_check(bool(player.get_held_item_payload().get(Energy.PROCESS_REWARDED, false)), "Cut output owns its processing marker.")
	_check(table.receive_item_from_player(player), "Processed food can be staged on a table.")
	_hold(Items.PLATE_ID)
	_check(table.take_item_to_player(player) and assembly.interact_with_player(player), "Processed food transfers through plate and assembly.")
	player.clear_held_item()
	_check(assembly.take_item_to_player(player) and bool(player.get_held_item_payload().get(Energy.PROCESS_REWARDED, false)), "Assembly retrieval preserves the original processing marker.")
	var loose: Node = load("res://Scenes/Restaurant/loose_item.tscn").instantiate()
	main.add_child(loose)
	loose.setup_item(player.get_held_item_id(), player.get_held_item_texture(), player.get_held_item_process_state(), "", player.get_held_item_payload())
	player.clear_held_item()
	_check(loose.take_item_to_player(player) and bool(player.get_held_item_payload().get(Energy.PROCESS_REWARDED, false)), "Dropping and retrieving food preserves its processing marker.")
	_check(cut.receive_item_from_player(player) and cut.take_item_to_player(player), "Cut station can store a prepared ingredient.")
	_expect_energy(player, 5, "Picking stored food up again does not grant processing energy.")
	_hold(Items.SUN_SEED_ID)
	_check(grind.receive_item_from_player(player), "Raw seed enters grinder.")
	grind._advance_processing(grind.hold_process_duration * 0.6, teammate)
	_expect_energy(teammate, 5, "Coarse grind rewards the actual worker once.")
	_check(grind.take_item_to_player(player), "Another player can collect coarse seasoning.")
	_check(table.receive_item_from_player(player), "Coarse batch can be staged.")
	_hold(Items.PLATE_ID)
	_check(table.take_item_to_player(player), "A plate removes one seasoning portion.")
	var plate_payload: Dictionary = player.get_held_item_payload()
	_check(table.item_payload.get(Energy.PROCESS_REWARDED, false) and plate_payload.items[0].payload.get(Energy.PROCESS_REWARDED, false), "Both batch remainder and split portion inherit the reward marker.")
	var plate: Dictionary = plate_payload.duplicate(true)
	player.clear_held_item()
	_check(Carry.take_last_portion(player, Items.PLATE_ID, plate), "LIFO extraction recovers the portion with metadata.")
	_check(grind.receive_item_from_player(player), "Coarse portion may be refined.")
	grind._advance_processing(grind.hold_process_duration, player)
	_expect_energy(player, 5, "Refining a rewarded coarse portion grants no duplicate reward.")
	_expect_energy(teammate, 5, "Batch splitting does not duplicate the worker reward.")
	_check(int(player.get_held_item_payload().servings) == 1, "Reprocessing a split portion conserves servings.")
	for state_fraction: float in [0.4, 0.8, 1.0]:
		roast.reset_state()
		_hold(Items.MEAT_RED_ID)
		roast.receive_item_from_player(player)
		var actor_energy: float = player.skill_controller.ultimate_energy
		var collector_energy: float = teammate.skill_controller.ultimate_energy
		roast._advance_processing(roast.auto_process_duration * state_fraction, null)
		_expect_energy(player, actor_energy, "Automatic roast does not reward the depositor.")
		_hold(Items.EGG_ID)
		_check(not roast.take_item_to_player(player) and not bool(roast.item_payload.get(Energy.PROCESS_REWARDED, false)), "Rejected roast pickup must not consume the processing reward.")
		teammate.clear_held_item()
		_check(roast.take_item_to_player(teammate), "Cooked food can be collected at every doneness.")
		_expect_energy(teammate, collector_energy + 5, "Every roast doneness grants the collector the same reward.")
		_check(roast.receive_item_from_player(teammate), "A cooked ingredient can be put back on the grill.")
		roast._advance_processing(roast.auto_process_duration, null)
		_check(roast.take_item_to_player(teammate), "Reheated food remains collectible.")
		_expect_energy(teammate, collector_energy + 5, "Reheating a roast cannot grant another reward.")
	table.reset_state()
	assembly.reset_state()
	player.clear_held_item()
	teammate.clear_held_item()

func _test_work_speed() -> void:
	var cut: Node = main.get_node("TestCooker")
	var grind: Node = main.get_node("GrindCooker")
	var roast: Node = main.get_node("BakeCooker")
	player.skill_controller.add_energy(Energy.CAPACITY)
	_check(player.skill_controller.try_activate_big(), "Work-speed test activates the ultimate.")
	_hold(Items.VEG_LEAF_ID)
	cut.receive_item_from_player(player)
	for i in range(ceili(float(cut.required_interact_presses) / 2.0)):
		cut._advance_processing(0, player, true)
	_check(not cut.has_item and player.get_held_item_process_state() == Items.PROCESS_STATE_CUT, "Ultimate halves the number of cutting presses.")
	_hold(Items.SUN_SEED_ID)
	grind.receive_item_from_player(player)
	grind._advance_processing(grind.hold_process_duration / 2, player)
	_check(not grind.has_item, "Ultimate halves attended grind duration.")
	_hold(Items.MEAT_RED_ID)
	roast.receive_item_from_player(player)
	roast._advance_processing(roast.auto_process_duration * 0.25, null)
	_check(is_equal_approx(roast.process_progress, 25.0), "Ultimate leaves automatic roast timing unchanged.")
	roast.reset_state()
	player.clear_held_item()
	var sink: Node2D = main.get_node("PlateSink")
	sink.reset_state()
	sink.dirty_plates = 1
	player.global_position = sink.get_interaction_rect_global().get_center() + Vector2(0, 110)
	var energy_before: float = player.skill_controller.ultimate_energy
	_check(sink.process_hold_interaction(player, 2.5) and sink.dirty_plates == 0, "Ultimate halves attended washing to 2.5 seconds.")
	_expect_energy(player, energy_before + 3, "Completing a wash grants energy once per plate.")
	var manager: Node = main.get_node("OrderManager")
	manager.set_orders([{"order_id": "speed_order", "customer_id": "speed_guest", "target_slot": 1, "dish_item_id": Items.DISH_CRISP_PLATE_ID}])
	var customer: Dictionary = manager.customers["slot:1"]
	var duration: float = manager._get_take_action_duration(customer)
	manager.process_take_order_at_slot(1, duration * 0.25, player)
	_check(is_equal_approx(float(customer.order_take_action_progress), duration * 0.5), "Ultimate doubles held order-taking progress.")
	manager.process_take_order_at_slot(1, duration * 0.25, player)
	_check(manager.get_waiting_order_for_slot(1).is_empty(), "Order acceptance completes in half its normal duration.")
	var forage: Node = load("res://Scenes/Forage/forage_point.tscn").instantiate()
	main.add_child(forage)
	_stop_ticks(forage)
	forage.global_position = player.global_position
	forage._start_search(player)
	forage.process_hold_interaction(player, forage.search_duration * 0.25)
	_check(is_equal_approx(forage.search_progress, forage.search_duration * 0.5), "Ultimate doubles gathering search progress.")
	forage.process_hold_interaction(player, forage.search_duration * 0.25)
	_check(forage.state == forage.ForageState.SELECTING and is_equal_approx(forage.selection_remaining, forage.selection_duration), "Gathering search takes half the time without shortening its selection window.")
	forage.queue_free()
	player.reset_temporary_state()

func _test_instant_grind_stages() -> void:
	var grind: Node = main.get_node("GrindCooker")
	grind.reset_state()
	player.clear_held_item()
	player.skill_controller.set_big_variant(BigSkillDefs.INSTANT)
	player.skill_controller.ultimate_energy = Energy.CAPACITY
	_check(player.skill_controller.try_activate_big(), "Instant-work ultimate activates for the two-stage grind test.")
	_hold(Items.SUN_SEED_ID)
	_check(grind.receive_item_from_player(player), "Raw seed enters grinder for the instant-stage test.")
	_check(grind._advance_processing(0.0, player), "Instant coarse grind interaction succeeds.")
	_check(grind.has_item and grind.item_process_state == Items.PROCESS_STATE_GRIND_COARSE and is_equal_approx(grind.process_progress, grind.required_process_progress * 0.5), "Instant coarse grind stops at the coarse threshold.")
	_check(not grind.process_hold_interaction(player, 0.0), "Held input cannot immediately chain the free fine grind in the same press.")
	grind.instant_grind_requires_release = false
	_check(grind._advance_processing(0.0, player), "Free fine grind follow-up succeeds.")
	_check(not grind.has_item and player.get_held_item_id() == Items.SEASONING_BOX_ID, "Free fine grind completes the same ingredient without consuming another charge.")
	player.skill_controller.set_big_variant(BigSkillDefs.BASE)
	player.clear_held_item()

func _test_orders_and_economy() -> void:
	_zero_energy()
	var assembly: Node = main.get_node("AssemblyStation")
	assembly.reset_state()
	for i in range(2):
		_hold(Items.VEG_LEAF_ID, Items.PROCESS_STATE_CUT)
		assembly.receive_item_from_player(player)
	_check(assembly.interact_with_player(player), "Valid dish is assembled by its maker.")
	_expect_energy(player, 8, "Assembly energy is personal.")
	_expect_energy(teammate, 0, "Assembly does not credit teammates.")
	_check(not assembly.interact_with_player(player), "Completed dish cannot be assembled again for energy.")
	var manager: Node = main.get_node("OrderManager")
	manager.set_orders([
		{"order_id": "energy_a", "customer_id": "energy_guest", "target_slot": 1, "dish_item_id": Items.DISH_CRISP_PLATE_ID},
		{"order_id": "energy_b", "customer_id": "energy_guest", "target_slot": 1, "dish_item_id": Items.DISH_CRISP_PLATE_ID}
	])
	_check(manager.process_take_order_at_slot(1, 10.0, player), "Held order acceptance succeeds.")
	_expect_energy(player, 11, "Accepting a multi-dish customer rewards once.")
	_check(not manager.take_order_at_slot(1, player), "Accepted customer cannot be accepted twice.")
	_hold(Items.PLATE_ID)
	_check(assembly.take_item_to_player(player), "Dish can be plated for actual delivery.")
	var counter: Node = main.get_node("TestServingCounter")
	counter.focused_slot_index = 0
	_check(counter.receive_item_from_player(player), "Actual serving counter accepts the dish.")
	_expect_energy(player, 21, "Serving grants exactly one team share to the server.")
	_expect_energy(teammate, 10, "Serving grants the same energy to a teammate.")
	var barrel: Node = main.get_node("FixedBarrelLeftA")
	barrel.reset_state()
	_hold(StringName(Items.BARREL_INPUTS[Items.DRINK_QINGMEI_WINE_ID]))
	_check(barrel.receive_item_from_player(player), "Barrel consumes an actual raw ingredient.")
	_expect_energy(player, 23, "Barrel insertion gives a small energy reward.")
	_check(not barrel.receive_item_from_player(player), "Empty hand cannot repeatedly claim barrel energy.")
	var forage: Node = load("res://Scenes/Forage/forage_point.tscn").instantiate()
	main.add_child(forage)
	forage.active_player = player
	forage._select_option({"item_id": Items.VEG_LEAF_ID, "yield_amount": 3})
	_expect_energy(player, 29, "A completed gather rewards once regardless of yield.")
	forage.queue_free()

func _test_combat() -> void:
	_zero_energy()
	player.global_position = Vector2(10000, 10000)
	var enemy: Node2D = load("res://Scenes/Enemies/pig_enemy.tscn").instantiate()
	main.add_child(enemy)
	_stop_ticks(enemy)
	enemy.global_position = player.global_position + Vector2(70, -34)
	enemy.current_health = 1000
	var shape: Dictionary = {"direction": Vector2.RIGHT, "inner_radius": 0.0, "outer_radius": 200.0, "angle_degrees": 180.0}
	var any_zone: Callable = func(_point: Vector2) -> bool: return true
	player.combat_controller._apply_attack_hit(shape, any_zone, 0.0)
	_expect_energy(player, 1, "A light hit grants one energy.")
	player.combat_controller._apply_attack_hit(shape, any_zone, 1.0)
	_expect_energy(player, 5, "A landed heavy grants four times a light hit.")
	enemy.current_health = 1
	player.combat_controller._apply_attack_hit(shape, any_zone, 0.0)
	_expect_energy(player, 16, "Kill energy dominates the finishing hit reward.")
	player.combat_controller._apply_attack_hit(shape, any_zone, 0.0)
	_expect_energy(player, 16, "Dead targets cannot grant more energy.")
	var scarab: Node2D = Scarab.new()
	main.add_child(scarab)
	_stop_ticks(scarab)
	scarab.global_position = player.global_position + Vector2(70, -34)
	scarab.state = Scarab.State.ESCAPING
	player.combat_controller._apply_attack_hit(shape, any_zone, 1.0)
	_expect_energy(player, 16, "Invulnerable escaping scarab grants no hit or kill reward.")
	scarab.state = Scarab.State.SEARCHING
	player.combat_controller._apply_attack_hit(shape, any_zone, 1.0)
	_expect_energy(player, 30, "A killable scarab grants heavy-hit and kill energy.")

func _run() -> void:
	main = MAIN.instantiate()
	root.add_child(main)
	current_scene = main
	await process_frame
	paused = false
	_stop_ticks(main)
	player = main.get_node("Player")
	flow = main.get_node("LevelFlowController")
	var template: Node = MAIN.instantiate()
	teammate = template.get_node("Player")
	template.remove_child(teammate)
	template.free()
	teammate.name = "EnergyTeammate"
	main.add_child(teammate)
	_stop_ticks(teammate)
	teammate.global_position = Vector2(8000, 8000)
	_test_skills()
	_test_processing()
	_test_work_speed()
	_test_instant_grind_stages()
	_test_orders_and_economy()
	_test_combat()
	var hud: Node = main.get_node("RunStatusHud")
	hud.sync_skill_states(player)
	_check(hud.skill_slot_big.cost_label.text == "能量" and hud.skill_slot_big.cooldown_label.text == "7%", "Ultimate HUD displays the reduced energy percentage rather than a magic cost or cooldown.")
	main.queue_free()
	await process_frame
	if failures.is_empty():
		print("PASS: energy lifecycle, ten-second work ultimate without control immunity, once-only processing through containers, roast ownership, all attended work timing, team delivery, economy and combat attribution.")
	quit(0 if failures.is_empty() else 1)
