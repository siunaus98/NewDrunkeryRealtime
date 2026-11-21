extends RefCounted

const InteractionGeometry = preload("res://Scripts/Core/InteractionGeometry.gd")

var player: CharacterBody2D
var collision_shape: CollisionShape2D
var item_push_area: Area2D
var item_push_collision_shape: CollisionShape2D

var movement_bounds: Rect2 = Rect2(Vector2.ZERO, Vector2(1792, 1152))
var edge_padding: Vector2 = Vector2(24, 24)
var show_item_push_debug: bool = false
var item_push_margin: float = 8.0
var item_push_acceleration: float = 5400.0
var item_push_min_speed: float = 24.0
var item_push_overlap_bias: float = 2.5
var item_push_low_speed_multiplier: float = 0.08
var item_push_high_speed_multiplier: float = 0.58
var item_push_speed_curve: float = 1.55
var dash_nearby_push_multiplier: float = 8.0
var dash_nearby_push_ahead_margin: float = 0.05
var dash_horizontal_push_force_multiplier: float = 1.7
var movement_substep_pixels: float = 6.0

var ignored_pushable_items: Dictionary = {}
var prototype_map: Node
var last_playable_position: Vector2 = Vector2.ZERO

func setup(
	new_player: CharacterBody2D,
	new_collision_shape: CollisionShape2D,
	new_item_push_area: Area2D,
	new_item_push_collision_shape: CollisionShape2D,
	config: Dictionary
) -> void:
	player = new_player
	collision_shape = new_collision_shape
	item_push_area = new_item_push_area
	item_push_collision_shape = new_item_push_collision_shape
	movement_bounds = config.get("movement_bounds", movement_bounds)
	edge_padding = config.get("edge_padding", edge_padding)
	show_item_push_debug = bool(config.get("show_item_push_debug", show_item_push_debug))
	item_push_margin = float(config.get("item_push_margin", item_push_margin))
	item_push_acceleration = float(config.get("item_push_acceleration", item_push_acceleration))
	item_push_min_speed = float(config.get("item_push_min_speed", item_push_min_speed))
	item_push_overlap_bias = float(config.get("item_push_overlap_bias", item_push_overlap_bias))
	item_push_low_speed_multiplier = float(config.get("item_push_low_speed_multiplier", item_push_low_speed_multiplier))
	item_push_high_speed_multiplier = float(config.get("item_push_high_speed_multiplier", item_push_high_speed_multiplier))
	item_push_speed_curve = float(config.get("item_push_speed_curve", item_push_speed_curve))
	dash_nearby_push_multiplier = float(config.get("dash_nearby_push_multiplier", dash_nearby_push_multiplier))
	dash_nearby_push_ahead_margin = float(config.get("dash_nearby_push_ahead_margin", dash_nearby_push_ahead_margin))
	dash_horizontal_push_force_multiplier = float(config.get("dash_horizontal_push_force_multiplier", dash_horizontal_push_force_multiplier))
	movement_substep_pixels = float(config.get("movement_substep_pixels", movement_substep_pixels))
	last_playable_position = player.global_position

func set_movement_bounds(new_bounds: Rect2) -> void:
	movement_bounds = new_bounds

func set_prototype_map(new_prototype_map: Node) -> void:
	prototype_map = new_prototype_map

func move_with_axis_separation(
	motion: Vector2,
	current_velocity: Vector2,
	current_move_speed: float,
	is_dash_active: bool
) -> void:
	var max_component: float = maxf(absf(motion.x), absf(motion.y))
	var steps: int = max(1, int(ceil(max_component / maxf(movement_substep_pixels, 0.001))))
	var step_motion: Vector2 = motion / float(steps)

	for _i in range(steps):
		_try_move_axis(Vector2(step_motion.x, 0.0), current_velocity, current_move_speed, is_dash_active)
		_try_move_axis(Vector2(0.0, step_motion.y), current_velocity, current_move_speed, is_dash_active)

