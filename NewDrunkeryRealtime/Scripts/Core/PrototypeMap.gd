extends Node2D

const SurfaceArt = preload("res://Scripts/Core/WorldSurfaceArt.gd")
const EnvironmentArt = preload("res://Scripts/Core/WorldEnvironmentArt.gd")

const ZONE_NONE: StringName = &"none"
const ZONE_BATTLE: StringName = &"battle"
const ZONE_KITCHEN: StringName = &"kitchen"
const REGION_NEAR: StringName = &"near"
const REGION_LEFT: StringName = &"left"
const REGION_RIGHT: StringName = &"right"
const REGION_TOP: StringName = &"top"
const REGION_TOUCH_EPSILON: float = 0.5

@export var tile_size: Vector2 = Vector2(128, 128)

func get_tile_size() -> Vector2:
	return tile_size
@export var columns: int = 36
@export var rows: int = 15
@export var border_color: Color = Color("a58155")
@export var border_width: float = 2.0
@export var grid_line_color: Color = Color(0.08, 0.055, 0.035, 0.42)
@export var grid_line_width: float = 2.0
@export var kitchen_fill_color: Color = Color("b8c5bd")
@export var battle_near_color: Color = Color("cfb57e")
@export var battle_left_color: Color = Color("c9a379")
@export var battle_right_color: Color = Color("bfba86")
@export var battle_top_color: Color = Color("d6bd90")
@export var path_fill_color: Color = Color(0.60, 0.42, 0.20)
@export var portal_marker_fill_color: Color = Color(0.02, 0.018, 0.014, 0.92)
@export var portal_marker_outline_color: Color = Color(0.0, 0.0, 0.0, 1.0)
@export var portal_marker_inner_color: Color = Color(0.18, 0.11, 0.22, 0.76)
@export var portal_marker_radius: float = 24.0
@export var dune_color: Color = Color(0.93, 0.82, 0.48, 0.22)
@export var dune_wall_color: Color = Color(0.90, 0.68, 0.28, 0.96)
@export var dune_wall_shadow_color: Color = Color(0.43, 0.26, 0.10, 0.88)
@export var dune_wall_highlight_color: Color = Color(1.0, 0.86, 0.46, 0.86)
@export var dune_wall_outline_color: Color = Color(0.24, 0.16, 0.07, 0.92)
@export var dune_wall_thickness_cells: int = 1
@export var region_gate_width_cells: int = 2
@export var rock_color: Color = Color(0.62, 0.46, 0.24, 0.34)
@export var fixed_layout_block_margin_cells: int = 0

var map_regions: Array[Dictionary] = []
var dune_wall_rects: Array[Rect2] = []
var frontline_spawn_points: Array[Vector2] = []
var rng := RandomNumberGenerator.new()
var dune_wall_collider_root: Node2D
var environment_art: Node2D
var tutorial_mode: bool = false

func _ready() -> void:
	tutorial_mode = bool(Dictionary(get_tree().get_meta("run_setup", {})).get("tutorial", false))
	if tutorial_mode:
		position = Vector2.ZERO
	rng.randomize()
	_rebuild_regions()
	_rebuild_dune_walls()
	_rebuild_spawn_points()
	_rebuild_dune_wall_colliders()
	refresh_environment(0, 0)
	queue_redraw()

func _draw() -> void:
	_ensure_regions()
	for region in map_regions:
		var rect: Rect2 = region.get("rect", Rect2())
		var color: Color = region.get("color", Color.WHITE)
		SurfaceArt.floor_region(self, rect, color, not bool(region.get("battle", false)), tile_size)

	_draw_desert_accents()
	for region in map_regions:
		var rect: Rect2 = region.get("rect", Rect2())
		draw_rect(rect, border_color, false, border_width)
	_draw_dune_walls()

	for spawn_point in frontline_spawn_points:
		_draw_portal_marker(spawn_point)

func get_world_bounds() -> Rect2:
	_ensure_regions()
	var bounds := Rect2()
	var has_bounds := false
	for region in map_regions:
		var rect: Rect2 = region.get("rect", Rect2())
		if not has_bounds:
			bounds = rect
			has_bounds = true
		else:
			bounds = bounds.merge(rect)
	return _local_rect_to_global(bounds)

func get_battle_zone_bounds() -> Rect2:
	return _local_rect_to_global(_get_local_union_rect(true))

func get_kitchen_zone_bounds() -> Rect2:
	return _local_rect_to_global(_get_local_union_rect(false))

