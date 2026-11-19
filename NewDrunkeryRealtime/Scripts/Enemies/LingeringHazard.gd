extends Area2D

const ZoneInteractionQuery = preload("res://Scripts/Core/ZoneInteractionQuery.gd")

@export var radius: float = 74.0
@export var duration: float = 4.0
@export var tick_interval: float = 0.55
@export var damage: int = 10
@export var movement_bounds: Rect2 = Rect2(Vector2.ZERO, Vector2(1792, 1152))
@export var edge_padding: Vector2 = Vector2(24.0, 24.0)
@export var base_fill_color: Color = Color(1.0, 0.26, 0.14, 0.16)
@export var pulse_fill_color: Color = Color(1.0, 0.34, 0.18, 0.34)
@export var outline_color: Color = Color(1.0, 0.84, 0.72, 0.94)
@export var ember_color: Color = Color(1.0, 0.64, 0.34, 0.46)

var prototype_map: Node
var owner_enemy: Node2D
var time_remaining: float = 0.0
var pulse_time: float = 0.0
var tracked_player_inside: bool = false

func _ready() -> void:
	add_to_group("lingering_hazards")
	time_remaining = duration
	queue_redraw()

func setup_hazard(
	start_position: Vector2,
	hazard_radius: float,
	hazard_duration: float,
	hazard_tick_interval: float,
	hazard_damage: int,
	bounds: Rect2,
	map_node: Node,
	source_enemy: Node2D
) -> void:
	global_position = start_position
	radius = maxf(hazard_radius, 1.0)
	duration = maxf(hazard_duration, 0.1)
	tick_interval = maxf(hazard_tick_interval, 0.05)
	damage = max(hazard_damage, 0)
	movement_bounds = bounds
	prototype_map = map_node
	owner_enemy = source_enemy
	time_remaining = duration
	tracked_player_inside = false
	queue_redraw()

func _process(delta: float) -> void:
	pulse_time += delta * 4.6
	queue_redraw()

func _physics_process(delta: float) -> void:
	time_remaining = maxf(time_remaining - delta, 0.0)
	if time_remaining <= 0.0:
		_clear_player_hazard_cooldown()
		queue_free()
		return

	if not _is_inside_bounds(global_position):
		_clear_player_hazard_cooldown()
		queue_free()
		return

	_update_player_damage_state(delta)

func _update_player_damage_state(delta: float) -> void:
	var player_node: Node = get_tree().get_first_node_in_group("player")
	if not (player_node is Node2D):
		tracked_player_inside = false
		return

	var player_point: Vector2 = player_node.global_position
	if player_node.has_method("get_sort_origin"):
		player_point = player_node.get_sort_origin()
	var is_inside: bool = player_point.distance_to(global_position) <= radius and _can_damage_player(player_node)
	var cooldown_remaining: float = _get_player_hazard_cooldown(player_node)
	cooldown_remaining = maxf(cooldown_remaining - delta, 0.0)
	_set_player_hazard_cooldown(player_node, cooldown_remaining)

	if is_inside and not tracked_player_inside:
		if cooldown_remaining <= 0.0:
			if _apply_damage_to_player(player_node, player_point):
				_set_player_hazard_cooldown(player_node, tick_interval)
		tracked_player_inside = true
		return

	if not is_inside:
		tracked_player_inside = false
		return

	tracked_player_inside = true
	if cooldown_remaining > 0.0:
		return

	if _apply_damage_to_player(player_node, player_point):
		_set_player_hazard_cooldown(player_node, tick_interval)

func _apply_damage_to_player(player_node: Node, player_point: Vector2) -> bool:
	if not player_node.has_method("take_damage"):
		return false
	var push_direction: Vector2 = (player_point - global_position).normalized()
	if push_direction.length_squared() <= 0.001:
		push_direction = Vector2.UP
	var was_applied: Variant = player_node.take_damage(damage, push_direction, &"special")
	if was_applied is bool and not was_applied:
		return false
	if player_node.has_method("apply_contact_push"):
		player_node.apply_contact_push(push_direction, 12.0)
	return true

func _get_player_hazard_cooldown(player_node: Node) -> float:
	var all_cooldowns: Dictionary = player_node.get_meta(&"lingering_hazard_cooldowns", {})
	return float(all_cooldowns.get(get_instance_id(), 0.0))

func _set_player_hazard_cooldown(player_node: Node, value: float) -> void:
	var all_cooldowns: Dictionary = player_node.get_meta(&"lingering_hazard_cooldowns", {}).duplicate()
	if value <= 0.0:
		all_cooldowns.erase(get_instance_id())
	else:
		all_cooldowns[get_instance_id()] = value
	player_node.set_meta(&"lingering_hazard_cooldowns", all_cooldowns)

func _clear_player_hazard_cooldown() -> void:
	var player_node: Node = get_tree().get_first_node_in_group("player")
	if player_node == null:
		return
	var all_cooldowns: Dictionary = player_node.get_meta(&"lingering_hazard_cooldowns", {}).duplicate()
	if not all_cooldowns.has(get_instance_id()):
		return
	all_cooldowns.erase(get_instance_id())
	player_node.set_meta(&"lingering_hazard_cooldowns", all_cooldowns)

func _can_damage_player(player_node: Node2D) -> bool:
	return ZoneInteractionQuery.can_points_interact(prototype_map, global_position, ZoneInteractionQuery.get_node_point(player_node))

func _is_inside_bounds(point: Vector2) -> bool:
	var min_pos: Vector2 = movement_bounds.position - edge_padding
	var max_pos: Vector2 = movement_bounds.position + movement_bounds.size + edge_padding
	return point.x >= min_pos.x and point.x <= max_pos.x and point.y >= min_pos.y and point.y <= max_pos.y

func _draw() -> void:
	var life_ratio: float = clampf(time_remaining / maxf(duration, 0.001), 0.0, 1.0)
	var pulse_ratio: float = 0.78 + 0.22 * sin(pulse_time)
	var fill_scale: float = 0.82 + 0.18 * pulse_ratio
	var ember_radius: float = radius * 0.34
	var current_fill: Color = base_fill_color
	current_fill.a *= 0.45 + 0.55 * life_ratio
	var current_pulse: Color = pulse_fill_color
	current_pulse.a *= 0.52 + 0.48 * pulse_ratio
	var current_ember: Color = ember_color
	current_ember.a *= 0.38 + 0.62 * life_ratio

	draw_circle(Vector2.ZERO, radius, current_fill)
	draw_circle(Vector2.ZERO, radius * fill_scale, current_pulse)
	draw_circle(Vector2.ZERO, ember_radius, current_ember)
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 32, outline_color, 3.0, true)
