extends SceneTree

const Boss = preload("res://Scripts/Enemies/MapMechanismBoss.gd")
var failures: Array[String] = []

class PracticePlayer extends Node2D:
	var hits: int = 0
	var damage: int = 0
	func take_damage(amount: int, _direction: Vector2, _kind: StringName) -> bool:
		hits += 1
		damage += amount
		return true

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

func reset(boss: Boss, point: Vector2, monitor: bool) -> void:
	boss.global_position = point
	boss.state = Boss.AttackState.ACTIVE
	boss.state_remaining = 0
	boss.attack_remaining = 1000
	boss.combat_movement.blocked_time = 0
	boss.combat_movement.turn_cooldown = 0
	boss.combat_movement.orbit_side = 1
	if monitor:
		boss.facing = Vector2.RIGHT
		boss.bait.clear()
		boss.scan_remaining = 1000
		boss.tongue.cooldown = 1000
		boss.facility_tongue.cooldown = 1000
		boss.bite_remaining = 1000

func check_bite(boss: Boss, actor: PracticePlayer, center: Vector2) -> void:
	reset(boss, center, true)
	actor.global_position = center + Vector2(260, 0)
	boss.bite_remaining = 0
	boss._physics_process(0.01)
	check(boss.attack == Boss.Attack.BITE and boss.state == Boss.AttackState.WINDUP, "Monitor starts a ready close-range bite without waiting for major skill cooldown")
	var direction: Vector2 = boss.attack_direction
	check(boss.attack_contains_point(center + direction * 290) and not boss.attack_contains_point(center - direction * 200) and not boss.attack_contains_point(center + direction.orthogonal() * 200), "Bite covers its forward warning but leaves rear and side escape routes")
	var hits := actor.hits
	var damage := actor.damage
	boss._physics_process(0.54)
	check(actor.hits == hits, "Bite cannot damage before its first warning expires")
	boss._physics_process(0.02)
	check(actor.hits == hits + 1 and actor.damage == damage + boss.bite_damage, "First bite deals exactly its skill damage without simultaneous contact")
	actor.global_position = center - direction * 260
	boss._physics_process(0.36)
	check(actor.hits == hits + 1 and boss.facing.is_equal_approx(direction), "Dodging behind avoids the second bite; committed bite cannot track player")
	check(boss.state == Boss.AttackState.RECOVERY and boss.bite_remaining > 3.9 and boss.attack_remaining > 990, "Double bite finishes with recovery/cooldown and preserves major attack timer")
	var recovery_point := boss.global_position
	boss._physics_process(0.8)
	check(boss.state == Boss.AttackState.RECOVERY and boss.global_position.is_equal_approx(recovery_point) and boss.facing.is_equal_approx(direction), "Bite leaves a full one-second stationary rear opening without turning or attacking")
	# Staying in front is dangerous for both pulses, rather than a cosmetic combo.
	reset(boss, center, true)
	actor.global_position = center + Vector2(260, 0)
	boss.start_attack(Boss.Attack.BITE)
	hits = actor.hits
	boss._physics_process(0.56)
	boss._physics_process(0.36)
	check(actor.hits == hits + 2, "Both bites hit a player who remains inside the warning")
	# Complete live combat: minor attacks recur without starving the major cycle.
	reset(boss, center, true)
	boss.bite_remaining = 0
	boss.attack_remaining = 1
	boss.cycle_index = 0
	var bites := 0
	for frame in range(2400):
		# Stay in front at melee reach, so each ready bite has a valid target.
		actor.global_position = boss.global_position + boss.facing * 260
		var was_bite := boss.state == Boss.AttackState.WINDUP and boss.attack == Boss.Attack.BITE
		boss._physics_process(1.0 / 60.0)
		if not was_bite and boss.state == Boss.AttackState.WINDUP and boss.attack == Boss.Attack.BITE:
			bites += 1
	check(bites >= 5 and boss.cycle_index >= 3, "Frequent bites and major attacks both continue across forty seconds")
	print("MONITOR PRESSURE: bites=%d major_skills=%d" % [bites, boss.cycle_index])
	reset(boss, center, true)
	actor.global_position = boss.prototype_map.get_kitchen_zone_bounds().get_center()
	boss.bite_remaining = 0
	boss._physics_process(1)
	check(boss.state == Boss.AttackState.ACTIVE, "Bite never attacks a player outside the arena")

