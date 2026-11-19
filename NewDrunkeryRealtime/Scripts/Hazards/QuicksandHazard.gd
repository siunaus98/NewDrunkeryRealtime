class_name QuicksandHazard
extends Node2D

@export var radius: float = 270.0
@export var suction_speed: float = 300.0
@export var center_damage_radius: float = 34.0
@export var center_soft_radius: float = 100.0
@export var damage_interval: float = 1.2
@export var damage_amount: int = 10
@export var lifetime: float = 8.0
@export var warning_duration: float = 1.0
@export var spawn_pull_distance: float = 0.0

var lifetime_remaining: float = 0.0
var warning_remaining: float = 0.0
var damage_cooldowns: Dictionary = {}
var boss_owner: Node
var normal_radius: float = 270.0
var spawn_pull_applied: bool = false
var birth_flash_remaining: float = 0.0
var kitchen_boss_hazard: bool = false
var transient_boss_hazard: bool = false

func configure_boss(owner_boss: Node, enlarged_radius: float, short_warning: float, initial_pull: float) -> void:
	normal_radius = radius
	boss_owner = owner_boss
	radius = enlarged_radius
	warning_duration = short_warning
	spawn_pull_distance = initial_pull

func _ready() -> void:
	add_to_group("quicksand_hazards")
	# Tick before the player, once per physics frame; rendering never drives motion.
	process_physics_priority = -20
	warning_remaining = maxf(warning_duration, 0.0)
	lifetime_remaining = maxf(lifetime, 0.1)
	queue_redraw()

func _physics_process(delta: float) -> void:
	if boss_owner != null and (not is_instance_valid(boss_owner) or boss_owner.is_dead):
		remove_boss_enhancement()
	if is_queued_for_deletion():
		return
	birth_flash_remaining = maxf(birth_flash_remaining - delta, 0.0)
	if warning_remaining > 0.0:
		warning_remaining = maxf(warning_remaining - delta, 0.0)
		if warning_remaining > 0.0:
			queue_redraw()
			return
	if not spawn_pull_applied:
		if _apply_initial_pull():
			# The player consumes the impulse this tick. Evaluate ongoing suction
			# next tick, using the resulting position instead of the old one.
			queue_redraw()
			return
	lifetime_remaining = maxf(lifetime_remaining - delta, 0.0)
	if lifetime_remaining <= 0.0:
		queue_free()
		return
	for player in get_tree().get_nodes_in_group("player"):
		if not is_instance_valid(player) or not player is Node2D:
			continue
		var to_center: Vector2 = global_position - player.global_position
		var distance := to_center.length()
		if distance > radius:
			continue
		if player.has_method("apply_quicksand_pull"):
			player.apply_quicksand_pull(get_pull_velocity(player.global_position, delta))
		var player_id := player.get_instance_id()
		var cooldown := maxf(float(damage_cooldowns.get(player_id, 0.0)) - delta, 0.0)
		if distance <= center_damage_radius and cooldown <= 0.0:
			if player.has_method("take_damage"):
				player.take_damage(damage_amount, Vector2.ZERO, &"quicksand")
			cooldown = damage_interval
		damage_cooldowns[player_id] = cooldown
	queue_redraw()

func _apply_initial_pull() -> bool:
	spawn_pull_applied = true
	if spawn_pull_distance <= 0.0:
		return false
	birth_flash_remaining = 0.35
	for player in get_tree().get_nodes_in_group("player"):
		if player is Node2D and global_position.distance_to(player.global_position) <= radius and player.has_method("apply_quicksand_spawn_pull"):
			player.apply_quicksand_spawn_pull(global_position, spawn_pull_distance)
	return true

func get_pull_velocity(player_position: Vector2, delta: float) -> Vector2:
	var offset := global_position - player_position
	var distance := offset.length()
	if warning_remaining > 0.0 or distance > radius or distance <= 0.05:
		return Vector2.ZERO
	var pull_ratio := clampf(1.0 - distance / radius, 0.0, 1.0)
	var speed := suction_speed * (0.25 + pull_ratio * 0.75)
	# Reduce force continuously near the center and never cross it in one tick.
	speed *= clampf(distance / maxf(center_soft_radius, 1.0), 0.0, 1.0)
	speed = minf(speed, distance / maxf(delta, 0.001))
	return offset.normalized() * speed

func remove_boss_enhancement() -> void:
	if kitchen_boss_hazard or transient_boss_hazard:
		queue_free()
		return
	radius = normal_radius
	spawn_pull_distance = 0.0
	boss_owner = null
	queue_redraw()

func is_position_blocked_for_forage(position: Vector2, extra_margin: float = 0.0) -> bool:
	return global_position.distance_to(position) <= radius + maxf(extra_margin, 0.0)

func get_hazard_radius() -> float:
	return radius

func get_remaining_lifetime() -> float:
	return lifetime_remaining

func _draw() -> void:
	var warning := warning_remaining > 0.0
	var border := Color(0.95, 0.75, 0.34, 0.95)
	if warning:
		var progress := 1.0 - warning_remaining / maxf(warning_duration, 0.001)
		draw_circle(Vector2.ZERO, radius, Color(0.88, 0.66, 0.23, 0.12))
		draw_arc(Vector2.ZERO, radius, 0.0, TAU, 64, border, 5.0, true)
		draw_arc(Vector2.ZERO, radius - 10.0, -PI * 0.5, -PI * 0.5 + TAU * progress, 64, border, 8.0, true)
	else:
		draw_circle(Vector2.ZERO, radius, Color(0.48, 0.28, 0.10, 0.32))
		draw_circle(Vector2.ZERO, radius * 0.68, Color(0.18, 0.09, 0.04, 0.75))
		draw_arc(Vector2.ZERO, radius, 0.0, TAU, 64, border, 5.0, true)
		draw_arc(Vector2.ZERO, radius * 0.48, 0.0, TAU, 48, Color(0.74, 0.43, 0.12, 0.8), 4.0, true)
		draw_circle(Vector2.ZERO, center_damage_radius, Color(0.08, 0.035, 0.02, 0.65))
		for index in range(5):
			var ring_radius: float = lerpf(center_damage_radius + 8, radius - 14, float(index) / 5)
			var angle: float = lifetime_remaining * 0.7 + float(index) * 1.1
			draw_arc(Vector2.ZERO, ring_radius, angle, angle + PI * 1.5, 40, Color(0.87, 0.66, 0.34, 0.42), 2.5, true)
			var at := Vector2.RIGHT.rotated(angle) * ring_radius
			draw_circle(at, 2.5, Color("e3c18a"))
	if birth_flash_remaining > 0.0:
		var progress := 1.0 - birth_flash_remaining / 0.35
		draw_arc(Vector2.ZERO, radius * (1.0 - progress * 0.65), 0.0, TAU, 64, Color(1.0, 0.74, 0.2, 1.0 - progress), 10.0, true)
	if is_instance_valid(boss_owner):
		for i in range(8):
			var direction := Vector2.RIGHT.rotated(TAU * float(i) / 8.0)
			draw_line(direction * radius * 0.88, direction * radius * 0.7, border, 5.0, true)
