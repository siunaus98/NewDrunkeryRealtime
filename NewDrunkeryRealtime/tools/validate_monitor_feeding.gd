extends SceneTree

const Items = preload("res://Scripts/Kitchen/TestItemDefs.gd")
const Cargo = preload("res://Scripts/Facilities/FacilityItems.gd")
const Travel = preload("res://Scripts/Restaurant/BossArenaTravel.gd")
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

func check_attack_turning(boss: CharacterBody2D, actor: CharacterBody2D) -> void:
	var origin: Vector2 = boss.global_position
	var player_health: int = actor.combat_controller.current_health
	boss.tongue.cooldown = 1000
	boss.facility_tongue.cooldown = 1000
	boss.scan_remaining = 1000
	boss.attack_remaining = 1000
	boss.bite_remaining = 1000
	boss.facing = Vector2.RIGHT
	actor.global_position = origin + Vector2.LEFT * 240
	boss._physics_process(0.5)
	check(boss.is_rear_hit(actor.global_position) and boss.facing != Vector2.RIGHT, "Idle tracking still turns, but a half-second flank remains a rear opening")
	for skill: int in [boss.Attack.STING, boss.Attack.SWEEP, boss.Attack.RUSH]:
		boss.global_position = origin
		boss.facing = Vector2.RIGHT
		actor.global_position = origin + Vector2.RIGHT * 300
		boss.start_attack(skill)
		var facing: Vector2 = boss.facing
		var locked := true
		var moved := false
		var recovered := false
		var rear_hit_landed := false
		var recovery_checked := false
		for frame in range(120):
			# Cross behind after the attack commits, including during movement.
			actor.global_position = boss.global_position + Vector2.LEFT.rotated(sin(frame * 0.2) * 0.4) * 240
			boss._physics_process(0.05)
			if boss.state == boss.AttackState.RECOVERY and not recovery_checked:
				check(is_equal_approx(boss.state_remaining, 2.0), "Major combat skills retain a two-second recovery opening: %d" % skill)
				recovery_checked = true
			locked = locked and boss.facing.is_equal_approx(facing)
			moved = moved or boss.global_position.distance_to(origin) > 1
			if not rear_hit_landed and boss.is_rear_hit(actor.global_position):
				var health: int = boss.current_health
				var damage: int = roundi(actor.combat_controller.get_current_attack_damage() * actor.combat_controller.light_attack_damage_multiplier)
				actor.combat_controller._apply_attack_hit({"direction": (boss.global_position - actor.global_position).normalized(), "inner_radius": 0, "outer_radius": actor.combat_controller.attack_outer_radius, "angle_degrees": actor.combat_controller.attack_angle_degrees}, Callable(actor, "_can_damage_target_across_zones"))
				rear_hit_landed = boss.current_health == health - damage * 2
			if boss.state == boss.AttackState.ACTIVE:
				recovered = true
				break
		check(locked and recovered and recovery_checked, "Committed skill preserves facing through windup, action and recovery: %d" % skill)
		check(rear_hit_landed, "Real melee can exploit rear weakness during committed skill: %d" % skill)
		if skill in [boss.Attack.STING, boss.Attack.RUSH]:
			check(moved, "Facing lock is exercised during real boss displacement: %d" % skill)
		check(boss.is_rear_hit(actor.global_position), "Flanking committed skill produces a real rear hit opportunity: %d" % skill)
	boss.global_position = origin
	boss.facing = Vector2.DOWN
	boss.tongue.cooldown = 8
	boss.facility_tongue.cooldown = 8
	actor.combat_controller.current_health = player_health

