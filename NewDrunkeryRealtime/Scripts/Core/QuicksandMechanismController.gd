class_name QuicksandMechanismController
extends Node

const MapMechanismDefs = preload("res://Scripts/Core/MapMechanismDefs.gd")
const LevelRefs = preload("res://Scripts/Core/LevelRefs.gd")
const QUICKSAND_SCENE := preload("res://Scenes/Hazards/quicksand_hazard.tscn")

@export var spawn_interval_min: float = 7.0
@export var spawn_interval_max: float = 12.0
@export var lifetime_min: float = 6.0
@export var lifetime_max: float = 10.0
@export var max_active_per_region: int = 2
@export var spawn_padding: Vector2 = Vector2(300.0, 300.0)
@export var forage_exclusion_margin: float = 60.0
@export var spawn_distance_min: float = 260.0
@export var spawn_distance_max: float = 680.0
@export var player_spawn_attempts: int = 24
@export var boss_radius: float = 400.0
@export var boss_warning_duration: float = 0.8
@export var boss_spawn_pull_distance: float = 180.0
@export var kitchen_boss_radius: float = 160.0
@export var kitchen_boss_warning_duration: float = 0.8
@export var kitchen_boss_pull_distance: float = 90.0
@export var kitchen_boss_lifetime: float = 8.0
@export var kitchen_boss_interval: float = 24.0
@export var kitchen_boss_first_delay: float = 6.0
@export var kitchen_boss_pool_count: int = 2

var level_refs: LevelRefs
var prototype_map: Node
var runtime_root: Node
var level_flow_controller: Node
var active: bool = false
var spawn_remaining: float = 0.0
var rng := RandomNumberGenerator.new()
var kitchen_boss_owner: Node2D
var kitchen_spawn_remaining: float = 0.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	rng.randomize()
	_resolve_refs()

func _process(delta: float) -> void:
	if not active:
		return
	_resolve_refs()
	_prune_hazards()
	_tick_kitchen_pressure(delta)
	spawn_remaining = maxf(spawn_remaining - delta, 0.0)
	if spawn_remaining > 0.0:
		return
	_spawn_one_if_possible()
	_reset_spawn_timer()

func configure_for_level(group_data: Dictionary) -> void:
	var ids: Variant = group_data.get("map_mechanism_ids", [])
	active = ids is Array and _contains_mechanism(ids, MapMechanismDefs.QUICKSAND)
	if not active:
		stop_gameplay()

func start_gameplay() -> void:
	if not active:
		return
	_resolve_refs()
	_reset_spawn_timer()

func stop_gameplay() -> void:
	active = false
	kitchen_boss_owner = null
	kitchen_spawn_remaining = 0.0
	if not is_inside_tree():
		return
	for hazard in get_tree().get_nodes_in_group("quicksand_hazards"):
		if is_instance_valid(hazard):
			hazard.queue_free()
	for tail in get_tree().get_nodes_in_group("sandworm_tail_strikes"):
		if is_instance_valid(tail):
			tail.queue_free()

func is_position_blocked_for_forage(position: Vector2, extra_margin: float = 0.0) -> bool:
	for hazard in get_tree().get_nodes_in_group("quicksand_hazards"):
		if is_instance_valid(hazard) and hazard.has_method("is_position_blocked_for_forage"):
			if bool(hazard.is_position_blocked_for_forage(position, extra_margin)):
				return true
	return false

func _resolve_refs() -> void:
	level_refs = LevelRefs.find_from(self)
	if level_refs == null:
		return
	prototype_map = level_refs.get_prototype_map()
	runtime_root = level_refs.get_runtime_root()
	level_flow_controller = level_refs.get_level_flow_controller()

func _spawn_one_if_possible() -> void:
	if runtime_root == null or prototype_map == null:
		return
	for region_id in prototype_map.get_battle_region_ids():
		if _get_region_hazard_count(region_id) >= max_active_per_region:
			continue
		var boss := _get_region_boss(region_id)
		var hazard_radius := boss_radius if boss != null else 270.0
		var position := _find_spawn_position(region_id, hazard_radius)
		if position == Vector2.INF:
			continue
		_create_hazard(position, boss)
		return

func _get_region_boss(region_id: StringName) -> Node2D:
	for boss in get_tree().get_nodes_in_group("sandworm_bosses"):
		if is_instance_valid(boss) and not boss.is_dead and prototype_map.get_battle_region_for_point(boss.global_position) == region_id:
			return boss as Node2D
	return null

