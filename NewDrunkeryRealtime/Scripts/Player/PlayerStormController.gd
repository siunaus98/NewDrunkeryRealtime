extends RefCounted

var player: CharacterBody2D
var owner_boss: Node
var direction: Vector2 = Vector2.ZERO
var distance_remaining: float = 0.0
var travel_speed: float = 1500.0
var impact_damage: int = 35
var impact_stun: float = 2.0
var stun_remaining: float = 0.0
var immunity_remaining: float = 0.0
var slows: Dictionary = {}

func setup(host: CharacterBody2D) -> void:
	player = host

func launch(push_direction: Vector2, distance: float, damage: int, stun: float, source: Node) -> bool:
	if player.is_control_immune():
		return false
	if blocks_actions() or immunity_remaining > 0.0 or push_direction.is_zero_approx() or distance <= 0.0:
		return false
	owner_boss = source
	direction = push_direction.normalized()
	distance_remaining = distance
	impact_damage = damage
	impact_stun = stun
	player.wind_jump_remaining = 0.0
	player.sprite.scale = player.wind_jump_base_sprite_scale
	player.held_item_sprite.scale = player.wind_jump_base_held_scale
	player.combat_controller.cancel_attack_charge(false)
	player.combat_controller.dash_time_remaining = 0.0
	player._interrupt_processing_for_quicksand()
	return true

func tick(delta: float) -> bool:
	immunity_remaining = maxf(immunity_remaining - delta, 0.0)
	for key: int in slows.keys():
		var entry: Dictionary = slows[key]
		entry.remaining -= delta
		if entry.remaining <= 0.0 or not is_instance_valid(entry.source) or entry.source.is_queued_for_deletion():
			slows.erase(key)
	if owner_boss != null and (not is_instance_valid(owner_boss) or owner_boss.is_queued_for_deletion() or owner_boss.is_dead):
		reset()
		return false
	if not blocks_actions():
		return false
	player.quicksand_pull_velocity = Vector2.ZERO
	player.quicksand_spawn_motion = Vector2.ZERO
	player.movement_input_direction = Vector2.ZERO
	player.velocity = Vector2.ZERO
	player._interrupt_processing_for_quicksand()
	if stun_remaining > 0.0:
		stun_remaining = maxf(stun_remaining - delta, 0.0)
		if stun_remaining <= 0.0:
			immunity_remaining = 0.65
		return true
	var motion := direction * minf(travel_speed * delta, distance_remaining)
	var before := player.global_position
	var collision := player.move_and_collide(motion)
	var before_clamp := player.global_position
	if player.push_controller != null:
		player.push_controller.clamp_to_map_bounds()
	var hit_boundary := before_clamp.distance_to(player.global_position) > 0.1
	distance_remaining = maxf(distance_remaining - before.distance_to(player.global_position), 0.0)
	if collision != null or hit_boundary:
		# Only this swept flight can cause a storm crash. A normal landing cannot.
		distance_remaining = 0.0
		if player.take_damage(impact_damage, direction, &"storm_crash") and not player.is_downed():
			stun_remaining = impact_stun
		immunity_remaining = 0.65
	elif distance_remaining <= 0.01:
		distance_remaining = 0.0
		immunity_remaining = 0.65
	return true

func blocks_actions() -> bool:
	return distance_remaining > 0.0 or stun_remaining > 0.0

func apply_slow(source: Node, multiplier: float) -> void:
	if player.is_control_immune():
		return
	if is_instance_valid(source):
		slows[source.get_instance_id()] = {"source": source, "multiplier": clampf(multiplier, 0.1, 1.0), "remaining": 0.08}

func get_speed_multiplier() -> float:
	var multiplier := 1.0
	for entry: Dictionary in slows.values():
		if is_instance_valid(entry.source) and not entry.source.is_queued_for_deletion():
			multiplier = minf(multiplier, entry.multiplier)
	return multiplier

func reset() -> void:
	owner_boss = null
	distance_remaining = 0.0
	stun_remaining = 0.0
	immunity_remaining = 0.0
	slows.clear()

func draw_status() -> void:
	if stun_remaining <= 0.0:
		return
	for i in range(3):
		var angle := stun_remaining * 4.0 + i * TAU / 3.0
		var point := Vector2(cos(angle) * 30.0, -100.0 + sin(angle) * 10.0)
		player.draw_line(point - Vector2(6, 0), point + Vector2(6, 0), Color("ffe59a"), 4.0)
		player.draw_line(point - Vector2(0, 6), point + Vector2(0, 6), Color("ffe59a"), 4.0)