func check_displacement(boss: Boss, actor: PracticePlayer, scene: String, center: Vector2) -> void:
	var skills: Array[int] = [Boss.Attack.RUSH]
	match scene:
		"monitor":
			skills = [Boss.Attack.STING, Boss.Attack.RUSH]
		"scorpion":
			skills = [Boss.Attack.LEAP]
		"vulture":
			skills = [Boss.Attack.DIVE]
	for skill in skills:
		var minimum := boss.rush_min_distance if skill == Boss.Attack.RUSH else boss.leap_min_distance
		for distance: float in [0.0, 30.0, 140.0, 270.0, 700.0]:
			reset(boss, center, scene == "monitor")
			actor.global_position = center + Vector2.RIGHT * distance
			boss.start_attack(skill)
			if skill == Boss.Attack.RUSH:
				check(boss.windup_total >= 0.5 and boss.windup_total <= 0.7, "%s rush has a shorter but readable windup" % scene)
			else:
				check(boss.leap_radius == 240, "%s landing warning uses the enlarged impact radius" % scene)
			check(boss.attack == skill and boss.attack_target.distance_to(center) + 0.1 >= minimum, "%s skill %d has minimum travel at player distance %s" % [scene, skill, distance])
			if scene == "monitor":
				check((boss.attack_target - center).normalized().dot(boss.facing) > 0.999, "Monitor minimum travel must still follow its head")
			# A warning locks its endpoint; moving the player cannot drag it back.
			var target := boss.attack_target
			actor.global_position = center - Vector2(300, 0)
			boss._physics_process(0.05)
			check(boss.attack_target.is_equal_approx(target), "%s displacement endpoint stays locked" % scene)
			boss._resolve_attack()
			for frame in range(300):
				if boss.state != Boss.AttackState.CHARGE:
					break
				boss._physics_process(1.0 / 60.0)
			check(boss.global_position.distance_to(center) + 0.1 >= minimum, "%s actual skill %d completes minimum travel" % [scene, skill])
		if skill != Boss.Attack.RUSH:
			for offset: float in [220.0, 260.0]:
				reset(boss, center, scene == "monitor")
				actor.global_position = center + Vector2(300, 0)
				boss.start_attack(skill)
				actor.global_position = boss.attack_target + Vector2.RIGHT * offset
				var previous_hits := actor.hits
				boss._resolve_attack()
				check(actor.hits == previous_hits + (1 if offset < boss.leap_radius else 0), "%s enlarged landing hits at 220 but leaves outside 240 safe" % scene)
	# Facing the nearby wall must redirect or select a different attack,
	# never produce a shortened displacement or violate the safe arena.
	var bounds := boss._get_safe_arena_bounds()
	var near_edge := Vector2(bounds.end.x - 10, center.y)
	for skill in skills:
		reset(boss, near_edge, scene == "monitor")
		actor.global_position = near_edge + Vector2(5, 0)
		boss.start_attack(skill)
		if scene == "monitor":
			check(boss.attack == Boss.Attack.SWEEP, "Monitor without forward space switches to sweep rather than jumping sideways")
		else:
			check(boss.attack == skill and boss.attack_target.distance_to(near_edge) + 0.1 >= boss._minimum_displacement(), "%s chooses a long-enough safe displacement near wall" % scene)
		check(bounds.grow(0.1).has_point(boss.attack_target), "%s displacement endpoint stays inside safe arena" % scene)