func push_nearby_items(
	delta: float,
	current_velocity: Vector2,
	current_move_speed: float,
	dash_speed_multiplier: float,
	is_dash_active: bool,
	overlaps_only: bool = false
) -> void:
	var player_speed: float = current_velocity.length()
	if player_speed < item_push_min_speed:
		return

	var push_direction: Vector2 = current_velocity.normalized()
	var capsule: Dictionary = get_active_push_capsule_data(push_direction)
	if capsule.is_empty():
		return

	var capsule_center: Vector2 = capsule.get("center", Vector2.ZERO)
	var capsule_radius: float = capsule.get("radius", 0.0)
	var capsule_top: Vector2 = capsule.get("top", Vector2.ZERO)
	var capsule_bottom: Vector2 = capsule.get("bottom", Vector2.ZERO)
	var lateral_axis: Vector2 = push_direction.orthogonal()
	var speed_ratio: float = clampf(player_speed / maxf(current_move_speed * dash_speed_multiplier, 1.0), 0.0, 1.0)
	var speed_factor: float = lerpf(item_push_low_speed_multiplier, item_push_high_speed_multiplier, pow(speed_ratio, item_push_speed_curve))
	var push_multiplier: float = 1.0
	var ahead_threshold_bias: float = 0.0
	var lateral_boost: float = 1.0
	if is_dash_active:
		push_multiplier = dash_nearby_push_multiplier
		if absf(push_direction.x) > absf(push_direction.y):
			ahead_threshold_bias = 0.11
			lateral_boost = 1.38
			push_multiplier *= dash_horizontal_push_force_multiplier
		else:
			ahead_threshold_bias = dash_nearby_push_ahead_margin
			lateral_boost = 1.24

	for item in player.get_tree().get_nodes_in_group("pushable_items"):
		if not is_instance_valid(item):
			continue
		if is_pushable_item_ignored(item):
			continue
		if not item.has_method("get_push_center") or not item.has_method("get_push_radius") or not item.has_method("apply_player_push"):
			continue

		var item_center: Vector2 = item.get_push_center()
		var item_radius: float = item.get_push_radius()
		var lateral_offset: float = absf((item_center - capsule_center).dot(lateral_axis))
		var lateral_limit: float = maxf(capsule_radius * 0.45 + item_radius * 0.15, 10.0) * lateral_boost
		if lateral_offset > lateral_limit:
			continue

		var ahead_amount: float = (item_center - capsule_center).dot(push_direction)
		var ahead_threshold: float = maxf(item_radius * 0.2, 2.0)
		if ahead_threshold_bias > 0.0:
			ahead_threshold = maxf(item_radius * ahead_threshold_bias, 0.5)
		if ahead_amount <= ahead_threshold:
			continue

		var closest_point: Vector2 = InteractionGeometry.closest_point_on_segment(item_center, capsule_top, capsule_bottom)
		var distance: float = item_center.distance_to(closest_point)
		var contact_distance: float = capsule_radius + item_radius
		var influence_distance: float = contact_distance + item_push_margin
		if distance > influence_distance:
			continue
		if overlaps_only and distance > contact_distance + 0.25:
			continue

		var margin_size: float = maxf(item_push_margin, 0.001)
		var closeness: float = 1.0 - clampf((distance - contact_distance) / margin_size, 0.0, 1.0)
		var push_force: float = item_push_acceleration * (0.22 + closeness * 0.78) * speed_factor * delta * push_multiplier
		var separation_direction: Vector2
		if distance > 0.001:
			separation_direction = (item_center - closest_point).normalized()
		else:
			separation_direction = push_direction

		separation_direction = (separation_direction * 0.35 + push_direction * 1.65).normalized()

		var penetration_depth: float = maxf(contact_distance - distance, 0.0)
		if overlaps_only:
			push_force *= 1.35
		var separation_motion: Vector2 = Vector2.ZERO
		if penetration_depth > 0.0:
			if overlaps_only and is_dash_active:
				ignore_pushable_item_temporarily(item, 0.12)
			var overlap_bias: float = item_push_overlap_bias
			if overlaps_only:
				overlap_bias *= 0.35
			separation_motion = separation_direction * (penetration_depth + overlap_bias)

		item.apply_player_push(push_direction, push_force, current_velocity, separation_motion)

