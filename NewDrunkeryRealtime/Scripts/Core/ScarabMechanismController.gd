class_name ScarabMechanismController
extends Node

const ScarabNavigationCache = preload("res://Scripts/Core/ScarabNavigationCache.gd")
const ScarabTargetQuery = preload("res://Scripts/Core/ScarabTargetQuery.gd")
const TestItemDefs = preload("res://Scripts/Kitchen/TestItemDefs.gd")
const MapMechanismDefs = preload("res://Scripts/Core/MapMechanismDefs.gd")
const ScarabEnemy = preload("res://Scripts/Enemies/ScarabEnemy.gd")
const LevelRefs = preload("res://Scripts/Core/LevelRefs.gd")
const LOOSE_ITEM_SCENE := preload("res://Scenes/Restaurant/loose_item.tscn")

@export var spawn_interval_min: float = 18.0
@export var spawn_interval_max: float = 28.0
@export var max_active_scarabs: int = 1
@export var ground_steal_duration: float = 1.0
@export var cabinet_steal_duration: float = 2.0
@export var death_experience_reward: int = 2
@export var target_refresh_interval: float = 0.2
# Keep the grid fine enough to represent the two-cell map gates after the
# scarab clearance is applied. A 64 px snapshot can mark a physically open
# gate corridor as disconnected when a forage collider sits near its edge.
@export var navigation_cell_size: float = 32.0
@export var navigation_clearance: float = 34.0
@export var boss_burst_count: int = 5
@export var boss_burst_interval: float = 2.0
@export var boss_burst_rest: float = 24.0

var level_refs: LevelRefs
var prototype_map: Node
var storage_manager: Node
var runtime_root: Node
var progression_state: Object
var active: bool = false
var spawn_remaining: float = 0.0
var target_refresh_remaining: float = 0.0
var rng := RandomNumberGenerator.new()
var boss_scarab_mode: bool = false
var business_running: bool = false
var burst_owner: Node2D
var burst_remaining: int = 0
var burst_spawn_remaining: float = 0.0
var burst_rest_remaining: float = 0.0
var boss_burst_number: int = 0
var boss_burst_capacity: int = 0
var boss_wave_owner: Node2D
var configured_burst_interval: float = 2.0
var configured_burst_rest: float = 24.0
var navigation_cache := ScarabNavigationCache.new()
var navigation_retry_times: Dictionary = {}
var escape_search_retry_times: Dictionary = {}
var navigation_clock: float = 0.0
var navigation_obstacle_signature: Dictionary = {}
var navigation_probe_shape := CircleShape2D.new()
var navigation_probe := PhysicsShapeQueryParameters2D.new()
var warning_remaining: float = 0.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	rng.randomize()
	_resolve_scene_refs()

func _process(delta: float) -> void:
	if not active or not business_running:
		return
	warning_remaining = maxf(warning_remaining - delta, 0.0)
	navigation_clock += delta
	_refresh_navigation_for_moved_facilities()
	_tick_navigation_cache()
	target_refresh_remaining = maxf(target_refresh_remaining - delta, 0.0)
	if target_refresh_remaining <= 0.0:
		target_refresh_remaining = target_refresh_interval
		_update_scarab_targets()
	if boss_scarab_mode and _get_living_scorpion() != null:
		_tick_boss_burst(delta)
	else:
		_cancel_boss_burst()
		spawn_remaining = maxf(spawn_remaining - delta, 0.0)
		if spawn_remaining <= 0.0 and _get_active_scarab_count() < get_scarab_limit():
			if _spawn_scarab():
				_reset_spawn_timer()
			else:
				spawn_remaining = 0.25
	for scarab in get_tree().get_nodes_in_group("scarab_enemies"):
		if not is_instance_valid(scarab) or scarab.get_parent() == null:
			continue
		if scarab.current_target_kind == &"ground" and scarab.get_state() == ScarabEnemy.State.STEALING:
			if not _is_current_target_valid(scarab) or not _can_reach_ground(scarab, scarab.current_target, scarab.global_position):
				scarab.clear_target()
				navigation_retry_times.erase(scarab.get_instance_id())
				_update_single_scarab_target(scarab)
		if scarab.current_target_kind == &"cabinet" and scarab.get_state() in [ScarabEnemy.State.SEARCHING, ScarabEnemy.State.STEALING]:
			if not _is_current_target_valid(scarab) or not _is_cabinet_approach_valid(scarab):
				scarab.clear_target()
				storage_manager.release_stock_reservation(scarab)
				navigation_retry_times.erase(scarab.get_instance_id())
				_update_single_scarab_target(scarab)
		if scarab.get_state() == ScarabEnemy.State.ESCAPING_TO_CORNER:
			if not _can_retry_navigation(scarab):
				continue
			if scarab.escape_target_position == Vector2.INF:
				var escape_data := _pick_escape_route(scarab)
				if not escape_data.is_empty():
					scarab.set_escape_target(escape_data.get("position"), escape_data.get("route", []))
			elif scarab.is_navigation_stuck():
				var refreshed_escape := _pick_escape_route(scarab)
				if not refreshed_escape.is_empty():
					scarab.set_escape_target(refreshed_escape.get("position"), refreshed_escape.get("route", []))
			continue
		if scarab.get_state() != ScarabEnemy.State.SEARCHING:
			continue
		if scarab.current_target == null or not is_instance_valid(scarab.current_target):
			continue
		if scarab.current_target_kind == &"entry":
			if _is_in_kitchen(scarab.global_position):
				scarab.clear_target()
				navigation_retry_times.erase(scarab.get_instance_id())
				_update_single_scarab_target(scarab)
			continue
		if not _is_current_target_valid(scarab):
			scarab.clear_target()
			_update_single_scarab_target(scarab)
			continue
		var at_approach: bool = scarab.current_target_kind != &"cabinet" or (scarab.target_approach_position.is_finite() and scarab.global_position.distance_to(scarab.target_approach_position) <= 8.0)
		if at_approach and (scarab.current_target_kind == &"cabinet" or _can_reach_ground(scarab, scarab.current_target, scarab.global_position)):
			var kind: StringName = scarab.current_target_kind
			scarab.begin_steal(scarab.current_target, kind, cabinet_steal_duration if kind == &"cabinet" else ground_steal_duration)