func get_region_bounds(region_id: StringName) -> Rect2:
	_ensure_regions()
	for region in map_regions:
		if StringName(region.get("id", &"")) == region_id:
			return _local_rect_to_global(region.get("rect", Rect2()))
	return Rect2()

func get_source_sign_position(region_id: StringName) -> Vector2:
	## Source boards are mounted on non-gate dune walls. These are collision
	## areas outside the playable side of each battle zone, so the boards never
	## occupy a walkable route or the entrance itself.
	match region_id:
		REGION_NEAR:
			# Closed west segment of the near/kitchen dune wall.
			return to_global(Vector2(1600.0, 768.0))
		REGION_LEFT:
			# Top/left wall, fully closed and outside the playable area.
			return to_global(Vector2(1088.0, -512.0))
		REGION_RIGHT:
			# Top/right wall, fully closed and outside the playable area.
			return to_global(Vector2(3520.0, -512.0))
		REGION_TOP:
			# Closed west segment of the top/near wall.
			return to_global(Vector2(1536.0, -512.0))
		_:
			return global_position

func get_battle_region_ids() -> Array[StringName]:
	return [REGION_NEAR, REGION_LEFT, REGION_RIGHT, REGION_TOP]

func get_source_sign_mount_rect(region_id: StringName, source_kind: StringName = &"battle") -> Rect2:
	# Use the same rectangles as the drawn dunes and their collision shapes.
	_ensure_regions()
	if region_id == REGION_TOP:
		return Rect2()
	if region_id == REGION_NEAR:
		# The first battle area's wine barrels sit along the south wall. Mount
		# both source boards on the closed vertical dune instead, split into two
		# compact sections so neither board overlaps the barrels or the gate.
		if source_kind == &"forage":
			return _local_rect_to_global(Rect2(1152.0, 256.0, 256.0, 244.0))
		return _local_rect_to_global(Rect2(1152.0, 512.0, 256.0, 244.0))
	var anchor := to_local(get_source_sign_position(region_id))
	if source_kind == &"forage":
		match region_id:
			REGION_NEAR:
				anchor = Vector2(2944.0, 768.0)
			REGION_LEFT:
				anchor = Vector2(1280.0, -192.0)
			REGION_RIGHT:
				anchor = Vector2(3328.0, -192.0)
	for wall_rect in dune_wall_rects:
		if wall_rect.has_point(anchor):
			var mount := wall_rect.grow(-12.0)
			if source_kind == &"forage" and region_id in [REGION_LEFT, REGION_RIGHT]:
				# Leave the crossing horizontal dune clear for the battle board.
				mount.position.y = maxf(mount.position.y, -372.0)
				mount.size.y = wall_rect.end.y - 12.0 - mount.position.y
			return _local_rect_to_global(mount)
	return Rect2()

func get_random_point_in_region(region_id: StringName, padding: Vector2 = Vector2.ZERO) -> Vector2:
	var rect := get_region_bounds(region_id)
	if rect.size.x <= 0.0 or rect.size.y <= 0.0:
		return global_position
	var min_pos: Vector2 = rect.position + padding
	var max_pos: Vector2 = rect.position + rect.size - padding
	if min_pos.x > max_pos.x:
		min_pos.x = rect.get_center().x
		max_pos.x = min_pos.x
	if min_pos.y > max_pos.y:
		min_pos.y = rect.get_center().y
		max_pos.y = min_pos.y

	for _i in range(24):
		var candidate := Vector2(rng.randf_range(min_pos.x, max_pos.x), rng.randf_range(min_pos.y, max_pos.y))
		if is_point_in_playable_area(candidate, padding) and not is_environment_blocked(candidate, padding):
			return candidate
	return clamp_point_to_playable(rect.get_center(), padding)

func refresh_environment(seed_value: int, day_index: int) -> void:
	if tutorial_mode:
		return
	if not is_instance_valid(environment_art):
		environment_art = EnvironmentArt.new()
		environment_art.name = "DesertEnvironment"
		environment_art.map = self
		add_child(environment_art)
	environment_art.regenerate(seed_value, day_index)

func get_oasis_position(region_id: StringName) -> Vector2:
	return environment_art.get_oasis_position(region_id) if is_instance_valid(environment_art) else Vector2.INF