func clamp_to_map_bounds() -> void:
	var previous_position := last_playable_position
	if _is_player_position_playable(player.global_position):
		last_playable_position = player.global_position
		previous_position = last_playable_position

	player.global_position = _clamp_position_to_map_from(player.global_position, previous_position)
	if _is_player_position_playable(player.global_position):
		last_playable_position = player.global_position

func get_item_push_capsule_data() -> Dictionary:
	return _get_base_item_push_capsule_data()

func get_active_push_capsule_data(_push_direction: Vector2 = Vector2.ZERO) -> Dictionary:
	return _get_base_item_push_capsule_data()

func get_body_collision_data() -> Dictionary:
	if not is_instance_valid(collision_shape):
		return {}

	var shape := collision_shape.shape as CircleShape2D
	if shape == null:
		return {}

	return {
		"center": collision_shape.global_position,
		"radius": shape.radius
	}

func is_item_in_push_range(item: Node2D) -> bool:
	if not is_instance_valid(item_push_area) or not is_instance_valid(item):
		return false
	return item_push_area.overlaps_body(item)

func is_item_push_debug_enabled() -> bool:
	return show_item_push_debug

func ignore_pushable_item_temporarily(item: Node, duration: float) -> void:
	if not is_instance_valid(item):
		return
	ignored_pushable_items[item.get_instance_id()] = {
		"item": item,
		"time": maxf(duration, 0.0)
	}

func is_pushable_item_ignored(item: Node) -> bool:
	if not is_instance_valid(item):
		return false
	return ignored_pushable_items.has(item.get_instance_id())

func update_ignored_pushable_items(delta: float) -> void:
	if ignored_pushable_items.is_empty():
		return

	var expired_ids: Array[int] = []
	for item_id in ignored_pushable_items.keys():
		var entry: Dictionary = ignored_pushable_items[item_id]
		var item: Node = entry.get("item")
		if not is_instance_valid(item):
			expired_ids.append(item_id)
			continue
		var remaining: float = float(entry.get("time", 0.0)) - delta
		if remaining <= 0.0:
			expired_ids.append(item_id)
			continue
		entry["time"] = remaining
		ignored_pushable_items[item_id] = entry

	for item_id in expired_ids:
		ignored_pushable_items.erase(item_id)

func get_item_push_capsule_data_at_position(player_position: Vector2) -> Dictionary:
	if not is_instance_valid(item_push_collision_shape):
		return {}

	var shape := item_push_collision_shape.shape as CapsuleShape2D
	if shape == null:
		return {}

	var local_offset: Vector2 = item_push_collision_shape.global_position - player.global_position
	var center: Vector2 = player_position + local_offset
	var radius: float = shape.radius
	var segment_half_length: float = maxf(shape.height * 0.5 - radius, 0.0)
	var axis: Vector2 = Vector2.DOWN.rotated(item_push_collision_shape.global_rotation)

	return {
		"center": center,
		"top": center - axis * segment_half_length,
		"bottom": center + axis * segment_half_length,
		"radius": radius
	}

func get_body_collision_data_at_position(player_position: Vector2) -> Dictionary:
	if not is_instance_valid(collision_shape):
		return {}

	var shape := collision_shape.shape as CircleShape2D
	if shape == null:
		return {}

	var local_offset: Vector2 = collision_shape.global_position - player.global_position
	return {
		"center": player_position + local_offset,
		"radius": shape.radius
	}

func get_player_map_min_position() -> Vector2:
	return movement_bounds.position + edge_padding

func get_player_map_max_position() -> Vector2:
	return movement_bounds.position + movement_bounds.size - edge_padding

