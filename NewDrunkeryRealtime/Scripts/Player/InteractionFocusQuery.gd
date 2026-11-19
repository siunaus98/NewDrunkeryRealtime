extends RefCounted

# Selection only: facilities own eligibility; the controller commits focus/highlights.
# Custom focus data is returned unchanged so serving counters retain their slot data.
static func select_target(
	player: CharacterBody2D,
	candidates: Array,
	holding_item: bool,
	interaction_origin: Vector2,
	aim_direction: Vector2,
	interaction_radius: float,
	half_interaction_angle: float
) -> Dictionary:
	var best: Dictionary = {}
	for candidate in candidates:
		if not is_instance_valid(candidate):
			continue
		if candidate is CanvasItem and not (candidate as CanvasItem).is_visible_in_tree():
			continue
		if not _is_focusable(candidate, player, holding_item) or not candidate.has_method("get_pickup_drop_radius"):
			continue
		var radius: float = interaction_radius
		if candidate.has_method("get_player_interaction_radius"):
			var custom_radius: Variant = candidate.get_player_interaction_radius()
			if (custom_radius is float or custom_radius is int) and float(custom_radius) > 0.0:
				radius = float(custom_radius)
		radius = minf(radius, float(candidate.get_pickup_drop_radius()))
		var hits: Array[Dictionary] = []
		var focus_data: Dictionary = {}
		if candidate.has_method("evaluate_pickup_drop_focus"):
			var custom_hit: Variant = candidate.evaluate_pickup_drop_focus(player, interaction_origin, aim_direction, radius, half_interaction_angle)
			if custom_hit is Dictionary:
				hits.append(custom_hit)
				focus_data = custom_hit
		elif candidate.has_method("get_interaction_rect_global"):
			hits.append(_evaluate_rect_interaction_candidate(player, candidate, interaction_origin, aim_direction, radius, half_interaction_angle))
		else:
			hits = _evaluate_points(candidate, interaction_origin, aim_direction, radius, half_interaction_angle)
		for hit in hits:
			if not hit.get("valid", false):
				continue
			# Preserve the immediate winner for a point coincident with the origin.
			if focus_data.is_empty() and not candidate.has_method("get_interaction_rect_global") and hit.get("immediate", false):
				return {"target": candidate, "focus_data": {}}
			if _is_better(hit, best):
				best = {"target": candidate, "focus_data": focus_data, "distance": hit.get("distance", INF), "angle": hit.get("angle", INF)}
	return best

static func _is_focusable(candidate: Node, player: CharacterBody2D, holding_item: bool) -> bool:
	if preload("res://Scripts/Facilities/FacilityWorkPause.gd").is_paused(candidate):
		return true
	# A source rejected by a held plate must still consume J rather than
	# silently changing that action into a ground drop.
	if player.get_held_item_id() == &"transport_plate" and candidate.has_method("can_take_item"):
		return true
	if candidate.has_method("is_pickup_drop_focusable"):
		return bool(candidate.is_pickup_drop_focusable(player))
	if holding_item:
		return candidate.has_method("can_receive_item") and bool(candidate.can_receive_item(player))
	return candidate.has_method("can_take_item") and bool(candidate.can_take_item(player))

static func _is_better(hit: Dictionary, best: Dictionary) -> bool:
	var distance: float = hit.get("distance", INF)
	var best_distance: float = best.get("distance", INF)
	return distance < best_distance - 0.001 or (is_equal_approx(distance, best_distance) and float(hit.get("angle", INF)) < float(best.get("angle", INF)))

static func _evaluate_points(candidate: Node, origin: Vector2, aim: Vector2, radius: float, half_angle: float) -> Array[Dictionary]:
	var positions: Array = []
	if candidate.has_method("get_pickup_drop_positions"):
		positions = candidate.get_pickup_drop_positions()
	elif candidate.has_method("get_pickup_drop_position"):
		positions = [candidate.get_pickup_drop_position()]
	var hits: Array[Dictionary] = []
	for position in positions:
		var offset: Vector2 = position - origin
		var distance: float = offset.length()
		if distance > radius:
			continue
		if distance <= 0.001:
			hits.append({"valid": true, "immediate": true})
			break
		var angle: float = abs(aim.angle_to(offset.normalized()))
		if angle > half_angle:
			continue
		var hit: Dictionary = {"valid": true, "distance": distance, "angle": angle}
		hits.append(hit)
	return hits

static func _evaluate_rect_interaction_candidate(
	player: CharacterBody2D,
	candidate: Node,
	interaction_origin: Vector2,
	aim_direction: Vector2,
	interaction_radius: float,
	half_interaction_angle: float
) -> Dictionary:
	var interaction_rect: Variant = candidate.get_interaction_rect_global()
	if not (interaction_rect is Rect2):
		return {}

	var rect: Rect2 = interaction_rect
	var nearest_point := Vector2(
		clampf(interaction_origin.x, rect.position.x, rect.position.x + rect.size.x),
		clampf(interaction_origin.y, rect.position.y, rect.position.y + rect.size.y)
	)
	var to_nearest: Vector2 = nearest_point - interaction_origin
	var nearest_distance: float = to_nearest.length()
	if nearest_distance > interaction_radius:
		return {}

	var rect_center: Vector2 = rect.position + rect.size * 0.5
	var to_center: Vector2 = rect_center - interaction_origin
	var center_distance: float = to_center.length()
	var nearest_angle: float = abs(aim_direction.angle_to(to_nearest.normalized())) if nearest_distance > 0.001 else 0.0
	var center_angle: float = abs(aim_direction.angle_to(to_center.normalized())) if center_distance > 0.001 else 0.0
	var angle_slack: float = deg_to_rad(12.0)

	var nearest_passes: bool = nearest_distance <= interaction_radius and nearest_angle <= half_interaction_angle + angle_slack
	var center_passes: bool = center_distance <= interaction_radius and center_angle <= half_interaction_angle
	if not nearest_passes and not center_passes:
		return {}

	var focus_point: Vector2 = nearest_point if nearest_passes else rect_center
	if _is_interaction_path_blocked(player, candidate, interaction_origin, focus_point):
		return {}

	return {
		"valid": true,
		"distance": nearest_distance if nearest_passes else center_distance,
		"angle": nearest_angle if nearest_passes else center_angle
	}

static func _is_interaction_path_blocked(player: CharacterBody2D, candidate: Node, from_position: Vector2, to_position: Vector2) -> bool:
	if from_position.distance_squared_to(to_position) <= 0.001:
		return false

	var query := PhysicsRayQueryParameters2D.create(from_position, to_position)
	query.collision_mask = 4 | 8 | 16
	query.exclude = [player.get_rid()]
	var hit: Dictionary = player.get_world_2d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return false

	var collider: Node = hit.get("collider", null)
	if collider == null:
		return false
	var current: Node = collider
	while current != null:
		if current == candidate:
			return false
		current = current.get_parent()
	return true

