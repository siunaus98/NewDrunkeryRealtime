extends SceneTree

const Defs = preload("res://Scripts/Player/SmallSkillDefs.gd")
const BigDefs = preload("res://Scripts/Player/BigSkillDefs.gd")
const Field = preload("res://Scripts/Player/SmallSkillField.gd")
const Items = preload("res://Scripts/Kitchen/TestItemDefs.gd")
const Energy = preload("res://Scripts/Player/UltimateEnergyRules.gd")
const Context = preload("res://Scripts/Core/LevelContext.gd")
const MAIN = preload("res://Scenes/Main/main.tscn")
var failures: Array[String] = []
var main: Node
var player: CharacterBody2D
var teammate: CharacterBody2D
var flow: Node
var kitchen: Vector2
var battle: Vector2

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

func _select(id: StringName) -> RefCounted:
	player.reset_temporary_state()
	player.set_small_skill_variant(id)
	player.global_position = kitchen
	flow.magic_current = 6
	flow.run_context.state = Context.LevelState.PREPARE_PHASE
	return player.skill_controller.small

func _hold(id: StringName, state: StringName = &"", payload: Dictionary = {}) -> void:
	player.clear_held_item()
	_check(player.pick_up_item(id, Items.get_item_texture(id), state, "", payload), "Fixture pickup succeeds.")

func _arm_work() -> void:
	flow.magic_current = 0
	player.skill_controller.small.cooldown_remaining = 10.0

func _expect_work(message: String) -> void:
	_check(flow.magic_current == 0 and player.skill_controller.small.cooldown_remaining == 0.0, message)

func _test_kitchen_and_random() -> void:
	var small: RefCounted = _select(Defs.KITCHEN)
	_check(small.try_activate(1.0) and is_equal_approx(small.buff_remaining, 3.0) and is_equal_approx(small.get_personal_bonus(), 0.6), "Kitchen cast doubles duration and bonus.")
	player.global_position = battle
	_check(is_zero_approx(small.get_personal_bonus()), "Leaving kitchen immediately removes the bonus.")
	small.after_motion(Vector2.RIGHT, kitchen, battle, 10.0)
	player.global_position = kitchen
	_check(is_zero_approx(small.get_personal_bonus()), "Reentry cannot restore an ended kitchen cast.")
	small = _select(Defs.KITCHEN)
	player.global_position = battle
	small.try_activate(1.0)
	player.global_position = kitchen
	_check(is_equal_approx(small.get_personal_bonus(), 0.3) and is_equal_approx(small.buff_remaining, 1.5), "Outside cast is not upgraded by entering kitchen.")
	small = _select(Defs.RANDOM)
	small.rng.seed = 20261022
	var outcomes: Dictionary = {}
	var seen_bonuses: Dictionary = {}
	var seen_times: Dictionary = {}
	for i in range(800):
		small.reset_temporary_state()
		flow.magic_current = 4
		_check(small.try_activate(1.0), "Random cast succeeds.")
		_check(small.speed_bonus >= 0.3 and small.speed_bonus <= 1.3 and small.buff_duration >= 1.0 and small.buff_duration <= 2.0, "Random values stay within the agreed ranges.")
		_check(small.magic_feedback_delta == flow.magic_current - 2 and (small.magic_flash_remaining > 0.0) == (flow.magic_current != 2), "Magic glow matches the actual extra change only.")
		_check(player.interaction_controller.hint_label.text.split("\n").size() == 2, "Random hint uses separate speed and duration lines.")
		_check(is_equal_approx(small.cooldown_remaining, 15.0), "Random variant uses fifteen-second cooldown.")
		outcomes[flow.magic_current] = true
		seen_bonuses[roundi(small.speed_bonus * 100)] = true
		seen_times[roundi(small.buff_duration * 10)] = true
		_check(not small.try_activate(1.0), "A random refund does not bypass cooldown.")
	_check(outcomes.size() == 3 and outcomes.has(1) and outcomes.has(2) and outcomes.has(3), "All three extra-magic outcomes occur after initial cost.")
	_check(seen_bonuses.has(30) and seen_bonuses.has(130) and seen_times.has(10) and seen_times.has(20), "Random ranges include both endpoints.")
	for i in range(60):
		small.reset_temporary_state()
		flow.magic_current = 2
		small.try_activate(1.0)
		_check(flow.magic_current >= 0 and small.magic_feedback_delta >= 0, "At zero magic, blocked extra charge cannot produce a red glow.")
	small.reset_temporary_state()
	flow.magic_current = 1
	_check(not small.try_activate(1.0) and flow.magic_current == 1 and small.cooldown_remaining == 0.0, "Insufficient initial magic changes nothing.")

