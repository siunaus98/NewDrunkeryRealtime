extends SceneTree

const Pause = preload("res://Scripts/Facilities/FacilityWorkPause.gd")
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
	var boss: CharacterBody2D = load("res://Scenes/Enemies/monitor_boss.tscn").instantiate()
	main.add_child(boss)
	stop_ticks(boss)
	var map: Node2D = main.get_node("PrototypeMap")
	boss.movement_bounds = map.get_region_bounds(&"top")
	boss.global_position = boss.movement_bounds.get_center()
	var head: Node2D = boss.facility_tongue
	check(head.mouth() != boss.tongue.mouth(), "Heads use separate mouths")
	check(head.begin() and head.branches.size() == 1, "Saliva selects one production facility")
	var station: Node2D = head.branches[0].target.source.get_ref()
	check(not Pause.is_paused(station), "Lock alone does not pause facility")
	boss.receive_charged_hit(100)
	check(head.phase == head.Phase.LOCK, "Heavy body hit cannot interrupt saliva")
	var previous: Vector2 = station.global_position
	station.global_position += Vector2(128, 0)
	head.tick(head.lock_duration, false)
	check(not head.branches[0].cancelled and head.branches[0].target.position == station.global_position, "Moving locked facility preserves tracked target")
	head.tick(head.extend_duration, false)
	var effect: Node2D = station.get_node(Pause.EFFECT_NAME)
	effect.set_process(false)
	check(Pause.is_paused(station) and effect.remaining == 10 and effect.shutdown_duration == 15, "Normal impact attaches ten-second repair window and fifteen-second penalty")
	effect.queue_free()
	station.global_position = previous
	head.finish()
	await process_frame
	# A real carry hides the source node; the effect must still land without
	# restoring collision or forcing an unsafe placement.
	head.begin()
	station = head.branches[0].target.source.get_ref()
	var actor: Node2D = main.get_node("Player")
	actor.clear_held_item()
	var carried: Node2D
	if station.has_method("can_be_moved_by_player") and actor.facility_carry_controller.pick_up(station):
		carried = station
	else:
		for candidate in head._get_options():
			var option: Node2D = candidate.source.get_ref()
			if option.has_method("can_be_moved_by_player") and actor.facility_carry_controller.pick_up(option):
				carried = option
				head.branches[0].target = candidate
				break
	check(carried != null, "Real movable facility is available for carry regression")
	if carried != null:
		var origin: Vector2 = carried.global_position
		boss.current_health = boss.max_health / 2 - 1
		head.tick(head.lock_duration, false)
		actor.global_position += Vector2(80, 40)
		head.tick(head.extend_duration, false)
		effect = carried.get_node_or_null(Pause.EFFECT_NAME)
		check(effect != null and Pause.is_paused(carried) and effect.shutdown_duration == 30, "Saliva tracks hidden carried facility and frenzy only lengthens penalty")
		check(actor.is_carrying_facility() and carried.global_position == origin and not carried.visible and carried.collision_layer == 0, "Impact never drops carried facility or restores its collision")
		actor.facility_carry_controller.cancel_carry()
		check(Pause.is_paused(carried) and carried.visible and not carried.has_meta("facility_carrier"), "Placed facility retains attached effect")
	head.finish()
	Pause.clear_owned(self, boss)
	await process_frame
	boss.tongue.finish()
	boss.state = boss.AttackState.ACTIVE
	boss.bait.clear()
	boss.pressure_owner = null
	boss.next_pressure_is_facility = false
	boss.pressure_gap = 0
	boss.tongue.cooldown = 0
	head.cooldown = 0
	boss._tick_pressure(0.1)
	check(boss.tongue.active() and not head.active(), "Food preparation starts even without existing food")
	boss.tongue.tick(boss.tongue.remaining, false)
	boss.tongue.tick(boss.tongue.remaining, false)
	boss.tongue.tick(boss.tongue.remaining, false)
	boss._tick_pressure(0.1)
	check(boss.next_pressure_is_facility and boss.pressure_gap > 0, "Finished theft gives next turn to saliva with recovery gap")
	boss._tick_pressure(3.1)
	check(head.active() and not boss.tongue.active(), "Saliva follows preparation rather than overlapping it")
	var facing: Vector2 = boss.facing
	boss._physics_process(0.1)
	check(boss.velocity == Vector2.ZERO and boss.facing == facing, "Saliva preparation fixes position and facing for weak-point opportunity")
	boss._die()
	main.queue_free()
	await process_frame
	print("MONITOR DUAL HEADS: %d failures; separate mouths, tracking, carry safety, frenzy duration, alternation and facing lock" % failures.size())
	quit(0 if failures.is_empty() else 1)
