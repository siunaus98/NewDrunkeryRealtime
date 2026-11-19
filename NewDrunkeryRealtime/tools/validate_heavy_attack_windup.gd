extends SceneTree

var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error(message)

func stop_ticks(node: Node) -> void:
	node.set_process(false)
	node.set_physics_process(false)
	for child: Node in node.get_children():
		stop_ticks(child)

func _run() -> void:
	var main: Node = load("res://Scenes/Main/main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	await process_frame
	paused = false
	stop_ticks(main)
	var player: Node2D = main.get_node("Player")
	player.global_position = Vector2(10000, 10000)
	var combat: RefCounted = player.combat_controller
	var shape: Dictionary = {"direction": Vector2.RIGHT, "inner_radius": 0.0, "outer_radius": 200.0, "angle_degrees": 180.0}
	var any_zone: Callable = func(_point: Vector2) -> bool: return true
	for scene_name: String in ["pig_enemy", "ranged_enemy", "slam_enemy", "bullet_hell_enemy"]:
		var enemy: Node2D = load("res://Scenes/Enemies/%s.tscn" % scene_name).instantiate()
		main.add_child(enemy)
		stop_ticks(enemy)
		enemy.global_position = player.global_position + Vector2(70, -34)
		enemy.movement_bounds = Rect2(Vector2(9000, 9000), Vector2(2000, 2000))
		enemy.current_health = 10000
		enemy._start_windup(Vector2.LEFT if scene_name == "pig_enemy" else player.global_position)
		var windup: int = enemy.attack_state
		var warning: Node2D = enemy.warning_circle if scene_name == "slam_enemy" else enemy.telegraph
		for charge: float in [0.5, 1.0]:
			var health_before: int = enemy.current_health
			var time_before: float = enemy.state_time_remaining
			var queue_before: Array = enemy.bullet_queue.duplicate(true) if scene_name == "bullet_hell_enemy" else []
			combat._apply_attack_hit(shape, any_zone, charge)
			var expected: int = roundi(combat.get_current_attack_damage() * lerpf(combat.heavy_damage_multiplier_min, combat.heavy_damage_multiplier_max, charge))
			check(health_before - enemy.current_health == expected, "%s heavy damage unchanged, with no interrupt bonus" % scene_name)
			check(enemy.attack_state == windup and enemy.state_time_remaining == time_before and warning.visible, "%s heavy hit preserves windup timer and warning" % scene_name)
			if scene_name == "bullet_hell_enemy":
				check(enemy.bullet_queue == queue_before, "Heavy hit preserves queued barrage")
		# Advance the surviving enemy's original windup through its actual state logic.
		for tick in range(100):
			enemy._process(0.1)
			enemy._physics_process(0.016)
			if enemy.attack_state != windup:
				break
		check(enemy.attack_state != windup, "%s completes its attack after being hit" % scene_name)
		enemy.free()
	var scarab: Node2D = load("res://Scripts/Enemies/ScarabEnemy.gd").new()
	main.add_child(scarab)
	stop_ticks(scarab)
	scarab.global_position = player.global_position + Vector2(70, -34)
	combat._apply_attack_hit(shape, any_zone, 1.0)
	check(scarab.is_dead, "Heavy hit still kills a vulnerable scarab")
	await process_frame
	main.queue_free()
	await process_frame
	print("HEAVY ATTACK WINDUP: %d failures; partial/full heavy damage, four enemy windups, warnings, barrage queue, attack completion and scarab kill" % failures.size())
	quit(0 if failures.is_empty() else 1)