func _test_work() -> void:
	var small: RefCounted = _select(Defs.WORK)
	small.try_activate(1.0)
	_check(flow.magic_current == 5 and is_equal_approx(small.buff_remaining, 1.0) and is_equal_approx(small.speed_bonus, 0.8), "Work cast costs one magic and grants one second at eighty percent speed.")
	small.tick(0.5, 1.0)
	player.on_work_completed(&"forage")
	_check(small.cooldown_remaining > 0.0 and flow.magic_current == 5, "Forage does not reset the work skill.")
	var cut: Node = main.get_node("TestCooker")
	cut.reset_state()
	_hold(Items.VEG_LEAF_ID, &"", {Energy.PROCESS_REWARDED: true})
	cut.receive_item_from_player(player)
	var energy_before: float = player.skill_controller.ultimate_energy
	for i in range(cut.required_interact_presses):
		cut._advance_processing(0.0, player, true)
	_check(small.cooldown_remaining == 0.0 and flow.magic_current == 5 and is_equal_approx(small.buff_remaining, 0.5), "Real cut resets cooldown without restoring magic or extending buff, even on energy-marked food.")
	_check(player.skill_controller.ultimate_energy == energy_before, "Work milestone cannot duplicate processing energy.")
	small.buff_remaining = 0.0
	var grind: Node = main.get_node("GrindCooker")
	grind.reset_state()
	_hold(Items.SUN_SEED_ID)
	grind.receive_item_from_player(player)
	flow.magic_current = 0
	small.cooldown_remaining = 10.0
	grind._advance_processing(grind.hold_process_duration * 0.6, player)
	_check(flow.magic_current == 0 and small.cooldown_remaining == 0.0, "Coarse stage resets cooldown without generating magic.")
	small.cooldown_remaining = 10.0
	grind._advance_processing(grind.hold_process_duration, player)
	_check(flow.magic_current == 0 and small.cooldown_remaining == 0.0, "Fine stage separately resets cooldown without generating magic.")
	var roast: Node = main.get_node("BakeCooker")
	roast.reset_state()
	_hold(Items.MEAT_RED_ID)
	roast.receive_item_from_player(player)
	roast._advance_processing(roast.auto_process_duration * 0.4, null)
	player.clear_held_item()
	_arm_work()
	var roast_energy_before: float = player.skill_controller.ultimate_energy
	_check(roast.take_item_to_player(player) and flow.magic_current == 0 and small.cooldown_remaining == 10.0, "Successful roast pickup no longer resets or restores magic.")
	_check(player.skill_controller.ultimate_energy == roast_energy_before + 5.0, "Roast still grants its separate ultimate reward.")
	roast.receive_item_from_player(player)
	player.clear_held_item()
	roast.take_item_to_player(player)
	_check(flow.magic_current == 0 and small.cooldown_remaining == 10.0, "Repeated roast pickup cannot reset work cooldown.")
	var assembly: Node = main.get_node("AssemblyStation")
	assembly.reset_state()
	for i in range(2):
		_hold(Items.VEG_LEAF_ID, Items.PROCESS_STATE_CUT)
		assembly.receive_item_from_player(player)
	_arm_work()
	_check(assembly.interact_with_player(player), "Real assembly succeeds.")
	_check(flow.magic_current == 0 and small.cooldown_remaining == 10.0, "Instant assembly no longer resets work cooldown.")
	_arm_work()
	_check(not assembly.interact_with_player(player) and flow.magic_current == 0, "Completed dish cannot grant another milestone.")
	var manager: Node = main.get_node("OrderManager")
	manager.set_orders([
		{"order_id": "work_a", "customer_id": "work_guest", "target_slot": 1, "dish_item_id": Items.DISH_CRISP_PLATE_ID},
		{"order_id": "work_b", "customer_id": "work_guest", "target_slot": 1, "dish_item_id": Items.DISH_CRISP_PLATE_ID}
	])
	_check(manager.process_take_order_at_slot(1, 10.0, player), "Real multi-dish customer acceptance succeeds.")
	_expect_work("Accepting a customer triggers a single work milestone.")
	_arm_work()
	_check(not manager.take_order_at_slot(1, player) and flow.magic_current == 0, "Already accepted customer cannot repeat the work reward.")
	_hold(Items.PLATE_ID)
	assembly.take_item_to_player(player)
	var counter: Node = main.get_node("TestServingCounter")
	counter.focused_slot_index = 0
	_check(counter.receive_item_from_player(player), "Real dish serving succeeds.")
	_expect_work("Actual serving resets the server's work skill.")
	var barrel: Node = main.get_node("FixedBarrelLeftA")
	barrel.reset_state()
	_hold(StringName(Items.BARREL_INPUTS[Items.DRINK_QINGMEI_WINE_ID]))
	_arm_work()
	_check(barrel.receive_item_from_player(player), "Real barrel ingredient insertion succeeds.")
	_check(flow.magic_current == 0 and small.cooldown_remaining == 10.0, "Barrel insertion no longer resets work cooldown.")
	var sink: Node2D = main.get_node("PlateSink")
	sink.reset_state()
	sink.dirty_plates = 1
	player.clear_held_item()
	player.global_position = sink.get_interaction_rect_global().get_center() + Vector2(0, 110)
	_arm_work()
	_check(sink.process_hold_interaction(player, 5.0), "Real attended plate wash succeeds.")
	_expect_work("A finished plate wash triggers a work milestone.")
	flow.run_context.state = Context.LevelState.NIGHT_REST
	small.cooldown_remaining = 10.0
	player.on_work_completed(&"wash")
	_check(flow.magic_current == 0 and small.cooldown_remaining == 10.0, "Night work cannot reset the cooldown or generate magic.")
	roast.reset_state()
	player.clear_held_item()