func check_body_alignment(boss: CharacterBody2D, actor: CharacterBody2D) -> void:
	var original_position: Vector2 = boss.global_position
	var bounds: Rect2 = boss._get_safe_arena_bounds()
	for direction: Vector2 in [Vector2.RIGHT, Vector2.LEFT, Vector2.UP, Vector2(1, 1).normalized()]:
		# Leave a full forward runway for the minimum-distance attacks; edge
		# fallback is covered separately by validate_boss_combat_movement.
		var origin := bounds.get_center()
		for axis in range(2):
			if absf(direction[axis]) > 0.01:
				origin[axis] = bounds.position[axis] + 32 if direction[axis] > 0 else bounds.end[axis] - 32
		for skill: int in [boss.Attack.STING, boss.Attack.RUSH]:
			boss.global_position = origin
			boss.facing = direction
			# A player behind the boss must not produce a backwards leap/rush.
			actor.global_position = origin - direction * 300
			var minimum: float = boss.rush_min_distance if skill == boss.Attack.RUSH else boss.leap_min_distance
			var forward_room: float = boss._forward_target(minimum).distance_to(origin)
			boss.start_attack(skill)
			if forward_room + 0.1 < minimum:
				# This arena is too shallow for a vertical three-cell rush.
				check(boss.attack == boss.Attack.SWEEP, "Insufficient forward runway replaces displacement with sweep")
				continue
			var offset: Vector2 = boss.attack_target - origin
			check(offset.length() > 1 and offset.normalized().dot(direction) > 0.999, "Displacement targets follow head even when player is behind: skill=%d direction=%s bounds=%s origin=%s selected=%d" % [skill, direction, bounds, origin, boss.attack])
			if skill == boss.Attack.STING:
				boss.state_remaining = boss.windup_total * 0.5
				boss._update_visuals()
				check(boss.sprite.global_position.distance_to(origin) > 1, "Leap pose really leaves grounded origin")
				check(boss.weakpoint_view.global_position.is_equal_approx(boss.sprite.global_position), "Weakpoint pose follows airborne body translation")
				var marker: Vector2 = boss.weakpoint_view.to_global(Vector2(0, 125))
				var body_marker: Vector2 = boss.sprite.to_global(Vector2(0, 125 / boss.base_sprite_scale.y))
				check(marker.is_equal_approx(body_marker), "Weakpoint marker follows body rotation and scale")
				check(boss.get_hit_position().is_equal_approx(boss.sprite.to_global(boss.hit_center_offset)), "Actual melee geometry follows airborne body")
				actor.global_position = boss.get_hit_position() - direction * 180
				var health: int = boss.current_health
				boss.receive_player_hit(100, direction, actor, false)
				check(boss.current_health == health - 200, "Airborne rear damage is relative to visible body")
			else:
				boss._resolve_attack()
				boss._physics_process(0.1)
				var motion: Vector2 = boss.global_position - origin
				check(motion.length() > 1 and motion.normalized().dot(direction) > 0.999, "Actual rush motion follows head")
	# An oblique approach to an arena edge must shorten the ray, not turn it.
	boss.global_position = boss._get_safe_arena_bounds().end - Vector2(10, 30)
	boss.facing = Vector2(1, 1).normalized()
	var edge_motion: Vector2 = boss._forward_target(300) - boss.global_position
	check(edge_motion.normalized().dot(boss.facing) > 0.999 and boss._get_safe_arena_bounds().grow(0.1).has_point(boss.global_position + edge_motion), "Arena-edge clipping preserves head direction")
	boss.global_position = original_position
	boss.state = boss.AttackState.ACTIVE
	boss.facing = Vector2.DOWN
	boss._update_visuals()

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
	var actor: CharacterBody2D = main.get_node("Player")
	var no_blessings: Array[StringName] = []
	actor.combat_controller.blessing_controller.set_owned_blessings(no_blessings)
	actor.clear_held_item()
	await physics_frame
	check_body_alignment(boss, actor)
	check_attack_turning(boss, actor)
	# Prior combat checks intentionally deal real damage. Feeding starts from
	# a fresh full-health fixture; below half health requires two offering spots.
	boss.current_health = boss.max_health
	var head: Node2D = boss.tongue
	check(head.begin() and head.spots.size() == 1 and head.remaining == 30, "Preparation creates one reachable offering space for thirty seconds without existing food")
	if head.spots.is_empty():
		quit(1)
		return
	check(not head.blocks_boss(), "Preparation does not freeze boss")
	actor.global_position = boss.global_position + Vector2(400, 0)
	boss.player = actor
	var previous: Vector2 = boss.global_position
	boss.attack_remaining = 100
	boss._physics_process(0.5)
	check(boss.global_position != previous and boss.facing.dot(Vector2.RIGHT) > 0, "Boss moves and turns toward arena player during preparation")
	var spot: Node2D = head.spots[0]
	check(map.get_kitchen_zone_bounds().has_point(spot.global_position), "Marker lies in kitchen")
	actor.pick_up_item(Items.MEAT_RED_ID, Items.get_item_texture(Items.MEAT_RED_ID))
	check(spot.receive_item_from_player(actor) and not actor.is_holding_item(), "J deposits raw ingredient")
	check(spot.take_item_to_player(actor) and actor.get_held_item_id() == Items.MEAT_RED_ID, "Player can retrieve and replace offering before deadline")
	actor.clear_held_item()
	actor.pick_up_item(Items.DISH_RED_ROLL_ID, Items.get_item_texture(Items.DISH_RED_ROLL_ID), &"", "", {"uses_plate": true})
	spot.receive_item_from_player(actor)
	var health: int = boss.current_health
	boss.start_attack(boss.Attack.SWEEP)
	head.tick(head.remaining, false)
	check(not head.blocks_boss() and head.phase == head.Phase.EXTEND and not head.branches[0].food.is_empty(), "Deadline captures offering without granting early eating stun")
	check(boss.state == boss.AttackState.WINDUP and boss.attack == boss.Attack.SWEEP, "Offering deadline does not cancel a combat skill already in progress")
	check(not spot.take_item_to_player(actor), "Captured offering cannot be retrieved for free")
	for phase: int in [head.Phase.EXTEND, head.Phase.RETRACT]:
		check(head.phase == phase and boss.eating_remaining == 0 and boss.current_health == health, "Food in transit has neither stun nor meal damage: %d" % phase)
		boss.state = boss.AttackState.ACTIVE
		boss.attack_remaining = 100
		boss.facing = Vector2.RIGHT.rotated(-0.3)
		actor.global_position = boss.global_position + Vector2(400, 0)
		var transit_position: Vector2 = boss.global_position
		var transit_facing: Vector2 = boss.facing
		boss._physics_process(0.1)
		check(boss.global_position.distance_to(transit_position) > 1 and not boss.facing.is_equal_approx(transit_facing), "Boss still moves and turns while tongue transports food: %d" % phase)
		check(not head.status_text().contains("弱点暴露") and boss.eating_remaining == 0, "Transit never displays eating weakness")
		if phase == head.Phase.EXTEND:
			head.tick(head.remaining, false)
	head.tick(head.remaining - 0.02, false)
	check(head.phase == head.Phase.RETRACT and boss.current_health == health and boss.eating_remaining == 0, "Last part of return travel still gives no early damage or stun")
	head.tick(0.021, false)
	check(boss.current_health < health and boss.eating_remaining >= 5 and boss.eating_remaining <= 10, "Dish inflicts direct damage and quality-based capped stun")
	var swallowed_health: int = boss.current_health
	var swallowed_position: Vector2 = boss.global_position
	var swallowed_facing: Vector2 = boss.facing
	boss._physics_process(0.2)
	check(boss.current_health == swallowed_health and boss.global_position.is_equal_approx(swallowed_position) and boss.facing.is_equal_approx(swallowed_facing), "Swallowed food grants stationary stun without duplicate meal damage")
	var dirty := get_nodes_in_group("loose_items").filter(func(item: Node) -> bool: return item.item_id == Items.DIRTY_PLATE_ID)
	check(dirty.size() == 1, "Plated offering preserves exactly one physical dirty plate")
	boss.facing = Vector2.RIGHT
	boss._update_visuals()
	health = boss.current_health
	actor.global_position = boss.global_position + Vector2(100, 0)
	boss.receive_player_hit(100, Vector2.LEFT, actor, false)
	check(boss.current_health == health - 100, "Front attacks retain base damage, including during stun")
	actor.global_position = boss.global_position - Vector2(100, 0)
	health = boss.current_health
	boss.receive_player_hit(100, Vector2.RIGHT, actor, true)
	check(boss.current_health == health - 200, "Rear attacks gain positional multiplier")
	# A ground drop in the marked cell is accepted without a custom J deposit.
	boss.current_health = boss.max_health / 2 - 1
	boss.eating_remaining = 0
	check(head.begin() and head.spots.size() == 2, "Below half health prepares two distinct offering spaces")
	var storage: Node = main.get_node("StorageManager")
	storage.fill_test_stock(4)
	var before: Dictionary = {}
	for id: StringName in Items.get_all_ingredient_ids():
		before[id] = storage.get_stock(id)
	Cargo.drop(main, head.spots[0].global_position, {"item_id": Items.VEG_ROOT_ID, "process_state": &"", "payload": {}})
	head.tick(head.remaining, false)
	check(not head.branches[0].food.is_empty() and head.branches[1].food.is_empty(), "Ground offering satisfies its own slot only")
	var emptied := 0
	for id: StringName in before:
		if before[id] > 0 and storage.get_stock(id) == 0:
			emptied += 1
	check(emptied == 1, "One missing slot clears exactly one nonempty ordinary stock type")
	check(head.rage_target != null, "Rage identifies the affected cabinet visibly")
	var captured := get_nodes_in_group("loose_items").size()
	head.release_captured_food()
	check(get_nodes_in_group("loose_items").size() == captured + 1, "Death during tongue travel returns captured food once")
	await process_frame
	check(get_nodes_in_group("monitor_feeding_spots").is_empty(), "Finished preparation leaves no inventory or placement blockers")
	# Both empty slots still have only one penalty per wave.
	storage.fill_test_stock(4)
	head.begin()
	head.tick(head.remaining, false)
	emptied = 0
	for id: StringName in before:
		if before[id] > 0 and storage.get_stock(id) == 0:
			emptied += 1
	check(emptied == 1, "Two missing offerings do not double rage penalty")
	head.finish()
	var statue: Node
	for station in get_nodes_in_group("pickup_drop_targets"):
		if station.get("interaction_type") == &"blessing_statue":
			statue = station
			break
	check(statue != null and Travel.current_boss(statue) == boss, "Daytime statue discovers living boss")
	actor.global_position = map.get_kitchen_zone_bounds().get_center()
	actor.clear_held_item()
	actor.pick_up_item(Items.VEG_ROOT_ID, Items.get_item_texture(Items.VEG_ROOT_ID))
	check(statue.receive_item_from_player(actor) and boss.movement_bounds.has_point(actor.global_position) and actor.get_held_item_id() == Items.VEG_ROOT_ID, "Statue transports player and held food to safe arena entrance")
	check(not actor.test_move(actor.global_transform, Vector2.ZERO), "Teleport landing does not overlap a solid collider")
	# Verify the actor's real melee path uses its position, rather than attack
	# direction or the first player in the scene, to determine rear damage.
	actor.global_position = boss.global_position - Vector2(180, 0)
	boss.facing = Vector2.RIGHT
	boss._update_visuals()
	health = boss.current_health
	var damage: int = roundi(actor.combat_controller.get_current_attack_damage() * actor.combat_controller.light_attack_damage_multiplier)
	actor.combat_controller._apply_attack_hit({"direction": Vector2.RIGHT, "inner_radius": 0, "outer_radius": 240, "angle_degrees": 120}, Callable(actor, "_can_damage_target_across_zones"))
	check(boss.current_health == health - damage * 2, "Actual player melee dispatch applies rear damage")
	# Run several complete pressure cycles with the player staying in kitchen.
	actor.global_position = map.get_kitchen_zone_bounds().get_center()
	boss.eating_remaining = 0
	boss.state = boss.AttackState.ACTIVE
	boss.pressure_owner = null
	boss.pressure_gap = 0
	boss.next_pressure_is_facility = false
	head.cooldown = 0
	boss.facility_tongue.cooldown = 0
	var preparations := 0
	var saliva_casts := 0
	for frame in range(400):
		var was_food_active: bool = head.active()
		var was_saliva_active: bool = boss.facility_tongue.active()
		boss._physics_process(0.5)
		if not was_food_active and head.active():
			preparations += 1
		if not was_saliva_active and boss.facility_tongue.active():
			saliva_casts += 1
		for effect: Node in get_nodes_in_group("facility_work_pauses"):
			effect._process(0.5)
	check(preparations >= 3 and saliva_casts >= 2, "Two heads keep cycling autonomously through multiple failed offerings and disabled facilities")
	boss._die()
	check(Travel.current_boss(statue) == null, "Statue stops offering travel after boss death")
	main.queue_free()
	await process_frame
	print("MONITOR FEEDING: %d failures; preparation, movement, capture, rage, conservation, quality damage, rear weakness and statue travel" % failures.size())
	quit(0 if failures.is_empty() else 1)
