extends RefCounted

# Pure target geometry shared by attack hit tests and auto-aim selection.

static func get_target_position(target: Node) -> Vector2:
	if target != null and target.has_method("get_hit_position"):
		return target.get_hit_position()
	return target.global_position if target is Node2D else Vector2.ZERO

static func get_target_radius(target: Node) -> float:
	return float(target.get_hit_radius()) if target != null and target.has_method("get_hit_radius") else 0.0

static func get_target_geometry(target: Node, origin: Vector2) -> Dictionary:
	var position := get_target_position(target)
	var offset := position - origin
	return {"position": position, "radius": get_target_radius(target), "offset": offset, "distance": offset.length()}

static func is_in_attack_geometry(geometry: Dictionary, inner_radius: float, outer_radius: float, direction: Vector2, half_angle: float) -> bool:
	var radius: float = float(geometry.get("radius", 0.0))
	var distance: float = float(geometry.get("distance", INF))
	if distance < inner_radius - radius or distance > outer_radius + radius:
		return false
	var offset: Vector2 = geometry.get("offset", Vector2.ZERO)
	if offset.length_squared() <= 0.001:
		return true
	return abs(direction.angle_to(offset.normalized())) <= half_angle
