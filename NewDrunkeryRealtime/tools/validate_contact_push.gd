extends SceneTree

var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var main: Node = load("res://Scenes/Main/main.tscn").instantiate()
	root.add_child(main)
	await physics_frame
	await physics_frame
	paused = false
	_stop_ticks(main)
	var player: CharacterBody2D = main.get_node("Player")
	var map: Node2D = main.get_node("PrototypeMap")
	var center: Vector2 = map.get_region_bounds(&"top").get_center()
	var forage: StaticBody2D = load("res://Scenes/Forage/forage_point.tscn").instantiate()
	forage.position = center
	main.add_child(forage)
	_stop_ticks(forage)
	await physics_frame
	var player_shape: CollisionShape2D = player.get_node("CollisionShape2D")
	var forage_shape: CollisionShape2D = forage.get_node("CollisionShape2D")
	var obstacle_center := forage_shape.global_position
	var separation: float = player_shape.shape.radius + forage_shape.shape.radius
	# The longest sweep also catches tunnelling completely through the obstacle.
	for i in range(8):
		var direction := Vector2.RIGHT.rotated(i * TAU / 8.0)
		for distance in [12.0, 26.0, 34.0, 42.0, 240.0]:
			player.position = obstacle_center - direction * (separation + 6.0) - player_shape.position
			for repeat in range(4):
				player.apply_contact_push(direction, distance)
				_check(player_shape.global_position.distance_to(obstacle_center) >= separation - 0.05, "Repeated enemy knockback must not penetrate a forage point (%d, %.0f)." % [i, distance])
				_check((player_shape.global_position - obstacle_center).dot(direction) < 0.0, "Knockback must not tunnel through the forage point.")
			var before := player.position
			player.move_and_collide(-direction * 20.0)
			_check(player.position.distance_to(before) > 19.0, "Player must remain free to move away from the forage point.")
	player.position = center + Vector2(300, 200)
	var start := player.position
	player.apply_contact_push(Vector2.RIGHT, 42.0)
	_check(player.position.distance_to(start + Vector2(42, 0)) < 0.05, "Unobstructed knockback must preserve its full distance.")
	var wall := StaticBody2D.new()
	wall.position = center + Vector2(600, 200)
	wall.collision_layer = 4
	var wall_shape := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = Vector2(16, 200)
	wall_shape.shape = rectangle
	wall.add_child(wall_shape)
	main.add_child(wall)
	await physics_frame
	player.position = wall.position - Vector2(70, 0) - player_shape.position
	player.apply_contact_push(Vector2.RIGHT, 200.0)
	_check(player_shape.global_position.x <= wall.position.x - 8.0 - player_shape.shape.radius + 0.05, "Long knockback must also stop before thin walls.")
	var boss: Node2D = load("res://Scenes/Enemies/sandworm_boss.tscn").instantiate()
	main.add_child(boss)
	_stop_ticks(boss)
	boss.position = center
	boss.movement_bounds = map.get_region_bounds(&"top")
	player.position = center + Vector2(250, 0)
	var original_center: Vector2 = boss.get_hit_position()
	_check(original_center.is_equal_approx(boss.sprite.to_global(Vector2(7, 2))), "Worm hit center must use the visible body's local center.")
	boss.start_attack(boss.Attack.SLAM)
	boss.state_remaining = boss.windup_total * 0.3
	boss._update_visuals()
	_check(boss.get_hit_position().y < original_center.y - 100.0, "Hit center must follow the raised sprite during slam.")
	boss._resolve_attack()
	boss._update_visuals()
	_check((boss.get_hit_position() - original_center).dot(boss.attack_direction) > 140.0, "Hit center must follow the body forward at impact.")
	boss.impact_remaining = 0.0
	boss._update_visuals()
	_check(boss.get_hit_position().is_equal_approx(original_center), "Hit center must recover with the sprite.")
	forage.queue_free()
	await physics_frame
	boss.state = boss.AttackState.ACTIVE
	boss.attack_remaining = 100.0
	boss.contact_cooldown_remaining = 0.0
	player.combat_controller.reset_temporary_state()
	var sort_offset: Vector2 = player.get_sort_origin() - player.global_position
	player.global_position = boss.get_hit_position() + Vector2(150, 0) - sort_offset
	boss._physics_process(0.01)
	_check(player.combat_controller.current_health == 100, "Space between 140px contact and 160px hit radius must be safe.")
	player.global_position = boss.get_hit_position() + Vector2(139, 0) - sort_offset
	var contact_start := player.global_position
	boss._physics_process(0.01)
	_check(player.combat_controller.current_health == 90, "Touching the worm must deal 10 damage.")
	_check(player.global_position.x > contact_start.x + 30.0, "Contact damage must push the player away safely.")
	player.global_position = boss.get_hit_position() + Vector2(130, 0) - sort_offset
	player.combat_controller.tick_cooldowns(0.4)
	boss._physics_process(0.4)
	_check(player.combat_controller.current_health == 90, "Continuous contact must respect the boss damage interval.")
	player.combat_controller.tick_cooldowns(0.41)
	boss._physics_process(0.41)
	_check(player.combat_controller.current_health == 80, "Continuous contact must damage again after the interval.")
	player.combat_controller.reset_temporary_state()
	boss.contact_cooldown_remaining = 0.0
	player.global_position = boss.get_hit_position() + Vector2(100, 0) - sort_offset
	boss._damage_player(30, Vector2.RIGHT)
	boss._try_contact_damage()
	_check(player.combat_controller.current_health == 70, "Skill hits must not stack with body damage on the same tick.")
	boss.contact_cooldown_remaining = 0.0
	player.combat_controller.reset_temporary_state()
	player.combat_controller.contact_immunity_remaining = 0.2
	contact_start = player.global_position
	boss._try_contact_damage()
	_check(player.combat_controller.current_health == 100 and player.global_position == contact_start, "Contact immunity must prevent both damage and push.")
	boss.is_dead = true
	player.combat_controller.contact_immunity_remaining = 0.0
	boss._try_contact_damage()
	_check(player.combat_controller.current_health == 100, "Dead worm must not cause contact damage.")
	main.queue_free()
	await process_frame
	if failures.is_empty():
		print("PASS: collision-safe knockback, animated worm hit center, smaller contact radius, damage interval, immunity and no skill/contact double hit.")
	quit(0 if failures.is_empty() else 1)

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error(message)

func _stop_ticks(node: Node) -> void:
	node.set_process(false)
	node.set_physics_process(false)
	for child in node.get_children():
		_stop_ticks(child)