func configure_for_level(group_data: Dictionary, new_progression_state: Object = null) -> void:
	progression_state = new_progression_state
	configured_burst_interval = maxf(float(group_data.get("scarab_burst_interval", boss_burst_interval)), 0.01)
	configured_burst_rest = maxf(float(group_data.get("scarab_burst_rest", boss_burst_rest)), 0.0)
	if group_data.is_empty():
		return
	var active_ids: Variant = group_data.get("map_mechanism_ids", [])
	active = active_ids is Array and _contains_mechanism(active_ids, MapMechanismDefs.SCARAB)
	boss_scarab_mode = StringName(group_data.get("boss_enhanced_map_mechanism_id", &"")) == MapMechanismDefs.SCARAB
	if not active:
		stop_business()

func set_progression_state(new_progression_state: Object) -> void:
	progression_state = new_progression_state

func start_business() -> void:
	if not active:
		return
	_resolve_scene_refs()
	business_running = true
	target_refresh_remaining = 0.0
	spawn_remaining = 0.0
	# Prime both navigation snapshots before the first summoned actor needs one.
	if prototype_map != null:
		var kitchen: Rect2 = prototype_map.get_kitchen_zone_bounds()
		_prime_navigation_bounds(kitchen)
		if boss_scarab_mode:
			_prime_navigation_bounds(kitchen.merge(prototype_map.get_region_bounds(&"near")).merge(prototype_map.get_region_bounds(&"top")))
	navigation_obstacle_signature = _get_navigation_obstacle_signature()

func _get_navigation_obstacle_signature() -> Dictionary:
	var signature: Dictionary = {}
	for facility in get_tree().get_nodes_in_group("movable_facilities"):
		if not is_instance_valid(facility) or not facility is Node2D:
			continue
		var body := facility as CollisionObject2D
		signature[facility.get_instance_id()] = [facility.global_position, facility.visible, body.collision_layer if body != null else 0]
	return signature

func _refresh_navigation_for_moved_facilities() -> void:
	var current := _get_navigation_obstacle_signature()
	if current != navigation_obstacle_signature:
		navigation_obstacle_signature = current
		navigation_cache.request_refresh()

func _prime_navigation_bounds(bounds: Rect2) -> void:
	var cell_size := maxf(navigation_cell_size, 16.0)
	var grid_size := Vector2i(maxi(int(ceil(bounds.size.x / cell_size)), 1), maxi(int(ceil(bounds.size.y / cell_size)), 1))
	_get_navigation_grid(bounds, cell_size, grid_size)

func stop_business(return_stolen_items: bool = false) -> void:
	navigation_cache.clear()
	navigation_retry_times.clear()
	escape_search_retry_times.clear()
	_cancel_boss_burst()
	burst_rest_remaining = 0.0
	boss_burst_number = 0
	boss_burst_capacity = 0
	boss_wave_owner = null
	warning_remaining = 0.0
	active = false
	business_running = false
	boss_scarab_mode = false
	if not is_inside_tree():
		return
	for scarab in get_tree().get_nodes_in_group("scarab_enemies"):
		if is_instance_valid(scarab):
			scarab.set_physics_process(false)
			if return_stolen_items and not scarab.is_dead and not scarab.is_queued_for_deletion():
				_spawn_stolen_items(scarab.stolen_items, scarab.global_position)
			storage_manager.release_stock_reservation(scarab)
			scarab.queue_free()

func _get_living_scorpion() -> Node2D:
	for boss in get_tree().get_nodes_in_group("scorpion_bosses"):
		if is_instance_valid(boss) and not boss.is_dead and not boss.is_queued_for_deletion():
			return boss as Node2D
	return null

func can_begin_boss_burst(boss: Node2D) -> bool:
	return active and business_running and boss_scarab_mode and is_instance_valid(boss) and not boss.is_dead and burst_remaining == 0 and burst_rest_remaining <= 0.0

func begin_boss_burst(boss: Node2D) -> bool:
	if not can_begin_boss_burst(boss):
		return false
	if boss_wave_owner != boss:
		boss_wave_owner = boss
		boss_burst_number = 0
	boss_burst_number += 1
	burst_owner = boss
	burst_remaining = maxi(boss_burst_count, 1) + int((boss_burst_number - 1) / 2)
	# Existing survivors must never consume this wave's promised spawns.
	boss_burst_capacity = _get_active_scarab_count() + burst_remaining
	burst_spawn_remaining = 0.0
	return true