func get_spawn_point_for_enemy(region_id: StringName, enemy_id: StringName) -> Vector2:
	return environment_art.get_spawn_point_for_enemy(region_id, enemy_id) if is_instance_valid(environment_art) else get_random_point_in_region(region_id, Vector2(128, 128))

func is_environment_blocked(point: Vector2, padding: Vector2 = Vector2.ZERO) -> bool:
	return is_instance_valid(environment_art) and environment_art.is_environment_blocked(point, padding)

func clamp_point_to_playable(point: Vector2, padding: Vector2 = Vector2.ZERO) -> Vector2:
	_ensure_regions()
	if is_point_in_playable_area(point, padding):
		return point

	var best_point := point
	var best_distance := INF
	for region in map_regions:
		var rect: Rect2 = _get_region_playable_rect(region, padding)
		var candidate := point.clamp(rect.position, rect.position + rect.size)
		candidate = _push_point_out_of_dune_walls(candidate, padding)
		if not is_point_in_playable_area(candidate, padding):
			continue
		var distance := point.distance_squared_to(candidate)
		if distance < best_distance:
			best_distance = distance
			best_point = candidate
	return best_point

func clamp_point_to_playable_from(point: Vector2, previous_point: Vector2, padding: Vector2 = Vector2.ZERO) -> Vector2:
	_ensure_regions()
	var previous_region_id := _get_region_id_for_point(previous_point)
	if is_point_in_playable_area(point, padding):
		var current_region_id := _get_region_id_for_point(point)
		if previous_region_id == &"" or current_region_id == previous_region_id:
			return point
		if not is_segment_blocked_by_dune_wall(previous_point, point, padding):
			return point
		var blocked_transition_candidate: Variant = _try_clamp_point_to_region(point, previous_region_id, padding)
		if blocked_transition_candidate is Vector2:
			return blocked_transition_candidate
		if is_point_in_playable_area(previous_point, padding):
			return previous_point
		return point

	if previous_region_id != &"":
		var same_region_candidate: Variant = _try_clamp_point_to_region(point, previous_region_id, padding)
		if same_region_candidate is Vector2:
			return same_region_candidate
		if is_point_in_playable_area(previous_point, padding):
			return previous_point

	return clamp_point_to_playable(point, padding)

func is_point_in_playable_area(point: Vector2, padding: Vector2 = Vector2.ZERO) -> bool:
	_ensure_regions()
	if _is_point_in_dune_wall(point, padding):
		return false
	for region in map_regions:
		var rect: Rect2 = _get_region_playable_rect(region, padding)
		if rect.has_point(point):
			return true
	return false

func get_zone_for_point(point: Vector2) -> StringName:
	_ensure_regions()
	if _is_point_in_dune_wall(point, Vector2.ZERO):
		return ZONE_NONE
	var local_point: Vector2 = to_local(point)
	for region in map_regions:
		var rect: Rect2 = region.get("rect", Rect2())
		if rect.has_point(local_point):
			return ZONE_BATTLE if bool(region.get("battle", false)) else ZONE_KITCHEN
	return ZONE_NONE

func _get_region_id_for_point(point: Vector2) -> StringName:
	_ensure_regions()
	if _is_point_in_dune_wall(point, Vector2.ZERO):
		return &""
	var local_point: Vector2 = to_local(point)
	for region in map_regions:
		var rect: Rect2 = region.get("rect", Rect2())
		if rect.has_point(local_point):
			return StringName(region.get("id", &""))
	return &""

func get_battle_region_for_point(point: Vector2) -> StringName:
	_ensure_regions()
	if _is_point_in_dune_wall(point, Vector2.ZERO):
		return &""
	var local_point: Vector2 = to_local(point)
	for region in map_regions:
		if not bool(region.get("battle", false)):
			continue
		var rect: Rect2 = region.get("rect", Rect2())
		if rect.has_point(local_point):
			return StringName(region.get("id", REGION_NEAR))
	return &""

func is_segment_blocked_by_dune_wall(from_point: Vector2, to_point: Vector2, padding: Vector2 = Vector2.ZERO) -> bool:
	_ensure_regions()
	var segment := to_point - from_point
	var distance := segment.length()
	if distance <= 0.001:
		return _is_point_in_dune_wall(to_point, padding)

	var step_count: int = max(1, int(ceil(distance / 8.0)))
	for i in range(1, step_count + 1):
		var t := float(i) / float(step_count)
		if _is_point_in_dune_wall(from_point.lerp(to_point, t), padding):
			return true
	return false