func _test_fields() -> void:
	var small: RefCounted = _select(Defs.FIELD)
	player.global_position = battle
	_check(not small.try_activate(1.0) and flow.magic_current == 6 and small.cooldown_remaining == 0.0, "Aura rejects outside cast before consuming resources.")
	player.global_position = kitchen
	_check(small.try_activate(1.0), "Solo kitchen aura casts.")
	var aura: Node2D = small.field
	aura.set_process(false)
	_check(flow.magic_current == 3 and is_equal_approx(aura.remaining, 8.0) and is_equal_approx(aura.get_bonus_at(kitchen), 0.8), "Solo aura uses three magic and eight-second eighty-percent speed.")
	player.global_position += Vector2(500, 0)
	_check(aura.global_position == kitchen and is_zero_approx(player.skill_controller.get_move_speed_multiplier() - 1.0), "Aura stays at the cast point when caster leaves.")
	_check(aura.get_bonus_at(kitchen + Vector2(319, 0)) == 0.8 and aura.get_bonus_at(kitchen + Vector2(321, 0)) == 0.0, "Aura range matches its visible radius.")
	main.add_child(teammate)
	_stop_ticks(teammate)
	teammate.global_position = kitchen
	_check(is_equal_approx(teammate.skill_controller.get_move_speed_multiplier(), 1.8), "A teammate entering an existing solo aura receives its cast-time strength.")
	small = _select(Defs.FIELD)
	small.try_activate(1.0)
	aura = small.field
	aura.set_process(false)
	_check(is_equal_approx(aura.speed_bonus, 0.4) and is_equal_approx(aura.remaining, 8.0), "Multiplayer cast snapshots reduced strength and duration.")
	teammate.set_small_skill_variant(Defs.BASE)
	teammate.skill_controller.small.try_activate(1.0)
	_check(is_equal_approx(teammate.skill_controller.get_move_speed_multiplier(), 1.4), "Personal and shared skill bonuses use maximum instead of multiplying.")
	teammate.reset_temporary_state()
	aura._process(8.0)
	_check(aura.get_bonus_at(kitchen) == 0.0, "Expired aura stops granting speed immediately.")
	small = _select(Defs.TRAIL)
	small.try_activate(1.0)
	var path: Node2D = small.field
	path.set_process(false)
	small.after_motion(Vector2.RIGHT, kitchen, kitchen + Vector2(120, 0), 120)
	small.after_motion(Vector2.ZERO, kitchen, kitchen, 0)
	_check(path.segments.size() == 1 and not path.active and path.get_bonus_at(kitchen) == 0.0, "Moving creates dormant path; standing still creates none.")
	_check(is_equal_approx(teammate.skill_controller.get_move_speed_multiplier(), 1.0), "Dormant path provides no teammate speed.")
	_check(small.cooldown_remaining == 30.0 and small.buff_remaining == 3.0, "Trail uses three-second laying and thirty-second cooldown.")
	small.tick(2.9, 1.0)
	_check(not path.active, "Path stays dormant throughout personal skill.")
	small.tick(0.11, 1.0)
	_check(path.active and is_equal_approx(path.remaining, 6.0) and is_equal_approx(path.get_bonus_at(kitchen + Vector2(100, 0)), 0.3), "All path activates at skill end with one shared six-second timer.")
	_check(is_equal_approx(player.skill_controller.get_move_speed_multiplier(), 1.3) and is_equal_approx(teammate.skill_controller.get_move_speed_multiplier(), 1.3), "Active path grants the same nonstacking bonus to both players.")
	path._process(6.0)
	_check(path.get_bonus_at(kitchen) == 0.0, "Path expires as a whole.")
	player.reset_temporary_state()
	_check(player.skill_controller.small.variant_id == Defs.TRAIL and is_equal_approx(player.skill_controller.get_move_speed_multiplier(), 1.0), "Day reset clears fields but keeps selected variant.")