func _tick_boss_burst(delta: float) -> void:
	burst_rest_remaining = maxf(burst_rest_remaining - delta, 0.0)
	if burst_remaining <= 0:
		return
	if not is_instance_valid(burst_owner) or burst_owner.is_dead:
		_cancel_boss_burst()
		return
	burst_spawn_remaining = maxf(burst_spawn_remaining - delta, 0.0)
	if burst_spawn_remaining > 0.0:
		return
	if _spawn_scarab():
		burst_remaining -= 1
		burst_spawn_remaining = configured_burst_interval
	else:
		burst_spawn_remaining = 0.25
	if burst_remaining <= 0:
		_finish_boss_burst()

func _finish_boss_burst() -> void:
	_cancel_boss_burst()
	burst_rest_remaining = configured_burst_rest

func _cancel_boss_burst() -> void:
	burst_owner = null
	burst_remaining = 0
	burst_spawn_remaining = 0.0

func _resolve_scene_refs() -> void:
	level_refs = LevelRefs.find_from(self)
	if level_refs == null:
		return
	prototype_map = level_refs.get_prototype_map()
	storage_manager = level_refs.get_storage_manager()
	runtime_root = level_refs.get_runtime_root()

func _spawn_scarab() -> bool:
	_resolve_scene_refs()
	if runtime_root == null:
		return false
	# The scarab scene only held this script and a 20 px collision circle. Build
	# that tiny runtime actor directly so a stale PackedScene script binding
	# cannot turn the instance back into a plain CharacterBody2D.
	var scarab := ScarabEnemy.new()
	scarab.collision_layer = 2
	scarab.collision_mask = 4 | 8 | 16
	var collision_shape := CollisionShape2D.new()
	var collision_circle := CircleShape2D.new()
	collision_circle.radius = 34.0
	collision_shape.shape = collision_circle
	scarab.add_child(collision_shape)
	runtime_root.add_child(scarab)
	var spawn_position := _find_open_kitchen_position(scarab)
	if spawn_position == Vector2.INF:
		scarab.queue_free()
		return false
	scarab.global_position = spawn_position
	if is_instance_valid(burst_owner):
		burst_owner.show_scarab_emergence(spawn_position)
	scarab.set_meta("cross_region_navigation", boss_scarab_mode)
	_show_scarab_warning("圣甲虫进入料理区！优先拦截它，或看住食材柜。")
	scarab.steal_action_finished.connect(_on_scarab_steal_action_finished)
	scarab.escape_finished.connect(_on_scarab_escape_finished)
	scarab.defeated.connect(_on_scarab_defeated)
	return true

func _find_open_kitchen_position(scarab: CharacterBody2D) -> Vector2:
	var directions: Array[Vector2] = []
	for i in range(8):
		directions.append(Vector2.RIGHT.rotated(TAU * float(i) / 8.0))
	var valid_positions: Array[Vector2] = []
	for _attempt in range(48):
		var candidate := _random_kitchen_position()
		if not _is_spawn_position_open(candidate, scarab, directions):
			continue
		valid_positions.append(candidate)
		if valid_positions.size() >= 8:
			break
	if not valid_positions.is_empty():
		return valid_positions[rng.randi_range(0, valid_positions.size() - 1)]
	return Vector2.INF

func _random_kitchen_position() -> Vector2:
	if boss_scarab_mode and prototype_map != null and prototype_map.has_method("get_random_point_in_region"):
		return prototype_map.get_random_point_in_region(&"top", Vector2(128.0, 128.0))
	if prototype_map != null and prototype_map.has_method("get_random_point_in_region"):
		return prototype_map.get_random_point_in_region(&"kitchen", Vector2(128.0, 128.0))
	if prototype_map != null and prototype_map.has_method("get_kitchen_zone_bounds"):
		var bounds: Rect2 = prototype_map.get_kitchen_zone_bounds()
		return Vector2(rng.randf_range(bounds.position.x, bounds.end.x), rng.randf_range(bounds.position.y, bounds.end.y))
	return Vector2.ZERO

func _is_spawn_position_open(position: Vector2, scarab: CharacterBody2D, directions: Array[Vector2]) -> bool:
	if not position.is_finite() or not _is_scarab_spawn_zone(position):
		return false
	var viewport := get_viewport()
	var world_2d: World2D = runtime_root.get_world_2d() if runtime_root is CanvasItem else (viewport.world_2d if viewport != null else null)
	if world_2d == null:
		return true
	var body_shape := CircleShape2D.new()
	body_shape.radius = 30.0
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = body_shape
	query.collision_mask = 4 | 8 | 16
	query.transform = Transform2D(0.0, position)
	query.exclude = [scarab]
	if not world_2d.direct_space_state.intersect_shape(query, 1).is_empty():
		return false
	# Require several open escape directions so a newly spawned scarab is not
	# boxed in by stations, cabinets, walls, or loose items.
	var open_directions := 0
	for direction in directions:
		var clear := true
		for distance in [48.0, 96.0, 144.0]:
			query.transform = Transform2D(0.0, position + direction * distance)
			if not world_2d.direct_space_state.intersect_shape(query, 1).is_empty():
				clear = false
				break
		if clear:
			open_directions += 1
	if open_directions < 3:
		return false
	return true