func is_point_in_battle_zone(point: Vector2, padding: Vector2 = Vector2.ZERO) -> bool:
	_ensure_regions()
	if _is_point_in_dune_wall(point, padding):
		return false
	for region in map_regions:
		if not bool(region.get("battle", false)):
			continue
		var rect: Rect2 = _get_region_playable_rect(region, padding)
		if rect.has_point(point):
			return true
	return false

func is_point_in_kitchen_zone(point: Vector2) -> bool:
	return get_zone_for_point(point) == ZONE_KITCHEN

func get_cell_for_point(point: Vector2) -> Vector2i:
	var local_point: Vector2 = to_local(point)
	return Vector2i(int(floor(local_point.x / tile_size.x)), int(floor(local_point.y / tile_size.y)))

func is_cell_editable_for_facility(cell: Vector2i, ignored_node: Node = null) -> bool:
	var cell_center := to_global(Vector2(cell) * tile_size + tile_size * 0.5)
	var outside: bool = ignored_node != null and ignored_node.get("allows_battle_placement") == true
	var allowed := is_point_in_playable_area(cell_center, tile_size * 0.44) if outside else is_point_in_kitchen_zone(cell_center)
	return allowed and not is_environment_blocked(cell_center, tile_size * 0.7) and not is_cell_reserved_for_fixed_layout(cell, ignored_node)

func is_cell_reserved_for_fixed_layout(cell: Vector2i, ignored_node: Node = null) -> bool:
	var cell_center := to_global(Vector2(cell) * tile_size + tile_size * 0.5)
	for portal: Node2D in get_tree().get_nodes_in_group("item_portals"):
		if portal != ignored_node and portal.active() and portal.output_rect(portal.global_position).has_point(cell_center):
			return true
	if not is_point_in_kitchen_zone(cell_center):
		return false
	for blocker in get_tree().get_nodes_in_group("facility_layout_blockers"):
		if not (blocker is Node2D) or not is_instance_valid(blocker):
			continue
		if blocker == ignored_node:
			continue
		# Inactive windows are hidden between order groups, but their fixed
		# footprints must remain reserved for when that window opens again.
		if blocker is CanvasItem and not (blocker as CanvasItem).visible and not blocker.is_in_group("serving_counters"):
			continue
		var blocked_rect: Rect2i = _get_fixed_layout_blocker_cell_rect(blocker as Node2D)
		if blocked_rect.has_point(cell):
			return true
	return false

func get_frontline_spawn_points() -> Array[Vector2]:
	var result: Array[Vector2] = []
	for point in frontline_spawn_points:
		result.append(to_global(point))
	return result

func can_zones_interact(zone_a: StringName, zone_b: StringName) -> bool:
	if zone_a == ZONE_NONE or zone_b == ZONE_NONE:
		return true
	return zone_a == zone_b

func _ensure_regions() -> void:
	if map_regions.is_empty():
		_rebuild_regions()
	if dune_wall_rects.is_empty():
		_rebuild_dune_walls()

func configure_tutorial_lesson(lesson: int, bounds: Rect2, is_battle: bool) -> void:
	if not tutorial_mode:
		return
	map_regions = [_region(REGION_NEAR if is_battle else &"kitchen", "教学小关 %d" % (lesson + 1), bounds, battle_near_color if is_battle else kitchen_fill_color, is_battle)]
	dune_wall_rects.clear()
	frontline_spawn_points.clear()
	_rebuild_dune_wall_colliders()
	queue_redraw()

