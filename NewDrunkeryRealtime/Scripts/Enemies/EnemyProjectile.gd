extends Area2D

const AudioCue = preload("res://Scripts/Audio/AudioCue.gd")

const ZoneInteractionQuery = preload("res://Scripts/Core/ZoneInteractionQuery.gd")

signal projectile_resolved(hit_player: bool)

enum ProjectileMode {
	FIXED,
	HOMING
}

@export var radius: float = 22.0
@export var speed: float = 352.0
@export var damage: int = 10
@export var max_travel_distance: float = 320.0
@export var player_hit_radius: float = 22.0
@export var movement_bounds: Rect2 = Rect2(Vector2.ZERO, Vector2(1792, 1152))
@export var edge_padding: Vector2 = Vector2(24, 24)
@export var fill_color: Color = Color(1.0, 0.28, 0.18, 0.92)
@export var outline_color: Color = Color(1.0, 0.96, 0.84, 1.0)
@export var trail_color: Color = Color(1.0, 0.54, 0.34, 0.34)
@export var projectile_mode: ProjectileMode = ProjectileMode.FIXED
@export var homing_strength: float = 0.9
@export var homing_max_turn_rate_degrees: float = 7.5

var direction: Vector2 = Vector2.RIGHT
var travelled_distance: float = 0.0
var prototype_map: Node
var owner_enemy: Node2D
var has_hit_player: bool = false
var dodge_notified: bool = false
var pulse_time: float = 0.0

func _ready() -> void:
	add_to_group("enemy_projectiles")
	queue_redraw()

func setup_projectile(
	start_position: Vector2,
	travel_direction: Vector2,
	travel_speed: float,
	travel_range: float,
	projectile_damage: int,
	projectile_radius: float,
	bounds: Rect2,
	map_node: Node,
	source_enemy: Node2D,
	mode: ProjectileMode = ProjectileMode.FIXED,
	turn_strength: float = 0.9,
	max_turn_rate_degrees: float = 7.5
) -> void:
	global_position = start_position
	AudioCue.at(self, &"enemy_shoot", -8.0)
	direction = travel_direction.normalized() if travel_direction.length_squared() > 0.001 else Vector2.RIGHT
	speed = maxf(travel_speed, 0.0)
	max_travel_distance = maxf(travel_range, 0.0)
	damage = max(projectile_damage, 0)
	radius = maxf(projectile_radius, 1.0)
	movement_bounds = bounds
	prototype_map = map_node
	owner_enemy = source_enemy
	projectile_mode = mode
	homing_strength = maxf(turn_strength, 0.0)
	homing_max_turn_rate_degrees = maxf(max_turn_rate_degrees, 0.0)
	rotation = direction.angle()
	queue_redraw()

func _process(delta: float) -> void:
	pulse_time += delta * 9.0
	queue_redraw()

func _physics_process(delta: float) -> void:
	if has_hit_player:
		queue_free()
		return

	var motion: Vector2 = direction * speed * delta
	if projectile_mode == ProjectileMode.HOMING:
		_update_homing_direction(delta)
		motion = direction * speed * delta
	global_position += motion
	travelled_distance += motion.length()
	if travelled_distance >= max_travel_distance:
		_notify_dodged()
		queue_free()
		return
	if not _is_inside_bounds(global_position):
		_notify_dodged()
		queue_free()
		return

	_try_hit_player()

func _update_homing_direction(delta: float) -> void:
	var player_node: Node = get_tree().get_first_node_in_group("player")
	if not (player_node is Node2D):
		return
	if not player_node.has_method("get_sort_origin"):
		return

	var player_point: Vector2 = player_node.get_sort_origin()
	var to_player: Vector2 = player_point - global_position
	if to_player.length_squared() <= 0.001:
		return

	var desired_direction: Vector2 = to_player.normalized()
	var turn_limit: float = deg_to_rad(homing_max_turn_rate_degrees) * delta
	var turn_amount: float = clampf(homing_strength * delta, 0.0, 1.0)
	var blended_direction: Vector2 = direction.lerp(desired_direction, turn_amount).normalized()
	if blended_direction.length_squared() <= 0.001:
		return

	if turn_limit > 0.0 and direction.length_squared() > 0.001:
		var angle_delta: float = direction.angle_to(blended_direction)
		angle_delta = clampf(angle_delta, -turn_limit, turn_limit)
		direction = direction.rotated(angle_delta).normalized()
	else:
		direction = blended_direction
	rotation = direction.angle()

func _try_hit_player() -> void:
	var player_node: Node = get_tree().get_first_node_in_group("player")
	if not (player_node is Node2D):
		return
	if not player_node.has_method("take_damage"):
		return
	if not _can_damage_player(player_node):
		return

	var player_point: Vector2 = player_node.global_position
	if player_node.has_method("get_sort_origin"):
		player_point = player_node.get_sort_origin()
	if player_point.distance_to(global_position) > radius + player_hit_radius:
		return

	var push_direction: Vector2 = direction
	var was_applied: Variant = player_node.take_damage(damage, push_direction, &"special")
	if was_applied is bool and not was_applied:
		return
	if player_node.has_method("apply_contact_push"):
		player_node.apply_contact_push(push_direction, 26.0)
	has_hit_player = true
	if not dodge_notified:
		dodge_notified = true
		projectile_resolved.emit(true)

func _notify_dodged() -> void:
	if has_hit_player or dodge_notified:
		return
	dodge_notified = true
	projectile_resolved.emit(false)

func _can_damage_player(player_node: Node2D) -> bool:
	return ZoneInteractionQuery.can_points_interact(prototype_map, global_position, ZoneInteractionQuery.get_node_point(player_node))

func _is_inside_bounds(point: Vector2) -> bool:
	var min_pos: Vector2 = movement_bounds.position - edge_padding
	var max_pos: Vector2 = movement_bounds.position + movement_bounds.size + edge_padding
	return point.x >= min_pos.x and point.x <= max_pos.x and point.y >= min_pos.y and point.y <= max_pos.y

func _draw() -> void:
	var trail_length: float = radius * 1.7
	var pulse: float = 0.86 + 0.14 * sin(pulse_time)
	var current_fill: Color = fill_color
	current_fill.a *= pulse
	# Trails sit behind a crisp hostile core, so radius remains unambiguous.
	for index in range(5, 0, -1):
		var t: float = float(index) / 5.0
		var trail := Color(trail_color, trail_color.a * (1.0 - t * 0.8))
		draw_circle(Vector2.LEFT * trail_length * t, radius * (0.25 + (1.0 - t) * 0.5), trail)
	draw_circle(Vector2.ZERO, radius, current_fill.darkened(0.2))
	draw_circle(Vector2(-radius * 0.12, -radius * 0.12), radius * 0.78, current_fill)
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 32, outline_color, 2.0, true)
	draw_circle(Vector2(-radius * 0.2, -radius * 0.25), radius * 0.28, outline_color)
	draw_arc(Vector2.ZERO, radius * 0.65, -1.6, -0.2, 16, Color(outline_color, 0.7), 1.5, true)