func _pick_escape_corner() -> Vector2:
	var bounds := Rect2()
	if prototype_map != null and prototype_map.has_method("get_kitchen_zone_bounds"):
		bounds = prototype_map.get_kitchen_zone_bounds()
	if bounds.size == Vector2.ZERO:
		return Vector2.ZERO
	var inset := Vector2(128.0, 128.0)
	var corners := [
		bounds.position + inset,
		Vector2(bounds.end.x - inset.x, bounds.position.y + inset.y),
		Vector2(bounds.position.x + inset.x, bounds.end.y - inset.y),
		bounds.end - inset
	]
	return corners[rng.randi_range(0, corners.size() - 1)]

func _pick_escape_route(scarab: ScarabEnemy) -> Dictionary:
	navigation_retry_times[scarab.get_instance_id()] = navigation_clock + 0.8
	var bounds := Rect2()
	if prototype_map != null and prototype_map.has_method("get_kitchen_zone_bounds"):
		bounds = prototype_map.get_kitchen_zone_bounds()
	if bounds.size == Vector2.ZERO:
		return {}
	var candidates := _get_escape_corner_candidates(bounds)
	candidates.shuffle()
	for corner in candidates:
		var route := _build_route_to_position(scarab, corner, [scarab], false)
		if not route.is_empty():
			return {"position": corner, "route": route}
	return {}

func _get_escape_corner_candidates(bounds: Rect2) -> Array[Vector2]:
	var candidates: Array[Vector2] = []
	var inset := Vector2(128.0, 128.0)
	var anchors: Array[Vector2] = [
		bounds.position + inset,
		Vector2(bounds.end.x - inset.x, bounds.position.y + inset.y),
		Vector2(bounds.position.x + inset.x, bounds.end.y - inset.y),
		bounds.end - inset
	]
	var interior_signs: Array[Vector2] = [Vector2(1.0, 1.0), Vector2(-1.0, 1.0), Vector2(1.0, -1.0), Vector2(-1.0, -1.0)]
	for i in range(anchors.size()):
		for _sample in range(8):
			var sign := interior_signs[i]
			var offset := Vector2(rng.randf_range(0.0, 192.0) * sign.x, rng.randf_range(0.0, 192.0) * sign.y)
			var candidate := anchors[i] + offset
			if prototype_map != null and prototype_map.has_method("is_point_in_playable_area") and not prototype_map.is_point_in_playable_area(candidate, Vector2(34.0, 34.0)):
				continue
			if not _is_in_kitchen(candidate):
				continue
			candidates.append(candidate)
	return candidates

func _update_scarab_targets() -> void:
	var targets := _collect_steal_targets()
	for scarab in get_tree().get_nodes_in_group("scarab_enemies"):
		if not is_instance_valid(scarab) or scarab.is_dead or scarab.is_queued_for_deletion():
			continue
		if scarab.get_state() in [ScarabEnemy.State.ESCAPING_TO_CORNER, ScarabEnemy.State.ESCAPING]:
			_try_resume_scarab_for_new_target(scarab, targets)
			continue
		if scarab.get_state() != ScarabEnemy.State.SEARCHING:
			continue
		if not _can_retry_navigation(scarab):
			continue
		if _route_incoming_scarab(scarab):
			continue
		navigation_retry_times[scarab.get_instance_id()] = navigation_clock + 1.0
		var choice := _find_nearest_target(scarab, targets)
		_apply_target_choice(scarab, choice, targets.is_empty())

func _update_single_scarab_target(scarab: ScarabEnemy) -> void:
	if not _can_retry_navigation(scarab):
		return
	if _route_incoming_scarab(scarab):
		return
	navigation_retry_times[scarab.get_instance_id()] = navigation_clock + 0.8
	var targets := _collect_steal_targets()
	var choice := _find_nearest_target(scarab, targets)
	_apply_target_choice(scarab, choice, targets.is_empty())

func _apply_target_choice(scarab: ScarabEnemy, choice: Dictionary, no_food: bool) -> void:
	if choice.is_empty():
		# An unfinished initial grid is not evidence that the food is unreachable.
		var kitchen: Rect2 = prototype_map.get_kitchen_zone_bounds()
		_prime_navigation_bounds(kitchen)
		if not no_food and navigation_cache.caches[kitchen].grid == null:
			return
		scarab.begin_escape()
		storage_manager.release_stock_reservation(scarab)
		navigation_retry_times.erase(scarab.get_instance_id())
		escape_search_retry_times[scarab.get_instance_id()] = navigation_clock + 0.8
	elif not is_instance_valid(scarab.current_target) or scarab.current_target != choice.get("node") or scarab.target_approach_position != choice.get("approach", Vector2.INF) or scarab.is_navigation_stuck():
		# Preserve waypoint progress while the same target still has a valid route.
		_assign_target_choice(scarab, choice)

func _assign_target_choice(scarab: ScarabEnemy, choice: Dictionary) -> void:
	storage_manager.release_stock_reservation(scarab)
	scarab.set_target(choice.get("node"), choice.get("kind", &""), choice.get("route", []), choice.get("approach", Vector2.INF))
	if scarab.current_target_kind == &"cabinet":
		var cabinet: Node = scarab.current_target
		# A deleted source must invalidate its reservation before passing it to
		# a typed Node argument; a bound freed Node cannot be invoked safely.
		var cabinet_ref: WeakRef = weakref(cabinet)
		var valid := func() -> bool:
			var source: Node = cabinet_ref.get_ref() as Node
			return source != null and scarab.is_reserving_cabinet(source)
		if not storage_manager.reserve_stock(scarab, cabinet.stored_item_id, valid):
			scarab.clear_target()