func _test_direction() -> void:
	var small: RefCounted = _select(Defs.DIRECTION)
	small.try_activate(1.0)
	_check(is_equal_approx(player.skill_controller.get_move_speed_multiplier(), 1.6), "Directional variant grants sixty percent speed before route renewal.")
	small.before_motion(Vector2(1, 1).normalized())
	var locked: Vector2 = small.locked_direction
	for input: Vector2 in [Vector2.RIGHT, Vector2.DOWN, Vector2(1, 1).normalized()]:
		for i in range(30):
			small.tick(0.1, 1.0)
			small.after_motion(input, Vector2.ZERO, input * 20.0, 20.0)
	_check(is_equal_approx(small.buff_remaining, 2.0) and small.locked_direction == locked, "Original diagonal and both adjacent directions renew indefinitely without turning reference.")
	small.tick(0.25, 1.0)
	small.after_motion(Vector2.RIGHT, Vector2.ZERO, Vector2.ZERO, 20)
	_check(is_equal_approx(small.buff_remaining, 1.75), "Pushing into a wall cannot renew.")
	small.after_motion(Vector2.ZERO, Vector2.ZERO, Vector2.RIGHT * 20, 20)
	_check(is_equal_approx(small.buff_remaining, 1.75), "Forced motion without input cannot renew.")
	small.after_motion(Vector2.RIGHT, Vector2.ZERO, Vector2.RIGHT * 20, 20)
	_check(is_equal_approx(small.buff_remaining, 2.0), "Allowed motion resumes renewal before expiry.")
	small.before_motion(Vector2.UP)
	_check(small.buff_remaining == 0.0 and player.skill_controller.get_move_speed_multiplier() == 1.0, "Wrong input direction ends the bonus before the host calculates movement.")
	small.before_motion(Vector2.RIGHT)
	small.after_motion(Vector2.RIGHT, Vector2.ZERO, Vector2.RIGHT * 20, 20)
	_check(small.buff_remaining == 0.0, "Returning to the original direction cannot revive a canceled buff.")
	small = _select(Defs.DIRECTION)
	small.try_activate(1.0)
	small.before_motion(Vector2.RIGHT)
	small.after_motion(Vector2.LEFT, Vector2.ZERO, Vector2.LEFT * 20, 20)
	_check(is_equal_approx(small.buff_remaining, 2.0), "Wrong motion direction preserves the initial guaranteed duration.")
	small.tick(1.99, 1.0)
	small.before_motion(Vector2.LEFT)
	small.after_motion(Vector2.LEFT, Vector2.ZERO, Vector2.RIGHT * 20, 20)
	_check(is_equal_approx(small.buff_remaining, 0.01), "Wrong input cannot renew grace even when forced motion goes forward.")
	small.tick(0.02, 1.0)
	_check(small.buff_remaining == 0.0 and small.direction_grace_remaining == 0.0, "Wrong-direction grace expires at two seconds without renewal.")
	small = _select(Defs.DIRECTION)
	small.try_activate(1.0)
	small.tick(2.1, 1.0)
	small.before_motion(Vector2.RIGHT)
	small.after_motion(Vector2.RIGHT, Vector2.ZERO, Vector2.RIGHT * 20, 20)
	_check(small.buff_remaining == 0.0, "Expired speed cannot restart without another cast.")
	small = _select(Defs.DIRECTION)
	small.try_activate(1.0)
	small.tick(1.01, 1.0)
	small.before_motion(Vector2.RIGHT)
	_check(small.locked_direction.is_zero_approx(), "First movement after the one-second wait cannot lock direction.")
	var grace: RefCounted = _select(Defs.DIRECTION)
	grace.try_activate(1.0)
	grace.before_motion(Vector2.RIGHT)
	grace.tick(0.5, 1.0)
	grace.before_motion(Vector2.UP)
	grace.after_motion(Vector2.UP, Vector2.ZERO, Vector2.UP * 20.0, 20.0)
	_check(grace.buff_remaining > 0.0 and is_equal_approx(player.skill_controller.get_move_speed_multiplier(), 1.6), "A wrong direction cannot cancel the initial two-second grace period.")
	grace.tick(1.4, 1.0)
	_check(grace.buff_remaining > 0.0, "The initial direction grace period lasts for the full two seconds.")
	grace.after_motion(Vector2.RIGHT, Vector2.ZERO, Vector2.RIGHT * 20.0, 20.0)
	grace.tick(0.2, 1.0)
	grace.before_motion(Vector2.UP)
	_check(grace.buff_remaining == 0.0, "After the grace period, a wrong direction ends the renewed bonus.")
	grace = _select(Defs.DIRECTION)
	grace.try_activate(1.0)
	grace.before_motion(Vector2.RIGHT)
	grace.tick(1.5, 1.0)
	grace.after_motion(Vector2.RIGHT, Vector2.ZERO, Vector2.RIGHT * 20.0, 20.0)
	grace.tick(0.6, 1.0)
	grace.after_motion(Vector2.UP, Vector2.ZERO, Vector2.UP * 20.0, 20.0)
	_check(grace.buff_remaining == 0.0, "Motion callback cancels a wrong direction after the initial grace expires.")
	grace = _select(Defs.DIRECTION)
	grace.try_activate(1.0)
	player.reset_temporary_state()
	_check(grace.direction_grace_remaining == 0.0, "Day reset clears direction grace.")

