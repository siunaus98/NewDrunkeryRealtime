extends SceneTree

const Boss = preload("res://Scripts/Enemies/MapMechanismBoss.gd")
const Wave = preload("res://Scripts/Hazards/SandstormWave.gd")
const Defs = preload("res://Scripts/Core/MapMechanismDefs.gd")
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
	var arena: Rect2 = map.get_region_bounds(&"top")
	var center := arena.get_center()
	var scorpion: Boss = load("res://Scenes/Enemies/scorpion_boss.tscn").instantiate()
	main.add_child(scorpion)
	_stop_ticks(scorpion)
	scorpion.setup_for_battle(&"meat_red", arena)
	scorpion.position = center - Vector2(300, 0)
	player.position = center
	player.reset_temporary_state()
	scorpion.start_attack(Boss.Attack.LEAP)
	var before := player.position
	scorpion._resolve_attack()
	_check(player.position.distance_to(before) > 170.0, "Scorpion leap must push a hit player out of contact range.")
	_check(player.combat_controller.current_health == 70, "Leap applies only its 30 damage.")
	scorpion._try_contact_damage()
	_check(player.combat_controller.current_health == 70 and scorpion.contact_cooldown_remaining >= 1.35, "Leap protects against immediate body damage, even if knockback is blocked.")
	scorpion.queue_free()
	await physics_frame
	var worm: Boss = load("res://Scenes/Enemies/sandworm_boss.tscn").instantiate()
	main.add_child(worm)
	_stop_ticks(worm)
	worm.setup_for_battle(&"meat_red", arena)
	worm.position = center - Vector2(300, 0)
	player.position = center
	player.reset_temporary_state()
	var sand_controller: Node = main.get_node("QuicksandMechanismController")
	sand_controller.configure_for_level({"map_mechanism_ids": [Defs.QUICKSAND]})
	worm.start_attack(Boss.Attack.TAIL)
	var strike_point := worm.attack_target
	worm._resolve_attack()
	var tails := get_nodes_in_group("sandworm_tail_strikes")
	_check(tails.size() == 1, "Each tail strike creates one independent emergence.")
	var tail: Node2D = tails[0]
	_stop_ticks(tail)
	_check(tail.global_position.is_equal_approx(strike_point), "Tail stays at its advertised impact point after the next strike locks.")
	tail._physics_process(0.9)
	_check(get_nodes_in_group("quicksand_hazards").is_empty(), "Tail must finish retracting and wait before creating sand.")
	tail._physics_process(0.2)
	var pools := get_nodes_in_group("quicksand_hazards")
	_check(pools.size() == 1, "Delayed tail creates its small pool.")
	var pool: Node2D = pools[0]
	_stop_ticks(pool)
	_check(pool.radius == 110.0 and pool.spawn_pull_distance == 0.0, "Tail pool must be small and have no initial impulse.")
	player.position = strike_point + Vector2(70, 0)
	player.quicksand_pull_velocity = Vector2.ZERO
	player.quicksand_spawn_motion = Vector2.ZERO
	pool._physics_process(0.79)
	_check(player.quicksand_pull_velocity == Vector2.ZERO and player.quicksand_spawn_motion == Vector2.ZERO, "Pool warning cannot drag the player.")
	pool._physics_process(0.02)
	_check(player.quicksand_pull_velocity.length() > 0.0 and player.quicksand_spawn_motion == Vector2.ZERO, "Activated tail pool uses only sustained suction.")
	worm.state = Boss.AttackState.ACTIVE
	worm.receive_hit(worm.max_health)
	_check(pool.is_queued_for_deletion(), "Worm death clears tail pools.")
	await physics_frame
	var manager: Node = main.get_node("BattleManager")
	manager.reset_runtime_state()
	manager.configure_for_order_group({"boss_enhanced_map_mechanism_id": Defs.SANDSTORM})
	manager.spawn_scheduled_boss()
	var vulture: Boss = get_first_node_in_group("vulture_bosses") as Boss
	_check(vulture != null and not vulture.is_in_group("sandworm_bosses"), "Wind pairing must spawn a distinct vulture without worm pressure.")
	_stop_ticks(vulture)
	vulture.position = center - Vector2(500, 0)
	player.position = map.get_kitchen_zone_bounds().get_center()
	var wind_controller: Node = main.get_node("WindSandMechanismController")
	wind_controller.configure_for_level({"map_mechanism_ids": [Defs.SANDSTORM]})
	await _check_pressure_routes(vulture, map, player, main.get_node("Camera2D"))
	player.reset_temporary_state()
	player.quicksand_pull_velocity = Vector2.ZERO
	player.position = center - Vector2(300, 0)
	var wave: Node2D = vulture.vulture_skills.spawn_wave(player.position, Vector2.RIGHT, 128.0, 1200.0, 1.5)
	_stop_ticks(wave)
	wave._physics_process(1.49)
	_check(not player.storm_controller.blocks_actions() and player.combat_controller.current_health == 100, "Wave warning must have no knockback or damage.")
	wave._physics_process(0.02)
	wave._physics_process(0.01)
	_check(player.storm_controller.distance_remaining == 620.0, "Touching an active wave launches exactly one pad distance.")
	before = player.position
	for i in range(40):
		player._physics_process(1.0 / 60.0)
	_check(absf(player.position.distance_to(before) - 620.0) < 0.1, "Open flight must travel 620 pixels without overshoot.")
	_check(player.combat_controller.current_health == 100 and player.storm_controller.stun_remaining == 0.0, "Open landing must not count as a crash.")
	wave.queue_free()
	var wall := StaticBody2D.new()
	wall.position = center
	wall.collision_layer = 4
	var collider := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = Vector2(12, 260)
	collider.shape = rectangle
	wall.add_child(collider)
	main.add_child(wall)
	await physics_frame
	player.reset_temporary_state()
	player.position = center - Vector2(100, 0)
	_check(player.apply_storm_launch(Vector2.RIGHT, 620.0, 35, 2.0, vulture), "Storm launch starts toward a nearby wall.")
	for i in range(10):
		player._physics_process(1.0 / 60.0)
	_check(player.position.x < wall.position.x - 6.0, "Storm crash cannot tunnel through a thin wall.")
	_check(player.combat_controller.current_health == 65 and player.storm_controller.stun_remaining > 1.7, "One crash causes exactly 35 damage and two seconds of stun.")
	_check(not player.apply_storm_launch(Vector2.RIGHT, 620.0, 35, 2.0, vulture), "Overlapping waves cannot chain-launch a stunned player.")
	before = player.position
	Input.action_press("move_left")
	Input.action_press("dash")
	player._process(0.01)
	player._physics_process(0.1)
	Input.action_release("move_left")
	Input.action_release("dash")
	_check(player.position == before and not player.combat_controller.is_dash_active(), "Stun blocks movement and dash input.")
	player._physics_process(2.1)
	_check(not player.storm_controller.blocks_actions(), "Stun expires and restores control.")
	wall.queue_free()
	await physics_frame
	# A real movable cooker must block flight just like a wall, without becoming
	# penetrable during the crash or trapping the player after stun ends.
	# Isolate the cooker test from the vulture's real blocking silhouette.
	var vulture_before_cooker := vulture.position
	vulture.position = center + Vector2(1000, 700)
	var cooker: StaticBody2D = load("res://Scenes/Restaurant/test_cooker.tscn").instantiate()
	cooker.position = center
	main.add_child(cooker)
	_stop_ticks(cooker)
	await physics_frame
	player.reset_temporary_state()
	player.position = center - Vector2(400, 0)
	player.apply_storm_launch(Vector2.RIGHT, 620.0, 35, 2.0, vulture)
	for i in range(20):
		player._physics_process(1.0 / 60.0)
	_check(player.position.x < center.x and player.combat_controller.current_health == 65, "Real cooker stops storm flight and causes one crash.")
	player._physics_process(2.1)
	before = player.position
	player.move_and_collide(Vector2.LEFT * 30.0)
	_check(player.position.distance_to(before) > 29.0, "Player can move away from the cooker after stun.")
	cooker.queue_free()
	vulture.position = vulture_before_cooker
	await physics_frame
	player.reset_temporary_state()
	player.position = center
	# Locking at windup leaves a real sidestep window for both active skills.
	vulture.start_attack(Boss.Attack.GUST)
	var heading := vulture.attack_direction
	player.position += Vector2(0, 220)
	vulture._resolve_attack()
	wave = get_nodes_in_group("boss_storm_hazards")[0]
	_stop_ticks(wave)
	_check(wave.width == 128.0 and wave.direction == heading, "Active gust is one cell wide and does not retarget after warning.")
	wave.queue_free()
	await physics_frame
	player.position = center
	vulture.start_attack(Boss.Attack.CYCLONE)
	vulture._resolve_attack()
	var cyclone: Node2D = get_first_node_in_group("tracking_sandstorms")
	_stop_ticks(cyclone)
	var initial_speed: float = player.get_current_move_speed()
	cyclone._physics_process(0.01)
	_check(player.combat_controller.current_health == 92 and player.get_current_move_speed() < initial_speed, "Cyclone damages and slows a player inside it.")
	cyclone._physics_process(0.1)
	_check(player.combat_controller.current_health == 92, "Cyclone damage obeys its interval.")
	before = cyclone.position
	player.position += Vector2(450, 0)
	cyclone._physics_process(0.1)
	_check(cyclone.position.distance_to(before) <= 10.01, "Cyclone follows slowly rather than sticking to the player.")
	player.storm_controller.tick(0.1)
	_check(is_equal_approx(player.get_current_move_speed(), initial_speed), "Leaving cyclone restores movement speed.")
	player.position = center
	vulture.start_attack(Boss.Attack.DIVE)
	var landing := vulture.attack_target
	player.position += Vector2(0, 300)
	vulture._resolve_attack()
	_check(vulture.position == landing and player.combat_controller.current_health == 92, "Dive lands at its warning and can be dodged.")
	player.apply_storm_launch(Vector2.RIGHT, 620.0, 35, 2.0, vulture)
	vulture.receive_hit(vulture.max_health)
	player.storm_controller.tick(0.01)
	_check(cyclone.is_queued_for_deletion() and not player.storm_controller.blocks_actions(), "Boss death clears storms and their player state.")
	wind_controller.stop_gameplay()
	_check(player.storm_controller.slows.is_empty(), "End of day clears storm slow state.")
	main.queue_free()
	await process_frame
	if failures.is_empty():
		print("PASS: scorpion leap push, delayed tail sand, vulture pairing/passive/skills, warning safety, swept crash, stun, slow and cleanup.")
	quit(0 if failures.is_empty() else 1)