func _is_cabinet_approach_valid(scarab: ScarabEnemy) -> bool:
	if not scarab.target_approach_position.is_finite() or not is_instance_valid(scarab.current_target):
		return false
	if not scarab.target_approach_position in scarab.current_target.get_scarab_approach_positions():
		return false
	if not _is_navigation_point_walkable(scarab.target_approach_position, scarab, null, [scarab]):
		return false
	if not _can_reach_cabinet(scarab, scarab.current_target, scarab.target_approach_position):
		return false
	if scarab.state == ScarabEnemy.State.STEALING or scarab.global_position.distance_to(scarab.target_approach_position) <= 8.0:
		return _can_reach_cabinet(scarab, scarab.current_target, scarab.global_position)
	return true

func _can_reach_cabinet(scarab: Node2D, cabinet: Node2D, from_point: Vector2) -> bool:
	# A walkable corner is not enough: another facility must not stand between
	# the thief and the cabinet. Use the same check in selection and casting.
	var blocker := _first_blocker(from_point, cabinet.global_position, [scarab])
	return blocker == cabinet or (is_instance_valid(blocker) and cabinet.is_ancestor_of(blocker))

func _can_reach_ground(scarab: Node2D, target: Node2D, from_point: Vector2) -> bool:
	if not is_instance_valid(target) or from_point.distance_to(target.global_position) > scarab.steal_reach:
		return false
	if prototype_map != null and prototype_map.is_segment_blocked_by_dune_wall(from_point, target.global_position, Vector2.ZERO):
		return false
	# Neighboring loose food must not hide a pile's contents. Walls and
	# facilities still block interaction, independently of walking clearance.
	return _first_blocker(from_point, target.global_position, [scarab, target], 4 | 16) == null

func _is_current_target_valid(scarab: ScarabEnemy) -> bool:
	return ScarabTargetQuery.is_current_target_valid(scarab)

func _retarget_scarab(scarab: ScarabEnemy) -> void:
	if not is_instance_valid(scarab) or scarab.get_state() != ScarabEnemy.State.SEARCHING:
		return
	navigation_retry_times.erase(scarab.get_instance_id())
	_update_single_scarab_target(scarab)

func _collect_steal_targets() -> Array[Dictionary]:
	return ScarabTargetQuery.collect(get_tree(), storage_manager, _is_in_kitchen)

func _try_resume_scarab_for_new_target(scarab: ScarabEnemy, targets: Array[Dictionary]) -> bool:
	if scarab.get_stolen_count() >= scarab.stolen_limit:
		return false
	if navigation_clock < float(escape_search_retry_times.get(scarab.get_instance_id(), 0.0)):
		return false
	# Food searches must not starve corner-route retries, or run every frame.
	escape_search_retry_times[scarab.get_instance_id()] = navigation_clock + 0.8
	var choice := _find_nearest_target(scarab, targets)
	if choice.is_empty():
		return false
	scarab.resume_searching()
	_assign_target_choice(scarab, choice)
	escape_search_retry_times.erase(scarab.get_instance_id())
	navigation_retry_times[scarab.get_instance_id()] = navigation_clock + 0.8
	return true

func _is_player_interactable(target: Node) -> bool:
	return ScarabTargetQuery.is_player_interactable(target)

func _find_nearest_target(scarab: Node2D, targets: Array[Dictionary]) -> Dictionary:
	# Claims are derived from live actors: death, escape and retargeting release
	# them automatically. Serial assignment makes new claims visible this tick.
	var reserved: Dictionary = {}
	var occupied: Dictionary = {}
	for other in get_tree().get_nodes_in_group("scarab_enemies"):
		if other == scarab or not is_instance_valid(other) or other.is_dead or other.is_queued_for_deletion():
			continue
		if other.get_state() in [ScarabEnemy.State.SEARCHING, ScarabEnemy.State.STEALING] and _is_current_target_valid(other):
			var id: int = other.current_target.get_instance_id()
			if other.current_target_kind == &"cabinet":
				if not occupied.has(id):
					occupied[id] = []
				occupied[id].append(other.target_approach_position)
			else:
				reserved[id] = true
	var available: Array[Dictionary] = []
	for entry in targets:
		var node: Node = entry.get("node")
		if is_instance_valid(node) and not reserved.has(node.get_instance_id()):
			if entry.get("kind") == &"cabinet" and storage_manager.get_available_stock(node.stored_item_id, scarab) <= 0:
				continue
			var candidate := entry.duplicate()
			candidate["occupied_positions"] = occupied.get(node.get_instance_id(), [])
			available.append(candidate)
	return ScarabTargetQuery.find_nearest(scarab, available, _build_route_to_position, _can_reach_cabinet, _can_reach_ground)

func _build_route(scarab: Node2D, target: Node2D) -> Array[Vector2]:
	return _build_route_to_position(scarab, target.global_position, [scarab, target], true)