func _try_move_axis(
	axis_motion: Vector2,
	current_velocity: Vector2,
	current_move_speed: float,
	is_dash_active: bool
) -> void:
	if axis_motion.length_squared() <= 0.000001:
		return

	var push_probe_motion: Vector2 = _get_effective_push_axis_motion(axis_motion)
	var push_attempts: int = 0
	while _would_overlap_pushable_item_on_sweep(push_probe_motion):
		if push_attempts >= 5:
			return
		if not _force_push_items_for_axis(push_probe_motion, current_velocity, current_move_speed, is_dash_active):
			return
		push_attempts += 1

	if player.test_move(player.global_transform, axis_motion):
		return

	if _would_overlap_pushable_item_on_sweep(push_probe_motion):
		return

	var previous_position := player.global_position
	var candidate_position := previous_position + axis_motion
	if _would_cross_blocked_map_boundary(previous_position, candidate_position):
		player.global_position = _clamp_position_to_map_from(candidate_position, previous_position)
		if _is_player_position_playable(player.global_position):
			last_playable_position = player.global_position
		return

	player.global_position = candidate_position
	if _is_player_position_playable(player.global_position):
		last_playable_position = player.global_position

func _is_player_position_playable(position: Vector2) -> bool:
	if prototype_map == null or not prototype_map.has_method("is_point_in_playable_area"):
		return movement_bounds.has_point(position)
	return bool(prototype_map.is_point_in_playable_area(position, edge_padding))

func _would_cross_blocked_map_boundary(from_position: Vector2, to_position: Vector2) -> bool:
	if prototype_map == null or not prototype_map.has_method("is_segment_blocked_by_dune_wall"):
		return false
	return bool(prototype_map.is_segment_blocked_by_dune_wall(from_position, to_position, edge_padding))

func _clamp_position_to_map_from(candidate_position: Vector2, previous_position: Vector2) -> Vector2:
	var clamped_position := candidate_position.clamp(get_player_map_min_position(), get_player_map_max_position())
	if prototype_map != null:
		if prototype_map.has_method("clamp_point_to_playable_from"):
			return prototype_map.clamp_point_to_playable_from(clamped_position, previous_position, edge_padding)
		if prototype_map.has_method("clamp_point_to_playable"):
			return prototype_map.clamp_point_to_playable(clamped_position, edge_padding)
	return clamped_position

func _get_effective_push_axis_motion(axis_motion: Vector2) -> Vector2:
	return axis_motion