func _check_pressure_routes(vulture: Boss, map: Node2D, player: CharacterBody2D, camera: Camera2D) -> void:
	var kitchen: Rect2 = map.get_kitchen_zone_bounds()
	var world: Rect2 = map.get_world_bounds()
	var original_zoom := camera.zoom
	var original_position := camera.global_position
	var directions: Dictionary = {}
	var lanes: Dictionary = {}
	vulture.vulture_skills.rng.seed = 1014
	vulture.vulture_skills.tick_pressure(6.9)
	_check(get_nodes_in_group("boss_storm_hazards").is_empty(), "Passive storms must respect the initial delay.")
	for cycle in range(32):
		# Include zoomed-out views at map edges, where off-map alone does not
		# guarantee offscreen. The scene camera is frozen and updated explicitly.
		camera.zoom = original_zoom if cycle % 2 == 0 else Vector2(0.35, 0.35)
		camera.global_position = kitchen.get_center() if cycle % 2 == 0 else world.position
		camera.force_update_scroll()
		var visible: Rect2 = camera.get_canvas_transform().affine_inverse() * camera.get_viewport_rect()
		vulture.vulture_skills.tick_pressure(0.11 if cycle == 0 else 20.0)
		var waves := get_nodes_in_group("boss_storm_hazards")
		_check(waves.size() == 2, "Every passive round must launch exactly two fronts.")
		for wave: Node2D in waves:
			_stop_ticks(wave)
			var heading: Vector2 = wave.direction
			_check(heading in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT], "Passive directions must be cardinal.")
			directions[heading] = true
			var vertical := heading.y != 0.0
			lanes[Vector2(1 if vertical else 0, wave.global_position.x if vertical else wave.global_position.y)] = true
			_check(wave.width == (map.tile_size.x if vertical else map.tile_size.y) * 2.0 and wave.warning_remaining == 0.0, "Passive fronts must be two cells wide with no ground warning.")
			var size := Vector2(wave.width, wave.thickness) if vertical else Vector2(wave.thickness, wave.width)
			var footprint := Rect2(wave.global_position - size * 0.5, size).grow(16.0)
			_check(not footprint.intersects(world) and not footprint.intersects(visible), "The entire front must spawn outside playable land and the camera view.")
			var finish := footprint
			finish.position += heading * wave.travel_distance
			_check(not finish.intersects(world) and not finish.intersects(visible), "The front must leave the far map and camera edge before expiring.")
			var intercept := Vector2(wave.global_position.x, kitchen.get_center().y) if vertical else Vector2(kitchen.get_center().x, wave.global_position.y)
			_check(kitchen.has_point(intercept), "Every passive route must cross the kitchen.")
			player.reset_temporary_state()
			player.global_position = intercept
			var approach: float = (intercept - wave.global_position).dot(heading)
			_check(approach > 256.0 and approach < wave.travel_distance, "The kitchen must lie ahead of the spawn and before the endpoint.")
			wave._physics_process((approach - 180.0) / wave.speed)
			_check(not player.storm_controller.blocks_actions(), "A distant approaching front must not hit early.")
			wave._physics_process(180.0 / wave.speed)
			_check(player.storm_controller.distance_remaining == 620.0 and player.storm_controller.direction == heading, "All four passive directions must reach and launch the kitchen player.")
			wave._physics_process((wave.travel_distance - wave.travelled + 1.0) / wave.speed)
			_check(wave.is_queued_for_deletion(), "A front must clean up at the end of its route.")
		await physics_frame
	_check(directions.size() == 4 and lanes.size() > 32, "Repeated rounds must vary both directions and kitchen lanes.")
	camera.zoom = original_zoom
	camera.global_position = original_position
	camera.force_update_scroll()

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error(message)