func spawn_boss_quicksand(boss: Node2D) -> bool:
	_resolve_refs()
	if not active or runtime_root == null or prototype_map == null or not is_instance_valid(boss) or boss.is_dead:
		return false
	var region_id: StringName = prototype_map.get_battle_region_for_point(boss.global_position)
	if _get_region_hazard_count(region_id) >= max_active_per_region:
		return false
	var position := _find_spawn_position(region_id, boss_radius, true)
	if position == Vector2.INF:
		return false
	_create_hazard(position, boss)
	_reset_spawn_timer()
	return true

func _create_hazard(position: Vector2, boss: Node2D) -> void:
	var hazard: Node2D = QUICKSAND_SCENE.instantiate()
	hazard.lifetime = rng.randf_range(minf(lifetime_min, lifetime_max), maxf(lifetime_min, lifetime_max))
	if is_instance_valid(boss):
		hazard.configure_boss(boss, boss_radius, boss_warning_duration, boss_spawn_pull_distance)
	# Configure before _ready so lifetime and warning use the selected values.
	hazard.position = runtime_root.to_local(position) if runtime_root is Node2D else position
	runtime_root.add_child(hazard)

func spawn_tail_quicksand(boss: Node2D, point: Vector2, pool_radius: float) -> bool:
	_resolve_refs()
	if not active or runtime_root == null or not is_instance_valid(boss) or boss.is_dead or boss.is_queued_for_deletion():
		return false
	if prototype_map == null or not prototype_map.is_point_in_battle_zone(point):
		return false
	var hazard: Node2D = QUICKSAND_SCENE.instantiate()
	hazard.transient_boss_hazard = true
	hazard.lifetime = 4.0
	hazard.configure_boss(boss, pool_radius, 0.8, 0.0)
	hazard.position = runtime_root.to_local(point) if runtime_root is Node2D else point
	runtime_root.add_child(hazard)
	return true

func _tick_kitchen_pressure(delta: float) -> void:
	if runtime_root == null or prototype_map == null:
		return
	var living_boss: Node2D
	for boss in get_tree().get_nodes_in_group("sandworm_bosses"):
		if is_instance_valid(boss) and not boss.is_dead and not boss.is_queued_for_deletion():
			living_boss = boss as Node2D
			break
	if living_boss == null:
		kitchen_boss_owner = null
		return
	if kitchen_boss_owner != living_boss:
		kitchen_boss_owner = living_boss
		kitchen_spawn_remaining = kitchen_boss_first_delay
	kitchen_spawn_remaining = maxf(kitchen_spawn_remaining - delta, 0.0)
	if kitchen_spawn_remaining > 0.0:
		return
	var count := 0
	for hazard in get_tree().get_nodes_in_group("quicksand_hazards"):
		if is_instance_valid(hazard) and not hazard.is_queued_for_deletion() and hazard.kitchen_boss_hazard:
			count += 1
	var spawned := false
	for index in range(count, kitchen_boss_pool_count):
		var position := _find_kitchen_spawn_position(index == 0)
		if position == Vector2.INF:
			continue
		var hazard: Node2D = QUICKSAND_SCENE.instantiate()
		hazard.kitchen_boss_hazard = true
		hazard.lifetime = kitchen_boss_lifetime
		hazard.configure_boss(living_boss, kitchen_boss_radius, kitchen_boss_warning_duration, kitchen_boss_pull_distance)
		hazard.position = runtime_root.to_local(position) if runtime_root is Node2D else position
		runtime_root.add_child(hazard)
		spawned = true
	kitchen_spawn_remaining = kitchen_boss_interval if spawned else 1.0

func _find_kitchen_spawn_position(near_player: bool) -> Vector2:
	var bounds: Rect2 = prototype_map.get_kitchen_zone_bounds().grow(-kitchen_boss_radius)
	if bounds.size.x <= 0.0 or bounds.size.y <= 0.0:
		return Vector2.INF
	var player: Node2D = get_tree().get_first_node_in_group("player") as Node2D
	var stations := get_tree().get_nodes_in_group("cooking_stations")
	var shape := CircleShape2D.new()
	shape.radius = 28.0
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.collision_mask = 4 | 8 | 16
	for attempt in range(48):
		var candidate := Vector2(rng.randf_range(bounds.position.x, bounds.end.x), rng.randf_range(bounds.position.y, bounds.end.y))
		if attempt < 24:
			var offset := Vector2.RIGHT.rotated(rng.randf_range(0.0, TAU)) * rng.randf_range(70.0, 120.0)
			if near_player and is_instance_valid(player) and prototype_map.is_point_in_kitchen_zone(player.global_position):
				candidate = player.global_position + offset
			elif not stations.is_empty():
				var station: Node = stations[rng.randi_range(0, stations.size() - 1)]
				if station.has_method("get_pickup_drop_positions"):
					var positions: Array[Vector2] = station.get_pickup_drop_positions()
					if not positions.is_empty():
						candidate = positions[rng.randi_range(0, positions.size() - 1)] + offset
		if not bounds.has_point(candidate):
			continue
		if is_position_blocked_for_forage(candidate, kitchen_boss_radius + 24.0):
			continue
		query.transform = Transform2D(0.0, candidate)
		if not prototype_map.get_world_2d().direct_space_state.intersect_shape(query, 1).is_empty():
			continue
		return candidate
	return Vector2.INF

