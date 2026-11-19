extends SceneTree

const Boss = preload("res://Scripts/Enemies/MapMechanismBoss.gd")
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
	var map: Node2D = main.get_node("PrototypeMap")
	var arena: Rect2 = map.get_region_bounds(&"top")
	var player: Node2D = main.get_node("Player")
	player.global_position = map.get_kitchen_zone_bounds().get_center()
	var controller: Node = main.get_node("ScarabMechanismController")
	controller.configure_for_level({"map_mechanism_ids": [Defs.SCARAB], "boss_enhanced_map_mechanism_id": Defs.SCARAB})
	var scorpion: Boss
	for scene in ["sandworm_boss", "scorpion_boss"]:
		var boss: Boss = load("res://Scenes/Enemies/%s.tscn" % scene).instantiate()
		main.add_child(boss)
		_stop_ticks(boss)
		boss.global_position = arena.get_center()
		boss.setup_for_battle(&"meat_red", arena)
		var bounds := boss._get_safe_arena_bounds()
		var positions: Array[Vector2] = [bounds.position, bounds.end, Vector2(bounds.position.x, bounds.end.y), Vector2(bounds.end.x, bounds.position.y), Vector2(bounds.get_center().x, bounds.end.y)]
		for point in positions:
			boss.global_position = point
			_check(map.is_point_in_playable_area(point, Vector2.ONE * boss.hit_radius), "Boss safe edge must not intersect map walls: " + scene)
			for i in range(8):
				var before := boss.global_position
				boss._move_in_arena(Vector2.RIGHT.rotated(i * TAU / 8.0) * 12.0)
				_check(boss.global_position.distance_to(before) <= 12.1, "Edge movement must never snap the boss: " + scene)
				_check(boss.global_position.is_equal_approx(boss._safe_arena_point(boss.global_position)), "Boss must remain in its safe arena: " + scene)
		_check(arena.end.y - bounds.end.y - boss.contact_damage_radius >= 200.0, "Boss must leave an exit approach clear: " + scene)
		if scene == "sandworm_boss":
			boss.queue_free()
		else:
			scorpion = boss
	await physics_frame
	scorpion.global_position = arena.get_center()
	# No periodic spawning on a living scorpion's day, before or after service starts.
	controller._process(60.0)
	_check(get_nodes_in_group("scarab_enemies").is_empty(), "Preparation must not generate scarabs.")
	controller.start_business()
	controller._process(60.0)
	_check(get_nodes_in_group("scarab_enemies").is_empty(), "Boss-day scarabs must wait for an active summon skill.")
	scorpion._physics_process(0.01)
	_check(scorpion.attack == Boss.Attack.SUMMON and scorpion.state == Boss.AttackState.WINDUP, "Boss must visibly cast summon even while the player is in the kitchen.")
	scorpion._physics_process(1.41)
	_check(controller.burst_remaining == 5, "Completed first cast must queue five scarabs.")
	controller._tick_boss_burst(0.01)
	_check(get_nodes_in_group("scarab_enemies").size() == 1, "First burst tick must spawn exactly one scarab.")
	controller._tick_boss_burst(1.0)
	_check(get_nodes_in_group("scarab_enemies").size() == 1, "Burst must not spawn several scarabs instantly.")
	for i in range(4):
		controller._tick_boss_burst(2.0)
	_check(get_nodes_in_group("scarab_enemies").size() == 5 and controller.burst_remaining == 0, "First wave must complete as five staggered spawns.")
	for scarab in get_nodes_in_group("scarab_enemies"):
		_check(map.get_battle_region_for_point(scarab.global_position) == &"top", "Summoned scarabs must still spawn in the boss arena.")
		scarab.queue_free()
	await physics_frame
	controller._tick_boss_burst(23.0)
	_check(not controller.can_begin_boss_burst(scorpion), "Wave completion must provide at least 24 seconds of rest.")
	controller._tick_boss_burst(1.01)
	_check(controller.can_begin_boss_burst(scorpion), "Boss may summon again after the rest.")
	# Keep every previous wave alive: survivors must not truncate new waves.
	for expected: int in [5, 6, 6, 7, 7]:
		controller.start_business()
		var before_count := get_nodes_in_group("scarab_enemies").size()
		_check(controller.begin_boss_burst(scorpion), "A new order wave must preserve summon progression and allow the next cast.")
		_check(controller.burst_remaining == expected, "Summon sequence must be 5,5,6,6,7,7.")
		for i in range(expected):
			controller._tick_boss_burst(2.0)
			for scarab in get_nodes_in_group("scarab_enemies"):
				_stop_ticks(scarab)
		_check(get_nodes_in_group("scarab_enemies").size() - before_count == expected, "Each growing wave must fully spawn with earlier survivors present.")
		_check(controller.burst_remaining == 0, "Full wave must finish.")
		controller._tick_boss_burst(24.01)
	# All three combat attacks emit distinct effects at their locked impact position.
	player.global_position = arena.get_center() + Vector2(180, 0)
	for kind in [Boss.Attack.STING, Boss.Attack.SWEEP, Boss.Attack.LEAP]:
		scorpion.global_position = arena.get_center()
		scorpion.start_attack(kind)
		scorpion.state_remaining = scorpion.windup_total * 0.25
		scorpion._update_visuals()
		var before := get_nodes_in_group("scorpion_skill_effects").size()
		scorpion._resolve_attack()
		_check(get_nodes_in_group("scorpion_skill_effects").size() == before + 1, "Every scorpion strike must create an impact effect.")
	player.global_position = Vector2(arena.get_center().x, arena.end.y - 10.0)
	scorpion.start_attack(Boss.Attack.LEAP)
	var landing := scorpion.attack_target
	_check(landing.y <= scorpion._get_safe_arena_bounds().end.y, "Leap must not target the exit or walls.")
	scorpion._resolve_attack()
	var landed := scorpion.global_position
	scorpion._move_in_arena(Vector2.DOWN)
	_check(scorpion.global_position.distance_to(landed) <= 1.01, "First movement after leap must not snap back from the edge.")
	controller.begin_boss_burst(scorpion)
	scorpion.receive_hit(scorpion.max_health)
	controller._process(0.01)
	_check(controller.burst_remaining == 0, "Boss death must cancel pending summoned scarabs.")
	controller.stop_business()
	_check(controller.burst_rest_remaining == 0.0, "Day reset must clear summon timing.")
	_check(controller.boss_burst_number == 0 and controller.boss_burst_capacity == 0, "Day reset must clear summon escalation and capacity.")
	main.queue_free()
	await process_frame
	if failures.is_empty():
		print("PASS: both bosses' map edges and exit clearance, safe leap landing, scorpion effects, active summons from kitchen, staggered waves/rest and lifecycle cleanup.")
	quit(0 if failures.is_empty() else 1)

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error(message)