func _force_push_items_for_axis(
	axis_motion: Vector2,
	current_velocity: Vector2,
	current_move_speed: float,
	is_dash_active: bool
) -> bool:
	var push_direction: Vector2 = axis_motion.normalized()
	if push_direction.length_squared() <= 0.000001:
		return false

	var capsule_data: Dictionary = get_active_push_capsule_data(push_direction)
	if capsule_data.is_empty():
		return false

	var capsule_top: Vector2 = capsule_data.get("top", player.global_position)
	var capsule_bottom: Vector2 = capsule_data.get("bottom", player.global_position)
	var capsule_radius: float = capsule_data.get("radius", 0.0)
	var moved_any: bool = false
	var push_passes: int = 0
	var max_push_passes: int = 4

	while push_passes < max_push_passes:
		var push_queue: Array[Dictionary] = _build_capsule_push_queue(axis_motion, capsule_top, capsule_bottom, capsule_radius)
		if push_queue.is_empty():
			break

		var player_velocity_hint: Vector2 = current_velocity
		if player_velocity_hint.length_squared() <= 0.000001:
			player_velocity_hint = push_direction * current_move_speed
		var emergency_push_force: float = item_push_acceleration * 0.028
		if is_dash_active:
			emergency_push_force = item_push_acceleration * 0.24
			if absf(push_direction.x) > absf(push_direction.y):
				emergency_push_force *= dash_horizontal_push_force_multiplier

		var moved_this_pass: bool = false
		var front_actual_shift: float = -1.0
		var front_axis_position: float = 0.0
		var front_radius: float = 0.0
		for queue_index in range(push_queue.size() - 1, -1, -1):
			var push_entry: Dictionary = push_queue[queue_index]
			var item: Node = push_entry.get("item")
			if not is_instance_valid(item):
				continue
			var item_radius: float = float(push_entry.get("radius", 0.0))
			var item_axis_position: float = float(push_entry.get("axis_position", 0.0))
			var required_axis_shift: float = float(push_entry.get("required_axis_shift", 0.0))
			var propagated_axis_shift: float = required_axis_shift
			if front_actual_shift >= 0.0:
				var gap_to_front: float = front_axis_position - item_axis_position - item_radius - front_radius
				propagated_axis_shift = minf(propagated_axis_shift, front_actual_shift + maxf(gap_to_front, 0.0))
			front_axis_position = item_axis_position
			front_radius = item_radius
			if propagated_axis_shift <= 0.001:
				front_actual_shift = 0.0
				continue
			var emergency_separation: float = required_axis_shift + 0.08
			var max_step_separation: float = axis_motion.length() + capsule_radius * 0.34
			if is_dash_active:
				emergency_separation = propagated_axis_shift * 0.45 + 0.04
				max_step_separation += item_radius * 0.95 + capsule_radius * 0.52
				if absf(push_direction.x) > absf(push_direction.y):
					max_step_separation += capsule_radius * 0.12
			emergency_separation = minf(emergency_separation, max_step_separation)

			var item_center_before: Vector2 = item.get_push_center()
			item.apply_player_push(
				push_direction,
				emergency_push_force,
				player_velocity_hint,
				push_direction * emergency_separation
			)
			var actual_axis_shift: float = maxf((item.get_push_center() - item_center_before).dot(push_direction), 0.0)
			front_actual_shift = actual_axis_shift
			if actual_axis_shift > 0.000001:
				moved_this_pass = true
				moved_any = true

		if not moved_this_pass:
			break
		push_passes += 1

	return moved_any

