extends Node2D

const TestItemDefs = preload("res://Scripts/Kitchen/TestItemDefs.gd")
const IngredientSourceDefs = preload("res://Scripts/Core/IngredientSourceDefs.gd")
const LevelRefs = preload("res://Scripts/Core/LevelRefs.gd")
const LevelContext = preload("res://Scripts/Core/LevelContext.gd")
const FORAGE_POINT_SCENE := preload("res://Scenes/Forage/forage_point.tscn")
const BATTLE_SOURCE_SIGN_SCENE := preload("res://Scripts/Forage/BattleSourceSign.gd")

@export var region_id: StringName = &"near"
@export var display_name: String = "采集区"
@export var forage_item_ids: Array[StringName] = [TestItemDefs.VEG_LEAF_ID, TestItemDefs.RICE_ID, TestItemDefs.EGG_ID]
@export var max_active_points: int = 4
@export var initial_spawn_count: int = 3
@export var spawn_interval_min: float = 5.0
@export var spawn_interval_max: float = 7.0
@export var search_duration: float = 3.0
@export var selection_duration: float = 1.0
@export var point_padding: Vector2 = Vector2(72, 72)
@export var point_min_distance: float = 112.0
@export var spawn_attempts: int = 18
@export var body_color: Color = Color(0.52, 0.38, 0.18, 1.0)
@export var body_highlight_color: Color = Color(0.82, 0.64, 0.28, 1.0)
@export var accent_color: Color = Color(0.18, 0.62, 0.28, 1.0)
@export var show_source_signs: bool = true

var active_points: Array[Node2D] = []
var spawn_timer: float = 0.0
var level_refs: LevelRefs
var prototype_map: Node
var level_flow_controller: Node
var was_daytime_active: bool = false
var rng := RandomNumberGenerator.new()

func _ready() -> void:
	rng.randomize()
	_resolve_refs()
	if show_source_signs:
		_build_source_signs()
	if _is_daytime_active():
		_spawn_initial_points()
		was_daytime_active = true
	_reset_spawn_timer()

func _build_source_signs() -> void:
	var old_root := get_node_or_null("SourceSignRoot")
	if old_root != null:
		old_root.queue_free()
	if region_id == &"top" or prototype_map == null or not prototype_map.has_method("get_source_sign_mount_rect"):
		return
	var root := Node2D.new()
	root.name = "SourceSignRoot"
	add_child(root)
	for source_kind: StringName in [&"forage", &"battle"]:
		var mount_rect: Rect2 = prototype_map.get_source_sign_mount_rect(region_id, source_kind)
		if not mount_rect.has_area() or (source_kind == &"forage" and forage_item_ids.is_empty()):
			continue
		var board := BATTLE_SOURCE_SIGN_SCENE.new()
		board.name = "ForageBoard" if source_kind == &"forage" else "BattleBoard"
		board.source_kind = source_kind
		board.forage_item_ids = forage_item_ids.duplicate()
		board.battle_entries = IngredientSourceDefs.get_enemy_drop_entries(region_id)
		# Keep the board face and every icon upright. The near-zone mount is
		# compacted to a square board instead of rotating its contents sideways.
		board.board_size = Vector2(minf(mount_rect.size.x, 620.0), minf(mount_rect.size.y, 220.0))
		board.rotation = 0.0
		var region_bounds: Rect2 = prototype_map.get_region_bounds(region_id)
		var toward_region := region_bounds.get_center() - mount_rect.get_center()
		board.region_direction = toward_region.normalized()
		root.add_child(board)
		board.global_position = mount_rect.get_center()

func _process(delta: float) -> void:
	_prune_points()
	var is_daytime_active := _is_daytime_active()
	if not is_daytime_active:
		if was_daytime_active or not active_points.is_empty():
			_clear_points()
		was_daytime_active = false
		return
	if not was_daytime_active:
		_spawn_initial_points()
		_reset_spawn_timer()
		was_daytime_active = true
	if active_points.size() >= max_active_points:
		return

	spawn_timer = maxf(spawn_timer - delta, 0.0)
	if spawn_timer > 0.0:
		return

	_try_spawn_point()
	_reset_spawn_timer()

