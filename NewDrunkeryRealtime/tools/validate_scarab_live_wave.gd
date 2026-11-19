extends SceneTree

const Defs = preload("res://Scripts/Core/MapMechanismDefs.gd")
const Context = preload("res://Scripts/Core/LevelContext.gd")
const LIVE_WAVE_SEEDS: Array[int] = [1, 42, 1090]
const SPAWN_DEPARTURE_DEADLINE_FRAMES: int = 360
const SPAWN_DEPARTURE_DISTANCE: float = 100.0
const MAX_TEST_FRAME_USEC: int = 32000
var failures: Array[String] = []
var sample_seed: int = 1

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var seeds: Array[int] = LIVE_WAVE_SEEDS.duplicate()
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--seed="):
			seeds.assign([int(argument.trim_prefix("--seed="))])
	for value in seeds:
		sample_seed = value
		await _run_sample()
	quit(0 if failures.is_empty() else 1)

func _run_sample() -> void:
	var main: Node = load("res://Scenes/Main/main.tscn").instantiate()
	root.add_child(main)
	await physics_frame
	await physics_frame
	paused = false
	var map: Node2D = main.get_node("PrototypeMap")
	# Spawn positions come from the map RNG, not the scarab controller RNG.
	map.rng.seed = sample_seed
	var region_index := 0
	for node in main.find_children("*", "Node", true, false):
		if node.get_script() == load("res://Scripts/Forage/ForageRegion.gd"):
			node.rng.seed = sample_seed + region_index
			node._reset_spawn_timer()
			region_index += 1
	var flow: Node = main.get_node("LevelFlowController")
	flow.set_process(false)
	flow.day_transition_active = false
	flow.input_release_guard_active = false
	flow.run_context = Context.new()
	flow.run_context.initialize({"map_mechanism_ids": Defs.get_all_ids()})
	flow.run_context.state = Context.LevelState.WAVE_ACTIVE
	var manager: Node = main.get_node("BattleManager")
	manager.set_process(false)
	manager.reset_runtime_state()
	var player: Node2D = main.get_node("Player")
	player.set_process(false)
	player.set_physics_process(false)
	main.get_node("QuicksandMechanismController").set_process(false)
	main.get_node("WindSandMechanismController").set_process(false)
	var controller: Node = main.get_node("ScarabMechanismController")
	controller.set_process(false)
	controller.configure_for_level({"map_mechanism_ids": [Defs.SCARAB], "boss_enhanced_map_mechanism_id": Defs.SCARAB})
	controller.start_business()
	manager.configure_for_order_group({"boss_enhanced_map_mechanism_id": Defs.SCARAB})
	manager.spawn_scheduled_boss()
	var boss: Node = get_first_node_in_group("scorpion_bosses")
	boss.set_physics_process(false)
	# Keep live forage spawning enabled: the earlier route fixture omitted it.
	await physics_frame
	await physics_frame
	var starts: Dictionary = {}
	var arrivals: Dictionary = {}
	var acted: Dictionary = {}
	var departure_deadlines: Dictionary = {}
	var departed: Dictionary = {}
	var missed_departures: Dictionary = {}
	var peak_us := 0
	var sum_us := 0
	var shared_gate_search_seen := false
	# Reproduce the stale central entry target being occupied, without blocking
	# the actual kitchen gate. Incoming scarabs must not depend on this point.
	var blocker := StaticBody2D.new()
	blocker.collision_layer = 4
	blocker.position = map.get_kitchen_zone_bounds().get_center()
	var collision := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 90.0
	collision.shape = shape
	blocker.add_child(collision)
	main.add_child(blocker)
	await physics_frame
	# Seed both controllers and the map so gate obstructions are reproducible.
	# Seeds 1 and 42 cover an initially blocked route and a new obstacle en route.
	controller.rng.seed = sample_seed
	controller.begin_boss_burst(boss)
	for frame in range(2400):
		await physics_frame
		var start := Time.get_ticks_usec()
		controller._process(1.0 / 60.0)
		var elapsed := Time.get_ticks_usec() - start
		peak_us = maxi(peak_us, elapsed)
		sum_us += elapsed
		for cache: Dictionary in controller.navigation_cache.caches.values():
			for gate: Vector2i in cache.gate_trees:
				var search: Dictionary = cache.gate_trees[gate]
				if search.next.size() > 100:
					shared_gate_search_seen = true
					_check(search.next[gate] == gate, "Incoming route search must be rooted at the kitchen gate.")
		for scarab in get_nodes_in_group("scarab_enemies"):
			var scarab_id: int = scarab.get_instance_id()
			if not starts.has(scarab_id):
				starts[scarab_id] = scarab.global_position
				scarab.rng.seed = sample_seed + starts.size()
				scarab.stolen_limit = 2 + starts.size() % 4
				departure_deadlines[scarab_id] = frame + SPAWN_DEPARTURE_DEADLINE_FRAMES
			if not departed.has(scarab_id) and scarab.global_position.distance_to(starts[scarab_id]) > SPAWN_DEPARTURE_DISTANCE:
				departed[scarab_id] = true
			if not departed.has(scarab_id) and not missed_departures.has(scarab_id) and frame >= int(departure_deadlines[scarab_id]):
				_check(false, "Each offscreen scarab must leave its spawn before the deterministic departure deadline.")
				missed_departures[scarab_id] = true
				_diagnose(controller, scarab, starts[scarab_id])
			if map.is_point_in_kitchen_zone(scarab.global_position):
				arrivals[scarab.get_instance_id()] = true
				_check(scarab.current_target_kind != &"entry", "Kitchen entry must switch to food without visiting the old central point.")
			if scarab.get_state() == scarab.State.STEALING or scarab.get_stolen_count() > 0:
				acted[scarab.get_instance_id()] = true
	_check(starts.size() == 5 and arrivals.size() == 5 and acted.size() == 5 and departed.size() == 5, "All five summoned scarabs must leave spawn, reach the kitchen, and steal with live forage and a blocked old entry point.")
	_check(shared_gate_search_seen, "Incoming scarabs must use shared reverse searches rooted at the kitchen gate.")
	_check(peak_us < MAX_TEST_FRAME_USEC, "Scarab controller must not stall a headless test frame for 32ms or longer.")
	print("Live wave seed=%d: spawned=%d departed=%d arrived=%d acted=%d peak_ms=%.2f mean_ms=%.2f" % [sample_seed, starts.size(), departed.size(), arrivals.size(), acted.size(), peak_us / 1000.0, sum_us / 2400000.0])
	if not failures.is_empty():
		for point in get_nodes_in_group("forage_points"):
			var collider: CollisionShape2D = point.get_node("CollisionShape2D")
			print("FORAGE at=%s radius=%s scale=%s" % [collider.global_position, collider.shape.radius, collider.global_scale])
		for scarab in get_nodes_in_group("scarab_enemies"):
			if not acted.has(scarab.get_instance_id()):
				_diagnose(controller, scarab, starts[scarab.get_instance_id()])
	controller.stop_business()
	_check(controller.navigation_cache.caches.is_empty() and controller.navigation_retry_times.is_empty(), "Leaving the day must clear navigation caches and retry state.")
	controller.configure_for_level({"map_mechanism_ids": [Defs.SCARAB], "boss_enhanced_map_mechanism_id": Defs.SCARAB})
	controller.start_business()
	_check(controller.navigation_cache.caches.size() == 2, "Restarted service must prepare fresh kitchen and cross-region navigation.")
	controller.stop_business()
	main.queue_free()
	await process_frame

func _check(condition: bool, message: String) -> void:
	if not condition and not failures.has(message):
		failures.append(message)
		push_error(message)

func _diagnose(controller: Node, scarab: Node2D, spawn: Vector2) -> void:
	print("SCARAB seed=%d spawn=%s now=%s state=%s kind=%s route=%d/%d stuck=%.2f" % [sample_seed, spawn, scarab.global_position, scarab.state, scarab.current_target_kind, scarab.navigation_route_index, scarab.navigation_route.size(), scarab.navigation_stuck_time])
	for bounds: Rect2 in controller.navigation_cache.caches:
		var cache: Dictionary = controller.navigation_cache.caches[bounds]
		print("  CACHE %s published=%s scan=%d/%d trees=%d" % [bounds, cache.grid != null, cache.cursor, cache.size.x * cache.size.y, cache.gate_trees.size()])
		for gate: Vector2i in cache.gate_trees:
			var tree: Dictionary = cache.gate_trees[gate]
			var start: Vector2i = controller._get_navigation_cell(bounds.position, cache.cell_size, cache.size, scarab.global_position)
			print("  GATE %s visited=%d complete=%s start=%s reached=%s" % [gate, tree.next.size(), tree.complete, start, tree.next.has(start)])
