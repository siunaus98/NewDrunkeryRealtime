extends RefCounted

## Read-only placement geometry. Uses current transforms without moving nodes.

static func calculate(player: Node2D, carried_facility: Node2D) -> Dictionary:
	if not is_instance_valid(carried_facility) or player == null or not is_instance_valid(player):
		return {"valid": false}
	var prototype_map: Node = player.get_prototype_map_node() if player.has_method("get_prototype_map_node") else null
	if prototype_map == null:
		return {"valid": false}
	var tile_size: Vector2 = prototype_map.get_tile_size() if prototype_map.has_method("get_tile_size") else Vector2(128.0, 128.0)
	var sort_origin: Vector2 = player.get_sort_origin() if player.has_method("get_sort_origin") else (player as Node2D).global_position
	var local_player_point: Vector2 = prototype_map.to_local(sort_origin)
	var player_cell := Vector2i(
		int(floor(local_player_point.x / tile_size.x)),
		int(floor(local_player_point.y / tile_size.y))
	)
	var aim_direction: Vector2 = player.get_aim_direction_world() if player.has_method("get_aim_direction_world") else Vector2.RIGHT
	var target_cell: Vector2i = player_cell + _get_cardinal_aim_cell_direction(aim_direction)
	var footprint: Vector2i = _get_carried_facility_footprint(carried_facility)
	var top_left_cell := Vector2i(
		target_cell.x - int(floor(float(footprint.x) * 0.5)),
		target_cell.y - int(floor(float(footprint.y) * 0.5))
	)
	var rect_local := Rect2(Vector2(top_left_cell) * tile_size, Vector2(footprint) * tile_size)
	var rect_global := Rect2(prototype_map.to_global(rect_local.position), rect_local.size)
	var place_position: Vector2 = rect_global.get_center()
	var is_valid: bool = _is_facility_placement_in_editable_area(prototype_map, top_left_cell, footprint, carried_facility)
	if is_valid and carried_facility.has_method("validate_placement"):
		is_valid = carried_facility.validate_placement(place_position)
	if is_valid:
		is_valid = _is_facility_placement_clear(player, carried_facility, rect_global)
	if is_valid:
		# The broad grid rectangle can miss an edge overlap when a facility's
		# authored collision shape is offset inside the cell. Check the actual
		# facility shapes against the player's body before restoring collisions.
		is_valid = not would_overlap_player_at(player, carried_facility, place_position)
	return {
		"valid": is_valid,
		"rect": rect_global,
		"position": place_position
	}

static func _get_carried_facility_footprint(carried_facility: Node2D) -> Vector2i:
	if carried_facility.has_method("get_layout_footprint"):
		var footprint_variant: Variant = carried_facility.get_layout_footprint()
		if footprint_variant is Vector2i:
			return Vector2i(maxi(footprint_variant.x, 1), maxi(footprint_variant.y, 1))
		if footprint_variant is Vector2:
			return Vector2i(maxi(int(footprint_variant.x), 1), maxi(int(footprint_variant.y), 1))
	return Vector2i(1, 1)

static func _get_cardinal_aim_cell_direction(safe_aim: Vector2) -> Vector2i:
	safe_aim = safe_aim.normalized() if safe_aim.length_squared() > 0.0001 else Vector2.RIGHT
	if absf(safe_aim.x) >= absf(safe_aim.y):
		return Vector2i(1 if safe_aim.x >= 0.0 else -1, 0)
	return Vector2i(0, 1 if safe_aim.y >= 0.0 else -1)

static func _is_facility_placement_in_editable_area(prototype_map: Node, top_left_cell: Vector2i, footprint: Vector2i, facility: Node = null) -> bool:
	var columns: int = int(prototype_map.get("columns"))
	var rows: int = int(prototype_map.get("rows"))
	var outside: bool = facility != null and facility.get("allows_battle_placement") == true
	if not outside and (top_left_cell.x < 0 or top_left_cell.y < 0):
		return false
	if not outside and (top_left_cell.x + footprint.x > columns or top_left_cell.y + footprint.y > rows):
		return false
	if prototype_map.has_method("is_cell_editable_for_facility"):
		for y in range(top_left_cell.y, top_left_cell.y + footprint.y):
			for x in range(top_left_cell.x, top_left_cell.x + footprint.x):
				if not bool(prototype_map.is_cell_editable_for_facility(Vector2i(x, y), facility)):
					return false
	return true

static func _is_facility_placement_clear(player: Node2D, carried_facility: Node2D, rect_global: Rect2) -> bool:
	for pad in player.get_tree().get_nodes_in_group("wind_sand_pads"):
		if is_instance_valid(pad) and pad is Node2D:
			var pad_rect := Rect2((pad as Node2D).global_position - Vector2(58.0, 58.0), Vector2(116.0, 116.0))
			if rect_global.intersects(pad_rect):
				return false
	var query_shape := RectangleShape2D.new()
	# Check the whole grid footprint. A tiny inset avoids treating two adjacent
	# facilities that merely touch at a cell boundary as overlapping.
	query_shape.size = Vector2(maxf(rect_global.size.x - 2.0, 4.0), maxf(rect_global.size.y - 2.0, 4.0))
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = query_shape
	query.transform = Transform2D(0.0, rect_global.get_center())
	# Include every gameplay body category: player, enemies/NPCs, facilities,
	# loose ingredients/dishes, and item blockers.
	query.collision_mask = 1 | 2 | 4 | 8 | 16
	var world_2d: World2D = player.get_world_2d() if player != null else null
	if world_2d == null:
		return false
	var overlaps: Array[Dictionary] = world_2d.direct_space_state.intersect_shape(query, 24)
	for hit in overlaps:
		var collider: Node = hit.get("collider", null)
		if collider == null or _is_node_inside_carried_facility(collider, carried_facility):
			continue
		return false
	return true

static func would_overlap_player_at(player: Node2D, carried_facility: Node2D, place_position: Vector2) -> bool:
	if player == null or not is_instance_valid(player) or not is_instance_valid(carried_facility):
		return true
	var player_body := player.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if player_body == null or player_body.shape == null:
		return true
	var offset := place_position - carried_facility.global_position
	var facility_shapes: Array[CollisionShape2D] = []
	_collect_collision_shapes(carried_facility, facility_shapes)
	for facility_shape in facility_shapes:
		if facility_shape.disabled or facility_shape.shape == null:
			continue
		var shape_transform := facility_shape.global_transform
		shape_transform.origin += offset
		if facility_shape.shape.collide(shape_transform, player_body.shape, player_body.global_transform):
			return true
	return false

static func _collect_collision_shapes(root: Node, output: Array[CollisionShape2D]) -> void:
	if root is CollisionShape2D:
		output.append(root as CollisionShape2D)
	for child in root.get_children():
		_collect_collision_shapes(child, output)

static func _is_node_inside_carried_facility(node: Node, carried_facility: Node2D) -> bool:
	var current: Node = node
	while current != null:
		if current == carried_facility:
			return true
		current = current.get_parent()
	return false