func _find_spawn_position(region_id: StringName, hazard_radius: float = 270.0, near_player: bool = false) -> Vector2:
	if not prototype_map.has_method("get_random_point_in_region"):
		return Vector2.INF
	var player: Node2D = get_tree().get_first_node_in_group("player") as Node2D
	for _i in range(maxi(player_spawn_attempts, 1)):
		var candidate: Vector2
		if is_instance_valid(player):
			var angle := rng.randf_range(0.0, TAU)
			var distance := rng.randf_range(180.0, hazard_radius * 0.85) if near_player else rng.randf_range(spawn_distance_min, spawn_distance_max)
			candidate = player.global_position + Vector2.RIGHT.rotated(angle) * distance
			if prototype_map.has_method("get_battle_region_for_point") and prototype_map.get_battle_region_for_point(candidate) != region_id:
				continue
			if prototype_map.has_method("is_point_in_battle_zone") and not prototype_map.is_point_in_battle_zone(candidate, Vector2.ONE * hazard_radius):
				continue
		else:
			candidate = prototype_map.get_random_point_in_region(region_id, Vector2.ONE * hazard_radius)
		if not prototype_map.is_point_in_battle_zone(candidate, Vector2.ONE * hazard_radius):
			continue
		if is_position_blocked_for_forage(candidate, hazard_radius + forage_exclusion_margin):
			continue
		if _is_near_forage_point(candidate, hazard_radius):
			continue
		if _is_near_other_hazard(candidate, region_id):
			continue
		return candidate
	return Vector2.INF

func _is_near_forage_point(position: Vector2, hazard_radius: float = 270.0) -> bool:
	for point in get_tree().get_nodes_in_group("forage_points"):
		if is_instance_valid(point) and point is Node2D and position.distance_to(point.global_position) <= hazard_radius + forage_exclusion_margin + 100.0:
			return true
	return false

func _is_near_other_hazard(position: Vector2, region_id: StringName) -> bool:
	for hazard in get_tree().get_nodes_in_group("quicksand_hazards"):
		if not is_instance_valid(hazard) or not hazard is Node2D:
			continue
		if prototype_map.has_method("get_battle_region_for_point") and prototype_map.get_battle_region_for_point(hazard.global_position) != region_id:
			continue
		var radius := float(hazard.get("radius")) if hazard.get("radius") != null else 270.0
		if position.distance_to(hazard.global_position) <= radius * 1.15:
			return true
	return false

func _get_region_hazard_count(region_id: StringName) -> int:
	var count := 0
	for hazard in get_tree().get_nodes_in_group("quicksand_hazards"):
		if not is_instance_valid(hazard) or not hazard is Node2D:
			continue
		if prototype_map != null and prototype_map.has_method("get_battle_region_for_point") and prototype_map.get_battle_region_for_point(hazard.global_position) == region_id:
			count += 1
	return count

func _prune_hazards() -> void:
	for hazard in get_tree().get_nodes_in_group("quicksand_hazards"):
		if not is_instance_valid(hazard):
			continue
		if hazard.kitchen_boss_hazard and prototype_map != null and prototype_map.is_point_in_kitchen_zone(hazard.global_position):
			continue
		if prototype_map != null and prototype_map.has_method("is_point_in_battle_zone") and not prototype_map.is_point_in_battle_zone(hazard.global_position):
			hazard.queue_free()

func _reset_spawn_timer() -> void:
	spawn_remaining = rng.randf_range(minf(spawn_interval_min, spawn_interval_max), maxf(spawn_interval_min, spawn_interval_max))

func _contains_mechanism(values: Array, wanted: StringName) -> bool:
	for value in values:
		if StringName(value) == wanted:
			return true
	return false