func _try_spawn_point() -> void:
	if active_points.size() >= max_active_points:
		return
	if forage_item_ids.is_empty():
		return
	if prototype_map == null:
		_resolve_refs()
	if prototype_map == null or not prototype_map.has_method("get_random_point_in_region"):
		return

	var spawn_position := _find_spawn_position()
	if spawn_position == Vector2.INF:
		return

	var point: Node2D = FORAGE_POINT_SCENE.instantiate()
	add_child(point)
	point.global_position = spawn_position
	point.set("display_name", display_name)
	point.set("forage_item_ids", forage_item_ids.duplicate())
	point.set("search_duration", search_duration)
	point.set("selection_duration", selection_duration)
	point.set("cooldown_duration", 0.0)
	point.set("body_color", body_color)
	point.set("body_highlight_color", body_highlight_color)
	point.set("accent_color", accent_color)
	point.set("remove_after_attempt", true)
	if point.has_signal("forage_finished"):
		point.forage_finished.connect(_on_point_finished)
	active_points.append(point)

func _find_spawn_position() -> Vector2:
	var best_position := Vector2.INF
	var best_score := -INF
	for _i in range(maxi(spawn_attempts, 1)):
		var candidate: Vector2 = prototype_map.get_random_point_in_region(region_id, point_padding)
		var quicksand_controller: Node = level_refs.get_quicksand_mechanism_controller() if level_refs != null else null
		if quicksand_controller != null and quicksand_controller.has_method("is_position_blocked_for_forage") and quicksand_controller.is_position_blocked_for_forage(candidate, 60.0):
			continue
		var nearest_distance := INF
		for point in active_points:
			if is_instance_valid(point):
				nearest_distance = minf(nearest_distance, candidate.distance_to(point.global_position))
		if nearest_distance < point_min_distance:
			continue
		var score := nearest_distance if nearest_distance < INF else 9999.0
		score += rng.randf_range(0.0, 64.0)
		if score > best_score:
			best_score = score
			best_position = candidate
	return best_position

func _reset_spawn_timer() -> void:
	spawn_timer = rng.randf_range(minf(spawn_interval_min, spawn_interval_max), maxf(spawn_interval_min, spawn_interval_max))

func _spawn_initial_points() -> void:
	for _i in range(mini(maxi(initial_spawn_count, 0), maxi(max_active_points - active_points.size(), 0))):
		_try_spawn_point()

func _prune_points() -> void:
	for i in range(active_points.size() - 1, -1, -1):
		if not is_instance_valid(active_points[i]):
			active_points.remove_at(i)

func _on_point_finished(point: Node, _success: bool) -> void:
	for i in range(active_points.size() - 1, -1, -1):
		if active_points[i] == point or not is_instance_valid(active_points[i]):
			active_points.remove_at(i)

func _clear_points() -> void:
	for point in active_points:
		if is_instance_valid(point):
			if point.has_method("prepare_for_removal"):
				point.prepare_for_removal()
			point.queue_free()
	active_points.clear()

func _is_daytime_active() -> bool:
	if level_flow_controller == null:
		_resolve_refs()
	if level_flow_controller == null or not level_flow_controller.has_method("get_current_level_state"):
		return false
	var state_value: int = int(level_flow_controller.get_current_level_state())
	return state_value in [
		LevelContext.LevelState.PREPARE_PHASE,
		LevelContext.LevelState.WAVE_ACTIVE,
		LevelContext.LevelState.WAVE_BREAK
	]

func _resolve_refs() -> void:
	level_refs = LevelRefs.find_from(self)
	if level_refs != null:
		prototype_map = level_refs.get_prototype_map()
		level_flow_controller = level_refs.get_level_flow_controller()