func _test_real_wall_motion() -> void:
	var small: RefCounted = _select(Defs.DIRECTION)
	player.global_position = battle
	player.window_input_focused = true
	var wall := StaticBody2D.new()
	wall.collision_layer = 4
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(30, 300)
	collision.shape = shape
	wall.add_child(collision)
	main.add_child(wall)
	wall.global_position = battle + Vector2(80, 0)
	await physics_frame
	small.try_activate(1.0)
	Input.action_press("move_right")
	for i in range(90):
		small.tick(1.0 / 60.0, 1.0)
		player._physics_process(1.0 / 60.0)
	Input.action_release("move_right")
	_check(player.global_position.x < wall.global_position.x and small.buff_remaining < 1.0, "Real player physics reaches a solid wall and stops renewing directional speed.")
	wall.queue_free()

func _run() -> void:
	# Formal starts no longer expose test selectors. Upgrade selection is
	# covered by validate_skill_upgrades; exercise variants on the real actor.
	main = MAIN.instantiate()
	root.add_child(main)
	current_scene = main
	await process_frame
	paused = false
	_stop_ticks(main)
	player = main.get_node("Player")
	flow = main.get_node("LevelFlowController")
	player.set_small_skill_variant(Defs.WORK)
	player.skill_controller.ultimate_energy = 0.0
	var map: Node = main.get_node("PrototypeMap")
	kitchen = map.get_kitchen_zone_bounds().get_center()
	battle = map.get_region_bounds(&"top").get_center()
	var template: Node = MAIN.instantiate()
	teammate = template.get_node("Player")
	template.remove_child(teammate)
	template.free()
	_test_kitchen_and_random()
	_test_work()
	_test_fields()
	_test_direction()
	await _test_real_wall_motion()
	player.set_small_skill_variant(Defs.FIELD)
	var hud: Node = main.get_node("RunStatusHud")
	hud.sync_skill_states(player)
	_check(hud.skill_slot_small.magic_cost == 3 and hud.skill_slot_small.tooltip_text.contains("灶边顺风"), "HUD cost and description follow selection.")
	main.queue_free()
	await process_frame
	if failures.is_empty():
		print("PASS: real player variants, kitchen boundary, random ranges/costs, work milestones, shared fixed aura, delayed trail lifecycle, original-direction renewal and real wall collision.")
	quit(0 if failures.is_empty() else 1)
