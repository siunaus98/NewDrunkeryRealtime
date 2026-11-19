extends RefCounted

const Catalog = preload("res://Scripts/Facilities/FacilityCatalog.gd")

static func purchase(flow: Node, id: StringName) -> bool:
	var entry := Catalog.definition(id)
	var count: int = flow.progression_state.get_stat_purchase_count(StringName("facility_%s" % id)) if flow.progression_state != null else 0
	if not Catalog.available(id, count):
		return false
	var reference: Node = flow.level_refs
	var root: Node = reference.get_runtime_root() if reference != null else flow.get_tree().current_scene
	if root == null:
		return false
	var created: Array[Node2D] = []
	for index in range(2 if bool(entry.get("pair", false)) else 1):
		var facility := Catalog.create(id)
		root.add_child(facility)
		var position: Vector2 = _find_vehicle_position(flow, facility) if id == &"forklift" else flow._find_support_facility_spawn_position(facility)
		if position == Vector2.INF:
			facility.free()
			for previous: Node2D in created:
				previous.free()
			return false
		facility.global_position = position
		if id == &"trap_rack":
			preload("res://Scripts/Facilities/FacilityItems.gd").drop(root, position, {"item_id": &"bear_trap", "payload": {"persistent_purchase": true}})
			facility.free()
			return true
		created.append(facility)
	if created.size() == 2:
		created[0].partner = created[1]
		created[1].partner = created[0]
		if id == &"shuttle":
			created[1].cart_here = false
	return true

static func _find_vehicle_position(flow: Node, facility: Node2D) -> Vector2:
	var map: Node = flow.level_refs.get_prototype_map()
	var region: Rect2 = map.get_region_bounds(&"near")
	for y in range(int(region.position.y / 128), int(region.end.y / 128)):
		for x in range(int(region.position.x / 128), int(region.end.x / 128)):
			var point := Vector2(x * 128 + 64, y * 128 + 64)
			var cell: Vector2i = map.get_cell_for_point(point)
			if flow._is_support_facility_spawn_clear(facility, map, cell, Vector2i.ONE, point):
				return point
	return Vector2.INF