func _build_capsule_push_queue(axis_motion: Vector2, capsule_top: Vector2, capsule_bottom: Vector2, capsule_radius: float) -> Array[Dictionary]:
	var push_direction: Vector2 = axis_motion.normalized()
	if push_direction.length_squared() <= 0.000001:
		return []

	var future_capsule_top: Vector2 = capsule_top + axis_motion
	var future_capsule_bottom: Vector2 = capsule_bottom + axis_motion
	var current_front_axis_position: float = maxf(capsule_top.dot(push_direction), capsule_bottom.dot(push_direction))
	var current_back_axis_position: float = minf(capsule_top.dot(push_direction), capsule_bottom.dot(push_direction))
	var target_axis_position: float = maxf(future_capsule_top.dot(push_direction), future_capsule_bottom.dot(push_direction)) + capsule_radius
	var candidate_entries: Dictionary = {}
	var search_queue: Array[Dictionary] = []

	for item in player.get_tree().get_nodes_in_group("pushable_items"):
		if not is_instance_valid(item):
			continue
		if is_pushable_item_ignored(item):
			continue
		if not item.has_method("get_push_center") or not item.has_method("get_push_radius") or not item.has_method("apply_player_push"):
			continue

		var item_center: Vector2 = item.get_push_center()
		var item_radius: float = item.get_push_radius()
		var contact_distance: float = capsule_radius + item_radius
		var closest_point_on_capsule: Vector2 = InteractionGeometry.closest_point_on_segment(item_center, capsule_top, capsule_bottom)
		var current_contact_distance: float = item_center.distance_to(closest_point_on_capsule)
		var closest_point_on_sweep: Vector2 = InteractionGeometry.closest_point_on_segment(
			item_center,
			closest_point_on_capsule,
			closest_point_on_capsule + axis_motion
		)
		var sweep_distance: float = item_center.distance_to(closest_point_on_sweep)
		if sweep_distance > contact_distance + 0.5:
			continue

		var item_axis_position: float = item_center.dot(push_direction)
		var front_margin: float = maxf(capsule_radius * 0.25, 1.0)
		if item_axis_position + item_radius < current_front_axis_position - front_margin:
			continue
		if item_axis_position < current_back_axis_position - maxf(capsule_radius * 0.15, 0.5):
			continue
		if current_contact_distance > contact_distance + maxf(axis_motion.length(), 0.75):
			continue

		var candidate_entry := {
			"item": item,
			"center": item_center,
			"radius": item_radius,
			"axis_position": item_axis_position,
			"contact_distance": contact_distance
		}
		candidate_entries[item.get_instance_id()] = candidate_entry
		search_queue.append(candidate_entry)

	while not search_queue.is_empty():
		var source_entry: Dictionary = search_queue.pop_back()
		var source_center: Vector2 = source_entry.get("center", Vector2.ZERO)
		var source_radius: float = float(source_entry.get("radius", 0.0))

		for item in player.get_tree().get_nodes_in_group("pushable_items"):
			if not is_instance_valid(item):
				continue
			if is_pushable_item_ignored(item):
				continue
			var item_id: int = item.get_instance_id()
			if candidate_entries.has(item_id):
				continue
			if not item.has_method("get_push_center") or not item.has_method("get_push_radius") or not item.has_method("apply_player_push"):
				continue

			var item_center: Vector2 = item.get_push_center()
			var item_radius: float = item.get_push_radius()
			var item_axis_position: float = item_center.dot(push_direction)
			if item_axis_position + item_radius < current_back_axis_position - maxf(capsule_radius * 0.2, 1.0):
				continue
			var neighbor_distance: float = source_center.distance_to(item_center)
			var neighbor_limit: float = source_radius + item_radius + maxf(axis_motion.length(), 6.0)
			if neighbor_distance > neighbor_limit:
				continue

			var expanded_entry := {
				"item": item,
				"center": item_center,
				"radius": item_radius,
				"axis_position": item_axis_position,
				"contact_distance": capsule_radius + item_radius
			}
			candidate_entries[item_id] = expanded_entry
			search_queue.append(expanded_entry)

	if candidate_entries.is_empty():
		return []

	var sorted_candidates: Array = candidate_entries.values()
	sorted_candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a.get("axis_position", 0.0)) < float(b.get("axis_position", 0.0))
	)

	var push_queue: Array[Dictionary] = []
	for candidate_entry in sorted_candidates:
		var candidate_radius: float = float(candidate_entry.get("radius", 0.0))
		target_axis_position += candidate_radius
		var required_axis_shift: float = maxf(target_axis_position - float(candidate_entry.get("axis_position", 0.0)), 0.0)
		candidate_entry["required_axis_shift"] = required_axis_shift
		push_queue.append(candidate_entry)
		target_axis_position += candidate_radius

	return push_queue

func _would_overlap_pushable_item_on_sweep(axis_motion: Vector2) -> bool:
	if axis_motion.length_squared() <= 0.000001:
		return false

	var capsule_data: Dictionary = get_active_push_capsule_data(axis_motion.normalized())
	if capsule_data.is_empty():
		return false

	var capsule_top: Vector2 = capsule_data.get("top", player.global_position)
	var capsule_bottom: Vector2 = capsule_data.get("bottom", player.global_position)
	var capsule_radius: float = capsule_data.get("radius", 0.0)
	return not _build_capsule_push_queue(axis_motion, capsule_top, capsule_bottom, capsule_radius).is_empty()

func _get_base_item_push_capsule_data() -> Dictionary:
	if not is_instance_valid(item_push_collision_shape):
		return {}

	var shape := item_push_collision_shape.shape as CapsuleShape2D
	if shape == null:
		return {}

	var center: Vector2 = item_push_collision_shape.global_position
	var radius: float = shape.radius
	var segment_half_length: float = maxf(shape.height * 0.5 - radius, 0.0)
	var axis: Vector2 = Vector2.DOWN.rotated(item_push_collision_shape.global_rotation)

	return {
		"center": center,
		"top": center - axis * segment_half_length,
		"bottom": center + axis * segment_half_length,
		"radius": radius
	}
