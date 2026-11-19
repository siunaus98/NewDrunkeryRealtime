extends RefCounted

# Pure scene query: the player owns how the result is combined with other
# movement modifiers; this helper only finds the strongest active aura.

static func get_movement_multiplier(tree: SceneTree, world_position: Vector2) -> float:
	return get_max_multiplier(tree, world_position, &"get_movement_speed_multiplier")

static func get_cook_multiplier(tree: SceneTree, world_position: Vector2) -> float:
	return get_max_multiplier(tree, world_position, &"get_cook_speed_multiplier")

static func get_max_multiplier(tree: SceneTree, world_position: Vector2, multiplier_method: StringName) -> float:
	if tree == null:
		return 1.0
	var multiplier: float = 1.0
	for support in tree.get_nodes_in_group("support_facilities"):
		if not is_instance_valid(support) or not (support is Node2D):
			continue
		if support is CanvasItem and not (support as CanvasItem).visible:
			continue
		if not support.has_method(multiplier_method) or not support.has_method("get_support_aura_radius"):
			continue
		if world_position.distance_to((support as Node2D).global_position) > float(support.get_support_aura_radius()):
			continue
		multiplier = maxf(multiplier, float(support.call(multiplier_method)))
	return multiplier
