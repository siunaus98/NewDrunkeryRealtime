extends RefCounted

# Pure map query: callers decide when an attack or hazard should be evaluated.

static func can_points_interact(prototype_map: Node, source_point: Vector2, target_point: Vector2) -> bool:
	if prototype_map == null or not prototype_map.has_method("get_zone_for_point"):
		return true
	var source_zone: Variant = prototype_map.get_zone_for_point(source_point)
	var target_zone: Variant = prototype_map.get_zone_for_point(target_point)
	if prototype_map.has_method("can_zones_interact"):
		return bool(prototype_map.can_zones_interact(StringName(source_zone), StringName(target_zone)))
	if source_zone == null or target_zone == null:
		return true
	if StringName(source_zone) == &"none" or StringName(target_zone) == &"none":
		return true
	return source_zone == target_zone

static func get_node_point(target: Node2D) -> Vector2:
	if target != null and target.has_method("get_sort_origin"):
		return target.get_sort_origin()
	return target.global_position if target != null else Vector2.ZERO
