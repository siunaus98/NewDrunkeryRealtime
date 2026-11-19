extends Node2D

## Persistent, seed-stable scenery. Sparse collision silhouettes leave the major
## travel lanes open. No processing tick, animations or gameplay random draws.
const IngredientSourceDefs = preload("res://Scripts/Core/IngredientSourceDefs.gd")
const REGION_NEAR: StringName = &"near"
const REGION_LEFT: StringName = &"left"
const REGION_RIGHT: StringName = &"right"
const REGION_TOP: StringName = &"top"
const SOLID_BOULDER = preload("res://ArtResource/Environment/solid_boulder.svg")
const SOLID_CACTUS = preload("res://ArtResource/Environment/solid_cactus.svg")
const GROUND_GRAVEL = preload("res://ArtResource/Environment/ground_gravel.svg")
const GROUND_CACTUS = preload("res://ArtResource/Environment/ground_cactus.svg")
var map: Node2D
var environment_collider_root: Node2D
var environment_decorations: Array[Dictionary] = []
var oasis_by_region: Dictionary = {}
var environment_seed: int = 0
var rng := RandomNumberGenerator.new()
var spawn_rng := RandomNumberGenerator.new()
var layout_key: String = ""

func regenerate(seed_value: int, day_index: int) -> void:
	## Environment uses its own deterministic stream. It never consumes battle RNG.
	var key := "soft-desert:%d:%d" % [seed_value, day_index]
	if layout_key == key:
		return
	layout_key = key
	environment_seed = hash(key)
	spawn_rng.seed = hash(key + ":spawn")
	environment_decorations.clear()
	oasis_by_region.clear()
	var region_order: Array[StringName] = [REGION_NEAR, REGION_LEFT, REGION_RIGHT, REGION_TOP]
	for region_id in region_order:
		rng.seed = hash(key + ":" + String(region_id))
		var bounds: Rect2 = map.get_region_bounds(region_id)
		if bounds.size == Vector2.ZERO:
			continue
		# Keep the central combat lanes, entrances and source points open.
		var oasis := _pick_environment_point(region_id, bounds, 160.0, true)
		if oasis != Vector2.INF:
			oasis_by_region[region_id] = oasis
			environment_decorations.append({"kind": &"oasis", "position": oasis, "radius": 112.0})
		for index in range(16 if region_id != REGION_TOP else 10):
			var point := _pick_environment_point(region_id, bounds, 112.0, false)
			if point == Vector2.INF:
				continue
			var kind: StringName
			var roll := rng.randf()
			if roll < 0.34:
				kind = &"rock"
			elif roll < 0.62:
				kind = &"cactus"
			elif roll < 0.82:
				kind = &"deadwood"
			else:
				kind = &"pebble"
			# The final arena remains visually varied but has no solid props; this
			# preserves generous boss movement and the weak-point attack lanes.
			var large := region_id != REGION_TOP and kind in [&"rock", &"cactus"] and rng.randf() < 0.45
			var radius := rng.randf_range(35.0, 44.0) if large else rng.randf_range(12.0, 22.0)
			environment_decorations.append({"kind": kind, "position": point, "radius": radius, "solid": large})
	_rebuild_environment_colliders()
	queue_redraw()

func get_oasis_position(region_id: StringName) -> Vector2:
	return Vector2(oasis_by_region.get(region_id, Vector2.INF))

func get_spawn_point_for_enemy(region_id: StringName, enemy_id: StringName) -> Vector2:
	var oasis := get_oasis_position(region_id)
	if oasis != Vector2.INF:
		var drop_item := IngredientSourceDefs.get_enemy_drop_item(enemy_id)
		var dry_species := enemy_id == &"ranged" # Cactus beetle -> crisp sprout.
		var non_meat := drop_item != &"" and not _is_meat_item_for_environment(drop_item) and not dry_species
		# Non-meat producers favor the oasis, while drought-adapted cactus enemies
		# stay away from it. The region itself and total spawn budget are unchanged.
		if (non_meat and spawn_rng.randf() < 0.8) or dry_species:
			for attempt in range(24):
				var direction := Vector2.RIGHT.rotated(spawn_rng.randf_range(0.0, TAU))
				var distance := spawn_rng.randf_range(130.0, 300.0) if non_meat else spawn_rng.randf_range(420.0, 680.0)
				var candidate: Vector2 = oasis + direction * distance
				if map.get_battle_region_for_point(candidate) == region_id and map.is_point_in_playable_area(candidate, Vector2(128, 128)) and not is_environment_blocked(candidate, Vector2(100, 100)):
					return candidate
	return map.get_random_point_in_region(region_id, Vector2(128, 128))

func is_environment_blocked(point: Vector2, padding: Vector2 = Vector2.ZERO) -> bool:
	for item in environment_decorations:
		if not bool(item.get("solid", false)):
			continue
		var radius := float(item.get("radius", 0.0))
		var margin := maxf(padding.x, padding.y)
		if point.distance_to(item.get("position", Vector2.INF)) <= radius + margin:
			return true
	return false