func _rebuild_regions() -> void:
	if tutorial_mode:
		map_regions = [
			_region(REGION_NEAR, "教学采集与战斗区", Rect2(128, 128, 1536, 512), battle_near_color, true),
			_region(&"kitchen", "教学料理区", Rect2(128, 640, 1536, 768), kitchen_fill_color, false)]
		return
	map_regions = [
		_region(REGION_TOP, "顶部沙冠区", Rect2(256, 0, 1280, 320), battle_top_color, true),
		_region(REGION_LEFT, "西侧花冠区", Rect2(0, 320, 640, 448), battle_left_color, true),
		_region(REGION_NEAR, "近门旱地", Rect2(640, 320, 512, 448), battle_near_color, true),
		_region(REGION_RIGHT, "东侧砂谷区", Rect2(1152, 320, 640, 448), battle_right_color, true),
		_region(&"kitchen", "料理长柄", Rect2(384, 768, 1024, 640), kitchen_fill_color, false),
		_region(&"handle_base_left", "料理长柄左底座", Rect2(128, 896, 256, 640), kitchen_fill_color.darkened(0.08), false),
		_region(&"handle_base_right", "料理长柄右底座", Rect2(1408, 896, 256, 640), kitchen_fill_color.darkened(0.08), false),
		_region(&"handle_base_bottom", "料理长柄底座", Rect2(128, 1408, 1536, 128), kitchen_fill_color.darkened(0.08), false)
	]
	map_regions = [
		_region(REGION_TOP, "top dune crown", Rect2(896, -1536, 2816, 1024), battle_top_color, true),
		_region(REGION_LEFT, "west forage field", Rect2(-640, -512, 1920, 1280), battle_left_color, true),
		_region(REGION_NEAR, "near dry field", Rect2(1280, -512, 2048, 1280), battle_near_color, true),
		_region(REGION_RIGHT, "east grain field", Rect2(3328, -512, 1920, 1280), battle_right_color, true),
		_region(&"kitchen", "kitchen hall", Rect2(1152, 768, 2304, 1280), kitchen_fill_color, false)
	]

func _region(id: StringName, display_name: String, rect: Rect2, color: Color, is_battle: bool) -> Dictionary:
	return {
		"id": id,
		"display_name": display_name,
		"rect": rect,
		"color": color,
		"battle": is_battle
	}

func _rebuild_dune_walls() -> void:
	dune_wall_rects.clear()
	_add_vertical_dune_wall_between(REGION_LEFT, REGION_NEAR, true, 0.5)
	_add_vertical_dune_wall_between(REGION_NEAR, REGION_RIGHT, true, 0.5)
	_add_horizontal_dune_wall_between(REGION_TOP, REGION_LEFT, false, 0.5)
	_add_horizontal_dune_wall_between(REGION_TOP, REGION_NEAR, true, 0.5)
	_add_horizontal_dune_wall_between(REGION_TOP, REGION_RIGHT, false, 0.5)
	_add_horizontal_dune_wall_between(REGION_LEFT, &"kitchen", false, 0.5)
	_add_horizontal_dune_wall_between(REGION_NEAR, &"kitchen", true, 0.5)
	_add_horizontal_dune_wall_between(REGION_RIGHT, &"kitchen", false, 0.5)

func _add_vertical_dune_wall_between(left_region_id: StringName, right_region_id: StringName, has_gate: bool, gate_ratio: float) -> void:
	var left_rect: Rect2 = _get_local_region_rect(left_region_id)
	var right_rect: Rect2 = _get_local_region_rect(right_region_id)
	if left_rect.size == Vector2.ZERO or right_rect.size == Vector2.ZERO:
		return
	var boundary_x: float = left_rect.position.x + left_rect.size.x
	if absf(boundary_x - right_rect.position.x) > REGION_TOUCH_EPSILON:
		return
	var overlap_min: float = maxf(left_rect.position.y, right_rect.position.y)
	var overlap_max: float = minf(left_rect.position.y + left_rect.size.y, right_rect.position.y + right_rect.size.y)
	if overlap_max <= overlap_min:
		return
	var thickness: float = maxf(tile_size.x * float(maxi(dune_wall_thickness_cells, 1)), 1.0)
	var wall_x: float = boundary_x - thickness
	var wall_width: float = thickness * 2.0
	_add_dune_wall_segments(true, wall_x, wall_width, overlap_min, overlap_max, has_gate, gate_ratio)

func _add_horizontal_dune_wall_between(top_region_id: StringName, bottom_region_id: StringName, has_gate: bool, gate_ratio: float) -> void:
	var top_rect: Rect2 = _get_local_region_rect(top_region_id)
	var bottom_rect: Rect2 = _get_local_region_rect(bottom_region_id)
	if top_rect.size == Vector2.ZERO or bottom_rect.size == Vector2.ZERO:
		return
	var boundary_y: float = top_rect.position.y + top_rect.size.y
	if absf(boundary_y - bottom_rect.position.y) > REGION_TOUCH_EPSILON:
		return
	var overlap_min: float = maxf(top_rect.position.x, bottom_rect.position.x)
	var overlap_max: float = minf(top_rect.position.x + top_rect.size.x, bottom_rect.position.x + bottom_rect.size.x)
	if overlap_max <= overlap_min:
		return
	var thickness: float = maxf(tile_size.y * float(maxi(dune_wall_thickness_cells, 1)), 1.0)
	var wall_y: float = boundary_y - thickness
	var wall_height: float = thickness * 2.0
	_add_dune_wall_segments(false, wall_y, wall_height, overlap_min, overlap_max, has_gate, gate_ratio)

