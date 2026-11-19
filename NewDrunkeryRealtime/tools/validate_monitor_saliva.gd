extends SceneTree

const Pause = preload("res://Scripts/Facilities/FacilityWorkPause.gd")
const Items = preload("res://Scripts/Kitchen/TestItemDefs.gd")
const Big = preload("res://Scripts/Player/BigSkillDefs.gd")
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
	var main: Node = load("res://Scenes/Main/main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	await process_frame
	stop_ticks(main)
	paused = false
	main.get_node("LevelFlowController").run_context.state = 7
	var boss: Node2D = load("res://Scenes/Enemies/monitor_boss.tscn").instantiate()
	main.add_child(boss)
	stop_ticks(boss)
	var actor: Node2D = main.get_node("Player")
	actor.clear_held_item()
	var assembly: Node2D = get_first_node_in_group("assembly_stations")
	assembly.stored_items.assign([{"item_id": Items.VEG_LEAF_ID, "process_state": Items.PROCESS_STATE_CUT, "payload": {}}])
	var effect: Node2D = Pause.attach(assembly, boss)
	effect.set_process(false)
	check(effect.remaining == 10 and not assembly.can_take_item(actor), "Ten-second attachment retains food and blocks taking")
	actor.interaction_controller._set_current_interaction_target(assembly)
	check(actor.interaction_controller.get_current_interaction_target() == effect and effect.get_hold_interaction_action() == &"interact", "Actual interaction focus redirects blocked assembly to K repair")
	check(not effect.is_in_group("damageables"), "Repair replaces heavy-attack cleansing")
	effect._process(9.99)
	check(not effect.deep and assembly.stored_items.size() == 1, "Food survives entire rescue window")
	effect.process_hold_interaction(actor, 3)
	check(not Pause.is_paused(assembly) and assembly.stored_items.size() == 1, "Three-second early repair preserves food")
	effect = Pause.attach(assembly, boss)
	effect.set_process(false)
	effect._process(10.25)
	check(effect.deep and is_equal_approx(effect.remaining, 14.75) and assembly.stored_items.is_empty(), "Missed deadline destroys food once and preserves timer overshoot")
	check(not effect.process_hold_interaction(actor, 100), "Forced shutdown rejects even very long repair input")
	check(Pause.attach(assembly, boss) == effect, "Reapplication never resets deep shutdown")
	actor.pick_up_item(Items.VEG_ROOT_ID, Items.get_item_texture(Items.VEG_ROOT_ID))
	check(not assembly.receive_item_from_player(actor) and actor.is_holding_item(), "Blocked transfers preserve held ingredient")
	actor.clear_held_item()
	effect._process(14.75)
	check(Pause.is_paused(assembly) and effect.can_repair() and effect.remaining == 0, "Shutdown expiry requires repair instead of automatically restoring facility")
	effect.process_hold_interaction(actor, 4.9)
	check(Pause.is_paused(assembly), "Late repair takes longer than early repair")
	await process_frame
	effect.process_hold_interaction(actor, 0.1)
	check(not Pause.is_paused(assembly), "Five-second late repair restores facility")
	# Work speed and instant-work branches use exactly the repair event.
	effect = Pause.attach(assembly, boss)
	effect.set_process(false)
	actor.set_big_skill_variant(Big.BASE)
	actor.skill_controller.big.try_activate()
	check(effect.process_hold_interaction(actor, 1.5) and not Pause.is_paused(assembly), "Base ultimate doubles repair speed")
	actor.skill_controller.big.reset_temporary_state()
	effect = Pause.attach(assembly, boss)
	effect.set_process(false)
	actor.set_big_skill_variant(Big.INSTANT)
	actor.skill_controller.big.try_activate()
	var charges: int = actor.skill_controller.big.charges
	actor.interaction_controller._set_current_interaction_target(assembly)
	actor.interaction_controller.handle_interact()
	check(not Pause.is_paused(assembly) and actor.skill_controller.big.charges == charges - 1, "Actual K interaction instantly repairs and consumes one ultimate charge")
	actor.skill_controller.big.reset_temporary_state()
	# Frying continues toward burning even though production and storage lock.
	for cooker: Node2D in get_nodes_in_group("cooking_stations"):
		cooker.has_item = true
		cooker.item_id = Items.VEG_ROOT_ID
		cooker.item_process_state = Items.PROCESS_STATE_CUT
		var pause_effect := Pause.attach(cooker, boss)
		pause_effect.set_process(false)
		check(not cooker.can_take_item(actor) and not cooker.can_be_moved_by_player(actor), "Cooking surface cannot be emptied or carried while affected")
		if cooker.overcook_enabled:
			cooker.processing_active = false
			cooker.item_process_state = cooker.output_process_state
			cooker.overcook_progress = 99
			cooker._process(0.2)
			check(cooker.item_process_state == Items.PROCESS_STATE_BURNT, "Full cooker still burns food while disabled")
		pause_effect._process(10)
		check(not cooker.has_item and pause_effect.deep, "Expired attachment destroys cooker contents")
	# Both halves of the plate facility share state and preserve plate counts.
	var sink: Node2D = get_first_node_in_group("plate_sinks")
	var clean_before: int = sink.clean_plates
	var dirty_before: int = sink.dirty_plates
	var sink_effect := Pause.attach(sink, boss)
	sink_effect.set_process(false)
	actor.interaction_controller._set_current_interaction_target(sink.rack)
	check(actor.interaction_controller.get_current_interaction_target() == sink_effect and not sink.rack.can_take_item(actor), "Clean rack redirects to same repair as basin")
	sink_effect._process(10)
	check(sink.clean_plates == clean_before and sink.dirty_plates == dirty_before, "Deep shutdown never destroys finite plate inventory")
	for barrel: Node2D in get_nodes_in_group("drink_barrels"):
		barrel.current_drink_item_id = Items.DRINK_OASIS_WINE_ID
		barrel.serving_count = 2
		barrel.queued_fill_count = 1
		var barrel_effect := Pause.attach(barrel, boss)
		barrel_effect.set_process(false)
		barrel_effect._process(10)
		check(barrel.serving_count == 0 and barrel.queued_fill_count == 0, "Overdue barrel loses its food batch")
	var furnace: Node2D = preload("res://Scripts/Facilities/FacilityCatalog.gd").create(&"fire_furnace")
	main.add_child(furnace)
	furnace.stored = {"item_id": Items.DISH_RED_ROLL_ID, "payload": {"uses_plate": true}}
	furnace.blessing_time = 4
	var furnace_effect := Pause.attach(furnace, boss, 10, 30)
	furnace_effect.set_process(false)
	furnace_effect._process(10)
	check(furnace_effect.remaining == 30 and furnace_effect.repair_duration() == 5 and furnace.stored.item_id == Items.DIRTY_PLATE_ID, "Frenzy only lengthens forced shutdown and preserves physical plate")
	Pause.clear_owned(self, boss)
	check(Pause.is_paused(sink), "Boss cleanup cannot clear deep shutdown")
	boss._die()
	furnace_effect._process(30)
	check(Pause.is_paused(furnace) and furnace_effect.can_repair(), "Deep damage remains repairable after boss death and timer expiry")
	furnace_effect.process_hold_interaction(actor, 5)
	check(not Pause.is_paused(furnace) and furnace.can_take_item(actor), "Post-boss repair returns surviving plate")
	main.queue_free()
	await process_frame
	print("MONITOR SALIVA: %d failures; ten-second attachment, early/late repair, work skills, forced shutdown, food loss, plate conservation and frenzy" % failures.size())
	quit(0 if failures.is_empty() else 1)