func _pick_environment_point(region_id: StringName, bounds: Rect2, padding: float, oasis: bool) -> Vector2:
	for _i in range(40):
		var candidate := Vector2(rng.randf_range(bounds.position.x + padding, bounds.end.x - padding), rng.randf_range(bounds.position.y + padding, bounds.end.y - padding))
		var center := bounds.get_center()
		if candidate.distance_to(center) < (650.0 if region_id == REGION_TOP else 250.0):
			continue
		# A broad cross-shaped lane connects every gate. Use world/map transforms
		# rather than fixed y cutoffs, so a moved map retains the same safeguards.
		if region_id != REGION_TOP and (absf(candidate.x - center.x) < 160.0 or absf(candidate.y - center.y) < 150.0):
			continue
		if not map.is_point_in_playable_area(candidate, Vector2.ONE * padding):
			continue
		var occupied := false
		for group: StringName in [&"forage_points", &"facility_layout_blockers", &"players", &"night_event_npcs"]:
			for node: Node in get_tree().get_nodes_in_group(group):
				if node is Node2D and node.global_position.distance_to(candidate) < padding + 110.0:
					occupied = true
		for point: Vector2 in map.get_frontline_spawn_points():
			if point.distance_to(candidate) < padding + 130.0:
				occupied = true
		if occupied:
			continue
		if oasis:
			return candidate
		var valid := true
		for item in environment_decorations:
			if candidate.distance_to(item.get("position", Vector2.INF)) < 190.0:
				valid = false
		if valid:
			return candidate
	return Vector2.INF

func _rebuild_environment_colliders() -> void:
	if is_instance_valid(environment_collider_root):
		environment_collider_root.queue_free()
	environment_collider_root = Node2D.new()
	environment_collider_root.name = "DesertEnvironmentColliders"
	add_child(environment_collider_root)
	for index in range(environment_decorations.size()):
		var item: Dictionary = environment_decorations[index]
		if not bool(item.get("solid", false)):
			continue
		var body := StaticBody2D.new()
		body.name = "EnvironmentObstacle_%02d" % index
		body.collision_layer = 4
		body.collision_mask = 0
		environment_collider_root.add_child(body)
		body.global_position = item.get("position", Vector2.ZERO)
		var shape := CollisionShape2D.new()
		var circle := CircleShape2D.new()
		circle.radius = float(item.get("radius", 20.0))
		shape.shape = circle
		body.add_child(shape)

func _is_meat_item_for_environment(item_id: StringName) -> bool:
	return item_id in [&"meat_white", &"meat_red", &"camel_meat", &"sand_hare", &"monitor_tenderloin"]

func _draw() -> void:
	for item in environment_decorations:
		var center: Vector2 = to_local(item.get("position", Vector2.ZERO))
		var radius := float(item.get("radius", 12.0))
		match StringName(item.get("kind", &"")):
			&"oasis":
				_paint_ellipse(center + Vector2(0, 10), Vector2(132, 56), Color(0.24, 0.48, 0.46, 0.20))
				_paint_ellipse(center, Vector2(116, 44), Color("75b8ad"))
				draw_polyline(PackedVector2Array([center + Vector2(-66, -8), center + Vector2(-30, -11), center + Vector2(3, -7)]), Color("b7dfc4"), 3.0, true)
				for offset in [Vector2(-66, -26), Vector2(60, -20), Vector2(-35, 22), Vector2(50, 25)]:
					draw_line(center + offset, center + offset + Vector2(0, -34), Color("628e69"), 5.0, true)
			&"rock":
				if bool(item.get("solid", false)):
					# The circle footprint fits the solid body, not its cast shadow.
					draw_texture_rect(SOLID_BOULDER, Rect2(center + Vector2(-1.4, -2.4) * radius, Vector2(2.8, 3.5) * radius), false)
				else:
					draw_texture_rect(GROUND_GRAVEL, Rect2(center - Vector2(1.3, 0.6) * radius, Vector2(2.6, 1.2) * radius), false)
			&"cactus":
				if bool(item.get("solid", false)):
					draw_texture_rect(SOLID_CACTUS, Rect2(center + Vector2(-1.4, -2.4) * radius, Vector2(2.8, 3.5) * radius), false)
				else:
					draw_texture_rect(GROUND_CACTUS, Rect2(center - Vector2(1.2, 0.7) * radius, Vector2(2.4, 1.4) * radius), false)
			&"deadwood":
				draw_line(center + Vector2(-18, 10), center + Vector2(20, -12), Color("785b48"), 8.0, true)
				draw_line(center + Vector2(-2, 0), center + Vector2(-11, -19), Color("8b6a51"), 5.0, true)
			&"pebble":
				draw_circle(center, radius * .55, Color("a99578"))

func _paint_ellipse(center: Vector2, radii: Vector2, color: Color) -> void:
	draw_colored_polygon(_ellipse_points(center, radii), color)

func _ellipse_points(center: Vector2, radii: Vector2) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in range(20):
		var angle := TAU * float(i) / 20.0
		points.append(center + Vector2(cos(angle) * radii.x, sin(angle) * radii.y))
	return points