func _add_dune_wall_segments(is_vertical: bool, fixed_position: float, fixed_size: float, overlap_min: float, overlap_max: float, has_gate: bool, gate_ratio: float) -> void:
	var gate_size: float = (tile_size.y if is_vertical else tile_size.x) * float(maxi(region_gate_width_cells, 1))
	var gate_start: float = overlap_min
	var gate_end: float = overlap_min
	if has_gate:
		var gate_center: float = lerpf(overlap_min, overlap_max, clampf(gate_ratio, 0.0, 1.0))
		gate_start = clampf(gate_center - gate_size * 0.5, overlap_min, maxf(overlap_min, overlap_max - gate_size))
		gate_end = minf(gate_start + gate_size, overlap_max)
	else:
		gate_start = overlap_max
		gate_end = overlap_max

	_add_dune_wall_segment(is_vertical, fixed_position, fixed_size, overlap_min, gate_start)
	_add_dune_wall_segment(is_vertical, fixed_position, fixed_size, gate_end, overlap_max)

func _add_dune_wall_segment(is_vertical: bool, fixed_position: float, fixed_size: float, segment_start: float, segment_end: float) -> void:
	if segment_end - segment_start <= 1.0:
		return
	if is_vertical:
		dune_wall_rects.append(Rect2(fixed_position, segment_start, fixed_size, segment_end - segment_start))
	else:
		dune_wall_rects.append(Rect2(segment_start, fixed_position, segment_end - segment_start, fixed_size))

func _get_local_region_rect(region_id: StringName) -> Rect2:
	for region in map_regions:
		if StringName(region.get("id", &"")) == region_id:
			return region.get("rect", Rect2())
	return Rect2()

func _get_local_union_rect(battle_only: bool) -> Rect2:
	_ensure_regions()
	var bounds := Rect2()
	var has_bounds := false
	for region in map_regions:
		if bool(region.get("battle", false)) != battle_only:
			continue
		var rect: Rect2 = region.get("rect", Rect2())
		if not has_bounds:
			bounds = rect
			has_bounds = true
		else:
			bounds = bounds.merge(rect)
	return bounds

func _local_rect_to_global(local_rect: Rect2) -> Rect2:
	return Rect2(to_global(local_rect.position), local_rect.size)

func _is_point_in_dune_wall(point: Vector2, padding: Vector2 = Vector2.ZERO) -> bool:
	if dune_wall_rects.is_empty():
		return false
	var local_point: Vector2 = to_local(point)
	var safe_padding := Vector2(maxf(padding.x, 0.0), maxf(padding.y, 0.0))
	for wall_rect in dune_wall_rects:
		var padded_rect := Rect2(wall_rect.position - safe_padding, wall_rect.size + safe_padding * 2.0)
		if padded_rect.has_point(local_point):
			return true
	return false

func _push_point_out_of_dune_walls(point: Vector2, padding: Vector2 = Vector2.ZERO) -> Vector2:
	var local_point: Vector2 = to_local(point)
	var safe_padding := Vector2(maxf(padding.x, 0.0), maxf(padding.y, 0.0))
	for _i in range(8):
		var pushed_this_pass := false
		for wall_rect in dune_wall_rects:
			var padded_rect := Rect2(wall_rect.position - safe_padding, wall_rect.size + safe_padding * 2.0)
			if not padded_rect.has_point(local_point):
				continue
			local_point = _get_nearest_point_outside_rect(local_point, padded_rect)
			pushed_this_pass = true
		if not pushed_this_pass:
			break
	return to_global(local_point)

func _get_nearest_point_outside_rect(point: Vector2, rect: Rect2) -> Vector2:
	var left_distance: float = absf(point.x - rect.position.x)
	var right_distance: float = absf(rect.position.x + rect.size.x - point.x)
	var top_distance: float = absf(point.y - rect.position.y)
	var bottom_distance: float = absf(rect.position.y + rect.size.y - point.y)
	var min_distance: float = minf(minf(left_distance, right_distance), minf(top_distance, bottom_distance))
	var result := point
	if is_equal_approx(min_distance, left_distance):
		result.x = rect.position.x - 0.5
	elif is_equal_approx(min_distance, right_distance):
		result.x = rect.position.x + rect.size.x + 0.5
	elif is_equal_approx(min_distance, top_distance):
		result.y = rect.position.y - 0.5
	else:
		result.y = rect.position.y + rect.size.y + 0.5
	return result

