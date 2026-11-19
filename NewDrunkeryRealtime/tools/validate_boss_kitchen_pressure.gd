extends SceneTree

const Defs = preload("res://Scripts/Core/MapMechanismDefs.gd")
const Items = preload("res://Scripts/Kitchen/TestItemDefs.gd")
const Sand = preload("res://Scripts/Hazards/QuicksandHazard.gd")
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _stop_ticks(node: Node) -> void:
	node.set_process(false)
	node.set_physics_process(false)
	for child in node.get_children():
		_stop_ticks(child)

func _run() -> void:
	var main: Node = load("res://Scenes/Main/main.tscn").instantiate()
	root.add_child(main)
	await physics_frame
	await physics_frame
	paused = false
	_stop_ticks(main)
	var player: CharacterBody2D = main.get_node("Player")
	var map: Node2D = main.get_node("PrototypeMap")
	var controller: Node = main.get_node("QuicksandMechanismController")
	controller.configure_for_level({"map_mechanism_ids": [Defs.QUICKSAND]})
	controller.start_gameplay()
	controller.spawn_remaining = 1000.0
	controller.rng.seed = 1020
	player.global_position = map.get_kitchen_zone_bounds().get_center() + Vector2(180, 260)
	controller._process(30.0)
	_check(get_nodes_in_group("quicksand_hazards").is_empty(), "No worm must mean no kitchen pools.")
	var worm: Node2D = load("res://Scenes/Enemies/sandworm_boss.tscn").instantiate()
	main.add_child(worm)
	_stop_ticks(worm)
	var arena: Rect2 = map.get_region_bounds(&"top")
	worm.global_position = arena.get_center()
	worm.setup_for_battle(&"meat_red", arena)
	controller._process(0.01)
	controller._process(5.0)
	_check(get_nodes_in_group("quicksand_hazards").is_empty(), "First kitchen attack must respect the initial delay.")
	controller._process(1.0)
	var pools := get_nodes_in_group("quicksand_hazards")
	_check(pools.size() == 2, "A living offscreen worm must generate two kitchen pools.")
	_check(player.quicksand_spawn_motion == Vector2.ZERO and not player.is_quicksand_processing_blocked(), "Pool creation must not pull or interrupt the kitchen player.")
	for pool in pools:
		_stop_ticks(pool)
		_check(pool.kitchen_boss_hazard and pool.radius == 160.0 and pool.warning_remaining == 0.8, "Kitchen pool must provide a 0.8-second warning.")
		_check(pool.lifetime_remaining == 8.0 and not pool.spawn_pull_applied, "Kitchen pool must reserve its pull until the warning ends.")
		_check(map.get_kitchen_zone_bounds().grow(-160.0).has_point(pool.global_position), "Whole kitchen pool must fit in kitchen bounds.")
		var query := PhysicsShapeQueryParameters2D.new()
		var shape := CircleShape2D.new()
		shape.radius = 28.0
		query.shape = shape
		query.collision_mask = 4 | 8 | 16
		query.transform = Transform2D(0.0, pool.global_position)
		_check(map.get_world_2d().direct_space_state.intersect_shape(query, 1).is_empty(), "Pool center must not be buried inside a fixture or wall.")
	var health_before: int = player.combat_controller.current_health
	for pool in pools:
		pool._physics_process(0.79)
	_check(player.quicksand_spawn_motion == Vector2.ZERO and player.quicksand_pull_velocity == Vector2.ZERO, "Warning must not apply any pull.")
	_check(player.combat_controller.current_health == health_before and not player.is_quicksand_processing_blocked(), "Warning must not damage or interrupt processing.")
	for pool in pools:
		pool._physics_process(0.02)
	_check(player.quicksand_spawn_motion.length() > 0.0 and player.quicksand_spawn_motion.length() <= 90.01, "Warning expiry must pull the nearby kitchen player at most 90 pixels.")
	controller._prune_hazards()
	for pool in pools:
		_check(not pool.is_queued_for_deletion(), "Battle-zone pruning must preserve kitchen pools.")
	controller.start_gameplay()
	controller.spawn_remaining = 1000.0
	controller._process(24.0)
	_check(get_nodes_in_group("quicksand_hazards").size() == 2, "Existing pools must prevent overlapping extra waves.")
	for pool in pools:
		pool._physics_process(0.01)
		pool._physics_process(8.1)
		_check(pool.is_queued_for_deletion(), "Kitchen pools must expire.")
	await physics_frame
	controller._process(1.1)
	_check(get_nodes_in_group("quicksand_hazards").size() == 2, "Living worm must keep applying kitchen pressure after previous pools expire.")
	for pool in get_nodes_in_group("quicksand_hazards"):
		_stop_ticks(pool)
	# Use real station scenes and the real player's input/processing interfaces.
	player.global_position = arena.get_center() + Vector2(600, 0)
	player.quicksand_spawn_motion = Vector2.ZERO
	player.quicksand_pull_velocity = Vector2.ZERO
	for scene in ["test_cooker", "grind_cooker"]:
		var station: Node = load("res://Scenes/Restaurant/%s.tscn" % scene).instantiate()
		main.add_child(station)
		_stop_ticks(station)
		_reset_pull(player)
		player.clear_held_item()
		_check(player.pick_up_item(Items.TEST_ITEM_ID, null), "Test ingredient must be picked up.")
		_check(station.receive_item_from_player(player), "Real station must receive the ingredient.")
		_check(station.interact_with_player(player), "Manual processing must work before suction.")
		var progress: float = station.process_progress
		Input.action_press("interact")
		var pool := Sand.new()
		pool.kitchen_boss_hazard = true
		pool.position = player.global_position + Vector2(100, 0)
		pool.configure_boss(worm, 160.0, 0.8, 90.0)
		main.add_child(pool)
		_stop_ticks(pool)
		pool._physics_process(0.79)
		_check(station.interact_with_player(player), "Cutting and grinding must remain usable during the warning.")
		progress = station.process_progress
		pool._physics_process(0.02)
		_check(not station.interact_with_player(player), "Birth pull must interrupt both cutting and grinding.")
		_check(not station.process_hold_interaction(player, 0.5), "Held grind must not bypass the interruption.")
		_check(station.process_progress == progress and station.has_item, "Interruption must preserve ingredient and earned progress.")
		_check(station.get_interaction_progress_data(player).is_empty(), "Interrupted manual action must hide player action progress.")
		player._physics_process(0.2)
		_check(not station.interact_with_player(player), "Holding the old key must not auto-resume after the impulse.")
		Input.action_release("interact")
		player._process(0.0)
		_check(station.interact_with_player(player), "Release and restart must resume manual processing.")
		# Ordinary pools must interrupt too, not just kitchen empowered ones.
		_reset_pull(player)
		pool.kitchen_boss_hazard = false
		pool.global_position = player.global_position + Vector2(90, 0)
		pool._physics_process(1.0 / 60.0)
		progress = station.process_progress
		_check(player.quicksand_pull_velocity.length() > 0.0, "Sustained suction must reach the real player.")
		_check(not station.interact_with_player(player) and station.process_progress == progress, "Sustained suction must block both manual processes.")
		_reset_pull(player)
		player.global_position = pool.global_position + Vector2(170, 0)
		pool._physics_process(1.0 / 60.0)
		_check(not player.is_quicksand_processing_blocked(), "Outside the pool must not interrupt processing.")
		pool.queue_free()
		station.queue_free()
		await physics_frame
	_reset_pull(player)
	var escaped_pool := Sand.new()
	escaped_pool.kitchen_boss_hazard = true
	escaped_pool.position = player.global_position + Vector2(100, 0)
	escaped_pool.configure_boss(worm, 160.0, 0.8, 90.0)
	main.add_child(escaped_pool)
	_stop_ticks(escaped_pool)
	escaped_pool._physics_process(0.79)
	player.global_position = escaped_pool.global_position + Vector2(170, 0)
	escaped_pool._physics_process(0.02)
	_check(player.quicksand_spawn_motion == Vector2.ZERO and not player.is_quicksand_processing_blocked(), "Leaving during the warning must avoid the activation pull and interruption.")
	escaped_pool.queue_free()
	var oven: Node = load("res://Scenes/Restaurant/bake_cooker.tscn").instantiate()
	main.add_child(oven)
	_stop_ticks(oven)
	player.clear_held_item()
	player.pick_up_item(Items.TEST_ITEM_ID, null)
	_check(oven.receive_item_from_player(player), "Oven must receive its ingredient.")
	player.apply_quicksand_pull(Vector2(100, 0))
	oven._process(0.5)
	_check(oven.process_progress > 0.0, "Automatic baking must continue while the player is pulled.")
	worm.receive_hit(worm.max_health)
	for pool in get_nodes_in_group("quicksand_hazards"):
		_check(pool.is_queued_for_deletion(), "Killing the worm must immediately remove its kitchen pools.")
	await physics_frame
	controller.spawn_remaining = 1000.0
	controller._process(30.0)
	_check(get_nodes_in_group("quicksand_hazards").is_empty(), "Dead worm must never continue kitchen attacks.")
	controller.stop_gameplay()
	_check(controller.kitchen_boss_owner == null and controller.kitchen_spawn_remaining == 0.0, "Day cleanup must clear kitchen attack timing.")
	Input.action_release("interact")
	main.queue_free()
	await process_frame
	if failures.is_empty():
		print("PASS: offscreen worm kitchen pressure, legal small pools, 0.8s harmless warning, delayed/dodgeable pull, timing/cap/expiry, cutting/grinding interruption and restart, preserved ingredients, baking unaffected, death/day cleanup.")
	quit(0 if failures.is_empty() else 1)

func _reset_pull(player: Node) -> void:
	Input.action_release("interact")
	player.quicksand_processing_block_remaining = 0.0
	player.quicksand_processing_needs_release = false
	player.quicksand_spawn_motion = Vector2.ZERO
	player.quicksand_pull_velocity = Vector2.ZERO

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error(message)