func run() -> void:
	var main: Node = load("res://Scenes/Main/main.tscn").instantiate()
	root.add_child(main)
	await physics_frame
	await physics_frame
	paused = false
	stop_ticks(main)
	main.get_node("Player").remove_from_group("player")
	var actor := PracticePlayer.new()
	main.add_child(actor)
	actor.add_to_group("player")
	var map: Node2D = main.get_node("PrototypeMap")
	var arena: Rect2 = map.get_region_bounds(&"top")
	for scene: String in ["sandworm", "scorpion", "vulture", "monitor"]:
		var boss: Boss = load("res://Scenes/Enemies/%s_boss.tscn" % scene).instantiate()
		main.add_child(boss)
		stop_ticks(boss)
		boss.setup_for_battle(&"meat_red", arena)
		boss.level_refs = null # Isolate combat from kitchen pressure and summons.
		boss.player = actor
		var monitor := scene == "monitor"
		var center := boss._get_safe_arena_bounds().get_center()
		check_displacement(boss, actor, scene, center)
		if monitor:
			check_bite(boss, actor, center)
		# Both distances used to be inside the stationary melee circle.
		for distance: float in [180.0, 240.0]:
			reset(boss, center, monitor)
			actor.global_position = center + Vector2.RIGHT * distance
			var moved_frames := 0
			for frame in range(180):
				var before := boss.global_position
				boss._physics_process(1.0 / 60.0)
				if boss.global_position.distance_to(before) > 0.1:
					moved_frames += 1
			check(moved_frames >= 120 and absf(boss.global_position.y - center.y) > 30, "%s must actively reposition at melee distance %s" % [scene, distance])
		# Far-away players are approached rather than endlessly circled.
		reset(boss, center - Vector2(250, 0), monitor)
		actor.global_position = center + Vector2(350, 0)
		var initial_distance := boss.global_position.distance_to(actor.global_position)
		for frame in range(120):
			boss._physics_process(1.0 / 60.0)
		check(boss.global_position.distance_to(actor.global_position) < initial_distance - boss.move_speed, "%s closes long distance" % scene)
		# Ordinary movement must not consume committed warning/recovery windows.
		for phase: int in [Boss.AttackState.WINDUP, Boss.AttackState.RECOVERY]:
			reset(boss, center, monitor)
			boss.state = phase
			boss.attack = Boss.Attack.SWEEP
			boss.state_remaining = 10
			boss._physics_process(0.2)
			check(boss.global_position.is_equal_approx(center), "%s retains stationary committed phase %s" % [scene, phase])
		# Test actual steering at all safe corners, with the player nearer walls.
		var bounds := boss._get_safe_arena_bounds()
		var safe_edges := true
		var moving_edges := true
		for point: Vector2 in [bounds.position, bounds.end, Vector2(bounds.position.x, bounds.end.y), Vector2(bounds.end.x, bounds.position.y)]:
			reset(boss, point, monitor)
			actor.global_position = arena.get_center() + (point - arena.get_center()) * 1.1
			for frame in range(120):
				var before := boss.global_position
				boss._physics_process(1.0 / 60.0)
				safe_edges = safe_edges and boss.global_position.distance_to(before) <= boss.move_speed / 60.0 + 0.1
				safe_edges = safe_edges and bounds.grow(0.1).has_point(boss.global_position)
			moving_edges = moving_edges and boss.global_position.distance_to(point) > 30
		check(safe_edges, "%s normal steering respects safe edges and never teleports" % scene)
		check(moving_edges, "%s does not stay pinned to a corner while player hugs outer walls" % scene)
		# Follow a complete combat loop, not just an isolated movement method.
		reset(boss, center, monitor)
		actor.global_position = center + Vector2(220, 0)
		boss.cycle_index = 0
		boss.attack_remaining = 0.5
		var active_moving_frames := 0
		for frame in range(2700):
			var before := boss.global_position
			var active := boss.state == Boss.AttackState.ACTIVE
			boss._physics_process(1.0 / 60.0)
			if active and boss.global_position.distance_to(before) > 0.1:
				active_moving_frames += 1
		check(boss.cycle_index >= 3 and active_moving_frames > 180, "%s must both move and keep casting through several complete skill cycles" % scene)
		# Leaving the battle region must not make the boss chase into the kitchen.
		reset(boss, center, monitor)
		actor.global_position = map.get_kitchen_zone_bounds().get_center()
		boss._physics_process(1.0)
		check(boss.global_position.is_equal_approx(center), "%s stays in its arena when player leaves" % scene)
		print("MOVEMENT %s: cycles=%d moving_frames=%d" % [scene, boss.cycle_index, active_moving_frames])
		boss.queue_free()
		await process_frame
	main.queue_free()
	await process_frame
	print("BOSS COMBAT MOVEMENT: %d failures; four bosses, minimum displacement, close repositioning, chase, committed windows, safe edges, complete skill cycles and arena exit" % failures.size())
	quit(0 if failures.is_empty() else 1)