func _rebuild_dune_wall_colliders() -> void:
	if is_instance_valid(dune_wall_collider_root):
		dune_wall_collider_root.queue_free()

	dune_wall_collider_root = Node2D.new()
	dune_wall_collider_root.name = "DuneWallColliders"
	add_child(dune_wall_collider_root)

	for i in range(dune_wall_rects.size()):
		var wall_rect: Rect2 = dune_wall_rects[i]
		var wall_body := StaticBody2D.new()
		wall_body.name = "DuneWall_%02d" % i
		wall_body.collision_layer = 4
		wall_body.collision_mask = 0
		dune_wall_collider_root.add_child(wall_body)

		var shape := RectangleShape2D.new()
		shape.size = wall_rect.size
		var collision_shape := CollisionShape2D.new()
		collision_shape.position = wall_rect.get_center()
		collision_shape.shape = shape
		wall_body.add_child(collision_shape)

func _get_fixed_layout_blocker_cell_rect(blocker: Node2D) -> Rect2i:
	var blocker_cell: Vector2i = get_cell_for_point(blocker.global_position)
	var footprint := Vector2i(1, 1)
	if blocker.has_method("get_layout_footprint"):
		var footprint_value: Variant = blocker.get_layout_footprint()
		if footprint_value is Vector2i:
			footprint = footprint_value
		elif footprint_value is Vector2:
			footprint = Vector2i(maxi(int(round(footprint_value.x)), 1), maxi(int(round(footprint_value.y)), 1))
	footprint.x = maxi(footprint.x, 1)
	footprint.y = maxi(footprint.y, 1)

	var margin: int = fixed_layout_block_margin_cells
	if blocker.has_method("get_layout_block_margin_cells"):
		margin = maxi(int(blocker.get_layout_block_margin_cells()), 0)

	var top_left := Vector2i(
		blocker_cell.x - int(floor(float(footprint.x) * 0.5)) - margin,
		blocker_cell.y - int(floor(float(footprint.y) * 0.5)) - margin
	)
	return Rect2i(top_left, footprint + Vector2i(margin * 2, margin * 2))

func _shrink_rect(rect: Rect2, padding: Vector2) -> Rect2:
	var safe_padding := Vector2(maxf(padding.x, 0.0), maxf(padding.y, 0.0))
	var size := rect.size - safe_padding * 2.0
	size.x = maxf(size.x, 0.0)
	size.y = maxf(size.y, 0.0)
	return Rect2(rect.position + safe_padding, size)

func _get_region_playable_rect(region: Dictionary, padding: Vector2) -> Rect2:
	var local_rect: Rect2 = region.get("rect", Rect2())
	var safe_padding := Vector2(maxf(padding.x, 0.0), maxf(padding.y, 0.0))
	var min_offset := Vector2.ZERO
	var max_offset := Vector2.ZERO

	if _is_region_side_exterior(local_rect, Vector2.LEFT):
		min_offset.x = safe_padding.x
	if _is_region_side_exterior(local_rect, Vector2.RIGHT):
		max_offset.x = safe_padding.x
	if _is_region_side_exterior(local_rect, Vector2.UP):
		min_offset.y = safe_padding.y
	if _is_region_side_exterior(local_rect, Vector2.DOWN):
		max_offset.y = safe_padding.y

	var position: Vector2 = local_rect.position + min_offset
	var size: Vector2 = local_rect.size - min_offset - max_offset
	size.x = maxf(size.x, 0.0)
	size.y = maxf(size.y, 0.0)
	return _local_rect_to_global(Rect2(position, size))

func _try_clamp_point_to_region(point: Vector2, region_id: StringName, padding: Vector2) -> Variant:
	for region in map_regions:
		if StringName(region.get("id", &"")) != region_id:
			continue
		var rect: Rect2 = _get_region_playable_rect(region, padding)
		var candidate := point.clamp(rect.position, rect.position + rect.size)
		candidate = _push_point_out_of_dune_walls(candidate, padding)
		if is_point_in_playable_area(candidate, padding) and _get_region_id_for_point(candidate) == region_id:
			return candidate
		return null
	return null

