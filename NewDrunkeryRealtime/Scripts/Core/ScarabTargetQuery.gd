extends RefCounted

const TestItemDefs = preload("res://Scripts/Kitchen/TestItemDefs.gd")
const GROUND_PREFERENCE_DISTANCE: float = 128.0

## Read-only target selection. Navigation is supplied by the caller so all
## scarabs retain the same shared grids, gate routes and frame budget.
static func is_current_target_valid(scarab: Node2D) -> bool:
	if not is_instance_valid(scarab.current_target) or scarab.current_target.is_queued_for_deletion():
		return false
	if scarab.current_target_kind == &"cabinet":
		return scarab.current_target.has_method("is_scarab_steal_target") and bool(scarab.current_target.is_scarab_steal_target())
	if scarab.current_target_kind == &"ground":
		return is_player_interactable(scarab.current_target) and scarab.current_target.has_method("get_item_id") and TestItemDefs.is_ingredient(scarab.current_target.get_item_id())
	return false

static func collect(tree: SceneTree, storage_manager: Node, is_in_kitchen: Callable) -> Array[Dictionary]:
	var targets: Array[Dictionary] = []
	for item in tree.get_nodes_in_group("loose_items"):
		if not is_instance_valid(item) or not item is Node2D:
			continue
		if item.has_method("get_item_id") and TestItemDefs.is_ingredient(item.get_item_id()):
			if is_in_kitchen.call(item.global_position) and is_player_interactable(item):
				targets.append({"node": item, "kind": &"ground"})
	for cabinet in tree.get_nodes_in_group("storage_facilities"):
		if not is_instance_valid(cabinet) or not cabinet is Node2D or not is_in_kitchen.call(cabinet.global_position):
			continue
		if storage_manager == null or not storage_manager.has_method("get_stock"):
			continue
		var item_id := StringName(cabinet.get("stored_item_id"))
		if item_id == &"" or storage_manager.get_stock(item_id) <= 0 or not is_player_interactable(cabinet):
			continue
		targets.append({"node": cabinet, "kind": &"cabinet"})
	return targets

static func is_player_interactable(target: Node) -> bool:
	# A player carrying an item cannot take another one, but that temporary hand
	# state must not make every scarab lose its target. Target validity follows
	# the source's current menu/visibility eligibility instead.
	if is_instance_valid(target) and not target.is_queued_for_deletion() and target.has_method("is_scarab_steal_target"):
		return bool(target.is_scarab_steal_target())
	return false

static func find_nearest(scarab: Node2D, targets: Array[Dictionary], route_to_position: Callable, can_reach_cabinet: Callable, can_reach_ground: Callable) -> Dictionary:
	var nearest_target := {}
	var nearest_distance := INF
	for entry in targets:
		var node: Node2D = entry.get("node")
		if not is_instance_valid(node) or not is_player_interactable(node):
			continue
		var positions: Array[Vector2] = []
		var cabinet: bool = entry.get("kind") == &"cabinet"
		if cabinet:
			positions = node.get_scarab_approach_positions()
		else:
			positions = _ground_approach_positions(scarab, node)
		var occupied: Array = entry.get("occupied_positions", [])
		for position in positions:
			# Straight-line distance is a lower bound on route cost. Skip only
			# candidates that cannot beat the already reachable best choice.
			var lower_bound := scarab.global_position.distance_to(position)
			if cabinet:
				lower_bound = maxf(lower_bound - 32.0, 0.0)
			else:
				lower_bound += position.distance_to(node.global_position) - GROUND_PREFERENCE_DISTANCE
			if lower_bound >= nearest_distance:
				continue
			if cabinet and not can_reach_cabinet.call(scarab, node, position):
				continue
			var unavailable := false
			for taken: Vector2 in occupied:
				if taken.distance_to(position) < 68.0:
					unavailable = true
					break
			if unavailable:
				continue
			var route: Array[Vector2] = []
			# Cabinet queries include the cabinet collider. Neither an empty
			# route nor being near the center permits stealing through scenery.
			if cabinet or not position.is_equal_approx(scarab.global_position):
				# Ground candidates share the published grid and local endpoint
				# repairs; never rebuild the whole grid for every ring sample.
				route = route_to_position.call(scarab, position, [scarab], false, false, cabinet)
				if route.is_empty():
					continue
			if not cabinet and not can_reach_ground.call(scarab, node, position):
				continue
			var distance := _route_length(scarab.global_position, route, position)
			# Loose food within roughly one tile of the cabinet's route cost
			# wins, but distant drops must not override a nearby source.
			if not cabinet:
				distance += position.distance_to(node.global_position) - GROUND_PREFERENCE_DISTANCE
			# Keep a usable assigned slot stable as the actor follows its path.
			if cabinet and node == scarab.current_target and scarab.target_approach_position.is_equal_approx(position):
				distance = maxf(distance - 32.0, 0.0)
			if distance >= nearest_distance:
				if not cabinet:
					break
				continue
			nearest_distance = distance
			nearest_target = entry.duplicate()
			nearest_target["route"] = route
			nearest_target["approach"] = position
			if not cabinet:
				# Candidates are ordered from the actor's side. Stop at the first
				# reachable one rather than running AStar for every ring sample.
				break
	return nearest_target

static func _ground_approach_positions(scarab: Node2D, target: Node2D) -> Array[Vector2]:
	var positions: Array[Vector2] = []
	if scarab.global_position.distance_to(target.global_position) <= scarab.steal_reach:
		positions.append(scarab.global_position)
	var direction := target.global_position.direction_to(scarab.global_position)
	if direction.is_zero_approx():
		direction = Vector2.RIGHT
	# Leave room for arrival tolerance while standing outside the food's body.
	var radius: float = maxf(scarab.steal_reach - 16.0, 1.0)
	for step in [0, 1, -1, 2, -2, 3, -3, 4]:
		positions.append(target.global_position + direction.rotated(float(step) * TAU / 8.0) * radius)
	return positions

static func _route_length(origin: Vector2, route: Array[Vector2], destination: Vector2) -> float:
	var previous := origin
	var total := 0.0
	for point in route:
		total += previous.distance_to(point)
		previous = point
	return total + previous.distance_to(destination)

