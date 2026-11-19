class_name WindSandMechanismController
extends Node

const MapMechanismDefs = preload("res://Scripts/Core/MapMechanismDefs.gd")
const LevelRefs = preload("res://Scripts/Core/LevelRefs.gd")
const WIND_PAD_SCENE := preload("res://Scenes/Hazards/wind_sand_pad.tscn")

@export var spawn_interval_min: float = 6.0
@export var spawn_interval_max: float = 11.0
@export var max_active_pads: int = 3
@export var spawn_distance_min: float = 220.0
@export var spawn_distance_max: float = 620.0
@export var spawn_attempts: int = 24
@export var launch_path_padding: float = 24.0
@export var launch_distance: float = 620.0
@export var launch_distance_randomness: float = 0.1

var level_refs: LevelRefs
var prototype_map: Node
var runtime_root: Node
var active: bool = false
var spawn_remaining: float = 0.0
var rng := RandomNumberGenerator.new()

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	rng.randomize()
	_resolve_refs()

func _process(delta: float) -> void:
	if not active:
		return
	_resolve_refs()
	_prune_pads()
	spawn_remaining = maxf(spawn_remaining - delta, 0.0)
	if spawn_remaining > 0.0 or _get_active_pad_count() >= max_active_pads:
		return
	_spawn_near_player()
	_reset_spawn_timer()

func configure_for_level(group_data: Dictionary) -> void:
	var ids: Variant = group_data.get("map_mechanism_ids", [])
	active = ids is Array and _contains_mechanism(ids, MapMechanismDefs.SANDSTORM)
	if not active:
		stop_gameplay()

func start_gameplay() -> void:
	if not active:
		return
	_resolve_refs()
	_reset_spawn_timer()

func stop_gameplay() -> void:
	active = false
	if not is_inside_tree():
		return
	for pad in get_tree().get_nodes_in_group("wind_sand_pads"):
		if is_instance_valid(pad):
			pad.queue_free()
	for hazard in get_tree().get_nodes_in_group("boss_storm_hazards"):
		if is_instance_valid(hazard):
			hazard.queue_free()
	for player in get_tree().get_nodes_in_group("player"):
		if player.get("storm_controller") != null:
			player.storm_controller.reset()

func _resolve_refs() -> void:
	level_refs = LevelRefs.find_from(self)
	if level_refs == null:
		return
	prototype_map = level_refs.get_prototype_map()
	runtime_root = level_refs.get_runtime_root()

func _spawn_near_player() -> void:
	if runtime_root == null or prototype_map == null:
		return
	var player: CharacterBody2D = get_tree().get_first_node_in_group("player") as CharacterBody2D
	if not is_instance_valid(player):
		return
	var spawn_data := _find_near_player_spawn_data(player)
	if spawn_data.is_empty():
		return
	var pad: Node2D = WIND_PAD_SCENE.instantiate()
	if pad.has_method("configure_direction"):
		pad.configure_direction(int(spawn_data.get("direction_index", 0)))
	runtime_root.add_child(pad)
	pad.global_position = spawn_data.get("position", Vector2.ZERO)

func _find_near_player_spawn_data(player: CharacterBody2D) -> Dictionary:
	var player_position := player.global_position
	for _i in range(maxi(spawn_attempts, 1)):
		var angle := rng.randf_range(0.0, TAU)
		var distance := rng.randf_range(spawn_distance_min, spawn_distance_max)
		var candidate := player_position + Vector2.RIGHT.rotated(angle) * distance
		if not prototype_map.has_method("is_point_in_playable_area") or not prototype_map.is_point_in_playable_area(candidate, Vector2(72.0, 72.0)):
			continue
		if _is_near_other_pad(candidate):
			continue
		if _is_blocked_by_facility(candidate):
			continue
		var valid_directions: Array[int] = []
		for direction_index in range(8):
			var direction := Vector2.RIGHT.rotated(TAU * float(direction_index) / 8.0)
			if _is_launch_path_clear(player, candidate, direction):
				valid_directions.append(direction_index)
		if not valid_directions.is_empty():
			return {
				"position": candidate,
				"direction_index": valid_directions[rng.randi_range(0, valid_directions.size() - 1)]
			}
	return {}

func _is_launch_path_clear(player: CharacterBody2D, start_position: Vector2, direction: Vector2) -> bool:
	var max_distance := launch_distance * (1.0 + absf(launch_distance_randomness))
	var target_position := start_position + direction * max_distance
	if prototype_map.has_method("clamp_point_to_playable_from"):
		var clamped_target: Vector2 = prototype_map.clamp_point_to_playable_from(target_position, start_position, Vector2(launch_path_padding, launch_path_padding))
		if clamped_target.distance_to(target_position) > 1.0:
			return false
	elif prototype_map.has_method("is_point_in_playable_area") and not prototype_map.is_point_in_playable_area(target_position, Vector2(launch_path_padding, launch_path_padding)):
		return false
	var launch_transform := Transform2D(player.global_rotation, start_position)
	return not player.test_move(launch_transform, direction * max_distance)

func _is_near_other_pad(position: Vector2) -> bool:
	for pad in get_tree().get_nodes_in_group("wind_sand_pads"):
		if is_instance_valid(pad) and pad is Node2D and position.distance_to(pad.global_position) < 160.0:
			return true
	return false

func _is_blocked_by_facility(position: Vector2) -> bool:
	var world_2d: World2D = runtime_root.get_world_2d() if runtime_root is CanvasItem else get_viewport().world_2d
	if world_2d == null:
		return true
	var shape := RectangleShape2D.new()
	shape.size = Vector2(116.0, 116.0)
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.transform = Transform2D(0.0, position)
	query.collision_mask = 4 | 16
	for hit in world_2d.direct_space_state.intersect_shape(query, 16):
		var collider: Node = hit.get("collider", null)
		if collider != null and not collider.is_in_group("wind_sand_pads"):
			return true
	return false

func _prune_pads() -> void:
	for pad in get_tree().get_nodes_in_group("wind_sand_pads"):
		if not is_instance_valid(pad):
			continue
		if prototype_map != null and prototype_map.has_method("is_point_in_playable_area") and not prototype_map.is_point_in_playable_area(pad.global_position):
			pad.queue_free()

func _get_active_pad_count() -> int:
	var count := 0
	for pad in get_tree().get_nodes_in_group("wind_sand_pads"):
		if is_instance_valid(pad):
			count += 1
	return count

func _reset_spawn_timer() -> void:
	spawn_remaining = rng.randf_range(minf(spawn_interval_min, spawn_interval_max), maxf(spawn_interval_min, spawn_interval_max))

func _contains_mechanism(values: Array, wanted: StringName) -> bool:
	for value in values:
		if StringName(value) == wanted:
			return true
	return false