func _is_region_side_exterior(rect: Rect2, side: Vector2) -> bool:
	for other_region in map_regions:
		var other_rect: Rect2 = other_region.get("rect", Rect2())
		if other_rect == rect:
			continue
		if side == Vector2.LEFT:
			if absf((other_rect.position.x + other_rect.size.x) - rect.position.x) <= REGION_TOUCH_EPSILON and _ranges_overlap(rect.position.y, rect.position.y + rect.size.y, other_rect.position.y, other_rect.position.y + other_rect.size.y):
				return false
		elif side == Vector2.RIGHT:
			if absf((rect.position.x + rect.size.x) - other_rect.position.x) <= REGION_TOUCH_EPSILON and _ranges_overlap(rect.position.y, rect.position.y + rect.size.y, other_rect.position.y, other_rect.position.y + other_rect.size.y):
				return false
		elif side == Vector2.UP:
			if absf((other_rect.position.y + other_rect.size.y) - rect.position.y) <= REGION_TOUCH_EPSILON and _ranges_overlap(rect.position.x, rect.position.x + rect.size.x, other_rect.position.x, other_rect.position.x + other_rect.size.x):
				return false
		elif side == Vector2.DOWN:
			if absf((rect.position.y + rect.size.y) - other_rect.position.y) <= REGION_TOUCH_EPSILON and _ranges_overlap(rect.position.x, rect.position.x + rect.size.x, other_rect.position.x, other_rect.position.x + other_rect.size.x):
				return false
	return true

func _ranges_overlap(a_min: float, a_max: float, b_min: float, b_max: float) -> bool:
	return minf(a_max, b_max) > maxf(a_min, b_min)

func _rebuild_spawn_points() -> void:
	frontline_spawn_points.clear()
	if tutorial_mode:
		return
	frontline_spawn_points.append(Vector2(320, 128))
	frontline_spawn_points.append(Vector2(2304, 128))
	frontline_spawn_points.append(Vector2(4288, 128))
	frontline_spawn_points.append(Vector2(1600, -1024))
	frontline_spawn_points.append(Vector2(3008, -1024))

func _draw_portal_marker(center: Vector2) -> void:
	SurfaceArt.portal(self, center, portal_marker_radius)

func _draw_desert_accents() -> void:
	if tutorial_mode:
		return
	var dunes := [
		Rect2(180.0, 470.0, 820.0, 104.0),
		Rect2(1180.0, -560.0, 760.0, 116.0),
		Rect2(2200.0, -500.0, 760.0, 104.0),
		Rect2(3440.0, 470.0, 840.0, 104.0)
	]
	for dune_rect in dunes:
		_draw_filled_ellipse(dune_rect.position + dune_rect.size * 0.5, dune_rect.size * 0.5, dune_color)

	var rocks := [
		Vector2(320.0, 660.0),
		Vector2(860.0, 280.0),
		Vector2(1320.0, -380.0),
		Vector2(1900.0, 660.0),
		Vector2(1760.0, 720.0),
		Vector2(3020.0, 280.0),
		Vector2(3660.0, -120.0),
		Vector2(2540.0, -590.0),
		Vector2(4320.0, 620.0)
	]
	for rock_center in rocks:
		draw_circle(rock_center, 9.0, rock_color)
		draw_circle(rock_center + Vector2(10.0, -6.0), 5.0, rock_color)

func _draw_dune_walls() -> void:
	for wall_rect in dune_wall_rects:
		_draw_dune_wall(wall_rect)

func _draw_dune_wall(wall_rect: Rect2) -> void:
	SurfaceArt.dune(self, wall_rect)

func _draw_filled_ellipse(center: Vector2, radii: Vector2, color: Color) -> void:
	var points := PackedVector2Array()
	var point_count: int = 24
	for i in range(point_count):
		var angle: float = TAU * float(i) / float(point_count)
		points.append(center + Vector2(cos(angle) * radii.x, sin(angle) * radii.y))
	draw_colored_polygon(points, color)

func _is_local_cell_playable(cell_rect: Rect2) -> bool:
	return is_point_in_playable_area(to_global(cell_rect.get_center()))

func _get_local_playable_bounds() -> Rect2:
	_ensure_regions()
	var bounds := Rect2()
	var has_bounds := false
	for region in map_regions:
		var rect: Rect2 = region.get("rect", Rect2())
		if not has_bounds:
			bounds = rect
			has_bounds = true
		else:
			bounds = bounds.merge(rect)
	return bounds