func _build_route_to_position(scarab: Node2D, destination: Vector2, exclude: Array, allow_blocked_destination: bool = false, search_from_gate: bool = false, allow_live_grid_fallback: bool = true) -> Array[Vector2]:
	var origin := scarab.global_position
	if not _is_navigation_point_walkable(destination, scarab, null, exclude):
		return []
	if not _segment_blocked(origin, destination, exclude):
		return [destination]
	if prototype_map == null or not prototype_map.has_method("get_kitchen_zone_bounds"):
		return []
	var bounds: Rect2 = prototype_map.get_kitchen_zone_bounds()
	if boss_scarab_mode and not _is_in_kitchen(origin):
		bounds = bounds.merge(prototype_map.get_region_bounds(&"near")).merge(prototype_map.get_region_bounds(&"top"))
	var cell_size := maxf(navigation_cell_size, 16.0)
	var grid_origin := bounds.position
	var grid_size := Vector2i(
		maxi(int(ceil(bounds.size.x / cell_size)), 1),
		maxi(int(ceil(bounds.size.y / cell_size)), 1)
	)
	var grid := _get_navigation_grid(bounds, cell_size, grid_size)
	if grid == null:
		return []
	var start_cell := _get_navigation_cell(grid_origin, cell_size, grid_size, origin)
	var destination_cell := _get_navigation_cell(grid_origin, cell_size, grid_size, destination)
	start_cell = _find_connected_cell(grid, grid_origin, cell_size, start_cell, origin, exclude)
	if _is_navigation_point_walkable(destination, scarab, null, exclude):
		# The destination may have just been freed while the published snapshot
		# still marks its old cell solid. Keep that live endpoint and patch only
		# the small stale footprint while asking AStar for a route.
		destination_cell = destination_cell if grid.region.has_point(destination_cell) else _find_connected_cell(grid, grid_origin, cell_size, destination_cell, destination, exclude)
	else:
		destination_cell = _find_connected_cell(grid, grid_origin, cell_size, destination_cell, destination, exclude)
	if start_cell.x < 0 or destination_cell.x < 0:
		return []
	var cell_path: Array[Vector2i] = []
	if search_from_gate:
		cell_path = navigation_cache.get_gate_path(bounds, start_cell, destination_cell)
	else:
		cell_path = _get_live_endpoint_path(grid, grid_origin, cell_size, start_cell, destination_cell)
	if cell_path.is_empty() and allow_live_grid_fallback and _is_navigation_point_walkable(destination, scarab, null, exclude):
		# A missing route may be a stale obstacle snapshot. Refresh in slices;
		# rebuilding thousands of cells per cabinet candidate stalls the game.
		var cache: Dictionary = navigation_cache.caches[bounds]
		cache.updated = -10.0
		cache.urgent = true
	if cell_path.is_empty():
		return []
	var route: Array[Vector2] = []
	for i in range(cell_path.size()):
		var point := _get_navigation_cell_center(grid_origin, cell_size, Vector2i(cell_path[i]))
		route.append(point)
	if route.is_empty() or route.back().distance_to(destination) > 1.0:
		route.append(destination)
	return route

func _get_live_endpoint_path(grid: AStarGrid2D, grid_origin: Vector2, cell_size: float, start_cell: Vector2i, destination_cell: Vector2i) -> Array[Vector2i]:
	var patched: Array[Vector2i] = []
	# The exact approach point is authoritative when a blocker was lifted after
	# the last snapshot. Its cell center can still overlap the old collider.
	if grid.region.has_point(destination_cell) and grid.is_point_solid(destination_cell):
		grid.set_point_solid(destination_cell, false)
		patched.append(destination_cell)
	for y in range(-2, 3):
		for x in range(-2, 3):
			var cell := destination_cell + Vector2i(x, y)
			if not grid.region.has_point(cell) or not grid.is_point_solid(cell):
				continue
			var point := _get_navigation_cell_center(grid_origin, cell_size, cell)
			if _is_navigation_point_walkable(point, null):
				grid.set_point_solid(cell, false)
				patched.append(cell)
	var result := grid.get_id_path(start_cell, destination_cell, false)
	for cell in patched:
		grid.set_point_solid(cell, true)
	return result

func _can_retry_navigation(scarab: Node) -> bool:
	return navigation_clock >= float(navigation_retry_times.get(scarab.get_instance_id(), 0.0))

func _get_navigation_grid(bounds: Rect2, cell_size: float, grid_size: Vector2i) -> AStarGrid2D:
	return navigation_cache.get_grid(bounds, cell_size, grid_size)

func _tick_navigation_cache() -> void:
	# Facility motion must never clear or restart a build. Keep the last
	# complete snapshot until the periodic sliced replacement is published.
	navigation_cache.tick(navigation_clock, _is_navigation_point_walkable, _on_navigation_snapshot_ready)

func _on_navigation_snapshot_ready(bounds: Rect2, grid: AStarGrid2D, cell_size: float, grid_size: Vector2i) -> void:
	if not boss_scarab_mode or bounds == prototype_map.get_kitchen_zone_bounds():
		return
	# Prepare gate roots before a fresh wave needs the new obstacle snapshot.
	for destination in _get_kitchen_gate_candidates():
		var cell := _get_navigation_cell(bounds.position, cell_size, grid_size, destination)
		cell = _find_connected_cell(grid, bounds.position, cell_size, cell, destination, [])
		if cell.x >= 0 and _is_navigation_point_walkable(destination, null):
			navigation_cache.get_gate_path(bounds, cell, cell)

