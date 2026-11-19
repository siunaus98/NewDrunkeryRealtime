extends Node2D

const LevelRefs = preload("res://Scripts/Core/LevelRefs.gd")

var player: Node2D
var prototype_map: Node
var cooldown_remaining: float = 0.8
var attack_interval: float = 3.0
var attack_damage: int = 150
var attack_range: float = 620.0
var impact_radius: float = 150.0
var windup_duration: float = 0.35
var windup_remaining: float = 0.0
var impact_remaining: float = 0.0
var impact_position: Vector2 = Vector2.ZERO
var elapsed: float = 0.0
var target: Node2D

func setup(new_player: Node2D) -> void:
	player = new_player
	var refs := LevelRefs.find_from(player)
	prototype_map = refs.get_prototype_map() if refs != null else null
	z_index = 9
	global_position = player.global_position + Vector2(58, -78)
	visible = _player_in_battle()
	queue_redraw()

func _process(delta: float) -> void:
	if not is_instance_valid(player):
		queue_free()
		return
	elapsed += delta
	# Stay beside the player and channel attacks from here instead of bouncing.
	global_position = player.global_position + Vector2(58, -78 + sin(elapsed * 2.6) * 7.0)
	visible = _player_in_battle()
	if not visible:
		target = null
		windup_remaining = 0.0
		impact_remaining = 0.0
		return
	impact_remaining = maxf(impact_remaining - delta, 0.0)
	cooldown_remaining = maxf(cooldown_remaining - delta, 0.0)
	if windup_remaining > 0.0:
		windup_remaining = maxf(windup_remaining - delta, 0.0)
		if not _target_available(target):
			target = null
			windup_remaining = 0.0
		elif windup_remaining <= 0.0:
			_resolve_strike()
	elif cooldown_remaining <= 0.0:
		target = _find_target()
		if target != null:
			windup_remaining = windup_duration
			cooldown_remaining = attack_interval
	queue_redraw()

func _player_in_battle() -> bool:
	return is_instance_valid(player) and is_instance_valid(prototype_map) and prototype_map.is_point_in_battle_zone(player.global_position)

func _find_target() -> Node2D:
	var nearest: Node2D
	var best_distance: float = attack_range
	for enemy: Node in get_tree().get_nodes_in_group("enemies"):
		if not _target_available(enemy):
			continue
		var distance: float = player.global_position.distance_to(enemy.global_position)
		if distance < best_distance:
			nearest = enemy
			best_distance = distance
	return nearest

func _target_available(enemy: Variant) -> bool:
	if not is_instance_valid(enemy) or not enemy is Node2D or enemy.is_queued_for_deletion() or not enemy.has_method("receive_hit") or enemy.get("is_dead") == true:
		return false
	if not _player_in_battle() or player.global_position.distance_to(enemy.global_position) > attack_range:
		return false
	var region: StringName = prototype_map.get_battle_region_for_point(player.global_position)
	return region != &"" and region == prototype_map.get_battle_region_for_point(enemy.global_position) and not prototype_map.is_segment_blocked_by_dune_wall(player.global_position, enemy.global_position)

func _resolve_strike() -> void:
	impact_position = target.global_position
	impact_remaining = 0.45
	# Freeze the victim list before hits: killing a unit may change groups.
	for enemy: Node in get_tree().get_nodes_in_group("enemies"):
		if _target_available(enemy) and enemy.global_position.distance_to(impact_position) <= impact_radius:
			enemy.receive_hit(attack_damage, (enemy.global_position - player.global_position).normalized())
	target = null

func _draw() -> void:
	var glow := Color(0.96, 0.83, 0.46, 0.16)
	var veil := Color(0.87, 0.76, 0.47, 0.56)
	var light := Color(1.0, 0.92, 0.69, 0.8)
	# An airy hood, tapering cloth, face lights and orbiting grains.
	draw_circle(Vector2(0, -5), 38, glow)
	draw_colored_polygon(PackedVector2Array([Vector2(-23, -6), Vector2(-21, -30), Vector2(0, -46), Vector2(22, -29), Vector2(25, -4), Vector2(13, 15), Vector2(4, 28), Vector2(-8, 15), Vector2(-20, 20), Vector2(-15, 4)]), veil)
	draw_arc(Vector2(0, -13), 22, PI, TAU, 20, light, 2.0, true)
	draw_circle(Vector2(-7, -14), 3.2, light)
	draw_circle(Vector2(7, -14), 3.2, light)
	draw_arc(Vector2(0, -5), 13, 0.25, PI - 0.25, 12, light, 1.5, true)
	for index in range(8):
		var angle: float = elapsed * 0.8 + index * TAU / 8.0
		var grain := Vector2(cos(angle) * 31, sin(angle) * 12 + 14)
		draw_circle(grain, 2.0, light * Color(1, 1, 1, 0.6))
	if windup_remaining > 0.0 and is_instance_valid(target):
		var point := to_local(target.global_position)
		var charge: float = 1.0 - windup_remaining / windup_duration
		draw_arc(point, impact_radius * (1.0 - charge * 0.25), -elapsed * 3, -elapsed * 3 + TAU * 0.8, 36, Color(1.0, 0.88, 0.52, 0.55), 3, true)
		draw_line(Vector2(0, -5), point, Color(1.0, 0.88, 0.52, 0.15 + charge * 0.25), 3, true)
	if impact_remaining > 0.0:
		var point := to_local(impact_position)
		var fade: float = impact_remaining / 0.45
		for index in range(3):
			var radius: float = impact_radius * (1.0 - fade * 0.5) * (1.0 - index * 0.24)
			draw_arc(point + Vector2(0, -index * 14), radius, elapsed * 7 + index, elapsed * 7 + index + PI * 1.6, 32, Color(0.98, 0.82, 0.43, fade * 0.75), 8.0 * fade + 1, true)
		for index in range(12):
			var direction := Vector2.RIGHT.rotated(index * TAU / 12.0)
			draw_circle(point + direction * impact_radius * (1.0 - fade * 0.5), 4.0 * fade, Color(1.0, 0.93, 0.71, fade))
