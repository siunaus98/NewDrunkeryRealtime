extends SceneTree

const Sand = preload("res://Scripts/Hazards/QuicksandHazard.gd")
const Boss = preload("res://Scripts/Enemies/MapMechanismBoss.gd")
const Context = preload("res://Scripts/Core/LevelContext.gd")
const Defs = preload("res://Scripts/Core/MapMechanismDefs.gd")
var failures: Array[String] = []

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
	flow.day_transition_active = false
	flow.input_release_guard_active = false
	var manager: Node = main.get_node("BattleManager")
	manager.set_process(false)
	manager.reset_runtime_state()
	for controller_name in ["ScarabMechanismController", "QuicksandMechanismController", "WindSandMechanismController"]:
		main.get_node(controller_name).set_process(false)
	var player: CharacterBody2D = main.get_node("Player")
	player.set_process(false)
	player.set_physics_process(false)
	var map: Node2D = main.get_node("PrototypeMap")
	var arena: Rect2 = map.get_region_bounds(&"top")
	var center := arena.get_center()
	player.global_position = center + Vector2(240, 0)
	var group := {"map_mechanism_ids": Defs.get_all_ids(), "boss_enhanced_map_mechanism_id": Defs.QUICKSAND}
	manager.configure_for_order_group(group)
	flow.run_context = Context.new()
	flow.run_context.initialize(group)
	flow._enter_prepare_phase()
	flow._process(flow.prepare_phase_duration * 0.5 - 0.01)
	_check(not manager.has_active_boss(), "Boss must not appear before preparation midpoint.")
	flow._process(0.02)
	_check(manager.has_active_boss(), "Boss must appear at preparation midpoint.")
	var worm: Boss = get_first_node_in_group("sandworm_bosses") as Boss
	if worm == null:
		quit(1)
		return
	worm.set_physics_process(false)
	worm.global_position = center - Vector2(220, 0)
	flow._process(0.1)
	manager.start_wave(0, {}, group)
	_check(get_nodes_in_group("map_mechanism_bosses").size() == 1, "Preparation and first wave must share the same boss.")
	manager.set_process(false)
	var light_damage := int(round(player.attack_damage * player.light_attack_damage_multiplier))
	var ideal_seconds: float = float(worm.max_health) / float(light_damage) * player.attack_cooldown
	_check(ideal_seconds >= 60.0 and ideal_seconds <= 90.0, "Sandworm must require 60-90 seconds of uninterrupted base light attacks.")
	for enemy_id in [&"chaser", &"sprinter", &"slammer", &"ranged", &"bullet_fan", &"bruiser", &"sniper", &"splitter", &"orbiter"]:
		var enemy: Node2D = manager._get_enemy_scene_for_id(enemy_id).instantiate()
		main.add_child(enemy)
		enemy.process_mode = Node.PROCESS_MODE_DISABLED
		enemy.receive_hit(light_damage)
		_check(enemy.current_health > 0, "Base light attack must not one-shot %s." % enemy_id)
		_check(enemy.max_health >= 240 and enemy.max_health <= 620, "Ordinary enemy health must use the rescaled range.")
		for property in ["contact_damage", "dash_damage", "slam_damage", "projectile_damage", "bullet_damage", "lingering_hazard_damage"]:
			if enemy.get(property) != null:
				_check(int(enemy.get(property)) >= 10 and int(enemy.get(property)) <= 30, "%s damage must use the rescaled range." % enemy_id)
		enemy.queue_free()
	print("Sandworm ideal light-attack time: %.1f seconds." % ideal_seconds)

	worm.start_attack(Boss.Attack.SLAM)
	worm.state_remaining = worm.windup_total * 0.3
	worm._update_visuals()
	_check(worm.sprite.position.y < worm.base_sprite_position.y - 100.0, "Slam must visibly rear up.")
	worm.state_remaining = 0.0
	worm._update_visuals()
	_check((worm.sprite.position - worm.base_sprite_position).dot(worm.attack_direction) > 140.0, "Slam must strike forward before impact.")
	worm._resolve_attack()
	worm._update_visuals()
	_check(worm.sprite.scale.y < worm.base_sprite_scale.y, "Slam impact must visibly compress the boss.")
	worm.impact_remaining = 0.0
	worm._update_visuals()
	_check(worm.sprite.position == worm.base_sprite_position and worm.sprite.scale == worm.base_sprite_scale, "Slam recovery must restore the sprite.")

	var controller: Node = main.get_node("QuicksandMechanismController")
	controller.configure_for_level(group)
	controller.rng.seed = 101
	player.global_position = center
	_check(controller.spawn_boss_quicksand(worm), "Boss must be able to create empowered quicksand in the real arena.")
	var spawned: Sand = get_first_node_in_group("quicksand_hazards") as Sand
	if spawned != null:
		spawned.set_physics_process(false)
		_check(spawned.radius == 400.0 and spawned.warning_remaining == 0.8, "Empowered pool must provide a 0.8-second warning.")
		_check(is_equal_approx(spawned.lifetime_remaining, spawned.lifetime), "Random lifetime must be applied before ready.")
		spawned.queue_free()
	await physics_frame

	var sand := Sand.new()
	sand.position = center
	sand.lifetime = 100.0
	sand.configure_boss(worm, 400.0, 0.8, 180.0)
	main.add_child(sand)
	sand.set_physics_process(false)
	player.global_position = center + Vector2(250, 0)
	player.quicksand_pull_velocity = Vector2.ZERO
	var health_before: int = player.combat_controller.current_health
	sand._physics_process(0.79)
	player._physics_process(1.0 / 60.0)
	_check(absf(player.global_position.distance_to(center) - 250.0) < 0.2 and not sand.spawn_pull_applied, "Warning must not pull the player before 0.8 seconds.")
	_check(player.combat_controller.current_health == health_before, "Warning must not damage the player.")
	sand._physics_process(0.02)
	player._physics_process(1.0 / 60.0)
	_check(absf(player.global_position.distance_to(center) - 70.0) < 0.2, "Warning expiry must pull the real player 180 pixels.")
	sand._physics_process(1.0 / 60.0)
	_check(player.quicksand_spawn_motion == Vector2.ZERO and player.quicksand_pull_velocity.length() > 0.0, "Following ticks must apply sustained suction without repeating the impulse.")
	player.quicksand_pull_velocity = Vector2.ZERO
	# A player who leaves during the warning must avoid the activation pull.
	var escaped_sand := Sand.new()
	escaped_sand.position = center
	escaped_sand.configure_boss(worm, 400.0, 0.8, 180.0)
	main.add_child(escaped_sand)
	escaped_sand.set_physics_process(false)
	player.global_position = center + Vector2(250, 0)
	escaped_sand._physics_process(0.79)
	player.global_position = center + Vector2(410, 0)
	escaped_sand._physics_process(0.02)
	_check(player.quicksand_spawn_motion == Vector2.ZERO, "Leaving the pool during its warning must avoid the pull.")
	escaped_sand.queue_free()
	player.global_position = center + Vector2(25, 0)
	player.apply_quicksand_spawn_pull(center, 180.0)
	player._physics_process(1.0 / 60.0)
	_check(player.global_position.distance_to(center) < 0.2, "Birth pull must stop at the center rather than overshoot.")

	var blocker := StaticBody2D.new()
	blocker.position = center + Vector2(100, 0)
	blocker.collision_layer = player.collision_mask
	var collider := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(20, 180)
	collider.shape = shape
	blocker.add_child(collider)
	main.add_child(blocker)
	await physics_frame
	player.global_position = center + Vector2(200, 0)
	player.apply_quicksand_spawn_pull(center, 180.0)
	player._physics_process(1.0 / 60.0)
	_check(player.global_position.x > center.x + 110.0 and player.global_position.x < center.x + 200.0, "Birth pull must stop at a wall instead of passing through it.")
	blocker.queue_free()
	await physics_frame
	worm.global_position = center - Vector2(600, 0)
	sand.warning_remaining = 0.0
	var old_rate := Engine.physics_ticks_per_second
	for rate in [30, 60, 120]:
		Engine.physics_ticks_per_second = rate
		player.global_position = center + Vector2(6, 3)
		player.quicksand_pull_velocity = Vector2.ZERO
		player.combat_controller.current_health = 100
		player.set_physics_process(true)
		sand.set_physics_process(true)
		var previous := player.global_position - center
		var stable := true
		for frame in range(rate * 2):
			await physics_frame
			var offset := player.global_position - center
			if offset.length() > previous.length() + 0.01 or offset.dot(previous) < -0.0001:
				stable = false
			previous = offset
		player.set_physics_process(false)
		sand.set_physics_process(false)
		_check(stable and previous.length() < 0.2, "Real player must converge without oscillation at %d physics FPS." % rate)
	Engine.physics_ticks_per_second = old_rate
	_check(player.sprite.position == player.combat_controller.base_sprite_position and player.sprite.scale == player.combat_controller.base_sprite_scale, "Quicksand damage must not shake or squash the sprite.")
	player.quicksand_pull_velocity = Vector2.ZERO
	player.apply_quicksand_pull(Vector2(-300, 0))
	player.apply_quicksand_pull(Vector2(-300, 0))
	_check(player.quicksand_pull_velocity.length() == 300.0, "Overlapping pools must not stack their forces.")
	player.quicksand_pull_velocity = Vector2.ZERO
	player.global_position = center + Vector2(0.1, 0)
	player.combat_controller.reset_temporary_state()
	player.combat_controller.try_dash(Vector2.RIGHT, Vector2.RIGHT)
	player.set_physics_process(true)
	sand.set_physics_process(true)
	for frame in range(int(ceil(player.dash_duration * old_rate))):
		await physics_frame
		player.combat_controller.tick_cooldowns(1.0 / old_rate)
	player.set_physics_process(false)
	sand.set_physics_process(false)
	_check(player.global_position.distance_to(center) > sand.center_soft_radius, "One outward dash must escape the center's strong pull zone.")
	Input.action_press("move_right")
	player.set_physics_process(true)
	sand.set_physics_process(true)
	for frame in range(old_rate * 2):
		await physics_frame
	Input.action_release("move_right")
	player.set_physics_process(false)
	sand.set_physics_process(false)
	_check(player.global_position.distance_to(center) > sand.radius, "Dash followed by outward movement must escape the entire empowered pool.")
	worm.state = Boss.AttackState.ACTIVE
	worm.receive_hit(worm.max_health)
	_check(sand.radius == sand.normal_radius and sand.boss_owner == null, "Boss death must remove all existing pool enhancements.")
	main.queue_free()
	await process_frame
	if failures.is_empty():
		print("PASS: preparation timing, enemy durability, slam animation, real boss pool, one-shot collision-safe pull, center stability at 30/60/120 Hz, dash escape and cleanup.")
	quit(0 if failures.is_empty() else 1)

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error(message)