func _find_connected_cell(grid: AStarGrid2D, grid_origin: Vector2, cell_size: float, cell: Vector2i, point: Vector2, exclude: Array) -> Vector2i:
	for radius in range(3):
		for y in range(-radius, radius + 1):
			for x in range(-radius, radius + 1):
				if maxi(absi(x), absi(y)) != radius:
					continue
				var candidate := cell + Vector2i(x, y)
				if not grid.region.has_point(candidate):
					continue
				if grid.is_point_solid(candidate):
					var candidate_point := _get_navigation_cell_center(grid_origin, cell_size, candidate)
					if not _is_navigation_point_walkable(candidate_point, null, null, exclude):
						continue
				if not _segment_blocked(point, _get_navigation_cell_center(grid_origin, cell_size, candidate), exclude):
					return candidate
	return Vector2i(-1, -1)

func _get_navigation_cell(grid_origin: Vector2, cell_size: float, grid_size: Vector2i, position: Vector2) -> Vector2i:
	var local := (position - grid_origin) / cell_size
	return Vector2i(
		clampi(int(floor(local.x)), 0, grid_size.x - 1),
		clampi(int(floor(local.y)), 0, grid_size.y - 1)
	)

func _get_navigation_cell_center(grid_origin: Vector2, cell_size: float, cell: Vector2i) -> Vector2:
	return grid_origin + (Vector2(cell) + Vector2(0.5, 0.5)) * cell_size

func _is_navigation_point_walkable(point: Vector2, scarab: Node2D, target: Node2D = null, exclude: Array = []) -> bool:
	if not _is_scarab_travel_zone(point):
		return false
	var world_2d: World2D = runtime_root.get_world_2d() if runtime_root is CanvasItem else get_viewport().world_2d
	if world_2d == null:
		return true
	# Thousands of snapshot probes share one shape/query instead of creating
	# and destroying physics-server resources for every grid cell.
	if not is_equal_approx(navigation_probe_shape.radius, maxf(navigation_clearance, 1.0)):
		navigation_probe_shape.radius = maxf(navigation_clearance, 1.0)
	if navigation_probe.shape != navigation_probe_shape:
		navigation_probe.shape = navigation_probe_shape
	navigation_probe.transform = Transform2D(0.0, point)
	navigation_probe.collision_mask = 4 | 8 | 16
	navigation_probe.exclude = exclude
	return world_2d.direct_space_state.intersect_shape(navigation_probe, 1).is_empty()

func _segment_blocked(from_point: Vector2, to_point: Vector2, exclude: Array) -> bool:
	var world_2d: World2D = runtime_root.get_world_2d() if runtime_root is CanvasItem else get_viewport().world_2d
	if world_2d == null:
		return false
	if prototype_map != null and prototype_map.has_method("is_segment_blocked_by_dune_wall"):
		if prototype_map.is_segment_blocked_by_dune_wall(from_point, to_point, Vector2(navigation_clearance, navigation_clearance)):
			return true
	var query := PhysicsShapeQueryParameters2D.new()
	var shape := CircleShape2D.new()
	shape.radius = navigation_clearance
	query.shape = shape
	query.transform = Transform2D(0.0, from_point)
	query.motion = to_point - from_point
	query.collision_mask = 4 | 8 | 16
	query.exclude = exclude
	var fractions := world_2d.direct_space_state.cast_motion(query)
	return fractions[0] < 0.999

func _route_incoming_scarab(scarab: ScarabEnemy) -> bool:
	if not boss_scarab_mode:
		return false
	if _is_in_kitchen(scarab.global_position):
		_show_scarab_warning("圣甲虫已进入料理区！它会偷取地面食材或食材柜库存。")
		if scarab.current_target_kind == &"entry":
			scarab.clear_target()
		return false
	if scarab.current_target_kind == &"entry" and is_instance_valid(scarab.current_target) and not scarab.is_navigation_stuck():
		return true
	navigation_retry_times[scarab.get_instance_id()] = navigation_clock + (0.8 if is_instance_valid(scarab.current_target) else 0.2)
	# Aim just inside the gate, and try alternatives if movable objects block it.
	for destination in _get_kitchen_gate_candidates():
		var route := _build_route_to_position(scarab, destination, [scarab], false, true)
		if not route.is_empty():
			# Each scarab owns its destination: one replanning actor cannot move
			# another actor's target while it is following an existing route.
			var entry := scarab.get_node_or_null("KitchenEntry") as Node2D
			if entry == null:
				entry = Node2D.new()
				entry.name = "KitchenEntry"
				entry.top_level = true
				scarab.add_child(entry)
			entry.global_position = destination
			scarab.set_target(entry, &"entry", route)
			break
	return true

func _show_scarab_warning(message: String) -> void:
	if warning_remaining > 0.0 or level_refs == null:
		return
	var flow := level_refs.get_level_flow_controller()
	if flow != null and flow.overlay_controller != null and flow.overlay_controller.has_method("show_toast"):
		flow.overlay_controller.show_toast(message, 3.5)
		warning_remaining = 3.5

func _get_kitchen_gate_candidates() -> Array[Vector2]:
	var bounds: Rect2 = prototype_map.get_kitchen_zone_bounds()
	var gate := Vector2(bounds.get_center().x, bounds.position.y)
	return [gate + Vector2(0, 180), gate + Vector2(-64, 220), gate + Vector2(64, 220), gate + Vector2(0, 300)]

