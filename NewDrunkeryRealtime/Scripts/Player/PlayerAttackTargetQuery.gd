extends RefCounted

# Pure target geometry shared by attack hit tests and auto-aim selection.

static func get_target_position(target: Node) -> Vector2:
	if target != null and target.has_method("get_hit_position"):
		return target.get_hit_position()
	return target.global_position if target is Node2D else Vector2.ZERO

static func get_target_radius(target: Node) -> float:
	return float(target.get_hit_radius()) if target != null and target.has_method("get_hit_radius") else 0.0

static func get_target_geometry(target: Node, origin: Vector2) -> Dictionary:
	if target != null and target.has_method("get_hurt_regions"):
		var regions: Array[Dictionary] = target.get_hurt_regions()
		var best: Dictionary = {}
		var nearest := INF
		for region: Dictionary in regions:
			var offset: Vector2 = region.position - origin
			var candidate := {"position": region.position, "radius": region.radius, "offset": offset, "distance": offset.length()}
			var edge_distance: float = offset.length() - float(region.radius)
			if edge_distance < nearest:
				nearest = edge_distance
				best = candidate
		if not best.is_empty():
			best["regions"] = regions
			best["origin"] = origin
			return best
	var position := get_target_position(target)
	var offset := position - origin
	return {"position": position, "radius": get_target_radius(target), "offset": offset, "distance": offset.length()}

static func is_in_attack_geometry(geometry: Dictionary, inner_radius: float, outer_radius: float, direction: Vector2, half_angle: float, can_reach: Callable = Callable()) -> bool:
	if geometry.has("regions"):
		var best: Dictionary = {}
		var nearest := INF
		for region: Dictionary in geometry.regions:
			if can_reach.is_valid() and not bool(can_reach.call(region.position)):
				continue
			var offset: Vector2 = region.position - Vector2(geometry.origin)
			var radius: float = region.radius
			var distance := offset.length()
			if not circle_intersects_sector(offset, radius, inner_radius, outer_radius, direction, half_angle):
				continue
			if distance - radius < nearest:
				nearest = distance - radius
				best = {"position": region.position, "radius": radius, "offset": offset, "distance": distance}
		if best.is_empty():
			return false
		geometry.merge(best, true)
		return true
	var radius: float = float(geometry.get("radius", 0.0))
	var distance: float = float(geometry.get("distance", INF))
	if distance < inner_radius - radius or distance > outer_radius + radius:
		return false
	var offset: Vector2 = geometry.get("offset", Vector2.ZERO)
	if offset.length_squared() <= 0.001:
		return true
	return abs(direction.angle_to(offset.normalized())) <= half_angle

static func circle_intersects_sector(offset: Vector2, radius: float, inner_radius: float, outer_radius: float, direction: Vector2, half_angle: float) -> bool:
	var distance := offset.length()
	if distance > outer_radius + radius or distance + radius < inner_radius:
		return false
	if distance <= 0.001:
		return radius >= inner_radius
	var aim := direction.normalized() if not direction.is_zero_approx() else Vector2.RIGHT
	if half_angle >= PI or absf(aim.angle_to(offset / distance)) <= half_angle:
		return true
	# Circle may cross an edge of the sector even when its centre is outside.
	for sign_value: float in [-1.0, 1.0]:
		var edge := aim.rotated(half_angle * sign_value)
		var closest := Geometry2D.get_closest_point_to_segment(offset, edge * inner_radius, edge * outer_radius)
		if closest.distance_squared_to(offset) <= radius * radius:
			return true
	return false
