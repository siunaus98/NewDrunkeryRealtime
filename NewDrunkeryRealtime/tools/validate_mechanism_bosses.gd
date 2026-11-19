extends SceneTree

const Boss = preload("res://Scripts/Enemies/MapMechanismBoss.gd")
const Sand = preload("res://Scripts/Hazards/QuicksandHazard.gd")
const Defs = preload("res://Scripts/Core/MapMechanismDefs.gd")
var failures: Array[String] = []

class PracticePlayer extends Node2D:
	var hits: int = 0
	var pull: Vector2 = Vector2.ZERO
	func get_sort_origin() -> Vector2:
		return global_position
	func take_damage(_amount: int, _direction: Vector2, _kind: StringName) -> bool:
		hits += 1
		return true
	func apply_quicksand_pull(value: Vector2, _multiplier: float = 1.0) -> void:
		pull = value

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var main: Node = load("res://Scenes/Main/main.tscn").instantiate()
	root.add_child(main)
	await physics_frame
	await physics_frame
	paused = false
	var flow: Node = main.get_node("LevelFlowController")
	flow.set_process(false)
	var manager: Node = main.get_node("BattleManager")
	manager.set_process(false)
	manager.reset_runtime_state()
	var scarab_controller: Node = main.get_node("ScarabMechanismController")
	scarab_controller.set_process(false)
	main.get_node("QuicksandMechanismController").set_process(false)
	main.get_node("WindSandMechanismController").set_process(false)
	var actual_player: Node2D = main.get_node("Player")
	actual_player.process_mode = Node.PROCESS_MODE_DISABLED
	actual_player.remove_from_group("player")
	var player := PracticePlayer.new()
	main.add_child(player)
	player.add_to_group("player")
	var map: Node2D = main.get_node("PrototypeMap")
	var arena: Rect2 = map.get_region_bounds(&"top")
	player.global_position = arena.get_center() + Vector2(240, 0)
	var progression := preload("res://Scripts/Core/RunProgressionState.gd").new()
	progression.reset(0, 0, 10405)
	# Exercise scorpion behavior independently of the current day-one playtest selection.
	var group := {"map_mechanism_ids": [Defs.SCARAB], "boss_enhanced_map_mechanism_id": Defs.SCARAB}
	scarab_controller.configure_for_level(group)
	_check(not scarab_controller.business_running, "Scarab generation must wait for business start.")
	manager.configure_for_order_group(group)
	flow.day_transition_active = false
	flow.input_release_guard_active = false
	flow.run_context = preload("res://Scripts/Core/LevelContext.gd").new()
	flow.run_context.initialize(group)
	flow.run_context.state = flow.LevelContext.LevelState.PREPARE_PHASE
	flow.prepare_time_remaining = flow.prepare_phase_duration
	flow.day_time_remaining = flow.prepare_phase_duration + flow.service_phase_duration
	flow._process(flow.prepare_phase_duration * 0.5 - 0.01)
	_check(not manager.has_active_boss(), "Day-one scorpion must wait until preparation midpoint.")
	flow._process(0.02)
	# Keep the route fixture static; the live controller's obstacle-repath loop
	# is deliberately disabled in this test along with random forage spawning.
	flow.run_context.state = flow.LevelContext.LevelState.OUT_OF_LEVEL
	_check(get_nodes_in_group("scorpion_bosses").size() == 1, "Scarab pairing must create one scorpion.")
	var scorpion: Boss = get_first_node_in_group("scorpion_bosses") as Boss
	if scorpion == null:
		quit(1)
		return
	scorpion.set_physics_process(false)
	_check(scorpion.max_health == 24000 and scorpion.hit_radius == 160.0, "Scorpion durability and hit radius must match the worm baseline.")
	_check(scorpion.contact_damage == 10 and scorpion.contact_damage_radius == 140.0, "Scorpion must use the smaller contact-damage volume.")
	_check(scorpion.get_hit_position().is_equal_approx(scorpion.sprite.to_global(Vector2(12, 4))), "Scorpion hit center must match its own art.")
	scorpion.global_position = arena.get_center()
	manager.start_wave(1, {}, group)
	manager.start_wave(0, {}, group)
	_check(get_nodes_in_group("scorpion_bosses").size() == 1, "Starting/restarting waves must not duplicate a boss.")
	_check(scarab_controller.get_scarab_limit() == 5, "Living scorpion initially reserves a full five-scarab wave.")
	for kind in [Boss.Attack.STING, Boss.Attack.SWEEP, Boss.Attack.LEAP]:
		player.global_position = scorpion.global_position + Vector2(180, 0)
		scorpion.start_attack(kind)
		var locked_target := scorpion.attack_target
		_check(scorpion.state == Boss.AttackState.WINDUP, "Each scorpion skill must have a warning.")
		_check(scorpion.attack_contains_point(player.global_position), "The advertised attack must hit its target.")
		_check(not scorpion.attack_contains_point(scorpion.global_position + Vector2(-600, -600)), "The attack must leave safe space.")
		var previous_hits := player.hits
		scorpion._resolve_attack()
		_check(player.hits == previous_hits + 1, "Each resolved scorpion strike must apply damage once.")
		if kind == Boss.Attack.LEAP:
			_check(scorpion.global_position == locked_target, "Leap must land at the locked warning location.")
		if kind == Boss.Attack.STING:
			_check(scorpion.series_remaining == 2 and scorpion.state == Boss.AttackState.WINDUP, "Each successive sting needs another warning.")
	player.global_position = map.get_kitchen_zone_bounds().get_center()
	scorpion._physics_process(0.1)
	_check(scorpion.state == Boss.AttackState.ACTIVE, "Leaving the arena cancels the active attack.")

	# Real scene physics: three random top-region births must cross both gates.
	for sample in range(3):
		map.rng.seed = 1090 + sample
		scarab_controller.rng.seed = 1090 + sample
		_check(scarab_controller._spawn_scarab(), "Scarab boss-day spawning must succeed.")
		await physics_frame
		var scarab: CharacterBody2D = get_nodes_in_group("scarab_enemies").back()
		_check(map.get_battle_region_for_point(scarab.global_position) == &"top", "Every boss-day scarab starts in region four.")
		scarab_controller._update_scarab_targets()
		# Initial snapshots are time-sliced. Match the live test's six-second
		# departure deadline instead of assuming a particular grid build speed.
		for warmup in range(360):
			if scarab.current_target_kind == &"entry":
				break
			await physics_frame
			scarab_controller.navigation_clock += 1.0 / 60.0
			scarab_controller._tick_navigation_cache()
			scarab_controller._update_scarab_targets()
		_check(scarab.current_target_kind == &"entry" and not scarab.navigation_route.is_empty(), "Incoming scarab needs a traversable entry route.")
		if not is_instance_valid(scarab.current_target):
			print("Route failure sample=%d position=%s clock=%s retry=%s" % [sample, scarab.global_position, scarab_controller.navigation_clock, scarab_controller.navigation_retry_times])
			for bounds in scarab_controller.navigation_cache.caches:
				var cache: Dictionary = scarab_controller.navigation_cache.caches[bounds]
				print("Cache bounds=%s published=%s scan=%s size=%s gates=%s" % [bounds, cache.grid != null, cache.cursor, cache.size, cache.gate_trees.size()])
				for gate in cache.gate_trees:
					var tree: Dictionary = cache.gate_trees[gate]
					print("Gate %s visited=%s complete=%s" % [gate, tree.next.size(), tree.complete])
			quit(1)
			return
		for frame in range(2200):
			await physics_frame
			scarab_controller.navigation_clock += 1.0 / 60.0
			scarab_controller._tick_navigation_cache()
			if frame % 12 == 0:
				scarab_controller._update_scarab_targets()
			if map.is_point_in_kitchen_zone(scarab.global_position):
				break
		_check(map.is_point_in_kitchen_zone(scarab.global_position), "Scarab must physically reach the kitchen through the gates.")
		scarab.clear_target()
		scarab_controller.navigation_retry_times.erase(scarab.get_instance_id())
		scarab_controller._update_single_scarab_target(scarab)
		for warmup in range(120):
			if scarab.current_target_kind in [&"cabinet", &"ground"]:
				break
			await physics_frame
			scarab_controller.navigation_clock += 1.0 / 60.0
			scarab_controller._tick_navigation_cache()
			scarab_controller._update_single_scarab_target(scarab)
		_check(scarab.current_target_kind in [&"cabinet", &"ground"], "Arrived scarab must select an eligible ingredient.")
		if not is_instance_valid(scarab.current_target):
			quit(1)
			return
		var start_point := scarab.global_position
		for frame in range(90):
			await physics_frame
		_check(scarab.global_position.distance_to(start_point) > 12.0 or scarab.global_position.distance_to(scarab.current_target.global_position) <= scarab.get_current_target_reach(), "Arrived scarab must approach its food target.")
		scarab.stolen_items.assign([&"crisp_sprout", &"crisp_sprout", &"crisp_sprout"])
		scorpion.current_health = scorpion.max_health - 2000
		scarab_controller._on_scarab_escape_finished(scarab)
		_check(scorpion.current_health == scorpion.max_health - 800, "Three stolen ingredients restore 1200 HP, once.")
		await physics_frame
		print("Boss scarab route sample %d reached kitchen and food." % sample)
	scorpion.current_health = scorpion.max_health - 1
	scorpion.receive_scarab_escape(5)
	_check(scorpion.current_health == scorpion.max_health, "Healing must not exceed maximum HP.")
	scorpion.receive_hit(scorpion.max_health)
	_check(not scarab_controller.active and not scarab_controller.business_running, "Boss defeat suspends scarabs for the day.")
	manager.start_wave(0, {}, group)
	_check(not manager.has_active_boss(), "A killed boss must not respawn during the same day.")
	await physics_frame
	manager.reset_runtime_state()
	group["boss_enhanced_map_mechanism_id"] = Defs.QUICKSAND
	manager.start_wave(0, {}, group)
	var worm: Boss = get_first_node_in_group("sandworm_bosses") as Boss
	_check(worm != null, "Quicksand pairing must spawn a sandworm.")
	if worm == null:
		quit(1)
		return
	worm.set_physics_process(false)
	worm.global_position = arena.get_center()
	player.global_position = worm.global_position + Vector2(240, 0)
	for kind in [Boss.Attack.NEEDLES, Boss.Attack.TAIL, Boss.Attack.SLAM, Boss.Attack.RUSH]:
		worm.start_attack(kind)
		_check(worm.state == Boss.AttackState.WINDUP, "Each sandworm attack must be telegraphed.")
		var hp := worm.current_health
		worm.receive_hit(5)
		_check(worm.current_health == hp if kind == Boss.Attack.TAIL else worm.current_health == hp - 5, "Only the tail barrage grants invulnerability.")
		if kind == Boss.Attack.TAIL:
			for i in range(worm.tail_strike_count):
				worm._resolve_attack()
			_check(worm.state == Boss.AttackState.RECOVERY and not worm.is_invulnerable(), "Six tail strikes must finish and remove invulnerability.")
		elif kind == Boss.Attack.RUSH:
			worm._resolve_attack()
			var start := worm.global_position
			for i in range(10):
				worm._physics_process(1.0 / 60.0)
				await physics_frame
			_check(worm.global_position.distance_to(start) > 40.0, "A charge must physically move the boss.")
		else:
			worm._resolve_attack()
	var sand := Sand.new()
	sand.position = player.position - Vector2(100, 0)
	sand.configure_boss(worm, 400.0, 0.8, 180.0)
	main.add_child(sand)
	sand.set_physics_process(false)
	player.pull = Vector2.ZERO
	sand._physics_process(0.1)
	_check(player.pull == Vector2.ZERO, "Birth warning must not apply sustained suction.")
	sand._physics_process(0.71)
	sand._physics_process(0.01)
	_check(player.pull.length() > 0.0, "Quicksand must activate after its warning.")
	actual_player.quicksand_pull_velocity = Vector2.ZERO
	actual_player.apply_quicksand_pull(Vector2(2000, 0))
	_check(actual_player.quicksand_pull_velocity.length() <= 300.0 and actual_player.quicksand_pull_velocity.length() < actual_player.get_current_move_speed() * actual_player.dash_speed_multiplier, "Strengthened pulls must leave dash escape possible.")
	worm.state = Boss.AttackState.ACTIVE
	worm.receive_hit(worm.max_health)
	_check(sand.is_queued_for_deletion() and not main.get_node("QuicksandMechanismController").active, "Boss defeat removes quicksand and suspends it for the day.")
	scarab_controller.configure_for_level({"map_mechanism_ids": [Defs.SCARAB]})
	_check(not scarab_controller.boss_scarab_mode and scarab_controller.get_scarab_limit() == 2, "Next normal day must not retain boss scarab buffs.")
	manager.reset_runtime_state()
	group["boss_enhanced_map_mechanism_id"] = Defs.SANDSTORM
	manager.start_wave(0, {}, group)
	_check(manager.has_active_boss() and get_nodes_in_group("vulture_bosses").size() == 1, "Wind pairing must spawn its own vulture boss.")
	main.queue_free()
	await process_frame
	if failures.is_empty():
		print("PASS: boss skills, warnings, damage, day pairing, three cross-region scarab routes, healing, and daily mechanism shutdown.")
	quit(0 if failures.is_empty() else 1)

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error(message)