func _first_blocker(from_point: Vector2, to_point: Vector2, exclude: Array, collision_mask: int = 4 | 8 | 16) -> Node:
	var world_2d: World2D = runtime_root.get_world_2d() if runtime_root is CanvasItem else get_viewport().world_2d
	if world_2d == null:
		return null
	var query := PhysicsRayQueryParameters2D.create(from_point, to_point)
	query.collision_mask = collision_mask
	query.exclude = exclude
	var result := world_2d.direct_space_state.intersect_ray(query)
	return result.get("collider")

func _on_scarab_steal_action_finished(scarab: Node, target: Node, target_kind: StringName) -> void:
	if not is_instance_valid(scarab) or scarab.get_state() != ScarabEnemy.State.SEARCHING:
		return
	if not is_instance_valid(target):
		return
	if target_kind == &"ground":
		if not _is_player_interactable(target) or not target.has_method("get_item_id"):
			return
		if not _can_reach_ground(scarab, target, scarab.global_position):
			return
		var ground_item_id: StringName = target.get_item_id()
		if ground_item_id == &"":
			return
		target.queue_free()
		scarab.add_stolen_item(ground_item_id)
		return
	if target_kind == &"cabinet":
		if not _is_player_interactable(target):
			scarab.clear_target()
			_update_single_scarab_target(scarab)
			return
		_steal_from_cabinet(scarab, target)

func _steal_from_cabinet(scarab: Node, cabinet: Node) -> void:
	var item_id := StringName(cabinet.get("stored_item_id"))
	if scarab.get_stolen_count() < scarab.stolen_limit and _is_cabinet_approach_valid(scarab) and scarab.global_position.distance_to(scarab.target_approach_position) <= 8.0 and storage_manager.consume_reserved_stock(scarab, item_id):
		scarab.add_stolen_item(item_id)
	storage_manager.release_stock_reservation(scarab)
func _on_scarab_defeated(scarab: Node, items: Array[StringName], defeat_position: Vector2) -> void:
	navigation_retry_times.erase(scarab.get_instance_id())
	escape_search_retry_times.erase(scarab.get_instance_id())
	_spawn_stolen_items(items, defeat_position)
	if progression_state != null and progression_state.has_method("add_xp"):
		progression_state.add_xp(death_experience_reward)

func _on_scarab_escape_finished(scarab: Node) -> void:
	navigation_retry_times.erase(scarab.get_instance_id())
	escape_search_retry_times.erase(scarab.get_instance_id())
	if boss_scarab_mode:
		for boss in get_tree().get_nodes_in_group("scorpion_bosses"):
			if is_instance_valid(boss) and boss.has_method("receive_scarab_escape"):
				boss.receive_scarab_escape(scarab.get_stolen_count())
	if is_instance_valid(scarab):
		scarab.queue_free()

func _spawn_stolen_items(items: Array[StringName], position: Vector2) -> void:
	if runtime_root == null:
		_resolve_scene_refs()
	if runtime_root == null:
		return
	for item_id in items:
		var item: Node2D = LOOSE_ITEM_SCENE.instantiate()
		runtime_root.add_child(item)
		item.global_position = position + Vector2(rng.randf_range(-28.0, 28.0), rng.randf_range(-28.0, 28.0))
		if item.has_method("setup_item"):
			item.setup_item(item_id, TestItemDefs.get_item_texture(item_id), TestItemDefs.PROCESS_STATE_NONE)

func _is_in_kitchen(position: Vector2) -> bool:
	return prototype_map == null or not prototype_map.has_method("is_point_in_kitchen_zone") or bool(prototype_map.is_point_in_kitchen_zone(position))

func _is_scarab_spawn_zone(position: Vector2) -> bool:
	if boss_scarab_mode and prototype_map != null and prototype_map.has_method("is_point_in_battle_zone"):
		return prototype_map.get_battle_region_for_point(position) == &"top" and bool(prototype_map.is_point_in_battle_zone(position, Vector2(34.0, 34.0)))
	return _is_in_kitchen(position)

func _is_scarab_travel_zone(position: Vector2) -> bool:
	if boss_scarab_mode and prototype_map != null and prototype_map.has_method("is_point_in_playable_area"):
		# Shrinking each region separately creates an artificial gap across gates.
		return prototype_map.is_point_in_playable_area(position) and not prototype_map.is_segment_blocked_by_dune_wall(position, position, Vector2(navigation_clearance, navigation_clearance))
	return _is_in_kitchen(position)

func _get_active_scarab_count() -> int:
	var count := 0
	for scarab in get_tree().get_nodes_in_group("scarab_enemies"):
		if is_instance_valid(scarab):
			count += 1
	return count

func get_scarab_limit() -> int:
	if boss_scarab_mode and is_inside_tree() and _get_living_scorpion() != null:
		return maxi(boss_burst_capacity, boss_burst_count)
	var limit := max_active_scarabs
	if boss_scarab_mode and is_inside_tree():
		for boss in get_tree().get_nodes_in_group("scorpion_bosses"):
			if is_instance_valid(boss) and not boss.is_dead:
				limit += maxi(boss.scorpion_scarab_bonus, 0)
	return limit

func _reset_spawn_timer() -> void:
	spawn_remaining = rng.randf_range(minf(spawn_interval_min, spawn_interval_max), maxf(spawn_interval_min, spawn_interval_max))

func _contains_mechanism(values: Array, wanted: StringName) -> bool:
	for value in values:
		if StringName(value) == wanted:
			return true
	return false
